import 'dart:io';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'chat_screen.dart';
import 'product_review_screen.dart';
import 'proof_of_delivery_screen.dart';
import 'order_tracking_screen.dart';

// ─── My Orders ─────────────────────────────────────────────────────────────
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});
  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _orders = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final List<String> _statuses = ['All', 'pending', 'confirmed', 'prepared', 'shipped', 'delivered', 'cancelled'];

  @override
  void initState() { super.initState(); _tabs = TabController(length: _statuses.length, vsync: this); _load(); }

  @override
  void dispose() { _tabs.dispose(); _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/orders');
    if (mounted) setState(() { _orders = res['orders'] ?? []; _loading = false; });
  }

  List _filtered(String status) {
    var list = status == 'All' ? _orders : _orders.where((o) => o['status'] == status).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((o) {
        final num = (o['order_number'] ?? '').toString().toLowerCase();
        final items = (o['items'] as List? ?? []);
        final itemMatch = items.any((i) => (i['name'] ?? '').toString().toLowerCase().contains(q));
        return num.contains(q) || itemMatch;
      }).toList();
    }
    return list;
  }

  Future<void> _showCancelDialog(String orderNumber, Map<String, dynamic> order) async {
    String? selectedReason;
    String customReason = '';
    
    final reasons = [
      'Ordered by mistake',
      'Found a better price',
      'No longer needed',
      'Shipping too slow',
      'Payment issues',
      'Other'
    ];
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: AppTheme.warning, size: 24),
              const SizedBox(width: 12),
              const Text('Cancel Order'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to cancel this order?', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              const Text('Select a reason or type your own:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...reasons.map((reason) => RadioListTile<String>(
                title: Text(reason, style: const TextStyle(fontSize: 13)),
                value: reason,
                groupValue: selectedReason,
                onChanged: (value) {
                  setState(() {
                    selectedReason = value;
                    if (value != 'Other') customReason = '';
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              )),
              if (selectedReason == 'Other') ...[
                const SizedBox(height: 8),
                TextField(
                  onChanged: (value) => setState(() => customReason = value),
                  decoration: InputDecoration(
                    labelText: 'Enter your reason',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.warning, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Once cancelled, this action cannot be undone.', 
                        style: TextStyle(fontSize: 11, color: AppTheme.textDark)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep Order'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = selectedReason == 'Other' ? customReason.trim() : selectedReason;
                if (reason == null || reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select or enter a reason'), backgroundColor: AppTheme.warning),
                  );
                  return;
                }
                Navigator.pop(context);
                _cancelOrder(orderNumber, order, reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel Order'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelOrder(String orderNumber, Map<String, dynamic> order, String reason) async {
    try {
      final orderId = order['id']?.toString() ?? orderNumber;
      final res = await ApiService.put(
        '/api/orders/$orderId/status',
        {
          'status': 'cancelled',
          'cancel_reason': reason,
        },
      );
      
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order cancelled successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
          _load(); // Refresh the orders list
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Failed to cancel order'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection error. Please try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: AppTheme.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: _statuses.map((s) => Tab(text: s == 'All' ? 'All' : s[0].toUpperCase() + s.substring(1))).toList(),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by order number or product name...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                filled: true, fillColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : TabBarView(
                    controller: _tabs,
                    children: _statuses.map((s) {
                      final list = _filtered(s);
                      if (list.isEmpty) return EmptyState(icon: Icons.receipt_long_outlined, title: _searchQuery.isNotEmpty ? 'No matching orders' : 'No ${s == 'All' ? '' : s} orders');
                      return RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          itemBuilder: (_, i) => OrderCard(
                            order: list[i],
                            onTap: () => _showOrderDetail(list[i]),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scroll,
            children: [
              Row(
                children: [
                  Text(order['order_number'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  StatusBadge(status),
                ],
              ),
              const SizedBox(height: 16),
              ...(order['items'] as List? ?? []).map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text('${item['size'] ?? ''} · ${item['color'] ?? ''} · Qty: ${item['quantity']}', style: const TextStyle(fontSize: 12)),
                trailing: Text('₱${(item['price'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary)),
              )),
              const Divider(),
              _detailRow('Total', '₱${(order['total_amount'] as num).toStringAsFixed(2)}', bold: true),
              _detailRow('Payment', order['payment_method'] ?? ''),
              _detailRow('Payment Status', order['payment_status'] ?? ''),
              if (order['tracking_number'] != null) _detailRow('Tracking', order['tracking_number']),
              if (order['special_notes'] != null && order['special_notes'].toString().isNotEmpty)
                _detailRow('Notes', order['special_notes']),
              const SizedBox(height: 20),

              // Proof of delivery image (if delivered)
              if (status == 'delivered' && order['proof_of_delivery'] != null) ...[
                const Text('Proof of Delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    ApiService.imageUrl(order['proof_of_delivery']),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 80,
                      color: AppTheme.background,
                      child: const Center(child: Icon(Icons.image_not_supported, color: AppTheme.textMuted)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Track order (shipped/delivered)
                  if (['shipped', 'delivered'].contains(status))
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(orderNumber: order['order_number'], order: order),
                        ));
                      },
                      icon: const Icon(Icons.location_on_outlined, size: 16),
                      label: const Text('Track Order', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.info, side: const BorderSide(color: AppTheme.info)),
                    ),

                  // Chat with seller
                  if (order['seller_id'] != null)
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        final res = await ApiService.post('/api/chats/create', {
                          'recipient_id': order['seller_id'],
                          'order_id': order['id'],
                          'order_number': order['order_number'],
                        });
                        if (res['success'] == true && mounted) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ChatScreen(conversation: res['conversation'] ?? {}),
                          ));
                        }
                      },
                      icon: const Icon(Icons.chat_outlined, size: 16, color: Colors.white),
                      label: const Text('Chat Seller', style: TextStyle(fontSize: 13, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                    ),

                  // Write review (delivered)
                  if (status == 'delivered')
                    ...((order['items'] as List? ?? []).take(1).map((item) => OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ProductReviewScreen(
                            productId: item['product_id'] ?? item['id'],
                            productName: item['name'] ?? '',
                          ),
                        ));
                      },
                      icon: const Icon(Icons.rate_review_outlined, size: 16),
                      label: const Text('Write Review', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.warning, side: const BorderSide(color: AppTheme.warning)),
                    ))),

                  // View proof of delivery (delivered)
                  if (status == 'delivered' && order['proof_of_delivery'] == null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ProofOfDeliveryScreen(orderNumber: order['order_number'], order: order),
                        ));
                      },
                      icon: const Icon(Icons.photo_camera_outlined, size: 16),
                      label: const Text('Upload Proof', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.success, side: const BorderSide(color: AppTheme.success)),
                    ),

                  // Cancel order
                  if (['pending', 'confirmed', 'prepared'].contains(status))
                    OutlinedButton.icon(
                      onPressed: () { 
                        Navigator.pop(context); 
                        _showCancelDialog(order['order_number'], order);
                      },
                      icon: const Icon(Icons.cancel_outlined, color: AppTheme.error, size: 16),
                      label: const Text('Cancel Order', style: TextStyle(color: AppTheme.error, fontSize: 13)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text('$label: ', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        Expanded(child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w600, fontSize: bold ? 15 : 13, color: bold ? AppTheme.primary : AppTheme.textDark))),
      ],
    ),
  );
}

