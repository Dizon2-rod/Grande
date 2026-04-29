import 'package:flutter/material.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'package:intl/intl.dart';

class ChatCenterScreen extends StatefulWidget {
  const ChatCenterScreen({super.key});

  @override
  State<ChatCenterScreen> createState() => _ChatCenterScreenState();
}

class _ChatCenterScreenState extends State<ChatCenterScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/chats');
      if (mounted) {
        final chats = res['chats'] ?? [];
        final currentUser = await ApiService.getUser();
        final currentUserId = currentUser?['id'];
        
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(chats).map((chat) {
            // Determine display name based on user's role
            String displayName = '';
            String displaySubtitle = '';
            String roleInChat = 'unknown';
            
            if (currentUserId != null && chat['seller_id'] != null && chat['buyer_id'] != null) {
              if (currentUserId == chat['seller_id']) {
                // Current user is seller - show buyer's name
                roleInChat = 'seller';
                displayName = chat['buyer_name'] ?? 'Buyer';
                displaySubtitle = chat['order_number'] != null ? 'Order: ${chat['order_number']}' : '';
              } else if (currentUserId == chat['buyer_id']) {
                // Current user is buyer - show seller name + shop name
                roleInChat = 'buyer';
                final sellerName = chat['seller_name'] ?? '';
                final shopName = chat['shop_name'] ?? '';
                
                if (sellerName.isNotEmpty && shopName.isNotEmpty && sellerName != shopName) {
                  displayName = '$sellerName ($shopName)';
                } else if (shopName.isNotEmpty) {
                  displayName = shopName;
                } else if (sellerName.isNotEmpty) {
                  displayName = sellerName;
                } else {
                  displayName = 'Shop';
                }
                
                displaySubtitle = chat['order_number'] != null ? 'Order: ${chat['order_number']}' : '';
              }
            } else {
              // Fallback
              final userRole = currentUser?['role'] ?? 'buyer';
              if (userRole == 'seller') {
                roleInChat = 'seller';
                displayName = chat['buyer_name'] ?? 'Buyer';
              } else {
                roleInChat = 'buyer';
                displayName = chat['shop_name'] ?? chat['seller_name'] ?? 'Shop';
              }
              displaySubtitle = chat['order_number'] != null ? 'Order: ${chat['order_number']}' : '';
            }
            
            return {
              'id': chat['id'],
              'chat_id': chat['id'],
              'display_name': displayName,
              'subtitle': displaySubtitle,
              'last_message': chat['last_message'] ?? 'No messages yet',
              'last_message_time': chat['last_message_time'],
              'unread_count': chat['unread_count'] ?? 0,
              'order_number': chat['order_number'],
              'shop_name': chat['shop_name'],
              'seller_name': chat['seller_name'],
              'buyer_name': chat['buyer_name'],
              'role_in_chat': roleInChat,
              'seller_id': chat['seller_id'],
              'buyer_id': chat['buyer_id'],
            };
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chats: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: _conversations.isEmpty
                  ? const EmptyState(icon: Icons.mail_outline, title: 'No conversations', subtitle: 'Start messaging with sellers and riders')
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _conversations.length,
                      itemBuilder: (_, i) => _buildConversationTile(_conversations[i]),
                    ),
            ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv) {
    final unread = conv['unread_count'] as int? ?? 0;
    final displayName = conv['display_name'] ?? 'Unknown';
    final subtitle = conv['subtitle'] ?? '';
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)),
      ).then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unread > 0 ? AppTheme.primary.withValues(alpha: 0.05) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: unread > 0 ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(gradient: AppTheme.brandGradient, borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: Text(
                  displayName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(conv['last_message_time']),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv['last_message'] ?? 'No messages',
                          style: TextStyle(
                            fontSize: 12,
                            color: unread > 0 ? AppTheme.textDark : AppTheme.textMuted,
                            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return DateFormat('MMM d').format(dt);
    } catch (e) {
      return '';
    }
  }
}

// ─── Chat Screen ───────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> conversation;
  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ScrollController _scrollCtrl;
  final _msgCtrl = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/chats/${widget.conversation['chat_id']}/messages');
      if (mounted) {
        final currentUser = await ApiService.getUser();
        final currentUserId = currentUser?['id'];
        
        setState(() {
          _messages = List<Map<String, dynamic>>.from(res['messages'] ?? []).map((msg) {
            // Add is_own field based on sender_id
            msg['is_own'] = currentUserId != null && msg['sender_id'] == currentUserId;
            return msg;
          }).toList();
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;

    setState(() => _sending = true);
    try {
      final res = await ApiService.post('/api/chats/${widget.conversation['chat_id']}/messages', {
        'content': _msgCtrl.text.trim(),
      });
      
      if (res['success'] == true) {
        _msgCtrl.clear();
        _load();
      } else {
        throw Exception(res['error'] ?? 'Failed to send message');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.conversation['display_name'] ?? 'Chat', style: const TextStyle(fontSize: 16)),
            if (widget.conversation['subtitle'] != null && widget.conversation['subtitle'].toString().isNotEmpty)
              Text(widget.conversation['subtitle'], style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : Column(
                children: [
                  Expanded(
                    child: _messages.isEmpty
                        ? const Center(child: Text('No messages yet. Start the conversation!', style: TextStyle(color: AppTheme.textMuted)))
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  color: AppTheme.surface,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: AppTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: AppTheme.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _sending ? null : _sendMessage,
                            borderRadius: BorderRadius.circular(20),
                            child: Center(
                              child: _sending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.send, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isOwn = msg['is_own'] == true || msg['is_own'] == 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isOwn ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: !isOwn ? Border.all(color: AppTheme.border) : null,
          ),
          child: Column(
            crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                msg['content'] ?? '',
                style: TextStyle(
                  color: isOwn ? Colors.white : AppTheme.textDark,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatMessageTime(msg['created_at']),
                style: TextStyle(
                  color: isOwn ? Colors.white70 : AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMessageTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp.toString());
      return DateFormat('HH:mm').format(dt);
    } catch (e) {
      return '';
    }
  }
}
