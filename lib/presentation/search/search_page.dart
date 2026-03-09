import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../features/profile/data/repositories/profile_repository.dart';
import '../../features/profile/data/models/user_profile.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/chat/data/repositories/chat_repository.dart';
import '../../features/chat/data/models/conversation.dart';
import '../chat/chat_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final ProfileRepository _profileRepo;
  late final AuthRepository _authRepo;
  late final ChatRepository _chatRepo;

  final _searchController = TextEditingController();
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  bool _isGroupMode = false;
  final Set<String> _selectedUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _profileRepo = ProfileRepositoryImpl(sl.supabase);
    _authRepo = AuthRepositoryImpl(sl.supabase);
    _chatRepo = ChatRepositoryImpl(sl.supabase);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final users = await _profileRepo.searchUsers(query);

    if (mounted) {
      setState(() {
        _searchResults = users;
      });
    }
  }

  void _toggleGroupMode() {
    setState(() {
      _isGroupMode = !_isGroupMode;
      _selectedUserIds.clear();
    });
  }

  Future<void> _startChat(UserProfile user) async {
    final userId = _authRepo.currentUserId;
    if (userId == null) return;
    if (user.userId == userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tự chat với chính bạn')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final conversationId = await _chatRepo.createConversation(
        userId: userId,
        participantIds: [user.userId],
        isGroup: false,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading

        final conversation = Conversation(
          id: conversationId,
          isGroup: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          otherUserName: user.name,
          otherUserAvatar: user.avatarUrl,
          otherUserOnline: false,
        );

        Navigator.pop(context); // Close search
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
      }
    }
  }

  Future<void> _createGroupConversation() async {
    final currentUserId = _authRepo.currentUserId;
    if (currentUserId == null) return;

    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy chọn ít nhất 2 thành viên để tạo nhóm'),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    final groupName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo nhóm mới'),
        content: TextField(
          controller: controller,
          maxLength: 50,
          decoration: const InputDecoration(hintText: 'Tên nhóm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    if (groupName == null || groupName.isEmpty) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final conversationId = await _chatRepo.createConversation(
        userId: currentUserId,
        participantIds: _selectedUserIds.toList(),
        name: groupName,
        isGroup: true,
      );

      if (!mounted) return;
      Navigator.pop(context);

      final conversation = Conversation(
        id: conversationId,
        name: groupName,
        isGroup: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatPage(conversation: conversation)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tạo nhóm thất bại: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final isCompact = width <= 360;
    final isTablet = width >= 900;
    final isTabletLandscape = isTablet && width > height;
    final contentMaxWidth = isTablet
        ? (isTabletLandscape ? 760.0 : 860.0)
        : double.infinity;
    final currentUserId = _authRepo.currentUserId;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isCompact ? 12 : 16,
        title: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: Container(
              height: isCompact ? 40 : 42,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm...',
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                onChanged: _searchUsers,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isGroupMode ? Icons.close : Icons.group_add_outlined),
            tooltip: _isGroupMode ? 'Hủy tạo nhóm' : 'Tạo nhóm',
            onPressed: _toggleGroupMode,
          ),
          if (_isGroupMode)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Tạo nhóm',
              onPressed: _createGroupConversation,
            ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _searchUsers('');
              },
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: _isSearching
              ? _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: isCompact ? 68 : 80,
                              color: colorScheme.outlineVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không tìm thấy người dùng',
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          final isMe = user.userId == currentUserId;
                          final secondaryText =
                              user.phone?.trim().isNotEmpty == true
                              ? user.phone!.trim()
                              : user.bio?.trim().isNotEmpty == true
                              ? user.bio!.trim()
                              : 'Người dùng Kanion Chat';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundColor: colorScheme.surfaceContainerLow,
                              backgroundImage: user.avatarUrl != null
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null
                                  ? Text(
                                      user.initials,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.name,
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              secondaryText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isMe
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 12,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Đây là bạn',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _isGroupMode
                                ? Checkbox(
                                    value: _selectedUserIds.contains(
                                      user.userId,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedUserIds.add(user.userId);
                                        } else {
                                          _selectedUserIds.remove(user.userId);
                                        }
                                      });
                                    },
                                  )
                                : null,
                            onTap: isMe
                                ? null
                                : _isGroupMode
                                ? () {
                                    setState(() {
                                      if (_selectedUserIds.contains(
                                        user.userId,
                                      )) {
                                        _selectedUserIds.remove(user.userId);
                                      } else {
                                        _selectedUserIds.add(user.userId);
                                      }
                                    });
                                  }
                                : () => _startChat(user),
                          );
                        },
                      )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: isCompact ? 68 : 80,
                        color: colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tìm kiếm người dùng',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nhập tên để bắt đầu tìm kiếm',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