// ─── Wishlist ──────────────────────────────────────────────────────────────
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});
  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/wishlist');
    if (mounted) setState(() { _items = res['items'] ?? []; _loading = false; });
  }

  Future<void> _remove(int productId) async {
    await ApiService.delete('/api/wishlist/$productId');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Wishlist'), backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _items.isEmpty
              ? const EmptyState(icon: Icons.favorite_border, title: 'Your wishlist is empty', subtitle: 'Save items you love')
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72),
                  itemCount: _items.length,
                  itemBuilder: (_, i) => ProductCard(
                    product: _items[i],
                    isWishlisted: true,
                    onWishlist: () => _remove(_items[i]['product_id']),
                  ),
                ),
    );
  }
}

// ─── Notifications ─────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List _notifs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/notifications');
    if (mounted) setState(() { _notifs = res['notifications'] ?? []; _loading = false; });
  }

  Future<void> _markAllRead() async {
    await ApiService.put('/api/notifications/read-all', {});
    _load();
  }

  IconData _icon(String type) {
    switch (type) {
      case 'order_confirmed': return Icons.check_circle;
      case 'order_shipped': return Icons.local_shipping;
      case 'order_delivered': return Icons.done_all;
      case 'order_cancelled': return Icons.cancel;
      case 'payment_success': return Icons.payment;
      case 'stock_alert': return Icons.inventory;
      case 'price_drop': return Icons.trending_down;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        actions: [TextButton(onPressed: _markAllRead, child: const Text('Mark all read', style: TextStyle(color: Colors.white70, fontSize: 12)))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _notifs.isEmpty
              ? const EmptyState(icon: Icons.notifications_none, title: 'No notifications', subtitle: 'You\'re all caught up!')
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _notifs.length,
                    itemBuilder: (_, i) {
                      final n = _notifs[i];
                      final unread = n['is_read'] == false || n['is_read'] == 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: unread ? AppTheme.primary.withValues(alpha: 0.05) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: unread ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.border),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(gradient: AppTheme.brandGradient, borderRadius: BorderRadius.circular(12)),
                            child: Icon(_icon(n['type'] ?? ''), color: Colors.white, size: 20),
                          ),
                          title: Text(n['message'] ?? '', style: TextStyle(fontSize: 13, fontWeight: unread ? FontWeight.w600 : FontWeight.normal)),
                          subtitle: Text(n['time_ago'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          trailing: unread ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)) : null,
                          onTap: () async {
                            await ApiService.put('/api/notifications/${n['id']}/read', {});
                            _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─── Profile ───────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _user;
  String? _profilePhoto;
  bool _loading = true;
  int _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;
  Timer? _pollTimer;
  String? _lastPhotoHash;

  String get _profilePhotoUrl {
    if (_profilePhoto == null || _profilePhoto!.isEmpty) return '';
    return ApiService.imageUrl('$_profilePhoto?t=$_photoCacheBuster');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkForUpdates());
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;
    try {
      final res = await ApiService.get('/api/account/profile');
      if (!mounted) return;
      
      if (res['user'] is Map<String, dynamic>) {
        final serverUser = res['user'] as Map<String, dynamic>;
        final serverPhoto = (serverUser['profile_picture'] ?? serverUser['profile_photo'])?.toString();
        
        // Check if any user data has changed
        bool hasChanges = false;
        
        if (serverPhoto != _lastPhotoHash) {
          _lastPhotoHash = serverPhoto;
          hasChanges = true;
        }
        
        // Check other fields
        if (_user != null) {
          if (serverUser['name'] != _user!['name'] ||
              serverUser['email'] != _user!['email'] ||
              serverUser['phone'] != _user!['phone']) {
            hasChanges = true;
          }
        }
        
        if (hasChanges) {
          final prefs = await SharedPreferences.getInstance();
          if (serverPhoto?.isNotEmpty == true) {
            await prefs.setString('profile_photo', serverPhoto!);
            CachedNetworkImage.evictFromCache(ApiService.imageUrl(serverPhoto));
          } else {
            await prefs.remove('profile_photo');
            if (_profilePhoto != null) CachedNetworkImage.evictFromCache(ApiService.imageUrl(_profilePhoto!));
          }
          
          if (mounted) {
            setState(() {
              _user = serverUser;
              _profilePhoto = serverPhoto;
              _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;
            });
            context.read<AuthProvider>().loadUser();
          }
        }
      }
    } catch (e) {
      // Silently fail polling
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/account/profile');
    final prefs = await SharedPreferences.getInstance();

    String? serverPhoto;
    if (res['user'] is Map<String, dynamic>) {
      serverPhoto = (res['user']['profile_picture'] ?? res['user']['profile_photo'])?.toString();
    }

    _lastPhotoHash = serverPhoto;
    String? effectivePhoto = serverPhoto?.isNotEmpty == true ? serverPhoto : prefs.getString('profile_photo');

    if (serverPhoto?.isNotEmpty == true) {
      await prefs.setString('profile_photo', serverPhoto!);
      CachedNetworkImage.evictFromCache(ApiService.imageUrl(serverPhoto));
    }

    if (mounted) {
      setState(() {
        _user = res['user'];
        _profilePhoto = effectivePhoto;
        _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;
        _loading = false;
      });
      context.read<AuthProvider>().loadUser();
    }
  }



  Future<void> _uploadProfilePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
      
      if (photo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected'), backgroundColor: AppTheme.warning),
          );
        }
        return;
      }

      // Crop the image to a square
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: photo.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: AppTheme.primaryDark,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (croppedFile == null || croppedFile.path.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image cropping cancelled'), backgroundColor: AppTheme.warning),
          );
        }
        return;
      }

      // Upload to server
      if (mounted) setState(() => _loading = true);
      
      final response = await ApiService.uploadFile(
        '/api/account/profile-photo',
        File(croppedFile.path),
        'photo',
        {},
      );

      if (!mounted) return;

      if (response['success'] == true) {
        final photoUrl = response['photo_url'] as String?;
        if (photoUrl != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_photo', photoUrl);
          CachedNetworkImage.evictFromCache(ApiService.imageUrl(photoUrl));
          
          setState(() {
            _profilePhoto = photoUrl;
            _lastPhotoHash = photoUrl;
            _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;
            if (_user != null) {
              _user!['profile_photo'] = photoUrl;
              _user!['profile_picture'] = photoUrl;
            }
            _loading = false;
          });
          
          context.read<AuthProvider>().loadUser();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully!'), backgroundColor: AppTheme.success),
          );
        } else {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload succeeded but no photo URL returned'), backgroundColor: AppTheme.warning),
          );
        }
      } else {
        setState(() => _loading = false);
        final errorMsg = response['error'] ?? response['message'] ?? 'Failed to upload photo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppTheme.error),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text('Are you sure you want to remove your profile photo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ApiService.delete('/api/account/profile-photo');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_photo');
      if (_profilePhoto != null) CachedNetworkImage.evictFromCache(ApiService.imageUrl(_profilePhoto!));
      if (mounted) {
        setState(() {
          _profilePhoto = null;
          _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;
          if (_user != null) {
            _user!.remove('profile_photo');
            _user!.remove('profile_picture');
          }
        });
        context.read<AuthProvider>().loadUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo removed!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove photo'), backgroundColor: AppTheme.error),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _computeInitials() {
    final name = _user?['name'] ?? _user?['email'] ?? 'U';
    if (name.isEmpty) return 'U';
    if (name.contains('@')) return name[0].toUpperCase();
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFFEE3), Color(0xFFFFC6BF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Avatar with camera button
                          Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.brandGradient,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: _profilePhoto != null && _profilePhoto!.isNotEmpty
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: _profilePhotoUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Center(
                                            child: Text(_computeInitials(), style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w700)),
                                          ),
                                          errorWidget: (_, __, ___) => Center(
                                            child: Text(_computeInitials(), style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w700)),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(_computeInitials(), style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w700)),
                                      ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _uploadProfilePhoto,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.brandGradient,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primary.withValues(alpha: 0.4),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _user?['name'] ?? 'User',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user?['email'] ?? '',
                            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AppTheme.brandGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              (_user?['role'] ?? 'buyer').toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                            ),
                          ),
                          if (_profilePhoto != null && _profilePhoto!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _removeProfilePhoto,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Remove Photo', style: TextStyle(fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                side: const BorderSide(color: AppTheme.error),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Personal Information Section
                    const Text(
                      'Personal Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 12),
                    _infoTile('Full Name', _user?['name'] ?? '-', Icons.person_outline),
                    const SizedBox(height: 10),
                    _infoTile('Email Address', _user?['email'] ?? '-', Icons.email_outlined),
                    const SizedBox(height: 10),
                    _infoTile('Phone Number', _user?['phone'] ?? 'Not set', Icons.phone_outlined),
                    const SizedBox(height: 24),

                    // Account Settings Section
                    const Text(
                      'Account Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 12),
                    _menuItem(Icons.edit_outlined, 'Edit Profile', 'Update your personal information', () => Navigator.pushNamed(context, '/edit-profile').then((_) => _load())),
                    _menuItem(Icons.location_on_outlined, 'My Addresses', 'Manage delivery addresses', () => Navigator.pushNamed(context, '/addresses')),
                    _menuItem(Icons.lock_outline, 'Change Password', 'Update your password', () => Navigator.pushNamed(context, '/change-password')),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Orders & Activity Section
                    const Text(
                      'Orders & Activity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 12),
                    _menuItem(Icons.shopping_bag_outlined, 'My Orders', 'Track and manage orders', () => Navigator.pushNamed(context, '/orders')),
                    _menuItem(Icons.favorite_border, 'Wishlist', 'View saved items', () => Navigator.pushNamed(context, '/wishlist')),
                    _menuItem(Icons.notifications_outlined, 'Notifications', 'Manage notifications', () => Navigator.pushNamed(context, '/notifications')),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Logout
                    _menuItem(Icons.logout, 'Logout', 'Sign out of your account', () => Navigator.pushReplacementNamed(context, '/logout'), color: AppTheme.error),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.3),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _menuItem(IconData icon, String label, String subtitle, VoidCallback onTap, {Color? color}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: (color ?? AppTheme.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color ?? AppTheme.primary, size: 24),
      ),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: color ?? AppTheme.textDark),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
      ),
      trailing: Icon(Icons.chevron_right, color: color ?? AppTheme.textMuted, size: 20),
      onTap: onTap,
    ),
  );
}

