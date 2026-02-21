import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conversation.dart';
import '../models/message.dart';

abstract class ChatRepository {
  Future<List<Conversation>> getConversations(String userId);
  Future<List<Message>> getMessages(String conversationId, {int limit});
  Future<Message> sendMessage(Message message);
  Future<String> createConversation({
    required String userId,
    required List<String> participantIds,
    String? name,
    bool isGroup,
  });
  Future<void> markAsRead(String conversationId, String userId);
  Future<void> deleteConversation(String conversationId);
  RealtimeChannel subscribeToMessages(
    String conversationId,
    Function(Message) onMessage,
  );
}

class ChatRepositoryImpl implements ChatRepository {
  final SupabaseClient _supabase;

  ChatRepositoryImpl(this._supabase);

  @override
  Future<List<Conversation>> getConversations(String userId) async {
    try {
      final participantRows = await _supabase
          .from('participants')
          .select('conversation_id')
          .eq('user_id', userId);

      final conversationIds = participantRows
          .map<String?>((row) => row['conversation_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      if (conversationIds.isEmpty) return [];

      final conversationsResponse = await _supabase
          .from('conversations')
          .select('conversation_id,conversation_name,is_group,created_at')
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: false);

      List<Conversation> conversations = [];

      for (var convData in conversationsResponse) {
        final conversationId = convData['conversation_id'] as String;

        final lastMsgResponse = await _supabase
            .from('messages')
            .select('content,created_at')
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        String? otherUserName;
        String? otherUserAvatar;
        String? otherUserId;

        if (convData['is_group'] == false) {
          final participantRows = await _supabase
              .from('participants')
              .select('user_id')
              .eq('conversation_id', conversationId)
              .limit(20);

          final participantIds = participantRows
              .map<String?>((row) => row['user_id'] as String?)
              .whereType<String>()
              .toList();

          otherUserId = participantIds.firstWhere(
            (id) => id != userId,
            orElse: () =>
                participantIds.isNotEmpty ? participantIds.first : userId,
          );

          final profile = await _supabase
              .from('profiles')
              .select('display_name,avatar_url')
              .eq('user_id', otherUserId)
              .maybeSingle();
          otherUserName = profile?['display_name'] as String?;
          otherUserAvatar = profile?['avatar_url'] as String?;

          otherUserName ??= await _tryGetDisplayNameFromUsers(otherUserId);
        }

        final unreadCount = await _getUnreadCount(conversationId, userId);

        conversations.add(
          Conversation.fromJson({
            ...convData,
            'last_message': lastMsgResponse?['content'],
            'last_message_at': lastMsgResponse?['created_at'],
            'unread_count': unreadCount,
            'other_user_id': otherUserId,
            'other_user_name': otherUserName,
            'other_user_avatar': otherUserAvatar,
          }),
        );
      }

      return _deduplicateConversations(conversations);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);

      final senderIds = response
          .map<String?>((row) => row['sender_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> profileMap = {};
      if (senderIds.isNotEmpty) {
        final profileRows = await _supabase
            .from('profiles')
            .select('user_id,display_name,avatar_url')
            .inFilter('user_id', senderIds);

        profileMap = {
          for (final row in profileRows) (row['user_id'] as String): row,
        };
      }

      return response.map<Message>((json) {
        final message = Message.fromJson(json);
        final senderId = message.senderId;
        final profile = senderId != null ? profileMap[senderId] : null;
        return message.copyWith(
          senderName: profile?['display_name'] as String?,
          senderAvatar: profile?['avatar_url'] as String?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Message> sendMessage(Message message) async {
    final response = await _supabase
        .from('messages')
        .insert({
          'conversation_id': message.conversationId,
          'sender_id': message.senderId,
          'content': message.content,
          'is_read': false,
        })
        .select()
        .single();
    return Message.fromJson(response);
  }

  @override
  Future<String> createConversation({
    required String userId,
    required List<String> participantIds,
    String? name,
    bool isGroup = false,
  }) async {
    final uniqueParticipantIds = {userId, ...participantIds}.toList();

    if (!isGroup) {
      final targetUserId = uniqueParticipantIds.firstWhere(
        (id) => id != userId,
        orElse: () => userId,
      );
      final existingConversationId = await _findDirectConversationId(
        userId,
        targetUserId,
      );
      if (existingConversationId != null) {
        return existingConversationId;
      }
    }

    final convResponse = await _supabase
        .from('conversations')
        .insert({'conversation_name': name, 'is_group': isGroup})
        .select()
        .single();

    final conversationId = convResponse['conversation_id'] as String;

    final participants = uniqueParticipantIds
        .map((id) => {'conversation_id': conversationId, 'user_id': id})
        .toList();

    await _supabase.from('participants').insert(participants);

    return conversationId;
  }

  @override
  Future<void> markAsRead(String conversationId, String userId) async {
    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId);
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _supabase
        .from('conversations')
        .delete()
        .eq('conversation_id', conversationId);
  }

  @override
  RealtimeChannel subscribeToMessages(
    String conversationId,
    Function(Message) onMessage,
  ) {
    return _supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final message = Message.fromJson(payload.newRecord);
            onMessage(message);
          },
        )
        .subscribe();
  }

  Future<int> _getUnreadCount(String conversationId, String userId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('message_id')
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      return 0;
    }
  }

  List<Conversation> _deduplicateConversations(List<Conversation> source) {
    final deduped = <String, Conversation>{};

    for (final conversation in source) {
      final key = conversation.isGroup
          ? 'group:${conversation.id}'
          : 'direct:${conversation.otherUserId ?? conversation.id}';

      final existing = deduped[key];
      if (existing == null ||
          _conversationSortTime(
            conversation,
          ).isAfter(_conversationSortTime(existing))) {
        deduped[key] = conversation;
      }
    }

    final result = deduped.values.toList();
    result.sort(
      (a, b) => _conversationSortTime(b).compareTo(_conversationSortTime(a)),
    );
    return result;
  }

  DateTime _conversationSortTime(Conversation conversation) {
    return conversation.lastMessageAt ?? conversation.createdAt;
  }

  Future<String?> _findDirectConversationId(
    String userId,
    String otherUserId,
  ) async {
    final participantsOfTwoUsers = await _supabase
        .from('participants')
        .select('conversation_id,user_id')
        .inFilter('user_id', [userId, otherUserId]);

    if (participantsOfTwoUsers.isEmpty) return null;

    final candidateConversationIds = participantsOfTwoUsers
        .map<String?>((row) => row['conversation_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    if (candidateConversationIds.isEmpty) return null;

    final allParticipants = await _supabase
        .from('participants')
        .select('conversation_id,user_id')
        .inFilter('conversation_id', candidateConversationIds);

    final participantsByConversation = <String, Set<String>>{};
    for (final row in allParticipants) {
      final conversationId = row['conversation_id'] as String?;
      final participantUserId = row['user_id'] as String?;
      if (conversationId == null || participantUserId == null) continue;
      participantsByConversation.putIfAbsent(conversationId, () => <String>{});
      participantsByConversation[conversationId]!.add(participantUserId);
    }

    final expectedParticipants = userId == otherUserId
        ? {userId}
        : {userId, otherUserId};

    final directConversations = await _supabase
        .from('conversations')
        .select('conversation_id,created_at')
        .inFilter('conversation_id', candidateConversationIds)
        .eq('is_group', false)
        .order('created_at', ascending: false);

    for (final row in directConversations) {
      final conversationId = row['conversation_id'] as String?;
      if (conversationId == null) continue;
      final participants =
          participantsByConversation[conversationId] ?? <String>{};
      if (_sameUserSet(participants, expectedParticipants)) {
        return conversationId;
      }
    }

    return null;
  }

  Future<String?> _tryGetDisplayNameFromUsers(String userId) async {
    try {
      final userRow = await _supabase
          .from('users')
          .select('display_name,name,email')
          .eq('id', userId)
          .maybeSingle();

      if (userRow == null) return null;

      final displayName = (userRow['display_name'] as String?)?.trim();
      if (displayName != null && displayName.isNotEmpty) return displayName;

      final name = (userRow['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;

      final email = (userRow['email'] as String?)?.trim();
      if (email != null && email.isNotEmpty) {
        return email.split('@').first;
      }
    } catch (_) {}
    return null;
  }

  bool _sameUserSet(Set<String> left, Set<String> right) {
    if (left.length != right.length) return false;
    return left.containsAll(right);
  }
}
