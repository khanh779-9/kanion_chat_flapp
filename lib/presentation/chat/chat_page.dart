import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/datetime_helper.dart';
import '../../core/di/service_locator.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/chat/data/repositories/chat_repository.dart';
import '../../features/chat/data/models/conversation.dart';
import '../../features/chat/data/models/message.dart';
import '../../features/profile/data/models/user_profile.dart';
import '../../features/profile/data/repositories/profile_repository.dart';

class ChatPage extends StatefulWidget {
  final Conversation conversation;

  const ChatPage({super.key, required this.conversation});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatRepository _chatRepo;
  late final AuthRepository _authRepo;
  late final ProfileRepository _profileRepo;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Message> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _chatRepo = ChatRepositoryImpl(sl.supabase);
    _authRepo = AuthRepositoryImpl(sl.supabase);
    _profileRepo = ProfileRepositoryImpl(sl.supabase);
    _loadMessages();
    _subscribeToMessages();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) {
      setState(() => _isLoading = true);
    }

    final messages = await _chatRepo.getMessages(widget.conversation.id);

    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    }
  }

  void _subscribeToMessages() {
    _channel = _chatRepo.subscribeToMessages(widget.conversation.id, (message) {
      _loadMessages(showLoader: false);
      _markAsRead();
      _scrollToBottom();
    });
  }

  Future<void> _markAsRead() async {
    final userId = _authRepo.currentUserId;
    if (userId != null) {
      await _chatRepo.markAsRead(widget.conversation.id, userId);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final userId = _authRepo.currentUserId;
    if (userId == null) return;

    _messageController.clear();

    await _chatRepo.sendMessage(
      Message(
        id: '',
        conversationId: widget.conversation.id,
        senderId: userId,
        content: content,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await _loadMessages(showLoader: false);
    _scrollToBottom();
  }

  Future<void> _showMessageActions(Message message, bool isMine) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Sao chép'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Chỉnh sửa'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Xóa tin nhắn'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    if (selected == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.content));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã sao chép tin nhắn')));
      return;
    }

    if (selected == 'edit') {
      await _editMessage(message);
      return;
    }

    if (selected == 'delete') {
      await _deleteMessage(message);
    }
  }

  Future<void> _editMessage(Message message) async {
    final controller = TextEditingController(text: message.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa tin nhắn'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 6,
          maxLength: 1000,
          decoration: const InputDecoration(hintText: 'Nhập nội dung mới'),
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

    if (newContent == null ||
        newContent.isEmpty ||
        newContent == message.content) {
      return;
    }

    try {
      await _chatRepo.updateMessage(messageId: message.id, content: newContent);
      await _loadMessages(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chỉnh sửa: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tin nhắn'),
        content: const Text('Bạn có chắc muốn xóa tin nhắn này không?'),
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
      await _chatRepo.deleteMessage(message.id);
      await _loadMessages(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể xóa: ${e.toString()}')));
    }
  }

  Future<void> _showConversationMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Xem thành viên'),
              onTap: () => Navigator.pop(context, 'participants'),
            ),
            if (widget.conversation.isGroup)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Đổi tên nhóm'),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
            if (widget.conversation.isGroup)
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Thêm thành viên'),
                onTap: () => Navigator.pop(context, 'add_member'),
              ),
            ListTile(
              leading: const Icon(Icons.exit_to_app_outlined),
              title: Text(
                widget.conversation.isGroup
                    ? 'Rời nhóm'
                    : 'Rời cuộc trò chuyện',
              ),
              onTap: () => Navigator.pop(context, 'leave'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || selected == null) return;

    if (selected == 'participants') {
      await _showParticipantsSheet();
      return;
    }

    if (selected == 'rename') {
      await _renameGroup();
      return;
    }

    if (selected == 'add_member') {
      await _addMembersToGroup();
      return;
    }

    if (selected == 'leave') {
      await _leaveConversation();
    }
  }

  Future<void> _showParticipantsSheet() async {
    try {
      final participants = await _chatRepo.getConversationParticipants(
        widget.conversation.id,
      );
      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, controller) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.group),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Thành viên (${participants.length})'),
                      ),
                      if (widget.conversation.isGroup)
                        IconButton(
                          tooltip: 'Thêm thành viên',
                          onPressed: () async {
                            Navigator.pop(context);
                            await _addMembersToGroup();
                            if (!mounted) return;
                            await _showParticipantsSheet();
                          },
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final p = participants[index];
                      final displayName = (p['display_name'] as String?)
                          ?.trim();
                      final fallbackName =
                          (p['user_id'] as String?) ?? 'Unknown';
                      final isCurrentUser =
                          fallbackName == _authRepo.currentUserId;
                      final avatarUrl = p['avatar_url'] as String?;
                      final initials =
                          (displayName?.isNotEmpty == true
                                  ? displayName!
                                  : fallbackName)
                              .trim()
                              .substring(0, 1)
                              .toUpperCase();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(initials)
                              : null,
                        ),
                        title: Text(
                          displayName != null && displayName.isNotEmpty
                              ? displayName
                              : fallbackName,
                        ),
                        subtitle: Text(
                          isCurrentUser ? '$fallbackName (Bạn)' : fallbackName,
                        ),
                        trailing: widget.conversation.isGroup && !isCurrentUser
                            ? IconButton(
                                tooltip: 'Xóa khỏi nhóm',
                                icon: const Icon(Icons.person_remove_outlined),
                                onPressed: () async {
                                  await _removeParticipantFromGroup(
                                    participantUserId: fallbackName,
                                    participantName:
                                        displayName?.isNotEmpty == true
                                        ? displayName!
                                        : fallbackName,
                                  );
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop();
                                  await _showParticipantsSheet();
                                },
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải thành viên: ${e.toString()}')),
      );
    }
  }

  Future<void> _addMembersToGroup() async {
    if (!widget.conversation.isGroup) return;

    final currentUserId = _authRepo.currentUserId;
    if (currentUserId == null) return;

    final existingParticipants = await _chatRepo.getConversationParticipants(
      widget.conversation.id,
    );
    final existingUserIds = existingParticipants
        .map<String?>((row) => row['user_id'] as String?)
        .whereType<String>()
        .toSet();

    var query = '';
    final selectedUserIds = <String>{};
    List<UserProfile> searchResults = [];
    bool isLoading = false;

    if (!mounted) return;

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Thêm thành viên'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo tên hiển thị',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) async {
                    query = value.trim();
                    if (query.isEmpty) {
                      setStateDialog(() => searchResults = []);
                      return;
                    }

                    setStateDialog(() => isLoading = true);
                    final users = await _profileRepo.searchUsers(query);
                    if (!mounted) return;
                    setStateDialog(() {
                      searchResults = users
                          .where(
                            (u) =>
                                u.userId != currentUserId &&
                                !existingUserIds.contains(u.userId),
                          )
                          .toList();
                      isLoading = false;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  )
                else
                  SizedBox(
                    height: 240,
                    child: searchResults.isEmpty
                        ? const Center(
                            child: Text(
                              'Nhập từ khóa để tìm người dùng phù hợp',
                            ),
                          )
                        : ListView.builder(
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final user = searchResults[index];
                              final isChecked = selectedUserIds.contains(
                                user.userId,
                              );
                              return CheckboxListTile(
                                value: isChecked,
                                onChanged: (value) {
                                  setStateDialog(() {
                                    if (value == true) {
                                      selectedUserIds.add(user.userId);
                                    } else {
                                      selectedUserIds.remove(user.userId);
                                    }
                                  });
                                },
                                title: Text(user.name),
                                subtitle: Text(user.userId),
                                secondary: CircleAvatar(
                                  backgroundImage: user.avatarUrl != null
                                      ? NetworkImage(user.avatarUrl!)
                                      : null,
                                  child: user.avatarUrl == null
                                      ? Text(user.initials)
                                      : null,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                              );
                            },
                          ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: selectedUserIds.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );

    if (shouldSubmit != true || selectedUserIds.isEmpty) return;

    try {
      await _chatRepo.addParticipants(
        conversationId: widget.conversation.id,
        participantIds: selectedUserIds.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm thành viên vào nhóm')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể thêm thành viên: ${e.toString()}')),
      );
    }
  }

  Future<void> _removeParticipantFromGroup({
    required String participantUserId,
    required String participantName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thành viên'),
        content: Text('Xóa $participantName khỏi nhóm này?'),
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
      await _chatRepo.removeParticipant(
        conversationId: widget.conversation.id,
        userId: participantUserId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa thành viên khỏi nhóm')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa thành viên: ${e.toString()}')),
      );
    }
  }

  Future<void> _renameGroup() async {
    if (!widget.conversation.isGroup) return;

    final controller = TextEditingController(
      text: widget.conversation.displayName,
    );
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
      await _chatRepo.updateConversationName(widget.conversation.id, newName);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật tên nhóm')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể đổi tên nhóm: ${e.toString()}')),
      );
    }
  }

  Future<void> _leaveConversation() async {
    final userId = _authRepo.currentUserId;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.conversation.isGroup ? 'Rời nhóm' : 'Rời cuộc trò chuyện',
        ),
        content: const Text('Bạn có chắc muốn thực hiện thao tác này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _chatRepo.leaveConversation(
        conversationId: widget.conversation.id,
        userId: userId,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể rời cuộc trò chuyện: ${e.toString()}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final isTablet = width >= 900;
    final isTabletLandscape = isTablet && width > height;
    final contentMaxWidth = isTablet
        ? (isTabletLandscape ? 820.0 : 920.0)
        : double.infinity;

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessagesList(),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: _buildInputArea(),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width <= 360;

    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: isCompact ? 18 : 20,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: widget.conversation.displayAvatar.isNotEmpty
                ? NetworkImage(widget.conversation.displayAvatar)
                : null,
            child: widget.conversation.displayAvatar.isEmpty
                ? Text(
                    widget.conversation.displayName[0].toUpperCase(),
                    style: TextStyle(fontSize: isCompact ? 16 : 18),
                  )
                : null,
          ),
          SizedBox(width: isCompact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.conversation.displayName,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!widget.conversation.isGroup)
                  Text(
                    widget.conversation.otherUserOnline == true
                        ? 'Đang hoạt động'
                        : 'Ngoại tuyến',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
        IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showConversationMenu,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMessagesList() {
    final currentUserId = _authRepo.currentUserId;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width <= 360;
    final isTabletLandscape =
        width >= 900 && width > MediaQuery.sizeOf(context).height;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 6 : 8,
        horizontal: isCompact
            ? 8
            : isTabletLandscape
            ? 10
            : 12,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMine = message.senderId == currentUserId;

        bool showDateSeparator =
            index == _messages.length - 1 ||
            !DateTimeHelper.isSameDay(
              message.createdAt,
              _messages[index + 1].createdAt,
            );

        return Column(
          children: [
            if (showDateSeparator) _buildDateSeparator(message.createdAt),
            _buildMessageBubble(message, isMine),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        DateTimeHelper.formatMessageSeparator(date),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMine) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width <= 360;
    final customColors = theme.extension<CustomThemeColors>()!;

    final bubbleColor = isMine
        ? customColors.chatBubbleMine
        : customColors.chatBubbleOther;
    final textColor = isMine
        ? customColors.onChatBubbleMine
        : customColors.onChatBubbleOther;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(isMine ? 14 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 14),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onLongPress: () => _showMessageActions(message, isMine),
        borderRadius: borderRadius,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: isCompact ? 3 : 4),
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.of(context).size.width * (isCompact ? 0.82 : 0.75),
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 12,
            vertical: isCompact ? 8 : 9,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine && widget.conversation.isGroup)
                Text(
                  message.senderName ?? 'Unknown',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              Text(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateTimeHelper.formatMessageTime(message.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width <= 360;
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 8 : 10,
            isCompact ? 6 : 8,
            isCompact ? 8 : 10,
            isCompact ? 8 : 10,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: theme.colorScheme.primary,
                onPressed: () {},
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Nhắn tin...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: theme.colorScheme.primary,
                ),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 80,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Bắt đầu cuộc trò chuyện',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gửi tin nhắn để bắt đầu cuộc trò chuyện ngay bây giờ.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
