import 'package:flutter/material.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'product_detail_screen.dart';

class MarketScreen extends StatefulWidget {
  final String? category;
  final bool flashSale;

  const MarketScreen({super.key, this.category, this.flashSale = false});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _searchCtrl = TextEditingController();
  List _products = [];
  bool _loading = true;
  bool _gridView = true;
  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  String _sort = 'newest';
  String? _selectedCategory;
  double? _minPrice, _maxPrice;
  List<String> _selectedSizes = [];
  int? _minRating;

  final List<String> _sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  final List<String> _categories = [
    'Dresses & Skirts', 'Tops & Blouses', 'Activewear & Yoga Pants',
    'Lingerie & Sleepwear', 'Jackets & Coats', 'Shoes & Accessories'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    _loadProducts();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadProducts({bool reset = false}) async {
    if (reset) { _page = 1; _products = []; }
    setState(() => _loading = true);
    try {
      final res = await ApiService.get(widget.flashSale
          ? '/api/products/flash-sale?page=$_page&per_page=20'
          : '/api/products?page=$_page&per_page=20&sort_by=$_sort');
      if (mounted) {
        setState(() {
          _products = res['products'] ?? [];
          _totalPages = res['pages'] ?? 1;
          _totalCount = res['total'] ?? _products.length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

  void _showFilters() {
    String? tempCategory = _selectedCategory;
    List<String> tempSizes = List.from(_selectedSizes);
    double? tempMin = _minPrice;
    double? tempMax = _maxPrice;
    int? tempRating = _minRating;
    final minCtrl = TextEditingController(text: _minPrice?.toString() ?? '');
    final maxCtrl = TextEditingController(text: _maxPrice?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    const Icon(Icons.tune, color: AppTheme.primary, size: 24),
                    const SizedBox(width: 8),
                    const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setModal(() {
                          tempCategory = null;
                          tempSizes.clear();
                          tempMin = null;
                          tempMax = null;
                          tempRating = null;
                          minCtrl.clear();
                          maxCtrl.clear();
                        });
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear All'),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Category
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.category, size: 18, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((c) => FilterChip(
                        label: Text(c, style: TextStyle(fontSize: 13, color: tempCategory == c ? AppTheme.primary : AppTheme.textDark)),
                        selected: tempCategory == c,
                        onSelected: (v) => setModal(() => tempCategory = v ? c : null),
                        selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                        checkmarkColor: AppTheme.primary,
                        backgroundColor: AppTheme.surface,
                        labelStyle: TextStyle(color: tempCategory == c ? AppTheme.primary : AppTheme.textDark),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: tempCategory == c ? AppTheme.primary : AppTheme.border,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Size
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.straighten, size: 18, color: AppTheme.info),
                        ),
                        const SizedBox(width: 12),
                        const Text('Size', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sizes.map((s) => FilterChip(
                        label: Text(s, style: TextStyle(fontWeight: FontWeight.w600, color: tempSizes.contains(s) ? AppTheme.info : AppTheme.textDark)),
                        selected: tempSizes.contains(s),
                        onSelected: (v) {
                          setModal(() {
                            if (v) {
                              tempSizes.add(s);
                            } else {
                              tempSizes.remove(s);
                            }
                          });
                        },
                        selectedColor: AppTheme.info.withValues(alpha: 0.15),
                        checkmarkColor: AppTheme.info,
                        backgroundColor: AppTheme.surface,
                        labelStyle: TextStyle(color: tempSizes.contains(s) ? AppTheme.info : AppTheme.textDark),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: tempSizes.contains(s) ? AppTheme.info : AppTheme.border,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Price Range
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.attach_money, size: 18, color: AppTheme.success),
                        ),
                        const SizedBox(width: 12),
                        const Text('Price Range', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            decoration: InputDecoration(
                              labelText: 'Min ₱',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: AppTheme.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => tempMin = double.tryParse(v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            decoration: InputDecoration(
                              labelText: 'Max ₱',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: AppTheme.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => tempMax = double.tryParse(v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Customer Rating
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.star, size: 18, color: AppTheme.warning),
                        ),
                        const SizedBox(width: 12),
                        const Text('Customer Rating', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...([5, 4, 3].map((r) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: tempRating == r ? AppTheme.warning.withValues(alpha: 0.1) : AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: tempRating == r ? AppTheme.warning : AppTheme.border,
                            ),
                          ),
                          child: RadioListTile<int?>(
                            value: r,
                            groupValue: tempRating,
                            onChanged: (v) => setModal(() => tempRating = v),
                            activeColor: AppTheme.warning,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: Row(
                              children: [
                                ...List.generate(
                                    5,
                                    (i) => Icon(
                                          i < r ? Icons.star : Icons.star_border,
                                          size: 18,
                                          color: AppTheme.warning,
                                        )),
                                const SizedBox(width: 8),
                                Text('$r star${r < 5 ? ' & up' : ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
                              ],
                            ),
                          ),
                        ))),
                  ],
                ),
              ),
              // Apply button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: GradientButton(
                  label: 'Apply Filters',
                  icon: Icons.check,
                  onPressed: () {
                    setState(() {
                      _selectedCategory = tempCategory;
                      _selectedSizes = List.from(tempSizes);
                      _minPrice = tempMin;
                      _maxPrice = tempMax;
                      _minRating = tempRating;
                    });
                    Navigator.pop(context);
                    _loadProducts(reset: true);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.flashSale ? '⚡ Flash Sales' : (widget.category ?? 'Shop')),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          // Grid/List toggle
          IconButton(
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          IconButton(icon: const Icon(Icons.tune), onPressed: _showFilters),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            initialValue: _sort,
            onSelected: (v) {
              setState(() => _sort = v);
              _loadProducts(reset: true);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'relevance',
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18, color: _sort == 'relevance' ? AppTheme.primary : AppTheme.textMuted),
                    const SizedBox(width: 8),
                    const Text('Relevance'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'newest',
                child: Row(
                  children: [
                    Icon(Icons.new_releases, size: 18, color: _sort == 'newest' ? AppTheme.primary : AppTheme.textMuted),
                    const SizedBox(width: 8),
                    const Text('Newest'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'price-low',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 18, color: _sort == 'price-low' ? AppTheme.primary : AppTheme.textMuted),
                    const SizedBox(width: 8),
                    const Text('Price: Low to High'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'price-high',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, size: 18, color: _sort == 'price-high' ? AppTheme.primary : AppTheme.textMuted),
                    const SizedBox(width: 8),
                    const Text('Price: High to Low'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rating',
                child: Row(
                  children: [
                    Icon(Icons.star, size: 18, color: _sort == 'rating' ? AppTheme.primary : AppTheme.textMuted),
                    const SizedBox(width: 8),
                    const Text('Top Rated'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'bestseller',
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 18, color: _sort == 'bestseller' ? AppTheme.primary : AppTheme.textMuted),
                    const SizedBox(width: 8),
                    const Text('Best Sellers'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'discount-high',
                child: Row(
                  children: [
                    Icon(Icons.local_offer, size: 18, color: _sort == 'discount-high' ? AppTheme.primary : AppTheme.textMuted),
                    const SizedBox(width: 8),
                    const Text('Discount: High to Low'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.surface,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Home', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
                ),
                Text(
                  widget.flashSale ? 'Flash Sales' : (widget.category ?? 'Shop'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _loadProducts(reset: true); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                filled: true, fillColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _loadProducts(reset: true),
            ),
          ),

          // Active filters + product count row
          if (_selectedCategory != null || _selectedSizes.isNotEmpty || _minRating != null || _minPrice != null || _maxPrice != null || !_loading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product count
                  if (!_loading)
                    Row(
                      children: [
                        Text('$_totalCount product${_totalCount != 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 14, color: AppTheme.textDark, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (_selectedCategory != null || _selectedSizes.isNotEmpty || _minRating != null || _minPrice != null || _maxPrice != null)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = null;
                                _selectedSizes.clear();
                                _minRating = null;
                                _minPrice = null;
                                _maxPrice = null;
                              });
                              _loadProducts(reset: true);
                            },
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Clear All'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                      ],
                    ),
                  // Active filter chips
                  if (_selectedCategory != null || _selectedSizes.isNotEmpty || _minRating != null || _minPrice != null || _maxPrice != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_selectedCategory != null)
                          Chip(
                            avatar: const Icon(Icons.category, size: 16, color: AppTheme.primary),
                            label: Text(_selectedCategory!, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() => _selectedCategory = null);
                              _loadProducts(reset: true);
                            },
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                          ),
                        ..._selectedSizes.map((s) => Chip(
                            avatar: const Icon(Icons.straighten, size: 16, color: AppTheme.info),
                            label: Text('Size: $s', style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() => _selectedSizes.remove(s));
                              _loadProducts(reset: true);
                            },
                            backgroundColor: AppTheme.info.withValues(alpha: 0.1),
                            side: BorderSide(color: AppTheme.info.withValues(alpha: 0.3)),
                          )),
                        if (_minRating != null)
                          Chip(
                            avatar: const Icon(Icons.star, size: 16, color: AppTheme.warning),
                            label: Text('$_minRating★+', style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() => _minRating = null);
                              _loadProducts(reset: true);
                            },
                            backgroundColor: AppTheme.warning.withValues(alpha: 0.1),
                            side: BorderSide(color: AppTheme.warning.withValues(alpha: 0.3)),
                          ),
                        if (_minPrice != null || _maxPrice != null)
                          Chip(
                            avatar: const Icon(Icons.attach_money, size: 16, color: AppTheme.success),
                            label: Text(
                              _minPrice != null && _maxPrice != null
                                  ? '₱${_minPrice!.toStringAsFixed(0)} - ₱${_maxPrice!.toStringAsFixed(0)}'
                                  : _minPrice != null
                                      ? 'Min: ₱${_minPrice!.toStringAsFixed(0)}'
                                      : 'Max: ₱${_maxPrice!.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _minPrice = null;
                                _maxPrice = null;
                              });
                              _loadProducts(reset: true);
                            },
                            backgroundColor: AppTheme.success.withValues(alpha: 0.1),
                            side: BorderSide(color: AppTheme.success.withValues(alpha: 0.3)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          // Products
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _products.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        title: 'No products found',
                        subtitle: 'Try adjusting your filters or search term',
                        action: TextButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() { _selectedCategory = null; _selectedSizes.clear(); _minRating = null; });
                            _loadProducts(reset: true);
                          },
                          child: const Text('Clear Filters'),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: () => _loadProducts(reset: true),
                        child: _gridView
                            ? SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final cardWidth = (constraints.maxWidth - 10) / 2;
                                      return Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: List.generate(_products.length, (i) => SizedBox(
                                          width: cardWidth,
                                          child: ProductCard(
                                            product: _products[i],
                                            showActions: true,
                                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: _products[i]['id']))),
                                            onAddToCart: () => _addToCart(_products[i]['id']),
                                          ),
                                        )),
                                      );
                                    },
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _products.length,
                                itemBuilder: (_, i) => _ProductListTile(
                                  product: _products[i],
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: _products[i]['id']))),
                                  onAddToCart: () => _addToCart(_products[i]['id']),
                                ),
                              ),
                      ),
          ),

          // Pagination
          if (_totalPages > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _page > 1 ? () { setState(() => _page--); _loadProducts(); } : null),
                  Text('$_page / $_totalPages', style: const TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: _page < _totalPages ? () { setState(() => _page++); _loadProducts(); } : null),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// List view tile for products
class _ProductListTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const _ProductListTile({required this.product, this.onTap, this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final price = product['min_price'] ?? product['price'] ?? 0;
    final discountPrice = product['min_discount_price'];
    final hasDiscount = discountPrice != null && (discountPrice as num) < (price as num);
    final imageUrl = ApiService.imageUrl(product['image_url'] ?? product['image'] ?? '');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: AppTheme.background, child: const Icon(Icons.image, color: AppTheme.textMuted)))
                  : Container(width: 80, height: 80, color: AppTheme.background, child: const Icon(Icons.image, color: AppTheme.textMuted)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('₱${(hasDiscount ? discountPrice : price).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primary)),
                      if (hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text('₱${(price).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, decoration: TextDecoration.lineThrough)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: onAddToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Add to Cart', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
