import 'package:flutter/material.dart';
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
  List<Conversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chatRepo = ChatRepositoryImpl(sl.supabase);
    _authRepo = AuthRepositoryImpl(sl.supabase);
    _loadConversations();
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
    }
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
          : _conversations.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadConversations,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                itemCount: _conversations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final conv = _conversations[index];
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
      onLongPressStart: (details) =>
          _showConversationMenu(details.globalPosition, conv),
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

  Future<void> _showConversationMenu(
    Offset globalPosition,
    Conversation conv,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline),
            title: Text('Xóa cuộc trò chuyện'),
          ),
        ),
      ],
    );

    if (selected == 'delete' && mounted) {
      await _confirmDeleteConversation(conv);
    }
  }

  Future<void> _confirmDeleteConversation(Conversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa cuộc trò chuyện'),
        content: Text(
          'Bạn có chắc muốn xóa cuộc trò chuyện với ${conv.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _chatRepo.deleteConversation(conv.id);
      await _loadConversations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể xóa: ${e.toString()}')));
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
