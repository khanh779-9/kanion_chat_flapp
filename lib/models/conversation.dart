class Conversation {
  final String conversationId;
  final String? conversationName;
  final bool isGroup;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int? unreadCount;
  final String? otherUserAvatar;
  final String? otherUserName;

  Conversation({
    required this.conversationId,
    this.conversationName,
    required this.isGroup,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount,
    this.otherUserAvatar,
    this.otherUserName,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      conversationId: json['conversation_id'] ?? '',
      conversationName: json['conversation_name'],
      isGroup: json['is_group'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      lastMessage: json['last_message'],
      lastMessageTime: json['last_message_time'] != null 
          ? DateTime.parse(json['last_message_time']) 
          : null,
      unreadCount: json['unread_count'] ?? 0,
      otherUserAvatar: json['other_user_avatar'],
      otherUserName: json['other_user_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'conversation_name': conversationName,
      'is_group': isGroup,
      'created_at': createdAt.toIso8601String(),
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'unread_count': unreadCount,
      'other_user_avatar': otherUserAvatar,
      'other_user_name': otherUserName,
    };
  }
}
