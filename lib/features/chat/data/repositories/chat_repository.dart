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
  Future<void> updateConversationName(String conversationId, String name);
  Future<void> leaveConversation({
    required String conversationId,
    required String userId,
  });
  Future<void> addParticipants({
    required String conversationId,
    required List<String> participantIds,
  });
  Future<void> removeParticipant({
    required String conversationId,
    required String userId,
  });
  Future<void> setConversationPinned({
    required String conversationId,
    required String userId,
    required bool isPinned,
  });
  Future<void> setConversationArchived({
    required String conversationId,
    required String userId,
    required bool isArchived,
  });
  Future<void> updateMessage({
    required String messageId,
    required String content,
  });
  Future<void> deleteMessage(String messageId);
  Future<List<Map<String, dynamic>>> getConversationParticipants(
    String conversationId,
  );
  RealtimeChannel subscribeToMessages(
    String conversationId,
    Function(Message) onMessage,
  );
  RealtimeChannel subscribeToConversationEvents(Function() onChanged);
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

      List<dynamic> preferenceRows = [];
      try {
        preferenceRows = await _supabase
            .from('conversation_preferences')
            .select('conversation_id,is_pinned,is_archived')
            .eq('user_id', userId)
            .inFilter('conversation_id', conversationIds);
      } catch (_) {
        preferenceRows = [];
      }

      final preferenceByConversation = <String, Map<String, dynamic>>{
        for (final row in preferenceRows)
          (row['conversation_id'] as String): row,
      };

      final conversationsResponse = await _loadConversationRows(
        conversationIds,
      );

      final unreadRows = await _supabase
          .from('messages')
          .select('conversation_id')
          .inFilter('conversation_id', conversationIds)
          .neq('sender_id', userId)
          .eq('is_read', false);

      final unreadCountByConversation = <String, int>{};
      for (final row in unreadRows) {
        final conversationId = row['conversation_id'] as String?;
        if (conversationId == null) continue;
        unreadCountByConversation[conversationId] =
            (unreadCountByConversation[conversationId] ?? 0) + 1;
      }

      final allParticipants = await _supabase
          .from('participants')
          .select('conversation_id,user_id')
          .inFilter('conversation_id', conversationIds);

      final participantIdsByConversation = <String, List<String>>{};
      for (final row in allParticipants) {
        final conversationId = row['conversation_id'] as String?;
        final participantUserId = row['user_id'] as String?;
        if (conversationId == null || participantUserId == null) continue;
        participantIdsByConversation.putIfAbsent(
          conversationId,
          () => <String>[],
        );
        participantIdsByConversation[conversationId]!.add(participantUserId);
      }

      final otherUserIds = <String>{};
      for (final convData in conversationsResponse) {
        final isGroup = convData['is_group'] as bool? ?? false;
        if (isGroup) continue;
        final conversationId = convData['conversation_id'] as String?;
        if (conversationId == null) continue;
        final participantIds =
            participantIdsByConversation[conversationId] ?? <String>[];
        final otherUserId = participantIds.firstWhere(
          (id) => id != userId,
          orElse: () => userId,
        );
        if (otherUserId != userId) {
          otherUserIds.add(otherUserId);
        }
      }

      Map<String, Map<String, dynamic>> profileMap = {};
      if (otherUserIds.isNotEmpty) {
        final profileRows = await _supabase
            .from('profiles')
            .select('user_id,display_name,avatar_url')
            .inFilter('user_id', otherUserIds.toList());

        profileMap = {
          for (final row in profileRows) (row['user_id'] as String): row,
        };
      }

      final conversations = <Conversation>[];
      for (final convData in conversationsResponse) {
        final conversationId = convData['conversation_id'] as String;
        String? otherUserName;
        String? otherUserAvatar;
        String? otherUserId;

        if (convData['is_group'] == false) {
          final participantIds =
              participantIdsByConversation[conversationId] ?? <String>[];

          otherUserId = participantIds.firstWhere(
            (id) => id != userId,
            orElse: () =>
                participantIds.isNotEmpty ? participantIds.first : userId,
          );

          final profile = profileMap[otherUserId];
          otherUserName = profile?['display_name'] as String?;
          otherUserAvatar = profile?['avatar_url'] as String?;
          otherUserName ??= await _tryGetDisplayNameFromUsers(otherUserId);
          otherUserName ??= convData['conversation_name'] as String?;
        }

        conversations.add(
          Conversation.fromJson({
            ...convData,
            'unread_count': unreadCountByConversation[conversationId] ?? 0,
            'other_user_id': otherUserId,
            'other_user_name': otherUserName,
            'other_user_avatar': otherUserAvatar,
            'is_pinned':
                preferenceByConversation[conversationId]?['is_pinned'] ?? false,
            'is_archived':
                preferenceByConversation[conversationId]?['is_archived'] ??
                false,
          }),
        );
      }

      return _deduplicateConversations(conversations);
    } catch (_) {
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
    } catch (_) {
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
  Future<void> updateConversationName(
    String conversationId,
    String name,
  ) async {
    await _supabase
        .from('conversations')
        .update({'conversation_name': name.trim()})
        .eq('conversation_id', conversationId);
  }

  @override
  Future<void> leaveConversation({
    required String conversationId,
    required String userId,
  }) async {
    await _supabase
        .from('participants')
        .delete()
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);
  }

  @override
  Future<void> addParticipants({
    required String conversationId,
    required List<String> participantIds,
  }) async {
    if (participantIds.isEmpty) return;

    final existingRows = await _supabase
        .from('participants')
        .select('user_id')
        .eq('conversation_id', conversationId);

    final existingUserIds = existingRows
        .map<String?>((row) => row['user_id'] as String?)
        .whereType<String>()
        .toSet();

    final rowsToInsert = participantIds
        .where((id) => !existingUserIds.contains(id))
        .map((id) => {'conversation_id': conversationId, 'user_id': id})
        .toList();

    if (rowsToInsert.isEmpty) return;
    await _supabase.from('participants').insert(rowsToInsert);
  }

  @override
  Future<void> removeParticipant({
    required String conversationId,
    required String userId,
  }) async {
    await _supabase
        .from('participants')
        .delete()
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);
  }

  @override
  Future<void> setConversationPinned({
    required String conversationId,
    required String userId,
    required bool isPinned,
  }) async {
    await _upsertConversationPreference(
      conversationId: conversationId,
      userId: userId,
      changes: {
        'is_pinned': isPinned,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Future<void> setConversationArchived({
    required String conversationId,
    required String userId,
    required bool isArchived,
  }) async {
    await _upsertConversationPreference(
      conversationId: conversationId,
      userId: userId,
      changes: {
        'is_archived': isArchived,
        if (isArchived) 'is_pinned': false,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Future<void> updateMessage({
    required String messageId,
    required String content,
  }) async {
    await _supabase
        .from('messages')
        .update({'content': content.trim()})
        .eq('message_id', messageId);
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    await _supabase.from('messages').delete().eq('message_id', messageId);
  }

  @override
  Future<List<Map<String, dynamic>>> getConversationParticipants(
    String conversationId,
  ) async {
    final participantRows = await _supabase
        .from('participants')
        .select('user_id,joined_at')
        .eq('conversation_id', conversationId);

    final userIds = participantRows
        .map<String?>((row) => row['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    Map<String, Map<String, dynamic>> profileMap = {};
    if (userIds.isNotEmpty) {
      final profileRows = await _supabase
          .from('profiles')
          .select('user_id,display_name,avatar_url,phone,bio')
          .inFilter('user_id', userIds);
      profileMap = {
        for (final row in profileRows) (row['user_id'] as String): row,
      };
    }

    return participantRows.map<Map<String, dynamic>>((row) {
      final userId = row['user_id'] as String?;
      return {
        'user_id': userId,
        'joined_at': row['joined_at'],
        ...?profileMap[userId],
      };
    }).toList();
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

  @override
  RealtimeChannel subscribeToConversationEvents(Function() onChanged) {
    return _supabase
        .channel('conversation-events')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'participants',
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<List<dynamic>> _loadConversationRows(
    List<String> conversationIds,
  ) async {
    try {
      return await _supabase
          .from('conversations_with_last_message')
          .select(
            'conversation_id,conversation_name,is_group,created_at,last_message,last_message_at',
          )
          .inFilter('conversation_id', conversationIds)
          .order('last_message_at', ascending: false, nullsFirst: false)
          .order('created_at', ascending: false);
    } catch (_) {
      return await _supabase
          .from('conversations')
          .select('conversation_id,conversation_name,is_group,created_at')
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: false);
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
    result.sort((a, b) {
      final archivedCompare = (a.isArchived ? 1 : 0).compareTo(
        b.isArchived ? 1 : 0,
      );
      if (archivedCompare != 0) return archivedCompare;

      final pinnedCompare = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
      if (pinnedCompare != 0) return pinnedCompare;

      return _conversationSortTime(b).compareTo(_conversationSortTime(a));
    });
    return result;
  }

  DateTime _conversationSortTime(Conversation conversation) {
    return conversation.lastMessageAt ?? conversation.createdAt;
  }

  Future<void> _upsertConversationPreference({
    required String conversationId,
    required String userId,
    required Map<String, dynamic> changes,
  }) async {
    final existing = await _supabase
        .from('conversation_preferences')
        .select('preference_id')
        .eq('conversation_id', conversationId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('conversation_preferences')
          .update(changes)
          .eq('preference_id', existing['preference_id']);
      return;
    }

    await _supabase.from('conversation_preferences').insert({
      'conversation_id': conversationId,
      'user_id': userId,
      ...changes,
    });
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
