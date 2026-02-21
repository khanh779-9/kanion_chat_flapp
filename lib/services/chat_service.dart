import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../utils/constants.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get conversations for current user
  Future<List<Conversation>> getConversations(String userId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableParticipants)
          .select('''
            conversation_id,
            ${AppConstants.tableConversations} (
              conversation_id,
              conversation_name,
              is_group,
              created_at
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      List<Conversation> conversations = [];
      for (var item in response) {
        if (item['Conversations'] != null) {
          final conv = Conversation.fromJson(item['Conversations']);
          
          // Get last message
          final lastMsg = await getLastMessage(conv.conversationId);
          
          // Get unread count
          final unreadCount = await getUnreadCount(conv.conversationId, userId);
          
          // If not group, get other user info
          String? otherUserName;
          String? otherUserAvatar;
          if (!conv.isGroup) {
            final otherUser = await _getOtherParticipant(conv.conversationId, userId);
            otherUserName = otherUser?['display_name'];
            otherUserAvatar = otherUser?['avatar_url'];
          }
          
          conversations.add(Conversation(
            conversationId: conv.conversationId,
            conversationName: conv.conversationName ?? otherUserName ?? 'Unknown',
            isGroup: conv.isGroup,
            createdAt: conv.createdAt,
            lastMessage: lastMsg?.content,
            lastMessageTime: lastMsg?.createdAt,
            unreadCount: unreadCount,
            otherUserAvatar: otherUserAvatar,
            otherUserName: otherUserName,
          ));
        }
      }

      return conversations;
    } catch (e) {
      return [];
    }
  }

  // Get messages in a conversation
  Future<List<Message>> getMessages(String conversationId, {int limit = 50}) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableMessages)
          .select('''
            *,
            profiles!Messages_sender_id_fkey (
              display_name,
              avatar_url
            )
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map<Message>((json) {
        final message = Message.fromJson(json);
        if (json['profiles'] != null) {
          return Message(
            messageId: message.messageId,
            conversationId: message.conversationId,
            senderId: message.senderId,
            content: message.content,
            isRead: message.isRead,
            createdAt: message.createdAt,
            senderName: json['profiles']['display_name'],
            senderAvatar: json['profiles']['avatar_url'],
          );
        }
        return message;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Send message
  Future<Message?> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableMessages)
          .insert({
            'conversation_id': conversationId,
            'sender_id': senderId,
            'content': content,
            'is_read': false,
          })
          .select()
          .single();

      return Message.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Create conversation
  Future<String?> createConversation({
    required String userId,
    required List<String> participantIds,
    String? conversationName,
    bool isGroup = false,
  }) async {
    try {
      // Create conversation
      final convResponse = await _supabase
          .from(AppConstants.tableConversations)
          .insert({
            'conversation_name': conversationName,
            'is_group': isGroup,
          })
          .select()
          .single();

      final conversationId = convResponse['conversation_id'];

      // Add participants
      final participants = [userId, ...participantIds].map((id) => {
        'conversation_id': conversationId,
        'user_id': id,
      }).toList();

      await _supabase.from(AppConstants.tableParticipants).insert(participants);

      return conversationId;
    } catch (e) {
      return null;
    }
  }

  // Get last message
  Future<Message?> getLastMessage(String conversationId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableMessages)
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return Message.fromJson(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get unread count
  Future<int> getUnreadCount(String conversationId, String userId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableMessages)
          .select()
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      return 0;
    }
  }

  // Mark messages as read
  Future<void> markAsRead(String conversationId, String userId) async {
    try {
      await _supabase
          .from(AppConstants.tableMessages)
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId);
    } catch (e) {
      // Handle error
    }
  }

  // Subscribe to new messages
  RealtimeChannel subscribeToMessages(String conversationId, Function(Message) onMessage) {
    return _supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.tableMessages,
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

  // Get other participant in 1-on-1 conversation
  Future<Map<String, dynamic>?> _getOtherParticipant(String conversationId, String currentUserId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableParticipants)
          .select('''
            user_id,
            profiles!Participants_user_id_fkey (
              display_name,
              avatar_url
            )
          ''')
          .eq('conversation_id', conversationId)
          .neq('user_id', currentUserId)
          .limit(1)
          .maybeSingle();

      if (response != null && response['profiles'] != null) {
        return response['profiles'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
