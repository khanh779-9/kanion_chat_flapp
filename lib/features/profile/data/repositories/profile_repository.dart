import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile?> getProfile(String userId);
  Future<void> updateProfile(UserProfile profile);
  Future<List<UserProfile>> searchUsers(String query);
  Future<String?> uploadAvatar(
    String userId,
    String filePath, {
    Uint8List? fileBytes,
  });
}

class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepositoryImpl(this._supabase);

  @override
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _selectProfileByUserId(userId);
      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    try {
      await _updateThenInsertProfile(
        profile.userId,
        _writeProfilePayload(profile, birthColumnName: 'birth_day'),
      );
    } catch (e) {
      if (_isMissingExtendedProfileColumnsError(e)) {
        try {
          await _updateThenInsertProfile(
            profile.userId,
            _writeProfilePayload(profile, birthColumnName: 'birth_date'),
          );
          return;
        } catch (fallbackError) {
          if (_isMissingExtendedProfileColumnsError(fallbackError)) {
            await _updateThenInsertProfile(
              profile.userId,
              _basicWriteProfilePayload(profile),
            );
            return;
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  @override
  Future<List<UserProfile>> searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .or('display_name.ilike.%$query%')
          .limit(20);
      return response
          .map<UserProfile>((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _selectProfileByUserId(String userId) async {
    try {
      return await _supabase
          .from('profiles')
          .select(
            'id,user_id,display_name,birth_day,phone,bio,avatar_url,created_at',
          )
          .or('user_id.eq.$userId,id.eq.$userId')
          .single();
    } catch (e) {
      if (_isMissingExtendedProfileColumnsError(e)) {
        try {
          return await _supabase
              .from('profiles')
              .select(
                'id,user_id,display_name,birth_date,phone,bio,avatar_url,created_at',
              )
              .or('user_id.eq.$userId,id.eq.$userId')
              .single();
        } catch (fallbackError) {
          if (_isMissingExtendedProfileColumnsError(fallbackError)) {
            return await _supabase
                .from('profiles')
                .select('id,user_id,display_name,avatar_url,created_at')
                .or('user_id.eq.$userId,id.eq.$userId')
                .single();
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  Map<String, dynamic> _basicWriteProfilePayload(UserProfile profile) {
    return {
      'user_id': profile.userId,
      'display_name': profile.displayName,
      'avatar_url': profile.avatarUrl,
    };
  }

  Map<String, dynamic> _writeProfilePayload(
    UserProfile profile, {
    required String birthColumnName,
  }) {
    return {
      'user_id': profile.userId,
      'display_name': profile.displayName,
      birthColumnName: profile.birthDay != null
          ? '${profile.birthDay!.year.toString().padLeft(4, '0')}-${profile.birthDay!.month.toString().padLeft(2, '0')}-${profile.birthDay!.day.toString().padLeft(2, '0')}'
          : null,
      'phone': profile.phone,
      'bio': profile.bio,
      'avatar_url': profile.avatarUrl,
    };
  }

  bool _isMissingExtendedProfileColumnsError(Object error) {
    final raw = error.toString().toLowerCase();

    if (error is PostgrestException) {
      final code = (error.code ?? '').toString().toLowerCase();
      final message = error.message.toLowerCase();
      final details = (error.details ?? '').toString().toLowerCase();
      final hint = (error.hint ?? '').toString().toLowerCase();
      final full = '$code $message $details $hint $raw';

      final hasMissingColumnSignal =
          full.contains('pgrst204') ||
          full.contains('could not find the') ||
          full.contains('column of') ||
          full.contains('schema cache');

      final isProfileExtendedColumn =
          full.contains("'birth_day'") ||
          full.contains("'birth_date'") ||
          full.contains("'phone'") ||
          full.contains("'bio'");

      return hasMissingColumnSignal && isProfileExtendedColumn;
    }

    return (raw.contains('pgrst204') || raw.contains('schema cache')) &&
        (raw.contains("'birth_day'") ||
            raw.contains("'birth_date'") ||
            raw.contains("'phone'") ||
            raw.contains("'bio'"));
  }

  Future<void> _updateThenInsertProfile(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    final existing = await _supabase
        .from('profiles')
        .select('id,user_id')
        .or('user_id.eq.$userId,id.eq.$userId')
        .limit(1);

    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as String?;
      if (existingId != null && existingId.isNotEmpty) {
        await _supabase.from('profiles').update(payload).eq('id', existingId);
      } else {
        await _supabase
            .from('profiles')
            .update(payload)
            .or('user_id.eq.$userId,id.eq.$userId');
      }
      return;
    }

    final insertPayload = {...payload, 'user_id': userId};

    try {
      await _supabase.from('profiles').insert(insertPayload);
    } catch (e) {
      if (_isProfilesIdForeignKeyError(e)) {
        await _supabase.from('profiles').insert({
          ...insertPayload,
          'id': userId,
        });
        return;
      }
      rethrow;
    }
  }

  bool _isProfilesIdForeignKeyError(Object error) {
    if (error is! PostgrestException) return false;

    final code = (error.code ?? '').toString().toLowerCase();
    final message = error.message.toLowerCase();
    final details = (error.details ?? '').toString().toLowerCase();
    final full = '$code $message $details';

    return code == '23503' &&
        (full.contains('profiles_id_fkey') || full.contains('key (id)'));
  }

  @override
  Future<String?> uploadAvatar(
    String userId,
    String filePath, {
    Uint8List? fileBytes,
  }) async {
    try {
      final bytes = fileBytes ?? await File(filePath).readAsBytes();
      await _supabase.storage
          .from('avatars')
          .uploadBinary('$userId/avatar.jpg', bytes);
      return _supabase.storage
          .from('avatars')
          .getPublicUrl('$userId/avatar.jpg');
    } catch (e) {
      return null;
    }
  }
}
