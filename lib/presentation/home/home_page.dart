import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/datetime_helper.dart';
import '../../core/di/service_locator.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/chat/data/repositories/chat_repository.dart';
import '../../features/chat/data/models/conversation.dart';
import '../chat/chat_page.dart';
import '../search/search_page.dart';
import '../profile/profile_page.dart';
import '../settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ChatRepository _chatRepo;
  late final AuthRepository _authRepo;
  RealtimeChannel? _conversationEventsChannel;
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  bool _showArchivedOnly = false;

  @override
  void initState() {
    super.initState();
    _chatRepo = ChatRepositoryImpl(sl.supabase);
    _authRepo = AuthRepositoryImpl(sl.supabase);
    _loadConversations();
    _subscribeConversationEvents();
  }

  @override
  void dispose() {
    _conversationEventsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userId = _authRepo.currentUserId;
    if (userId != null) {
      final conversations = await _chatRepo.getConversations(userId);
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _conversations = [];
        _isLoading = false;
      });
    }
  }

  void _subscribeConversationEvents() {
    _conversationEventsChannel = _chatRepo.subscribeToConversationEvents(() {
      if (!mounted) return;
      _loadConversations();
    });
  }

  List<Conversation> get _visibleConversations {
    if (_showArchivedOnly) {
      return _conversations
          .where((conversation) => conversation.isArchived)
          .toList();
    }
    return _conversations
        .where((conversation) => !conversation.isArchived)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Trò chuyện',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showArchivedOnly ? Icons.inbox_outlined : Icons.archive_outlined,
            ),
            tooltip: _showArchivedOnly ? 'Hộp thư chính' : 'Kho lưu trữ',
            onPressed: () {
              setState(() => _showArchivedOnly = !_showArchivedOnly);
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
              _loadConversations();
            },
          ),
          _buildPopupMenu(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _visibleConversations.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadConversations,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                itemCount: _visibleConversations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final conv = _visibleConversations[index];
                  return _buildConversationTile(conv);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchPage()),
          );
          _loadConversations();
        },
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conv) {
    final theme = Theme.of(context);
    final bool isUnread = conv.unreadCount > 0;

    return ListTile(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatPage(conversation: conv)),
        );
        _loadConversations();
      },
      onLongPress: () => _showConversationMenu(conv),
      leading: _buildAvatar(conv, theme),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conv.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conv.isPinned)
            Icon(Icons.push_pin, size: 16, color: theme.colorScheme.primary),
          if (conv.isPinned) const SizedBox(width: 4),
          Text(
            conv.lastMessageAt != null
                ? DateTimeHelper.formatChatListTime(conv.lastMessageAt!)
                : '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isUnread
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conv.lastMessage ?? 'Chưa có tin nhắn',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isUnread
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isUnread) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 10,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                '${conv.unreadCount}',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      tileColor: theme.colorScheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }

  Future<void> _showConversationMenu(Conversation conv) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (conv.isGroup)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Đổi tên nhóm'),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
            ListTile(
              leading: Icon(
                conv.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(
                conv.isPinned ? 'Bỏ ghim hội thoại' : 'Ghim hội thoại',
              ),
              onTap: () => Navigator.pop(context, 'pin'),
            ),
            ListTile(
              leading: Icon(
                conv.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              title: Text(conv.isArchived ? 'Bỏ lưu trữ' : 'Lưu trữ'),
              onTap: () => Navigator.pop(context, 'archive'),
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app_outlined),
              title: const Text('Rời cuộc trò chuyện'),
              onTap: () => Navigator.pop(context, 'leave'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (selected == 'rename' && conv.isGroup) {
      await _renameGroup(conv);
      return;
    }

    if (selected == 'pin') {
      await _togglePin(conv);
      return;
    }

    if (selected == 'archive') {
      await _toggleArchive(conv);
      return;
    }

    if (selected == 'leave') {
      await _confirmLeaveConversation(conv);
    }
  }

  Future<void> _togglePin(Conversation conv) async {
    final userId = _authRepo.currentUserId;
    if (userId == null) return;

    try {
      await _chatRepo.setConversationPinned(
        conversationId: conv.id,
        userId: userId,
        isPinned: !conv.isPinned,
      );
      await _loadConversations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể ghim hội thoại: ${e.toString()}')),
      );
    }
  }

  Future<void> _toggleArchive(Conversation conv) async {
    final userId = _authRepo.currentUserId;
    if (userId == null) return;

    try {
      await _chatRepo.setConversationArchived(
        conversationId: conv.id,
        userId: userId,
        isArchived: !conv.isArchived,
      );
      await _loadConversations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu trữ hội thoại: ${e.toString()}')),
      );
    }
  }

  Future<void> _renameGroup(Conversation conv) async {
    final controller = TextEditingController(text: conv.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên nhóm'),
        content: TextField(
          controller: controller,
          maxLength: 50,
          decoration: const InputDecoration(hintText: 'Tên nhóm mới'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    try {
      await _chatRepo.updateConversationName(conv.id, newName);
      await _loadConversations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể đổi tên nhóm: ${e.toString()}')),
      );
    }
  }

  Future<void> _confirmLeaveConversation(Conversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rời cuộc trò chuyện'),
        content: Text(
          'Bạn có chắc muốn rời cuộc trò chuyện với ${conv.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rời'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final userId = _authRepo.currentUserId;
      if (userId == null) return;
      await _chatRepo.leaveConversation(
        conversationId: conv.id,
        userId: userId,
      );
      await _loadConversations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể rời cuộc trò chuyện: ${e.toString()}'),
        ),
      );
    }
  }

  Widget _buildAvatar(Conversation conv, ThemeData theme) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.surfaceContainerLow,
            backgroundImage: conv.displayAvatar.isNotEmpty
                ? NetworkImage(conv.displayAvatar)
                : null,
            child: conv.displayAvatar.isEmpty
                ? Text(
                    conv.displayName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : null,
          ),
          if (!conv.isGroup && conv.otherUserOnline == true)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.online,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: colorScheme.secondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'Bắt đầu cuộc trò chuyện',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn vào bút chì để bắt đầu một cuộc trò chuyện mới.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  PopupMenuButton _buildPopupMenu() {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Hồ sơ'),
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Cài đặt'),
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'profile') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          );
        } else if (value == 'settings') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        }
      },
    );
  }
}
