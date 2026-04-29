import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class SupabaseAuthService {
  final SupabaseService _supabaseService = SupabaseService();

  // Register new user
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String role = 'buyer',
  }) async {
    try {
      // First create auth user
      final authResponse = await _supabaseService.signUp(
        email: email,
        password: password,
        userMetadata: {
          'name': name,
          'role': role,
        },
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create auth user');
      }

      // Then create user record in users table
      final userData = {
        'name': name,
        'email': email.toLowerCase().trim(),
        'password': password, // Note: In production, use proper hashing
        'role': role,
        'status': 'pending',
        'email_verified': false,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final userResponse = await _supabaseService.createUser(userData);

      if (userResponse.data == null || userResponse.data!.isEmpty) {
        throw Exception('Failed to create user record');
      }

      return {
        'success': true,
        'user': userResponse.data![0],
        'session': authResponse.session,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      // First authenticate with Supabase Auth
      final authResponse = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Invalid credentials');
      }

      // Get user record from users table
      final userRecords = await _supabaseService.getUserByEmail(email);
      
      if (userRecords.isEmpty) {
        throw Exception('User record not found');
      }

      final user = userRecords.first;

      // Update last login
      await _supabaseService.updateUser(user['id'], {
        'last_login': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'user': user,
        'session': authResponse.session,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Logout user
  Future<void> logout() async {
    await _supabaseService.signOut();
  }

  // Get current user
  User? get currentUser => _supabaseService.currentUser;

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;
}

class SupabaseProductService {
  final SupabaseService _supabaseService = SupabaseService();

  // Get all products
  Future<List<Map<String, dynamic>>> getProducts({
    bool? isActive,
    int? sellerId,
    String? category,
  }) async {
    try {
      final response = await _supabaseService.getProducts(
        isActive: isActive,
        sellerId: sellerId,
        category: category,
      );

      // Get seller information for each product
      List<Map<String, dynamic>> productsWithSellers = [];
      for (var product in response) {
        final sellerRecords = await _supabaseService.getUserById(product['seller_id']);
        if (sellerRecords.isNotEmpty) {
          product['seller_name'] = sellerRecords.first['name'];
        }
        productsWithSellers.add(product);
      }

      return productsWithSellers;
    } catch (e) {
      throw Exception('Failed to get products: $e');
    }
  }

  // Get product by ID
  Future<Map<String, dynamic>?> getProductById(int productId) async {
    try {
      final response = await _supabaseService.getProductById(productId);
      
      if (response.isEmpty) return null;

      final product = response.first;

      // Get seller information
      final sellerRecords = await _supabaseService.getUserById(product['seller_id']);
      if (sellerRecords.isNotEmpty) {
        product['seller_name'] = sellerRecords.first['name'];
      }

      return product;
    } catch (e) {
      throw Exception('Failed to get product: $e');
    }
  }

  // Create new product
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> productData) async {
    try {
      final response = await _supabaseService.createProduct(productData);

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('Failed to create product');
      }

      return {
        'success': true,
        'product': response.data![0],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Update product
  Future<Map<String, dynamic>> updateProduct(int productId, Map<String, dynamic> productData) async {
    try {
      final response = await _supabaseService.updateProduct(productId, productData);

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('Failed to update product');
      }

      return {
        'success': true,
        'product': response.data![0],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

class SupabaseCartService {
  final SupabaseService _supabaseService = SupabaseService();

  // Get cart items for user
  Future<List<Map<String, dynamic>>> getCartItems(int userId) async {
    try {
      final response = await _supabaseService.getCartItems(userId);

      // Get product information for each cart item
      List<Map<String, dynamic>> cartItemsWithProducts = [];
      for (var item in response) {
        final productRecords = await _supabaseService.getProductById(item['product_id']);
        if (productRecords.isNotEmpty) {
          item['product_name'] = productRecords.first['name'];
          item['product_image'] = productRecords.first['image_url'];
        }
        cartItemsWithProducts.add(item);
      }

      return cartItemsWithProducts;
    } catch (e) {
      throw Exception('Failed to get cart items: $e');
    }
  }

  // Add item to cart
  Future<Map<String, dynamic>> addToCart(Map<String, dynamic> cartData) async {
    try {
      final response = await _supabaseService.addToCart(cartData);

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('Failed to add to cart');
      }

      return {
        'success': true,
        'cart_item': response.data![0],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Update cart item
  Future<Map<String, dynamic>> updateCartItem(int cartId, int userId, Map<String, dynamic> cartData) async {
    try {
      final response = await _supabaseService.updateCartItem(cartId, userId, cartData);

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('Failed to update cart item');
      }

      return {
        'success': true,
        'cart_item': response.data![0],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Remove cart item
  Future<Map<String, dynamic>> removeCartItem(int cartId, int userId) async {
    try {
      final response = await _supabaseService.removeCartItem(cartId, userId);

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('Failed to remove cart item');
      }

      return {
        'success': true,
        'message': 'Item removed from cart',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Clear cart
  Future<Map<String, dynamic>> clearCart(int userId) async {
    try {
      final response = await _supabaseService.clearCart(userId);

      return {
        'success': true,
        'message': 'Cart cleared',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

class SupabaseOrderService {
  final SupabaseService _supabaseService = SupabaseService();

  // Create order
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData, List<Map<String, dynamic>> orderItems) async {
    try {
      // Create order
      final orderResponse = await _supabaseService.createOrder(orderData);

      if (orderResponse.data == null || orderResponse.data!.isEmpty) {
        throw Exception('Failed to create order');
      }

      final order = orderResponse.data![0];

      // Create order items
      final itemsWithOrderId = orderItems.map((item) {
        item['order_id'] = order['id'];
        item['subtotal'] = (item['quantity'] as int) * (item['price'] as double);
        return item;
      }).toList();

      final itemsResponse = await _supabaseService.createOrderItems(itemsWithOrderId);

      return {
        'success': true,
        'order': order,
        'order_items': itemsResponse.data ?? [],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get orders for buyer
  Future<List<Map<String, dynamic>>> getBuyerOrders(int buyerId) async {
    try {
      final response = await _supabaseService.getOrdersByBuyer(buyerId);

      // Get order items for each order
      List<Map<String, dynamic>> ordersWithItems = [];
      for (var order in response) {
        final items = await _supabaseService.getOrderItems(order['id']);
        order['items'] = items;
        ordersWithItems.add(order);
      }

      return ordersWithItems;
    } catch (e) {
      throw Exception('Failed to get buyer orders: $e');
    }
  }

  // Get orders for seller
  Future<List<Map<String, dynamic>>> getSellerOrders(int sellerId) async {
    try {
      final response = await _supabaseService.getOrdersBySeller(sellerId);

      // Get order items for each order
      List<Map<String, dynamic>> ordersWithItems = [];
      for (var order in response) {
        final items = await _supabaseService.getOrderItems(order['id']);
        order['items'] = items;
        ordersWithItems.add(order);
      }

      return ordersWithItems;
    } catch (e) {
      throw Exception('Failed to get seller orders: $e');
    }
  }

  // Update order status
  Future<Map<String, dynamic>> updateOrderStatus(int orderId, String status) async {
    try {
      final response = await _supabaseService.updateOrderStatus(orderId, status);

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('Failed to update order status');
      }

      return {
        'success': true,
        'order': response.data![0],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

class SupabaseNotificationService {
  final SupabaseService _supabaseService = SupabaseService();

  // Get notifications for user
  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    try {
      final response = await _supabaseService.getNotifications(userId);
      return response;
    } catch (e) {
      throw Exception('Failed to get notifications: $e');
    }
  }

  // Create notification
  Future<Map<String, dynamic>> createNotification(Map<String, dynamic> notificationData) async {
    try {
      final response = await _supabaseService.createNotification(notificationData);

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('Failed to create notification');
      }

      return {
        'success': true,
        'notification': response.data![0],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Mark notification as read
  Future<Map<String, dynamic>> markNotificationRead(int notificationId, int userId) async {
    try {
      final response = await _supabaseService.markNotificationRead(notificationId, userId);

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('Failed to mark notification as read');
      }

      return {
        'success': true,
        'message': 'Notification marked as read',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
