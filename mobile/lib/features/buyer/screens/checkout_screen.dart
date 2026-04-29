import 'package:flutter/material.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'buyer_extra_screens.dart';

class CheckoutScreen extends StatefulWidget {
  final List cartItems;
  const CheckoutScreen({super.key, required this.cartItems});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'COD';
  bool _loading = false;
  bool _loadingAddresses = true;
  Map<String, dynamic>? _selectedAddress;
  List<Map<String, dynamic>> _addresses = [];
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingAddresses = true);
    final results = await Future.wait([
      ApiService.get('/api/account/profile'),
      ApiService.get('/api/account/addresses'),
    ]);
    if (mounted) {
      final user = results[0]['user'] ?? {};
      final addresses = (results[1]['addresses'] as List?) ?? [];
      setState(() {
        _user = user;
        _addresses = List<Map<String, dynamic>>.from(addresses);
        if (_addresses.isNotEmpty) {
          _selectedAddress = _addresses.first;
        }
        _loadingAddresses = false;
      });
    }
  }

  double get _subtotal => widget.cartItems.fold(0, (s, i) => s + ((i['price'] as num) * (i['quantity'] as num)));
  double get _deliveryFee => 50.0;
  double get _total => _subtotal + _deliveryFee;

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a delivery address')));
      return;
    }

    setState(() => _loading = true);
    final res = await ApiService.post('/api/orders', {
      'shipping_info': {
        'fullName': _selectedAddress?['contact_name'] ?? _user?['name'] ?? '',
        'email': _user?['email'] ?? '',
        'phone': _selectedAddress?['contact_phone'] ?? _user?['phone'] ?? '',
        'address': _selectedAddress?['street'] ?? '',
        'city': _selectedAddress?['city'] ?? '',
        'postal': _selectedAddress?['postal_code'] ?? '',
        'country': 'Philippines',
      },
      'payment_method': _paymentMethod,
      'special_notes': _notesCtrl.text,
      'items': widget.cartItems.map((i) => {
        'product_id': i['product_id'],
        'quantity': i['quantity'],
        'size': i['size'],
        'color': i['color'],
        'name': i['product_name'] ?? i['name'] ?? '',
        'price': i['price'],
      }).toList(),
      'shipping_fee': _deliveryFee,
      'total_amount': _total,
    });
    setState(() => _loading = false);
    if (!mounted) return;
    if (res['success'] == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: AppTheme.success, size: 40)),
              const SizedBox(height: 16),
              const Text('Order Placed!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Order #${res['order_number'] ?? ''}', style: const TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 6),
              const Text('Your order has been placed successfully.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('View Orders', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Order failed'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Checkout'), backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
      body: _loadingAddresses
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : LoadingOverlay(
              loading: _loading,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    // Delivery Address Selection
                    _section('Delivery Address', [
                      if (_addresses.isEmpty)
                        Center(
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              const Icon(Icons.location_off_outlined, size: 40, color: AppTheme.textMuted),
                              const SizedBox(height: 8),
                              const Text('No saved addresses', style: TextStyle(color: AppTheme.textMuted)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AddAddressScreen()),
                                ).then((_) => _loadProfile()),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Address'),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        )
                      else ...[
                        ..._addresses.map((addr) => GestureDetector(
                          onTap: () => setState(() => _selectedAddress = addr),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _selectedAddress?['id'] == addr['id'] ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _selectedAddress?['id'] == addr['id'] ? AppTheme.primary : AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _selectedAddress?['id'] == addr['id'] ? AppTheme.primary : Colors.transparent,
                                    border: Border.all(
                                      color: _selectedAddress?['id'] == addr['id'] ? AppTheme.primary : AppTheme.textMuted,
                                      width: 2,
                                    ),
                                  ),
                                  child: _selectedAddress?['id'] == addr['id']
                                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(addr['label'] ?? 'Address', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          const SizedBox(width: 8),
                                          if (addr['is_default'] == true || addr['is_default'] == 1)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                              child: const Text('Default', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${addr['street'] ?? ''}, ${addr['barangay'] ?? ''}, ${addr['city'] ?? ''}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text('${addr['contact_name'] ?? ''} • ${addr['contact_phone'] ?? ''}',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddAddressScreen()),
                            ).then((_) => _loadProfile()),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add New Address'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: const BorderSide(color: AppTheme.primary),
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 16),

                    // Payment Method
                    _section('Payment Method', [
                      Column(
                        children: ['COD', 'GCASH', 'PAYMAYA'].map((m) => RadioListTile<String>(
                          value: m,
                          groupValue: _paymentMethod,
                          onChanged: (value) => setState(() => _paymentMethod = value ?? 'COD'),
                          title: Text(m, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: m == 'COD' ? const Text('Pay on delivery', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)) : null,
                          activeColor: AppTheme.primary,
                          contentPadding: EdgeInsets.zero,
                        )).toList(),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Special Notes
                    _section('Special Notes (Optional)', [
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Any special instructions for delivery?',
                          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Order Summary
                    _section('Order Summary', [
                      ...widget.cartItems.map((i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text('${i['product_name']} x${i['quantity']}', style: const TextStyle(fontSize: 13))),
                            Text('₱${((i['price'] as num) * (i['quantity'] as num)).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      )),
                      const Divider(height: 20),
                      _row('Subtotal', '₱${_subtotal.toStringAsFixed(2)}'),
                      _row('Delivery Fee', '₱${_deliveryFee.toStringAsFixed(2)}'),
                      const Divider(height: 16),
                      _row('Total', '₱${_total.toStringAsFixed(2)}', bold: true),
                    ]),
                    const SizedBox(height: 24),

                    GradientButton(
                        label: 'Place Order — ₱${_total.toStringAsFixed(2)}', 
                        icon: Icons.check_circle_outline, 
                        onPressed: _placeOrder,
                        loading: _loading),
                    const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: bold ? AppTheme.textDark : AppTheme.textMuted, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: bold ? 16 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? AppTheme.primary : AppTheme.textDark)),
      ],
    ),
  );
}
