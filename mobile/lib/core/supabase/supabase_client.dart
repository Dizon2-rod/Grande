import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static SupabaseService? _instance;

  SupabaseService._internal();

  factory SupabaseService() {
    _instance ??= SupabaseService._internal();
    return _instance!;
  }

  SupabaseClient get client {
    _client ??= Supabase.instance.client;
    return _client!;
  }

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  }

  // Authentication Methods
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> userMetadata,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: userMetadata,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  User? get currentUser => client.auth.currentUser;

  // Database Methods
  Future<PostgrestList<T>> getAll<T>({
    required String tableName,
    List<String> selectColumns = const ['*'],
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
  }) async {
    var query = client.from(tableName).select(selectColumns.join(', '));

    if (filters != null) {
      filters.forEach((key, value) {
        query = query.eq(key, value);
      });
    }

    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending);
    }

    return await query as PostgrestList<T>;
  }

  Future<PostgrestList<T>> getByField<T>({
    required String tableName,
    required String fieldName,
    required dynamic value,
    List<String> selectColumns = const ['*'],
  }) async {
    return await client
        .from(tableName)
        .select(selectColumns.join(', '))
        .eq(fieldName, value) as PostgrestList<T>;
  }

  Future<PostgrestList<T>> getById<T>({
    required String tableName,
    required int id,
    List<String> selectColumns = const ['*'],
  }) async {
    return await client
        .from(tableName)
        .select(selectColumns.join(', '))
        .eq('id', id) as PostgrestList<T>;
  }

  Future<PostgrestResponse> insert({
    required String tableName,
    required Map<String, dynamic> data,
    List<String> selectColumns = const ['*'],
  }) async {
    return await client
        .from(tableName)
        .insert(data)
        .select(selectColumns.join(', '));
  }

  Future<PostgrestResponse> update({
    required String tableName,
    required int id,
    required Map<String, dynamic> data,
    List<String> selectColumns = const ['*'],
  }) async {
    return await client
        .from(tableName)
        .update(data)
        .eq('id', id)
        .select(selectColumns.join(', '));
  }

  Future<PostgrestResponse> delete({
    required String tableName,
    required int id,
  }) async {
    return await client.from(tableName).delete().eq('id', id);
  }

  // User specific methods
  Future<PostgrestList<Map<String, dynamic>>> getUserByEmail(String email) async {
    return await getByField<Map<String, dynamic>>(
      tableName: 'users',
      fieldName: 'email',
      value: email,
    );
  }

  Future<PostgrestList<Map<String, dynamic>>> getUserById(int userId) async {
    return await getById<Map<String, dynamic>>(
      tableName: 'users',
      id: userId,
    );
  }

  Future<PostgrestResponse> createUser(Map<String, dynamic> userData) async {
    return await insert(
      tableName: 'users',
      data: userData,
    );
  }

  Future<PostgrestResponse> updateUser(int userId, Map<String, dynamic> userData) async {
    return await update(
      tableName: 'users',
      id: userId,
      data: userData,
    );
  }

  // Product specific methods
  Future<PostgrestList<Map<String, dynamic>>> getProducts({
    bool? isActive,
    int? sellerId,
    String? category,
  }) async {
    Map<String, dynamic>? filters = {};
    if (isActive != null) filters['is_active'] = isActive;
    if (sellerId != null) filters['seller_id'] = sellerId;
    if (category != null) filters['category'] = category;

    return await getAll<Map<String, dynamic>>(
      tableName: 'products',
      filters: filters,
      orderBy: 'created_at',
      ascending: false,
    );
  }

  Future<PostgrestList<Map<String, dynamic>>> getProductById(int productId) async {
    return await getById<Map<String, dynamic>>(
      tableName: 'products',
      id: productId,
    );
  }

  Future<PostgrestResponse> createProduct(Map<String, dynamic> productData) async {
    return await insert(
      tableName: 'products',
      data: productData,
    );
  }

  Future<PostgrestResponse> updateProduct(int productId, Map<String, dynamic> productData) async {
    return await update(
      tableName: 'products',
      id: productId,
      data: productData,
    );
  }

  // Cart specific methods
  Future<PostgrestList<Map<String, dynamic>>> getCartItems(int userId) async {
    return await getByField<Map<String, dynamic>>(
      tableName: 'cart',
      fieldName: 'user_id',
      value: userId,
    );
  }

  Future<PostgrestResponse> addToCart(Map<String, dynamic> cartData) async {
    return await insert(
      tableName: 'cart',
      data: cartData,
    );
  }

  Future<PostgrestResponse> updateCartItem(int cartId, int userId, Map<String, dynamic> cartData) async {
    return await client
        .from('cart')
        .update(cartData)
        .eq('id', cartId)
        .eq('user_id', userId)
        .select();
  }

  Future<PostgrestResponse> removeCartItem(int cartId, int userId) async {
    return await client
        .from('cart')
        .delete()
        .eq('id', cartId)
        .eq('user_id', userId)
        .select();
  }

  Future<PostgrestResponse> clearCart(int userId) async {
    return await client
        .from('cart')
        .delete()
        .eq('user_id', userId)
        .select();
  }

  // Order specific methods
  Future<PostgrestResponse> createOrder(Map<String, dynamic> orderData) async {
    return await insert(
      tableName: 'orders',
      data: orderData,
    );
  }

  Future<PostgrestList<Map<String, dynamic>>> getOrdersByBuyer(int buyerId) async {
    return await getByField<Map<String, dynamic>>(
      tableName: 'orders',
      fieldName: 'buyer_id',
      value: buyerId,
    );
  }

  Future<PostgrestList<Map<String, dynamic>>> getOrdersBySeller(int sellerId) async {
    return await getByField<Map<String, dynamic>>(
      tableName: 'orders',
      fieldName: 'seller_id',
      value: sellerId,
    );
  }

  Future<PostgrestResponse> updateOrderStatus(int orderId, String status) async {
    return await update(
      tableName: 'orders',
      id: orderId,
      data: {'status': status},
    );
  }

  Future<PostgrestList<Map<String, dynamic>>> getOrderItems(int orderId) async {
    return await getByField<Map<String, dynamic>>(
      tableName: 'order_items',
      fieldName: 'order_id',
      value: orderId,
    );
  }

  Future<PostgrestResponse> createOrderItems(List<Map<String, dynamic>> orderItemsData) async {
    return await client
        .from('order_items')
        .insert(orderItemsData)
        .select();
  }

  // Notification specific methods
  Future<PostgrestList<Map<String, dynamic>>> getNotifications(int userId) async {
    return await getByField<Map<String, dynamic>>(
      tableName: 'notifications',
      fieldName: 'user_id',
      value: userId,
    );
  }

  Future<PostgrestResponse> createNotification(Map<String, dynamic> notificationData) async {
    return await insert(
      tableName: 'notifications',
      data: notificationData,
    );
  }

  Future<PostgrestResponse> markNotificationRead(int notificationId, int userId) async {
    return await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', userId)
        .select();
  }

  // Chat specific methods
  Future<PostgrestList<Map<String, dynamic>>> getConversations(int userId, String userType) async {
    String fieldName = userType == 'seller' ? 'seller_id' : 'buyer_id';
    return await client
        .from('chat_conversations')
        .select('*')
        .eq(fieldName, userId)
        .order('last_message_time', ascending: false);
  }

  Future<PostgrestList<Map<String, dynamic>>> getMessages(int conversationId) async {
    return await getByField<Map<String, dynamic>>(
      tableName: 'chat_messages',
      fieldName: 'conversation_id',
      value: conversationId,
    );
  }

  Future<PostgrestResponse> sendMessage(Map<String, dynamic> messageData) async {
    return await insert(
      tableName: 'chat_messages',
      data: messageData,
    );
  }

  // Application specific methods
  Future<PostgrestResponse> createApplication(Map<String, dynamic> applicationData) async {
    return await insert(
      tableName: 'applications',
      data: applicationData,
    );
  }

  Future<PostgrestList<Map<String, dynamic>>> getApplications({
    int? userId,
    String? applicationType,
    String? status,
  }) async {
    Map<String, dynamic>? filters = {};
    if (userId != null) filters['user_id'] = userId;
    if (applicationType != null) filters['application_type'] = applicationType;
    if (status != null) filters['status'] = status;

    return await getAll<Map<String, dynamic>>(
      tableName: 'applications',
      filters: filters,
    );
  }

  // Stock specific methods
  Future<PostgrestList<Map<String, dynamic>>> getProductStock(
    int productId, {
    String? size,
    String? color,
  }) async {
    var query = client.from('product_size_stock').select('*').eq('product_id', productId);
    
    if (size != null) query = query.eq('size', size);
    if (color != null) query = query.eq('color', color);

    return await query as PostgrestList<Map<String, dynamic>>;
  }

  Future<PostgrestResponse> updateProductStock(int stockId, Map<String, dynamic> stockData) async {
    return await update(
      tableName: 'product_size_stock',
      id: stockId,
      data: stockData,
    );
  }
}
