import 'package:flutter/material.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderNumber;
  final Map<String, dynamic> order;

  const OrderTrackingScreen({super.key, required this.orderNumber, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Map<String, dynamic> _order;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _startTracking();
  }

  void _startTracking() {
    // In a real app, you'd set up WebSocket or polling for live updates
    // For now, just load once
  }

  Future<void> _refreshTracking() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/orders/${widget.orderNumber}');
      if (mounted) {
        setState(() {
          _order = res['order'] ?? _order;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openMap() async {
    if (_order['delivery_latitude'] == null || _order['delivery_longitude'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available yet')));
      return;
    }

    final lat = _order['delivery_latitude'];
    final lng = _order['delivery_longitude'];
    final googleMapsUrl = 'https://maps.google.com/?q=$lat,$lng';
    final appleMapsUrl = 'maps://?q=$lat,$lng';

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl));
      }
    } catch (e) {
      print('Could not launch map: $e');
    }
  }

  Future<void> _callDeliveryPerson() async {
    final phone = _order['delivery_person_phone'];
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact information not available')));
      return;
    }

    final telUrl = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(telUrl))) {
      await launchUrl(Uri.parse(telUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = ['pending', 'confirmed', 'prepared', 'shipped', 'delivered'];
    final currentStatusIndex = statuses.indexOf(_order['status'] ?? 'pending');

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Order Tracking'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshTracking,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _refreshTracking,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Order Number', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          Text(_order['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('Estimated Delivery', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          Text(_order['estimated_delivery'] ?? 'Calculating...', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    StatusBadge(_order['status'] ?? 'pending'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Delivery Person Card
              if (_order['delivery_person_name'] != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(gradient: AppTheme.brandGradient, shape: BoxShape.circle),
                        child: Center(
                          child: Text((_order['delivery_person_name'] ?? 'D')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_order['delivery_person_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 12, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text('${(_order['delivery_person_rating'] ?? 5).toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: _callDeliveryPerson,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.phone, size: 16, color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Map Section (placeholder - can be replaced with actual map)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Stack(
                  children: [
                    // Placeholder map
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.location_on, size: 40, color: AppTheme.primary),
                          SizedBox(height: 8),
                          Text('Delivery in Progress', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          SizedBox(height: 4),
                          Text('Tap to view full map', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _openMap,
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Address Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_order['address'] ?? ''}, ${_order['city'] ?? ''}, ${_order['postal_code'] ?? ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Status Timeline
              const Text('Order Timeline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 16),
              _buildTimeline(statuses, currentStatusIndex),
              const SizedBox(height: 24),

              // Order Items
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 12),
              ...(_order['items'] as List? ?? []).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppTheme.border),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(ApiService.imageUrl(item['image_url']), fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${item['size'] ?? ''} · ${item['color'] ?? ''} · Qty: ${item['quantity']}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          const SizedBox(height: 4),
                          Text('₱${(item['price'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 24),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(List<String> statuses, int currentIndex) {
    final statusLabels = {
      'pending': 'Order Placed',
      'confirmed': 'Order Confirmed',
      'prepared': 'Being Prepared',
      'shipped': 'Out for Delivery',
      'delivered': 'Delivered',
    };

    return Column(
      children: List.generate(statuses.length, (index) {
        final status = statuses[index];
        final isCompleted = index <= currentIndex;
        final isCurrent = index == currentIndex;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.primary : AppTheme.border,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : Icons.schedule,
                    size: 16,
                    color: isCompleted ? Colors.white : AppTheme.textMuted,
                  ),
                ),
                if (index < statuses.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: index < currentIndex ? AppTheme.primary : AppTheme.border,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabels[status] ?? status,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13,
                        color: isCompleted ? AppTheme.textDark : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getStatusTime(status),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  String _getStatusTime(String status) {
    // In a real app, you'd get the actual timestamp from the order
    return 'Today';
  }
}
