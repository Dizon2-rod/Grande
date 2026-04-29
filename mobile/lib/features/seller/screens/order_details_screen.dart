import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderNumber;
  
  const OrderDetailsScreen({super.key, required this.orderNumber});
  
  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/orders/${widget.orderNumber}');
      if (mounted) {
        setState(() {
          _order = res['order'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_order == null) return;
    
    setState(() => _updating = true);
    
    try {
      final res = await ApiService.put(
        '/api/orders/${_order!['id']}/status',
        {'status': newStatus},
      );
      
      setState(() => _updating = false);
      
      if (res['success'] == true) {
        _load(); // Reload order
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order status updated!'), backgroundColor: AppTheme.success),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Failed to update status'), backgroundColor: AppTheme.error),
          );
        }
      }
    } catch (e) {
      setState(() => _updating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _showStatusDialog() async {
    if (_order == null) return;
    
    final currentStatus = _order!['status'] ?? 'pending';
    final availableStatuses = <String>[];
    
    // Define status flow
    if (currentStatus == 'pending') {
      availableStatuses.addAll(['confirmed', 'cancelled']);
    } else if (currentStatus == 'confirmed') {
      availableStatuses.add('prepared');
    } else if (currentStatus == 'prepared') {
      availableStatuses.add('shipped');
    }
    
    if (availableStatuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No status updates available'), backgroundColor: AppTheme.info),
      );
      return;
    }
    
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableStatuses.map((status) => ListTile(
            title: Text(status[0].toUpperCase() + status.substring(1)),
            onTap: () => Navigator.pop(context, status),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (selected != null) {
      _updateStatus(selected);
    }
  }

  Future<void> _printShippingLabel() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shipping label feature coming soon!'), backgroundColor: AppTheme.info),
    );
  }

  Future<void> _openChat() async {
    if (_order == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat feature coming soon!'), backgroundColor: AppTheme.info),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Order ${widget.orderNumber}'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          if (_order != null && ['confirmed', 'prepared', 'shipped'].contains(_order!['status']))
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printShippingLabel,
              tooltip: 'Print Shipping Label',
            ),
          if (_order != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: _openChat,
              tooltip: 'Chat with Customer',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _order == null
              ? const EmptyState(icon: Icons.error_outline, title: 'Order not found')
              : LoadingOverlay(
                  loading: _updating,
                  child: RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Status:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 10),
                                    StatusBadge(_order!['status'] ?? 'pending'),
                                    const Spacer(),
                                    if (['pending', 'confirmed', 'prepared'].contains(_order!['status']))
                                      TextButton(
                                        onPressed: _showStatusDialog,
                                        child: const Text('Update'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Placed: ${_formatDate(_order!['created_at'])}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Customer Info
                          _buildSection(
                            'Customer Information',
                            [
                              _buildInfoRow('Name', _order!['buyer']?['name'] ?? 'N/A'),
                              _buildInfoRow('Email', _order!['buyer']?['email'] ?? 'N/A'),
                              _buildInfoRow('Phone', _order!['buyer']?['phone'] ?? 'N/A'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Delivery Address
                          _buildSection(
                            'Delivery Address',
                            [
                              Text(
                                _order!['delivery_address'] ?? 'N/A',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Order Items
                          _buildSection(
                            'Order Items',
                            [
                              ...(_order!['items'] as List? ?? []).map((item) => _buildOrderItem(item)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Payment Summary
                          _buildSection(
                            'Payment Summary',
                            [
                              _buildSummaryRow('Subtotal', _order!['subtotal'] ?? 0),
                              _buildSummaryRow('Delivery Fee', _order!['delivery_fee'] ?? 0),
                              if (_order!['discount'] != null && _order!['discount'] > 0)
                                _buildSummaryRow('Discount', -(_order!['discount'] ?? 0), color: AppTheme.success),
                              const Divider(),
                              _buildSummaryRow(
                                'Total',
                                _order!['total_amount'] ?? 0,
                                isBold: true,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow('Payment Method', _order!['payment_method'] ?? 'N/A'),
                              _buildInfoRow('Payment Status', _order!['payment_status'] ?? 'N/A'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Rider Info (if assigned)
                          if (_order!['rider'] != null) ...[
                            _buildSection(
                              'Rider Information',
                              [
                                _buildInfoRow('Name', _order!['rider']?['name'] ?? 'N/A'),
                                _buildInfoRow('Phone', _order!['rider']?['phone'] ?? 'N/A'),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Notes
                          if (_order!['notes'] != null && _order!['notes'].toString().isNotEmpty) ...[
                            _buildSection(
                              'Order Notes',
                              [
                                Text(
                                  _order!['notes'] ?? '',
                                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 60,
              height: 60,
              color: AppTheme.surface,
              child: item['image_url'] != null
                  ? Image.network(
                      ApiService.imageUrl(item['image_url']),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, color: AppTheme.textMuted),
                    )
                  : const Icon(Icons.image, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item['size'] != null || item['color'] != null)
                  Text(
                    '${item['size'] ?? ''} ${item['color'] ?? ''}'.trim(),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                Text(
                  '₱${((item['price'] ?? 0) as num).toStringAsFixed(2)} × ${item['quantity'] ?? 1}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '₱${((item['subtotal'] ?? 0) as num).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, num amount, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? AppTheme.textDark,
            ),
          ),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: color ?? AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
