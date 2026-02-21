import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/datetime_helper.dart';
import '../../core/di/service_locator.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/chat/data/repositories/chat_repository.dart';
import '../../features/chat/data/models/conversation.dart';
import '../../features/chat/data/models/message.dart';

class ChatPage extends StatefulWidget {
  final Conversation conversation;

  const ChatPage({super.key, required this.conversation});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatRepository _chatRepo;
  late final AuthRepository _authRepo;
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

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

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
      if (mounted) {
        setState(() {
          _messages.insert(0, message);
        });
        _scrollToBottom();
      }
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
