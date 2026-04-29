import 'package:flutter/material.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/payment_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

class PaymentScreen extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final double amount;
  final String? paymentMethod;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    this.paymentMethod,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _selectedMethod;
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _loading = true);
    final methods = await PaymentService.getAvailablePaymentMethods();
    final savedMethod = await PaymentService.getSavedPaymentMethod();

    if (mounted) {
      setState(() {
        _paymentMethods = methods;
        _selectedMethod = savedMethod ?? (methods.isNotEmpty ? methods[0]['id'] : null);
        _loading = false;
      });
    }
  }

  Future<void> _processPayment() async {
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a payment method')));
      return;
    }

    setState(() => _processing = true);

    // Save preference
    await PaymentService.savePaymentMethod(methodId: _selectedMethod ?? '', methodName: _selectedMethod ?? '');

    if (_selectedMethod == 'cod') {
      // Process COD
      await _processCOD();
    } else if (_selectedMethod?.toLowerCase() == 'gcash' || _selectedMethod?.toLowerCase() == 'paymaya') {
      // Process PayMongo
      await _processPayMongo();
    } else if (_selectedMethod?.toLowerCase().contains('xendit') ?? false) {
      // Process Xendit
      await _processXendit();
    }

    setState(() => _processing = false);
  }

  Future<void> _processCOD() async {
    final res = await PaymentService.processCODPayment(
      orderId: widget.orderId,
      amount: widget.amount,
    );

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
                child: const Icon(Icons.check_circle, color: AppTheme.success, size: 40),
              ),
              const SizedBox(height: 16),
              const Text('Order Confirmed!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('You will pay on delivery', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 4),
              Text('Order #${widget.orderNumber}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Done', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Payment failed')));
    }
  }

  Future<void> _processPayMongo() async {
    final res = await PaymentService.initializePayMongoPayment(
      amount: widget.amount,
      description: 'Order #${widget.orderNumber}',
      orderId: widget.orderId,
      returnUrl: 'https://yourapp.com/payment-return',
      paymentMethod: _selectedMethod ?? 'gcash',
    );

    if (!mounted) return;

    if (res['success'] == true) {
      // Redirect to payment URL
      _showPaymentWebView(res['payment_url'] ?? res['checkoutUrl'] ?? '');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? 'Failed to initialize payment')),
      );
    }
  }

  Future<void> _processXendit() async {
    final userRes = await ApiService.get('/api/account/profile');
    final user = userRes['user'] ?? {};

    final res = await PaymentService.initializeXenditPayment(
      amount: widget.amount,
      description: 'Order #${widget.orderNumber}',
      orderId: widget.orderId,
      returnUrl: 'https://yourapp.com/payment-return',
      paymentMethod: _selectedMethod ?? 'CREDIT_CARD',
      email: user['email'] ?? '',
      phone: user['phone'] ?? '',
      name: user['name'] ?? '',
    );

    if (!mounted) return;

    if (res['success'] == true) {
      _showPaymentWebView(res['payment_url'] ?? '');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? 'Failed to initialize payment')),
      );
    }
  }

  void _showPaymentWebView(String url) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No payment URL provided')));
      return;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SafeArea(
          bottom: true,
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.55,
            child: Column(
              children: [
                AppBar(
                  title: const Text('Complete Payment'),
                  backgroundColor: AppTheme.primaryDark,
                  foregroundColor: Colors.white,
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.open_in_browser, size: 40, color: AppTheme.primary),
                        const SizedBox(height: 16),
                        const Text('Redirecting to payment provider...', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text('You will be redirected to complete your payment',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            // In a real app, you would open the payment URL in a browser
                            // For now, just show the URL
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open Payment Link'),
                        ),
                        const SizedBox(height: 16),
                        Text('Payment URL: $url',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Payment Method'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SafeArea(
              bottom: true,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // Order Summary
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
                        const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Order ID', style: TextStyle(color: AppTheme.textMuted)),
                            Flexible(
                              child: Text(widget.orderNumber,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text('Amount Due', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ),
                            Flexible(
                              child: Text('₱${widget.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Payment Methods
                  const Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),

                  if (_paymentMethods.isEmpty)
                    const Center(
                      child: Text('No payment methods available', style: TextStyle(color: AppTheme.textMuted)),
                    )
                  else
                    Column(
                      children: _paymentMethods.map((method) {
                        final isSelected = _selectedMethod == method['id'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedMethod = method['id']),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : AppTheme.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? AppTheme.primary : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? AppTheme.primary : AppTheme.border,
                                    ),
                                  ),
                                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(method['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      if (method['description'] != null)
                                        Text(method['description'], style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 32),

                  // Process Button
                  GradientButton(
                    label: 'Continue to Payment',
                    onPressed: _processing ? null : _processPayment,
                    isLoading: _processing,
                  ),
                  const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
