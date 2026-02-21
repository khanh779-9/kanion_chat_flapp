class Contact {
  final String contactId;
  final String userId;
  final String friendId;
  final String? friendName;
  final String? friendAvatar;
  final String? friendEmail;
  final DateTime createdAt;

  Contact({
    required this.contactId,
    required this.userId,
    required this.friendId,
    this.friendName,
    this.friendAvatar,
    this.friendEmail,
    required this.createdAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      contactId: json['contact_id'] ?? '',
      userId: json['user_id'] ?? '',
      friendId: json['friend_id'] ?? '',
      friendName: json['friend_name'],
      friendAvatar: json['friend_avatar'],
      friendEmail: json['friend_email'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contact_id': contactId,
      'user_id': userId,
      'friend_id': friendId,
      'friend_name': friendName,
      'friend_avatar': friendAvatar,
      'friend_email': friendEmail,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