// ─── Addresses ─────────────────────────────────────────────────────────────
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/account/addresses');
    if (mounted) {
      setState(() {
        _addresses = List<Map<String, dynamic>>.from(res['addresses'] ?? []);
        _loading = false;
      });
    }
  }

  Future<void> _deleteAddress(int? id) async {
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiService.delete('/api/account/addresses/$id');
      _load();
    }
  }

  Future<void> _setDefault(int? id) async {
    if (id == null) return;
    await ApiService.put('/api/account/addresses/$id', {'is_default': true});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Addresses'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _addresses.isEmpty
              ? const EmptyState(icon: Icons.location_on_outlined, title: 'No addresses saved', subtitle: 'Add a delivery address to get started')
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _addresses.length,
                    itemBuilder: (_, i) => _addressCard(_addresses[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddAddressScreen()),
        ).then((_) => _load()),
      ),
    );
  }

  Widget _addressCard(Map<String, dynamic> addr) {
    final isDefault = addr['is_default'] == true || addr['is_default'] == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDefault ? AppTheme.primary : AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(addr['label'] ?? 'Address', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        '${addr['street'] ?? ''}, ${addr['barangay'] ?? ''}, ${addr['city'] ?? ''}, ${addr['province'] ?? ''}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Default', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('${addr['contact_name'] ?? ''} · ${addr['contact_phone'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _setDefault(addr['id']),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Set as Default', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _deleteAddress(addr['id']),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add/Edit Address ──────────────────────────────────────────────────────
class AddAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? address;
  const AddAddressScreen({super.key, this.address});
  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  late TextEditingController _labelCtrl, _nameCtrl, _phoneCtrl, _streetCtrl, _regionCtrl, _provinceCtrl, _cityCtrl, _barangayCtrl, _postalCtrl;
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final addr = widget.address;
    _labelCtrl = TextEditingController(text: addr?['label'] ?? 'Home');
    _nameCtrl = TextEditingController(text: addr?['contact_name'] ?? '');
    _phoneCtrl = TextEditingController(text: addr?['contact_phone'] ?? '');
    _streetCtrl = TextEditingController(text: addr?['street'] ?? '');
    _regionCtrl = TextEditingController(text: addr?['region'] ?? '');
    _provinceCtrl = TextEditingController(text: addr?['province'] ?? '');
    _cityCtrl = TextEditingController(text: addr?['city'] ?? '');
    _barangayCtrl = TextEditingController(text: addr?['barangay'] ?? '');
    _postalCtrl = TextEditingController(text: addr?['postal_code'] ?? '');
    _isDefault = addr?['is_default'] == true || addr?['is_default'] == 1;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _regionCtrl.dispose();
    _provinceCtrl.dispose();
    _cityCtrl.dispose();
    _barangayCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_streetCtrl.text.isEmpty || _cityCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    setState(() => _saving = true);
    final payload = {
      'label': _labelCtrl.text,
      'contact_name': _nameCtrl.text,
      'contact_phone': _phoneCtrl.text,
      'street': _streetCtrl.text,
      'region': _regionCtrl.text,
      'province': _provinceCtrl.text,
      'city': _cityCtrl.text,
      'barangay': _barangayCtrl.text,
      'postal_code': _postalCtrl.text,
      'is_default': _isDefault,
    };

    late final response;
    if (widget.address != null) {
      response = await ApiService.put('/api/account/addresses/${widget.address!['id']}', payload);
    } else {
      response = await ApiService.post('/api/account/addresses', payload);
    }

    setState(() => _saving = false);

    if (response['success'] == true) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['error'] ?? 'Failed to save address')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.address == null ? 'Add Address' : 'Edit Address'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _field('Label', _labelCtrl, hint: 'e.g., Home, Work'),
            _field('Contact Name', _nameCtrl, required: true),
            _field('Phone Number', _phoneCtrl, required: true, keyboard: TextInputType.phone),
            const SizedBox(height: 16),
            const Text('Address Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.left),
            const SizedBox(height: 12),
            _field('Street Address*', _streetCtrl, required: true, lines: 2),
            _field('Region', _regionCtrl),
            _field('Province', _provinceCtrl),
            _field('City*', _cityCtrl, required: true),
            _field('Barangay', _barangayCtrl),
            _field('Postal Code', _postalCtrl),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v ?? false),
              title: const Text('Set as default address', style: TextStyle(fontSize: 14)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: widget.address == null ? 'Save Address' : 'Update Address',
              onPressed: _saving ? null : _save,
              loading: _saving,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool required = false, int lines = 1, TextInputType keyboard = TextInputType.text, String? hint}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: lines,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      const SizedBox(height: 16),
    ],
  );
}

