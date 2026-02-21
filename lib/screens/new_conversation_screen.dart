import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/database_service.dart';
import 'chat_screen.dart';
import '../models/conversation.dart';

class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({super.key});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final _authService = AuthService();
  final _chatService = ChatService();
  final _databaseService = DatabaseService();
  final _searchController = TextEditingController();

  List<Contact> _contacts = [];
  List<UserProfile> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);

    final userId = _authService.currentUserId;
    if (userId != null) {
      final contacts = await _databaseService.getContacts(userId);
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    final users = await _databaseService.searchUsers(query);
    final currentUserId = _authService.currentUserId;

    setState(() {
      _searchResults = users.where((u) => u.userId != currentUserId).toList();
    });
  }

  Future<void> _startConversation(String friendId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    setState(() => _isLoading = true);

    final conversationId = await _chatService.createConversation(
      userId: userId,
      participantIds: [friendId],
      isGroup: false,
    );

    if (conversationId != null && mounted) {
      // Get friend info for conversation display
      final friendProfile = await _authService.getUserProfile(friendId);
      if (!mounted) return;

      final conversation = Conversation(
        conversationId: conversationId,
        conversationName:
            friendProfile?.displayName ?? friendProfile?.email ?? 'Unknown',
        isGroup: false,
        createdAt: DateTime.now(),
        otherUserAvatar: friendProfile?.avatarUrl,
        otherUserName: friendProfile?.displayName,
      );

      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conversation),
        ),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuộc trò chuyện mới')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm người dùng...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isSearching
                ? _buildSearchResults()
                : _buildContactsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'Không tìm thấy người dùng',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Text((user.displayName ?? user.email ?? '?')[0].toUpperCase())
                : null,
          ),
          title: Text(user.displayName ?? user.email ?? 'Unknown'),
          subtitle: Text(user.email ?? ''),
          trailing: IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => _startConversation(user.userId),
          ),
        );
      },
    );
  }

  Widget _buildContactsList() {
    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có liên hệ nào',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tìm kiếm người dùng để bắt đầu',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: contact.friendAvatar != null
                ? NetworkImage(contact.friendAvatar!)
                : null,
            child: contact.friendAvatar == null
                ? Text((contact.friendName ?? '?')[0].toUpperCase())
                : null,
          ),
          title: Text(contact.friendName ?? 'Unknown'),
          subtitle: Text(contact.friendEmail ?? ''),
          onTap: () => _startConversation(contact.friendId),
        );
      },
    );
  }
}
