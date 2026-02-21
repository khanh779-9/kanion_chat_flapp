import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/contact.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Search users by display name from profiles
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

  // Get contacts
  Future<List<Contact>> getContacts(String userId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableUserContacts)
          .select('''
            *,
            profiles!UserContacts_friend_id_fkey (
              display_name,
              avatar_url,
              email
            )
          ''')
          .eq('user_id', userId);

      return response.map<Contact>((json) {
        final contact = Contact.fromJson(json);
        if (json['profiles'] != null) {
          return Contact(
            contactId: contact.contactId,
            userId: contact.userId,
            friendId: contact.friendId,
            friendName: json['profiles']['display_name'],
            friendAvatar: json['profiles']['avatar_url'],
            friendEmail: json['profiles']['email'],
            createdAt: contact.createdAt,
          );
        }
        return contact;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Add contact
  Future<bool> addContact(String userId, String friendId) async {
    try {
      await _supabase.from(AppConstants.tableUserContacts).insert({
        'user_id': userId,
        'friend_id': friendId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Remove contact
  Future<bool> removeContact(String contactId) async {
    try {
      await _supabase
          .from(AppConstants.tableUserContacts)
          .delete()
          .eq('contact_id', contactId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Block user
  Future<bool> blockUser(String userId, String blockedUserId) async {
    try {
      await _supabase.from(AppConstants.tableBlockedUsers).insert({
        'user_id': userId,
        'blocked_user_id': blockedUserId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get blocked users
  Future<List<String>> getBlockedUsers(String userId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableBlockedUsers)
          .select('blocked_user_id')
          .eq('user_id', userId);

      return response
          .map<String>((json) => json['blocked_user_id'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Upload file
  Future<String?> uploadFile(
    String bucket,
    String path,
    String filePath,
  ) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      await _supabase.storage.from(bucket).uploadBinary(path, bytes);
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }
}
