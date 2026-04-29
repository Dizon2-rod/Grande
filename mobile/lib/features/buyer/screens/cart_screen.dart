import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List _items = [];
  bool _loading = true;
  Set<String> _selectedItems = {};
  double _shippingFee = 50.0;

  @override
  void initState() { 
    super.initState(); 
    _load(); 
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/cart');
    if (mounted) {
      final items = res['items'] ?? [];
      setState(() { 
        _items = items;
        _loading = false;
        
        // Initialize all items as selected by default
        _selectedItems = items.map<String>((item) => _getItemKey(item)).toSet();
        
        // Get shipping fee from backend or use default
        if (res['shipping_fee'] != null) {
          _shippingFee = (res['shipping_fee'] as num).toDouble();
        } else {
          _shippingFee = items.isNotEmpty ? 50.0 : 0.0;
        }
      });
    }
  }

  String _getItemKey(dynamic item) {
    return '${item['product_id']}_${item['size'] ?? ''}_${item['color'] ?? ''}';
  }

  bool _isItemSelected(dynamic item) {
    return _selectedItems.contains(_getItemKey(item));
  }

  void _toggleItemSelection(dynamic item) {
    setState(() {
      final key = _getItemKey(item);
      if (_selectedItems.contains(key)) {
        _selectedItems.remove(key);
      } else {
        _selectedItems.add(key);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedItems.length == _items.length) {
        _selectedItems.clear();
      } else {
        _selectedItems = _items.map<String>((item) => _getItemKey(item)).toSet();
      }
    });
  }

  List _getSelectedItemsData() {
    return _items.where((item) => _isItemSelected(item)).toList();
  }

  double _getSelectedSubtotal() {
    return _getSelectedItemsData().fold(0.0, (sum, item) => 
      sum + ((item['price'] as num) * (item['quantity'] as num)));
  }

  double _getSelectedTotal() {
    final subtotal = _getSelectedSubtotal();
    return subtotal > 0 ? subtotal + _shippingFee : 0.0;
  }

  Future<void> _updateQty(int productId, int qty, String size, String color) async {
    if (qty < 1) return;
    
    final requestBody = <String, dynamic>{'quantity': qty};
    if (size.isNotEmpty) requestBody['size'] = size;
    if (color.isNotEmpty) requestBody['color'] = color;
    
    await ApiService.put('/api/cart/$productId', requestBody);
    _load();
  }

  Future<void> _remove(int productId, String size, String color) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: const Text('Remove this item from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    final requestBody = <String, dynamic>{};
    if (size.isNotEmpty) requestBody['size'] = size;
    if (color.isNotEmpty) requestBody['color'] = color;
    
    await ApiService.delete('/api/cart/$productId', requestBody.isNotEmpty ? requestBody : null);
    _load();
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to clear your entire cart? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await ApiService.delete('/api/cart/clear');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart cleared successfully'), backgroundColor: AppTheme.success),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cart: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedSubtotal = _getSelectedSubtotal();
    final selectedTotal = _getSelectedTotal();
    final selectedCount = _getSelectedItemsData().length;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Cart (${_items.length})'), 
        backgroundColor: AppTheme.primaryDark, 
        foregroundColor: Colors.white,
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(
                _selectedItems.length == _items.length ? 'Deselect All' : 'Select All',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearCart,
              tooltip: 'Clear Cart',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _items.isEmpty
              ? const EmptyState(icon: Icons.shopping_cart_outlined, title: 'Your cart is empty', subtitle: 'Add items to get started')
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      final imgUrl = ApiService.imageUrl(item['image_url'] ?? '');
                      final isSelected = _isItemSelected(item);
                      final size = item['size'] ?? '';
                      final color = item['color'] ?? '';
                      final colorName = item['color_name'] ?? color;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface, 
                          borderRadius: BorderRadius.circular(14), 
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleItemSelection(item),
                              activeColor: AppTheme.primary,
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: imgUrl.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: imgUrl, width: 70, height: 70, fit: BoxFit.cover)
                                  : Container(width: 70, height: 70, color: AppTheme.background, child: const Icon(Icons.image, color: AppTheme.textMuted)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['product_name'] ?? item['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('${size.isNotEmpty ? size : 'N/A'}${colorName.isNotEmpty ? ' · $colorName' : ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  const SizedBox(height: 6),
                                  Text('₱${(item['price'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 14)),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20), 
                                  onPressed: () => _remove(item['product_id'], size, color),
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: item['quantity'] > 1 ? () => _updateQty(item['product_id'], item['quantity'] - 1, size, color) : null,
                                      child: Container(
                                        width: 28, 
                                        height: 28, 
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppTheme.border), 
                                          borderRadius: BorderRadius.circular(6),
                                        ), 
                                        child: const Icon(Icons.remove, size: 14),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8), 
                                      child: Text('${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                    GestureDetector(
                                      onTap: () => _updateQty(item['product_id'], item['quantity'] + 1, size, color),
                                      child: Container(
                                        width: 28, 
                                        height: 28, 
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary, 
                                          borderRadius: BorderRadius.circular(6),
                                        ), 
                                        child: const Icon(Icons.add, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: _items.isEmpty ? null : Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: AppTheme.surface, 
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Selected ($selectedCount):', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('₱${selectedSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Shipping:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                Text('₱${_shippingFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('₱${selectedTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 12),
            GradientButton(
              label: 'Proceed to Checkout',
              icon: Icons.payment,
              onPressed: selectedCount > 0 ? () {
                final selectedItems = _getSelectedItemsData();
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => CheckoutScreen(cartItems: selectedItems)),
                ).then((_) => _load());
              } : null,
            ),
          ],
        ),
      ),
    );
  }
}