// ─── Edit Profile ──────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _addressCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/account/profile');
    if (mounted) {
      final user = res['user'] ?? {};
      _nameCtrl.text = user['name'] ?? '';
      _phoneCtrl.text = user['phone'] ?? '';
      _addressCtrl.text = user['address'] ?? '';
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _saving = true);
    final res = await ApiService.put('/api/account/profile', {
      'name': _nameCtrl.text,
      'phone': _phoneCtrl.text,
      'address': _addressCtrl.text,
    });
    setState(() => _saving = false);
    if (!mounted) return;
    if (res['success'] == true) {
      // Update AuthProvider immediately
      context.read<AuthProvider>().loadUser();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!'), backgroundColor: AppTheme.success));
      Navigator.pop(context, true); // Return true to indicate changes
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Failed to update profile'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Edit Profile'), backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _field('Full Name *', _nameCtrl),
                  _field('Phone Number', _phoneCtrl, keyboard: TextInputType.phone),
                  _field('Address', _addressCtrl, lines: 3),
                  const SizedBox(height: 24),
                  GradientButton(label: 'Save Changes', onPressed: _saving ? null : _save, loading: _saving),
                ],
              ),
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int lines = 1, TextInputType keyboard = TextInputType.text}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      TextField(
        controller: ctrl, keyboardType: keyboard, maxLines: lines,
        decoration: InputDecoration(
          filled: true, fillColor: AppTheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      const SizedBox(height: 16),
    ],
  );
}

