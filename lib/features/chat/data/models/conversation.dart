import '../../../../core/models/base_model.dart';

class Conversation extends BaseModel {
  final String? name;
  final String? avatarUrl;
  final bool isGroup;

  // Metadata (không lưu DB, tính toán runtime)
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserAvatar;
  final bool? otherUserOnline;
  final bool isPinned;
  final bool isArchived;

  Conversation({
    required super.id,
    this.name,
    this.avatarUrl,
    required this.isGroup,
    required super.createdAt,
    required super.updatedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
    this.otherUserOnline,
    this.isPinned = false,
    this.isArchived = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    return Conversation(
      id: (json['id'] ?? json['conversation_id']) as String,
      name: (json['name'] ?? json['conversation_name']) as String?,
      avatarUrl: json['avatar_url'] as String?,
      isGroup: json['is_group'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : createdAt,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      otherUserId: json['other_user_id'] as String?,
      otherUserName: json['other_user_name'] as String?,
      otherUserAvatar: json['other_user_avatar'] as String?,
      otherUserOnline: json['other_user_online'] as bool?,
      isPinned: json['is_pinned'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'conversation_id': id,
      'conversation_name': name,
      'avatar_url': avatarUrl,
      'is_group': isGroup,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Conversation copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isGroup,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
    bool? otherUserOnline,
    bool? isPinned,
    bool? isArchived,
  }) {
    return Conversation(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGroup: isGroup ?? this.isGroup,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      otherUserOnline: otherUserOnline ?? this.otherUserOnline,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  // Getters tiện ích
  String get displayName =>
      isGroup ? (name ?? 'Group Chat') : (otherUserName ?? 'Unknown');

  String get displayAvatar =>
      isGroup ? (avatarUrl ?? '') : (otherUserAvatar ?? '');
}
