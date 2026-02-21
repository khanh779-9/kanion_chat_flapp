class UserProfile {
  final String id;
  final String userId;
  final String? avatarUrl;
  final String? email;
  final String? displayName;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.userId,
    this.avatarUrl,
    this.email,
    this.displayName,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      avatarUrl: json['avatar_url'],
      email: json['email'],
      displayName: json['display_name'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'avatar_url': avatarUrl,
      'email': email,
      'display_name': displayName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? userId,
    String? avatarUrl,
    String? email,
    String? displayName,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
