import '../../../../core/models/base_model.dart';

class UserProfile extends BaseModel {
  static const _unset = Object();

  final String userId;
  final String? displayName;
  final DateTime? birthDay;
  final String? phone;
  final String? bio;
  final String? avatarUrl;

  UserProfile({
    required super.id,
    required this.userId,
    this.displayName,
    this.birthDay,
    this.phone,
    this.bio,
    this.avatarUrl,
    required super.createdAt,
    DateTime? updatedAt,
  }) : super(updatedAt: updatedAt ?? createdAt);

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      birthDay: _parseBirthDay(json['birth_day'] ?? json['birth_date']),
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'display_name': displayName,
      'birth_day': birthDay != null
          ? '${birthDay!.year.toString().padLeft(4, '0')}-${birthDay!.month.toString().padLeft(2, '0')}-${birthDay!.day.toString().padLeft(2, '0')}'
          : null,
      'phone': phone,
      'bio': bio,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? userId,
    Object? displayName = _unset,
    Object? birthDay = _unset,
    Object? phone = _unset,
    Object? bio = _unset,
    Object? avatarUrl = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: identical(displayName, _unset)
          ? this.displayName
          : displayName as String?,
      birthDay: identical(birthDay, _unset)
          ? this.birthDay
          : birthDay as DateTime?,
      phone: identical(phone, _unset) ? this.phone : phone as String?,
      bio: identical(bio, _unset) ? this.bio : bio as String?,
      avatarUrl: identical(avatarUrl, _unset)
          ? this.avatarUrl
          : avatarUrl as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get name {
    final value = displayName?.trim();
    if (value == null || value.isEmpty) return 'User';
    return value;
  }

  String get initials {
    final value = name.trim();
    if (value.isEmpty) return '?';

    final parts = value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  static DateTime? _parseBirthDay(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
