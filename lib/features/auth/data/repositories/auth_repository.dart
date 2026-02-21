import 'package:supabase_flutter/supabase_flutter.dart';

// Repository interface cho Auth
abstract class AuthRepository {
  User? get currentUser;
  String? get currentUserId;
  Stream<AuthState> get authStateChanges;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<UserResponse> updateDisplayName(String displayName);
}

// Implementation
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;

  AuthRepositoryImpl(this._supabase);

  @override
  User? get currentUser => _supabase.auth.currentUser;

  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  @override
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );

    final userId = response.user?.id;
    final trimmedDisplayName = displayName?.trim();
    if (userId != null &&
        trimmedDisplayName != null &&
        trimmedDisplayName.isNotEmpty) {
      await _syncProfileDisplayName(userId, trimmedDisplayName);
    }

    return response;
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  @override
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  @override
  Future<UserResponse> updateDisplayName(String displayName) async {
    final trimmedDisplayName = displayName.trim();

    final response = await _supabase.auth.updateUser(
      UserAttributes(data: {'display_name': trimmedDisplayName}),
    );

    final userId = currentUserId;
    if (userId != null && trimmedDisplayName.isNotEmpty) {
      await _syncProfileDisplayName(userId, trimmedDisplayName);
    }

    return response;
  }

  Future<void> _syncProfileDisplayName(
    String userId,
    String displayName,
  ) async {
    try {
      await _supabase
          .from('profiles')
          .update({'display_name': displayName})
          .eq('user_id', userId);
    } catch (_) {}
  }
}
