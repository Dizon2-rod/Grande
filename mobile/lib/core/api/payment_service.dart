import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class PaymentService {
  static const _storage = FlutterSecureStorage();
  static final _dio = Dio(BaseOptions(validateStatus: (_) => true));

  // ─── PayMongo Integration ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> initializePayMongoPayment({
    required double amount,
    required String description,
    required String orderId,
    required String returnUrl,
    required String paymentMethod,
  }) async {
    try {
      final payload = {
        'amount': (amount * 100).toInt(), // Convert to centavos
        'currency': 'PHP',
        'description': description,
        'statement_descriptor': 'GRANDE ECOMMERCE',
        'metadata': {
          'order_id': orderId,
          'payment_method': paymentMethod,
        },
        'billing': {
          'address': {
            'country': 'PH',
          },
        },
        'redirect': {
          'success': '$returnUrl?status=success',
          'failed': '$returnUrl?status=failed',
        },
      };

      if (paymentMethod == 'gcash' || paymentMethod == 'GCASH') {
        payload['payment_method_allowed'] = ['gcash'];
      } else if (paymentMethod == 'paymaya' || paymentMethod == 'PAYMAYA') {
        payload['payment_method_allowed'] = ['paymaya'];
      }

      // Call your backend to initiate PayMongo payment
      final res = await ApiService.post('/api/payments/paymongo/initialize', payload);

      if (res['success'] == true) {
        return {
          'success': true,
          'payment_url': res['payment_url'],
          'intentId': res['intent_id'] ?? res['id'],
          'checkoutUrl': res['checkout_url'],
        };
      } else {
        return {'success': false, 'error': res['error'] ?? 'Failed to initialize payment'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Payment initialization failed: $e'};
    }
  }

  // ─── Xendit Integration ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> initializeXenditPayment({
    required double amount,
    required String description,
    required String orderId,
    required String returnUrl,
    required String paymentMethod,
    required String email,
    required String phone,
    required String name,
  }) async {
    try {
      final payload = {
        'amount': amount,
        'currency': 'PHP',
        'description': description,
        'order_id': orderId,
        'customer_email': email,
        'customer_phone': phone,
        'customer_name': name,
        'return_url': '$returnUrl?status=success',
        'failure_redirect_url': '$returnUrl?status=failed',
        'payment_method': paymentMethod.toLowerCase() == 'cod' ? 'BANK_TRANSFER' : paymentMethod.toUpperCase(),
      };

      // Call your backend to initiate Xendit payment
      final res = await ApiService.post('/api/payments/xendit/initialize', payload);

      if (res['success'] == true) {
        return {
          'success': true,
          'payment_url': res['payment_url'] ?? res['invoice_url'],
          'invoiceId': res['invoice_id'] ?? res['id'],
          'externalId': res['external_id'],
        };
      } else {
        return {'success': false, 'error': res['error'] ?? 'Failed to initialize payment'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Payment initialization failed: $e'};
    }
  }

  // ─── Verify Payment Status ────────────────────────────────────────────
  static Future<Map<String, dynamic>> verifyPaymentStatus({
    required String paymentId,
    required String paymentGateway,
  }) async {
    try {
      final endpoint = paymentGateway == 'paymongo'
          ? '/api/payments/paymongo/verify/$paymentId'
          : '/api/payments/xendit/verify/$paymentId';

      final res = await ApiService.get(endpoint);

      if (res['success'] == true) {
        return {
          'success': true,
          'status': res['status'],
          'amount': res['amount'],
          'orderId': res['order_id'],
        };
      } else {
        return {'success': false, 'error': res['error'] ?? 'Failed to verify payment'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Verification failed: $e'};
    }
  }

  // ─── List Payment Methods ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getAvailablePaymentMethods() async {
    try {
      final res = await ApiService.get('/api/payments/methods');
      final methods = (res['methods'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      return methods
          .map((m) => {
                'id': m['id'],
                'name': m['name'],
                'description': m['description'],
                'icon': m['icon'],
                'gateway': m['gateway'],
                'status': m['status'], // 'active', 'inactive'
              })
          .toList();
    } catch (e) {
      print('Error fetching payment methods: $e');
      return [];
    }
  }

  // ─── Save Payment Method ───────────────────────────────────────────────
  static Future<bool> savePaymentMethod({
    required String methodId,
    required String methodName,
  }) async {
    try {
      await _storage.write(
        key: 'preferred_payment_method',
        value: methodId,
      );
      return true;
    } catch (e) {
      print('Error saving payment method: $e');
      return false;
    }
  }

  // ─── Get Saved Payment Method ──────────────────────────────────────────
  static Future<String?> getSavedPaymentMethod() async {
    try {
      return await _storage.read(key: 'preferred_payment_method');
    } catch (e) {
      return null;
    }
  }

  // ─── Process COD Payment ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> processCODPayment({
    required String orderId,
    required double amount,
  }) async {
    try {
      // For COD, just confirm the order without actual payment
      final res = await ApiService.post('/api/orders/$orderId/confirm-payment', {
        'payment_method': 'COD',
        'status': 'pending',
        'amount': amount,
      });

      if (res['success'] == true) {
        return {
          'success': true,
          'orderId': orderId,
          'status': 'pending',
          'message': 'Order confirmed. Pay on delivery.',
        };
      } else {
        return {'success': false, 'error': res['error'] ?? 'Failed to process COD'};
      }
    } catch (e) {
      return {'success': false, 'error': 'COD processing failed: $e'};
    }
  }

  // ─── Get Payment History ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final res = await ApiService.get('/api/payments/history');
      return (res['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      print('Error fetching payment history: $e');
      return [];
    }
  }

  // ─── Cancel Payment ───────────────────────────────────────────────────
  static Future<bool> cancelPayment({
    required String paymentId,
    required String gateway,
  }) async {
    try {
      final res = await ApiService.post('/api/payments/$paymentId/cancel', {
        'gateway': gateway,
      });
      return res['success'] == true;
    } catch (e) {
      print('Error cancelling payment: $e');
      return false;
    }
  }
}
