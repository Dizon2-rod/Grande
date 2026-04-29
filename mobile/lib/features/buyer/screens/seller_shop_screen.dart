import 'package:flutter/material.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'product_detail_screen.dart';

class SellerShopScreen extends StatefulWidget {
  final int sellerId;
  final String sellerName;
  const SellerShopScreen({super.key, required this.sellerId, required this.sellerName});

  @override
  State<SellerShopScreen> createState() => _SellerShopScreenState();
}

class _SellerShopScreenState extends State<SellerShopScreen> {
  List<dynamic> _products = [];
  Map<String, dynamic>? _sellerInfo;
  bool _loading = true;
  String _sortBy = 'newest';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<dynamic> products = [];
    Map<String, dynamic>? sellerInfo;
    
    // Load seller info & products in parallel
    try {
      final results = await Future.wait([
        ApiService.get('/api/products?seller_id=${widget.sellerId}&per_page=100&sort=$_sortBy&search=$_searchQuery'),
        ApiService.get('/api/sellers/${widget.sellerId}'),
      ]);
      
      products = results[0]['products'] ?? [];
      sellerInfo = results[1]['seller'];
    } catch (e) {
      print('Error loading seller shop: $e');
    }

    if (mounted) {
      setState(() {
        _products = products;
        _sellerInfo = sellerInfo;
        _loading = false;
      });
    }
  }

  Future<void> _addToCart(int productId) async {
    final res = await ApiService.post('/api/cart', {'product_id': productId, 'quantity': 1});
    if (res['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart!'), backgroundColor: AppTheme.success, duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _toggleWishlist(int productId) async {
    try {
      await ApiService.post('/api/wishlist/toggle', {'product_id': productId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wishlist updated!'), backgroundColor: AppTheme.primary, duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      print('Error toggling wishlist: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Seller Shop'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // Seller Info Header
                  if (_sellerInfo != null)
                    SliverToBoxAdapter(
                      child: _buildSellerHeader(),
                    ),

                  // Search & Filter Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Search products...',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  suffixIcon: _searchCtrl.text.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () {
                                            _searchCtrl.clear();
                                            setState(() => _searchQuery = '');
                                            _load();
                                          },
                                          child: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                                        )
                                      : null,
                                ),
                                onChanged: (value) {
                                  setState(() => _searchQuery = value);
                                },
                                onSubmitted: (_) => _load(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              setState(() => _sortBy = value);
                              _load();
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'newest', child: Text('Newest')),
                              const PopupMenuItem(value: 'price_low', child: Text('Price: Low to High')),
                              const PopupMenuItem(value: 'price_high', child: Text('Price: High to Low')),
                              const PopupMenuItem(value: 'rating', child: Text('Top Rated')),
                            ],
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                              child: const Icon(Icons.sort, size: 20, color: AppTheme.textDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Products Grid
                  if (_products.isEmpty)
                    SliverFillRemaining(
                      child: const EmptyState(icon: Icons.shopping_bag_outlined, title: 'No products found'),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      sliver: SliverToBoxAdapter(
                        child: SingleChildScrollView(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cardWidth = (constraints.maxWidth - 10) / 2;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: List.generate(_products.length, (index) => SizedBox(
                                    width: cardWidth,
                                    child: ProductCard(
                                      product: _products[index],
                                      showActions: true,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: _products[index]['id'])),
                                      ),
                                      onAddToCart: () => _addToCart(_products[index]['id']),
                                      onWishlist: () => _toggleWishlist(_products[index]['id']),
                                    ),
                                  )),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSellerHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Seller Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(gradient: AppTheme.brandGradient, borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Text(
                    (_sellerInfo?['name'] ?? 'Shop')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_sellerInfo?['name'] ?? widget.sellerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text('${(_sellerInfo?['rating'] ?? 0).toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        const Text('·', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        const SizedBox(width: 8),
                        Text('${_sellerInfo?['total_products'] ?? 0} products', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_sellerInfo?['description'] != null)
            Text(_sellerInfo!['description'], style: const TextStyle(fontSize: 12, color: AppTheme.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Text('${_sellerInfo?['response_time'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const Text('Response Time', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Text('${(_sellerInfo?['positive_feedback_rate'] ?? 0).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const Text('Positive Feedback', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Text('${_sellerInfo?['followers'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const Text('Followers', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
