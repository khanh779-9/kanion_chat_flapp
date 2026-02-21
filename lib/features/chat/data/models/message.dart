import '../../../../core/models/base_model.dart';

enum MessageType {
  text,
  image,
  file,
  audio,
  video;

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}

class Message extends BaseModel {
  final String conversationId;
  final String? senderId;
  final String content;
  final MessageType type;
  final String? replyTo;
  final bool edited;

  // Metadata
  final String? senderName;
  final String? senderAvatar;
  final bool? isMine;

  Message({
    required super.id,
    required this.conversationId,
    this.senderId,
    required this.content,
    this.type = MessageType.text,
    this.replyTo,
    this.edited = false,
    required super.createdAt,
    required super.updatedAt,
    this.senderName,
    this.senderAvatar,
    this.isMine,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    return Message(
      id: (json['id'] ?? json['message_id']) as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String?,
      content: json['content'] as String,
      type: MessageType.fromString(json['type'] as String? ?? 'text'),
      replyTo: json['reply_to'] as String?,
      edited: json['edited'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : createdAt,
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
      isMine: json['is_mine'] as bool?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'type': type.name,
      'reply_to': replyTo,
      'edited': edited,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    MessageType? type,
    String? replyTo,
    bool? edited,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? senderName,
    String? senderAvatar,
    bool? isMine,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      replyTo: replyTo ?? this.replyTo,
      edited: edited ?? this.edited,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      isMine: isMine ?? this.isMine,
    );
  }
}
