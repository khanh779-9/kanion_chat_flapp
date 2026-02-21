import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get current user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Auth state stream
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );

      // Create profile
      if (response.user != null) {
        await _supabase.from('profiles').insert({
          'user_id': response.user!.id,
          'email': email,
          'display_name': displayName,
        });
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Get user profile
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Update user profile
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        ...?displayName == null ? null : {'display_name': displayName},
        ...?avatarUrl == null ? null : {'avatar_url': avatarUrl},
      };

      await _supabase.from('profiles').update(updates).eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }

  // Upload avatar
  Future<String?> uploadAvatar(String userId, String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      await _supabase.storage
          .from('avatars')
          .uploadBinary('$userId/avatar.jpg', bytes);

      final url = _supabase.storage
          .from('avatars')
          .getPublicUrl('$userId/avatar.jpg');

      return url;
    } catch (e) {
      return null;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }
}