// ─── Change Password ───────────────────────────────────────────────────────
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true, _obscureNew = true, _obscureConfirm = true;

  @override
  void dispose() { _currentCtrl.dispose(); _newCtrl.dispose(); _confirmCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New passwords do not match'), backgroundColor: AppTheme.error));
      return;
    }
    if (_newCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: AppTheme.error));
      return;
    }
    setState(() => _saving = true);
    final res = await ApiService.put('/api/account/change-password', {
      'current_password': _currentCtrl.text,
      'new_password': _newCtrl.text,
    });
    setState(() => _saving = false);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed!'), backgroundColor: AppTheme.success));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Failed to change password'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Change Password'), backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _pwField('Current Password', _currentCtrl, _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent)),
            _pwField('New Password', _newCtrl, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
            _pwField('Confirm New Password', _confirmCtrl, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
            const SizedBox(height: 24),
            GradientButton(label: 'Change Password', onPressed: _saving ? null : _save, loading: _saving),
          ],
        ),
      ),
    );
  }

  Widget _pwField(String label, TextEditingController ctrl, bool obscure, VoidCallback toggle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      TextField(
        controller: ctrl, obscureText: obscure,
        decoration: InputDecoration(
          filled: true, fillColor: AppTheme.surface,
          suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: AppTheme.textMuted), onPressed: toggle),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      const SizedBox(height: 16),
    ],
  );
}
