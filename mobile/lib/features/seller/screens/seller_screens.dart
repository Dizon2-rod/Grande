import 'package:flutter/material.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'order_details_screen.dart';

// ─── Seller Dashboard ──────────────────────────────────────────────────────
class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});
  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _stats = {};
  List _recentOrders = [];
  List _recentProducts = [];
  List _bestProducts = [];
  List _topCustomers = [];
  List _lowStock = [];
  Map<String, dynamic> _salesData = {};
  String _selectedRange = '30d';
  late TabController _tabController;
  bool _loading = true;

  @override
  void initState() { 
    super.initState(); 
    _tabController = TabController(length: 5, vsync: this);
    _load(); 
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/api/seller/dashboard-stats'),
        ApiService.get('/api/seller/recent-orders?limit=8'),
        ApiService.get('/api/seller/products?sort_by=created_at&page=1&per_page=5'),
        ApiService.get('/api/seller/best-products?limit=5'),
        ApiService.get('/api/seller/top-customers?limit=8'),
        ApiService.get('/api/seller/low-stock?threshold=10&limit=8'),
        ApiService.get('/api/seller/analytics/timeseries?from=${_getDateFrom()}&to=${_getDateTo()}&granularity=day'),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0];
          _recentOrders = (results[1]['orders'] as List? ?? []);
          _recentProducts = (results[2]['products'] as List? ?? []);
          _bestProducts = (results[3]['products'] as List? ?? []);
          _topCustomers = (results[4]['customers'] as List? ?? []);
          _lowStock = (results[5]['products'] as List? ?? []);
          _salesData = results[6];
          _loading = false;
        });
      }
    } catch (e) { 
      print('Error loading dashboard: $e');
      if (mounted) setState(() => _loading = false); 
    }
  }

  String _getDateFrom() {
    final now = DateTime.now();
    int daysBack = _selectedRange == '7d' ? 6 : (_selectedRange == '90d' ? 89 : 29);
    return now.subtract(Duration(days: daysBack)).toIso8601String().split('T')[0];
  }

  String _getDateTo() {
    return DateTime.now().toIso8601String().split('T')[0];
  }

  void _changeRange(String range) {
    setState(() => _selectedRange = range);
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    try {
      final data = await ApiService.get('/api/seller/analytics/timeseries?from=${_getDateFrom()}&to=${_getDateTo()}&granularity=day');
      if (mounted) setState(() => _salesData = data);
    } catch (e) {
      print('Error loading sales data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.45,
                      children: [
                        StatCard(label: 'Total Revenue', value: '₱${((_stats['total_revenue'] ?? 0) as num).toStringAsFixed(2)}', icon: Icons.attach_money, color: AppTheme.primary),
                        StatCard(label: 'Total Orders', value: '${_stats['total_orders'] ?? 0}', icon: Icons.receipt, color: AppTheme.success),
                        StatCard(label: 'Products', value: '${_stats['total_products'] ?? 0}', icon: Icons.inventory_2, color: const Color(0xFF8B5CF6)),
                        StatCard(label: 'Pending', value: '${_stats['pending_orders'] ?? 0}', icon: Icons.pending_actions, color: AppTheme.warning),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Sales Trend Chart
                    _buildSalesTrendCard(),
                    const SizedBox(height: 20),

                    // Recent Products
                    SectionHeader(
                      title: 'Recent Products',
                      action: TextButton(onPressed: () => Navigator.pushNamed(context, '/seller/inventory'), child: const Text('Manage All', style: TextStyle(color: AppTheme.primary))),
                    ),
                    const SizedBox(height: 10),
                    if (_recentProducts.isEmpty)
                      const EmptyState(icon: Icons.inventory_2_outlined, title: 'No products yet')
                    else
                      ..._recentProducts.map((p) => _buildProductCard(p)),

                    const SizedBox(height: 20),

                    // Best Selling Products
                    SectionHeader(
                      title: 'Best Selling Products',
                      action: TextButton(onPressed: () => Navigator.pushNamed(context, '/seller/analytics'), child: const Text('View Analytics', style: TextStyle(color: AppTheme.primary))),
                    ),
                    const SizedBox(height: 10),
                    if (_bestProducts.isEmpty)
                      const EmptyState(icon: Icons.trending_up, title: 'No sales data yet')
                    else
                      ..._bestProducts.map((p) => _buildBestProductCard(p)),

                    const SizedBox(height: 20),

                    // Recent Orders
                    SectionHeader(
                      title: 'Recent Orders',
                      action: TextButton(onPressed: () => Navigator.pushNamed(context, '/seller/orders'), child: const Text('View All', style: TextStyle(color: AppTheme.primary))),
                    ),
                    const SizedBox(height: 10),
                    if (_recentOrders.isEmpty)
                      const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders yet')
                    else
                      ..._recentOrders.map((o) => OrderCard(order: o, onTap: () => Navigator.pushNamed(context, '/seller/orders'))),

                    const SizedBox(height: 20),

                    // Delivery Management
                    SectionHeader(
                      title: 'Delivery Management',
                      action: TextButton(onPressed: () {}, child: const Text('View All', style: TextStyle(color: AppTheme.primary))),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/seller/delivery-tracking'),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.info.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.local_shipping, color: AppTheme.info),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Delivery Tracking', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('Track all deliveries', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/seller/awaiting-pickup'),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warning.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.inventory_2, color: AppTheme.warning),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Awaiting Pickup', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('Ready for pickup', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Top Customers
                    if (_topCustomers.isNotEmpty) ...[
                      SectionHeader(
                        title: 'Top Customers',
                        action: TextButton(onPressed: () {}, child: const Text('View All', style: TextStyle(color: AppTheme.primary))),
                      ),
                      const SizedBox(height: 10),
                      ..._topCustomers.map((c) => _buildCustomerCard(c)),
                      const SizedBox(height: 20),
                    ],

                    // Low Stock Alert
                    if (_lowStock.isNotEmpty) ...[
                      SectionHeader(
                        title: '⚠️ Low Stock Alert',
                        action: TextButton(onPressed: () => Navigator.pushNamed(context, '/seller/inventory'), child: const Text('Manage', style: TextStyle(color: AppTheme.primary))),
                      ),
                      const SizedBox(height: 10),
                      ..._lowStock.map((p) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber, color: AppTheme.warning, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            Text('${p['total_stock'] ?? 0} left', style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 12)),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSalesTrendCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sales Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Row(
                children: [
                  _buildRangeButton('7D', '7d'),
                  const SizedBox(width: 4),
                  _buildRangeButton('30D', '30d'),
                  const SizedBox(width: 4),
                  _buildRangeButton('90D', '90d'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_salesData['labels'] != null && (_salesData['labels'] as List).isNotEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'Total: ₱${((_salesData['sales'] as List?)?.fold<double>(0, (sum, val) => sum + (val as num).toDouble()) ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.primary),
                ),
              ),
            )
          else
            const SizedBox(height: 200, child: Center(child: Text('No sales data', style: TextStyle(color: AppTheme.textMuted)))),
        ],
      ),
    );
  }

  Widget _buildRangeButton(String label, String value) {
    final isSelected = _selectedRange == value;
    return GestureDetector(
      onTap: () => _changeRange(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppTheme.textMuted)),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(product['category'] ?? 'Uncategorized', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                Text('Stock: ${product['total_stock'] ?? 0}', style: TextStyle(fontSize: 11, color: (product['total_stock'] ?? 0) > 0 ? AppTheme.success : AppTheme.error, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.info), onPressed: () => Navigator.pushNamed(context, '/seller/edit-product', arguments: product).then((_) => _load())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBestProductCard(Map<String, dynamic> product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image, color: AppTheme.textMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${product['total_sold'] ?? 0} sold', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Text('₱${((product['total_revenue'] ?? 0) as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.success, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final initials = (customer['customer_name'] ?? '??').split(' ').map((n) => n[0]).take(2).join().toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8b5cf6), Color(0xFFa855f7)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer['customer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${customer['total_orders'] ?? 0} orders', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Text('₱${((customer['total_spent'] ?? 0) as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.success, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Seller Orders ─────────────────────────────────────────────────────────
class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});
  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _orders = [];
  bool _loading = true;
  final List<String> _statuses = ['All', 'pending', 'confirmed', 'prepared', 'shipped', 'delivered', 'cancelled'];

  @override
  void initState() { super.initState(); _tabs = TabController(length: _statuses.length, vsync: this); _load(); }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/orders');
    if (mounted) setState(() { _orders = res['orders'] ?? []; _loading = false; });
  }

  List _filtered(String s) => s == 'All' ? _orders : _orders.where((o) => o['status'] == s).toList();

  Future<void> _updateStatus(int orderId, String status) async {
    final res = await ApiService.put('/api/orders/$orderId/status', {'status': status});
    if (res['success'] == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order status updated!'), backgroundColor: AppTheme.success));
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Failed'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Orders'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : TabBarView(
              controller: _tabs,
              children: _statuses.map((s) {
                final list = _filtered(s);
                if (list.isEmpty) return EmptyState(icon: Icons.receipt_long_outlined, title: 'No ${s == 'All' ? '' : s} orders');
                return RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final order = list[i];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailsScreen(orderNumber: order['order_number']),
                          ),
                        ).then((_) => _load()),
                        child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(order['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                const Spacer(),
                                StatusBadge(order['status'] ?? 'pending'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Customer: ${order['buyer']?['name'] ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            Text('Total: ₱${(order['total_amount'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 13)),
                            const SizedBox(height: 10),
                            // Action buttons
                            if (order['status'] == 'pending')
                              Row(children: [
                                Expanded(child: OutlinedButton(onPressed: () => _updateStatus(order['id'], 'confirmed'), child: const Text('Confirm', style: TextStyle(fontSize: 12)))),
                                const SizedBox(width: 8),
                                Expanded(child: OutlinedButton(onPressed: () => _updateStatus(order['id'], 'cancelled'), style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, side: const BorderSide(color: AppTheme.error)), child: const Text('Cancel', style: TextStyle(fontSize: 12)))),
                              ])
                            else if (order['status'] == 'confirmed')
                              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _updateStatus(order['id'], 'prepared'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary), child: const Text('Mark as Prepared', style: TextStyle(fontSize: 12, color: Colors.white))))
                            else if (order['status'] == 'prepared')
                              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _updateStatus(order['id'], 'shipped'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)), child: const Text('Mark as Shipped', style: TextStyle(fontSize: 12, color: Colors.white)))),
                          ],
                        ),
                      ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
    );
  }
}

// ─── Seller Inventory ──────────────────────────────────────────────────────
class SellerInventoryScreen extends StatefulWidget {
  const SellerInventoryScreen({super.key});
  @override
  State<SellerInventoryScreen> createState() => _SellerInventoryScreenState();
}

class _SellerInventoryScreenState extends State<SellerInventoryScreen> {
  List _products = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/seller/products?per_page=50');
    if (mounted) setState(() { _products = res['products'] ?? []; _loading = false; });
  }

  Future<void> _toggleActive(int id, bool current) async {
    await ApiService.put('/api/seller/products/$id', {'is_active': !current ? 1 : 0});
    _load();
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirm == true) { await ApiService.delete('/api/seller/products/$id'); _load(); }
  }

  List get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((p) => (p['name'] ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => Navigator.pushNamed(context, '/seller/add-product').then((_) => _load()))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                filled: true, fillColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _filtered.isEmpty
                    ? EmptyState(icon: Icons.inventory_2_outlined, title: 'No products', action: ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/seller/add-product').then((_) => _load()), child: const Text('Add Product')))
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final p = _filtered[i];
                            final active = (p['is_active'] as int? ?? 1) == 1;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(width: 56, height: 56, color: AppTheme.background, child: const Icon(Icons.image, color: AppTheme.textMuted)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text(p['category'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                        Row(
                                          children: [
                                            Text('Stock: ${p['total_stock'] ?? 0}', style: TextStyle(fontSize: 11, color: (p['total_stock'] ?? 0) < 5 ? AppTheme.error : AppTheme.success, fontWeight: FontWeight.w600)),
                                            const SizedBox(width: 8),
                                            StatusBadge(p['approval_status'] ?? 'pending'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      Switch(value: active, onChanged: (_) => _toggleActive(p['id'], active), activeThumbColor: AppTheme.primary),
                                      Row(
                                        children: [
                                          IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.info), onPressed: () => Navigator.pushNamed(context, '/seller/edit-product', arguments: p).then((_) => _load())),
                                          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error), onPressed: () => _delete(p['id'])),
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
          ),
        ],
      ),
    );
  }
}

// ─── Seller Delivery Tracking ─────────────────────────────────────────────────
class SellerDeliveryTrackingScreen extends StatefulWidget {
  const SellerDeliveryTrackingScreen({super.key});
  @override
  State<SellerDeliveryTrackingScreen> createState() => _SellerDeliveryTrackingScreenState();
}

class _SellerDeliveryTrackingScreenState extends State<SellerDeliveryTrackingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _deliveries = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  final List<String> _statuses = ['All', 'pending', 'assigned', 'picked_up', 'in_transit'];

  @override
  void initState() { super.initState(); _tabs = TabController(length: _statuses.length, vsync: this); _load(); }

  @override
  void dispose() { _tabs.dispose(); _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/seller/deliveries');
      if (mounted) setState(() { _deliveries = res['deliveries'] ?? []; _loading = false; });
    } catch (e) {
      print('Error loading deliveries: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List _filtered(String status) {
    if (status == 'All') return _deliveries;
    return _deliveries.where((d) => d['delivery_status'] == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Delivery Tracking'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: AppTheme.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: _statuses.map((s) => Tab(text: s == 'All' ? 'All' : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' '))).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search orders, customers, riders...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                filled: true, fillColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : TabBarView(
                    controller: _tabs,
                    children: _statuses.map((s) {
                      final list = _filtered(s);
                      if (list.isEmpty) return EmptyState(icon: Icons.local_shipping_outlined, title: 'No ${s == 'All' ? '' : s} deliveries');
                      return RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final delivery = list[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(delivery['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      const Spacer(),
                                      _buildStatusBadge(delivery['delivery_status'] ?? 'pending'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Customer: ${delivery['customer_name'] ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                  if (delivery['rider_name'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text('Rider: ${delivery['rider_name']}', style: const TextStyle(fontSize: 12, color: AppTheme.info)),
                                  ],
                                  const SizedBox(height: 8),
                                  Text('Address: ${delivery['delivery_address'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'assigned':
        color = AppTheme.info;
        label = 'Assigned';
        break;
      case 'picked_up':
        color = AppTheme.primary;
        label = 'Picked Up';
        break;
      case 'in_transit':
        color = AppTheme.success;
        label = 'In Transit';
        break;
      case 'delivered':
        color = const Color(0xFF10B981);
        label = 'Delivered';
        break;
      default:
        color = AppTheme.warning;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── Seller Awaiting Pickup ───────────────────────────────────────────────
class SellerAwaitingPickupScreen extends StatefulWidget {
  const SellerAwaitingPickupScreen({super.key});
  @override
  State<SellerAwaitingPickupScreen> createState() => _SellerAwaitingPickupScreenState();
}

class _SellerAwaitingPickupScreenState extends State<SellerAwaitingPickupScreen> {
  List _orders = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/seller/deliveries?status=pending');
      if (mounted) setState(() { _orders = res['deliveries'] ?? []; _loading = false; });
    } catch (e) {
      print('Error loading awaiting pickup: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _orders;
    return _orders.where((o) => 
      (o['order_number'] ?? '').toLowerCase().contains(q) ||
      (o['customer_name'] ?? '').toLowerCase().contains(q)
    ).toList();
  }

  int get _urgentCount => _orders.where((o) {
    final createdAt = DateTime.tryParse(o['created_at'] ?? '') ?? DateTime.now();
    final hours = DateTime.now().difference(createdAt).inHours;
    return hours > 48;
  }).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Awaiting Pickup'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          // Stats cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                StatCard(label: 'Ready for Pickup', value: '${_orders.length}', icon: Icons.inventory_2, color: AppTheme.primary),
                StatCard(label: 'Urgent (>48h)', value: '$_urgentCount', icon: Icons.warning, color: AppTheme.error),
              ],
            ),
          ),
          if (_urgentCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.error)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$_urgentCount orders have been waiting more than 48 hours', style: const TextStyle(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search orders...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                filled: true, fillColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _filtered.isEmpty
                    ? EmptyState(icon: Icons.local_shipping_outlined, title: 'No orders awaiting pickup')
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final order = _filtered[i];
                            final createdAt = DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now();
                            final hours = DateTime.now().difference(createdAt).inHours;
                            final isUrgent = hours > 48;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isUrgent ? AppTheme.error : AppTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(order['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      const Spacer(),
                                      if (isUrgent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.error)),
                                          child: const Text('URGENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.error)),
                                        )
                                      else
                                        Text('${hours}h', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Customer: ${order['customer_name'] ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                  const SizedBox(height: 4),
                                  Text('Address: ${order['delivery_address'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text('₱${(order['total_amount'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Add Product ───────────────────────────────────────────────────────────
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  bool _loading = false;
  bool _flashSale = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _descCtrl, _priceCtrl, _stockCtrl, _categoryCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final res = await ApiService.post('/api/seller/products', {
      'name': _nameCtrl.text,
      'description': _descCtrl.text,
      'price': double.tryParse(_priceCtrl.text) ?? 0,
      'total_stock': int.tryParse(_stockCtrl.text) ?? 0,
      'category': _categoryCtrl.text,
      'is_flash_sale': _flashSale ? 1 : 0,
    });
    setState(() => _loading = false);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added! Pending admin approval.'), backgroundColor: AppTheme.success));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Failed'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Add Product'), backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
      body: LoadingOverlay(
        loading: _loading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(label: 'Product Name', controller: _nameCtrl, prefixIcon: Icons.inventory_2_outlined, validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 14),
                AppTextField(label: 'Description', controller: _descCtrl, maxLines: 3, prefixIcon: Icons.description_outlined),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: AppTextField(label: 'Price (₱)', controller: _priceCtrl, keyboardType: TextInputType.number, prefixIcon: Icons.attach_money, validator: (v) => v!.isEmpty ? 'Required' : null)),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(label: 'Stock', controller: _stockCtrl, keyboardType: TextInputType.number, prefixIcon: Icons.numbers, validator: (v) => v!.isEmpty ? 'Required' : null)),
                ]),
                const SizedBox(height: 14),
                AppTextField(label: 'Category', controller: _categoryCtrl, prefixIcon: Icons.category_outlined),
                const SizedBox(height: 14),
                SwitchListTile(
                  value: _flashSale,
                  onChanged: (v) => setState(() => _flashSale = v),
                  title: const Text('Request Flash Sale', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Admin will review your request', style: TextStyle(fontSize: 12)),
                  activeThumbColor: AppTheme.primary,
                  tileColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(height: 24),
                GradientButton(label: 'Add Product', icon: Icons.add_circle_outline, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Seller Main Screen ────────────────────────────────────────────────────
class SellerMainScreen extends StatefulWidget {
  const SellerMainScreen({super.key});
  @override
  State<SellerMainScreen> createState() => _SellerMainScreenState();
}

class _SellerMainScreenState extends State<SellerMainScreen> {
  int _index = 0;

  final List<Widget> _screens = const [
    SellerDashboardScreen(),
    SellerInventoryScreen(),
    SellerOrdersScreen(),
    SellerAnalyticsScreen(),
    SellerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textMuted,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.surface,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ─── Seller Analytics ──────────────────────────────────────────────────────
class SellerAnalyticsScreen extends StatefulWidget {
  const SellerAnalyticsScreen({super.key});
  @override
  State<SellerAnalyticsScreen> createState() => _SellerAnalyticsScreenState();
}

class _SellerAnalyticsScreenState extends State<SellerAnalyticsScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _data = {};
  Map<String, dynamic> _timeseriesData = {};
  List _topProducts = [];
  List _recentOrders = [];
  String _selectedRange = '30d';
  late TabController _tabController;
  bool _loading = true;

  @override
  void initState() { 
    super.initState(); 
    _tabController = TabController(length: 3, vsync: this);
    _load(); 
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/api/seller/analytics'),
        ApiService.get('/api/seller/analytics/timeseries?from=${_getDateFrom()}&to=${_getDateTo()}&granularity=day'),
        ApiService.get('/api/seller/analytics/top-products?from=${_getDateFrom()}&to=${_getDateTo()}&limit=10'),
        ApiService.get('/api/seller/analytics/recent-orders?limit=10'),
      ]);
      if (mounted) {
        setState(() {
          _data = results[0];
          _timeseriesData = results[1];
          _topProducts = (results[2]['products'] as List? ?? []);
          _recentOrders = (results[3]['orders'] as List? ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading analytics: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getDateFrom() {
    final now = DateTime.now();
    int daysBack = _selectedRange == '7d' ? 6 : (_selectedRange == '90d' ? 89 : 29);
    return now.subtract(Duration(days: daysBack)).toIso8601String().split('T')[0];
  }

  String _getDateTo() {
    return DateTime.now().toIso8601String().split('T')[0];
  }

  void _changeRange(String range) {
    setState(() => _selectedRange = range);
    _loadTimeseries();
  }

  Future<void> _loadTimeseries() async {
    try {
      final data = await ApiService.get('/api/seller/analytics/timeseries?from=${_getDateFrom()}&to=${_getDateTo()}&granularity=day');
      if (mounted) setState(() => _timeseriesData = data);
    } catch (e) {
      print('Error loading timeseries: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Products'),
            Tab(text: 'Orders'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildProductsTab(),
                _buildOrdersTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time period stats
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                StatCard(label: 'Sales (Week)', value: '₱${((_data['salesWeek'] ?? 0) as num).toStringAsFixed(2)}', icon: Icons.calendar_today, color: AppTheme.primary),
                StatCard(label: 'Sales (Month)', value: '₱${((_data['sales'] ?? 0) as num).toStringAsFixed(2)}', icon: Icons.calendar_month, color: AppTheme.success),
                StatCard(label: 'Sales (Year)', value: '₱${((_data['salesYear'] ?? 0) as num).toStringAsFixed(2)}', icon: Icons.calendar_view_month, color: const Color(0xFF8B5CF6)),
                StatCard(label: 'Total Orders', value: '${_data['orders'] ?? 0}', icon: Icons.shopping_bag, color: AppTheme.info),
              ],
            ),
            const SizedBox(height: 20),

            // Sales Trend
            _buildSalesTrendCard(),
            const SizedBox(height: 20),

            // Commission breakdown
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
                  const Text('Earnings Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  _buildEarningRow('Total Sales', (_data['sales'] ?? 0) as num, AppTheme.primary),
                  _buildEarningRow('Commission (5%)', (_data['salesDelta'] ?? 0) as num, AppTheme.warning),
                  _buildEarningRow('Your Earnings', ((_data['sales'] ?? 0) as num) * 0.95, AppTheme.success),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: _topProducts.isEmpty
          ? const Center(child: EmptyState(icon: Icons.inventory_2_outlined, title: 'No product data'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _topProducts.length,
              itemBuilder: (context, index) {
                final product = _topProducts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppTheme.primary.withValues(alpha: 0.2), AppTheme.primary.withValues(alpha: 0.1)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(child: Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${product['units'] ?? 0} units sold', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      Text('₱${((product['sales'] ?? 0) as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.success, fontSize: 14)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildOrdersTab() {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: _recentOrders.isEmpty
          ? const Center(child: EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _recentOrders.length,
              itemBuilder: (context, index) {
                final order = _recentOrders[index];
                return OrderCard(order: order, onTap: () => Navigator.pushNamed(context, '/seller/orders'));
              },
            ),
    );
  }

  Widget _buildSalesTrendCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sales Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Row(
                children: [
                  _buildRangeButton('7D', '7d'),
                  const SizedBox(width: 4),
                  _buildRangeButton('30D', '30d'),
                  const SizedBox(width: 4),
                  _buildRangeButton('90D', '90d'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_timeseriesData['labels'] != null && (_timeseriesData['labels'] as List).isNotEmpty)
            SizedBox(
              height: 150,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '₱${((_timeseriesData['sales'] as List?)?.fold<double>(0, (sum, val) => sum + (val as num).toDouble()) ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                    const Text('Total Sales', style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 150, child: Center(child: Text('No sales data', style: TextStyle(color: AppTheme.textMuted)))),
        ],
      ),
    );
  }

  Widget _buildRangeButton(String label, String value) {
    final isSelected = _selectedRange == value;
    return GestureDetector(
      onTap: () => _changeRange(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppTheme.textMuted)),
      ),
    );
  }

  Widget _buildEarningRow(String label, num value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textMuted)),
          Text('₱${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─── Seller Profile ────────────────────────────────────────────────────────
class SellerProfileScreen extends StatelessWidget {
  const SellerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Profile'), backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(leading: const Icon(Icons.person_outline, color: AppTheme.primary), title: const Text('Edit Profile'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          ListTile(leading: const Icon(Icons.lock_outline, color: AppTheme.primary), title: const Text('Change Password'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          ListTile(leading: const Icon(Icons.store_outlined, color: AppTheme.primary), title: const Text('Shop Settings'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.error),
            title: const Text('Logout', style: TextStyle(color: AppTheme.error)),
            onTap: () => Navigator.pushReplacementNamed(context, '/logout'),
          ),
        ],
      ),
    );
  }
}
