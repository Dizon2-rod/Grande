import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'cart_screen.dart';
import 'seller_shop_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _product;
  List _reviews = [];
  bool _loading = true;
  bool _wishlisted = false;
  String? _selectedSize;
  String? _selectedColor;
  int _quantity = 1;
  int _imageIndex = 0;
  final _reviewController = TextEditingController();
  double _reviewRating = 5;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/api/products/${widget.productId}'),
        ApiService.get('/api/products/${widget.productId}/reviews'),
        ApiService.get('/api/wishlist'),
      ]);
      if (mounted) {
        final wishlist = (results[2]['items'] as List?) ?? [];
        setState(() {
          _product = results[0]['product'];
          _reviews = results[1]['reviews'] ?? [];
          _wishlisted = wishlist.any((w) => w['product_id'] == widget.productId);
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _addToCart() async {
    if (_selectedSize == null || _selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select size and color'), backgroundColor: AppTheme.warning));
      return;
    }
    final res = await ApiService.post('/api/cart', {
      'product_id': widget.productId,
      'size': _selectedSize,
      'color': _selectedColor,
      'quantity': _quantity,
    });
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart!'), backgroundColor: AppTheme.success));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Failed'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _toggleWishlist() async {
    final res = _wishlisted
        ? await ApiService.delete('/api/wishlist/${widget.productId}')
        : await ApiService.post('/api/wishlist/${widget.productId}', {});
    if (res['success'] == true && mounted) setState(() => _wishlisted = !_wishlisted);
  }

  Future<void> _submitReview() async {
    if (_reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a review comment'), backgroundColor: AppTheme.warning));
      return;
    }
    try {
      final res = await ApiService.post('/api/products/${widget.productId}/reviews', {
        'rating': _reviewRating,
        'comment': _reviewController.text.trim(),
      });
      if (res['success'] == true && mounted) {
        Navigator.pop(context);
        _reviewController.clear();
        setState(() => _reviewRating = 5);
        _load();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted!'), backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit review'), backgroundColor: AppTheme.error));
      }
    }
  }

  void _showReviewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Write a Review', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RatingBar.builder(
              initialRating: _reviewRating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (context, _) => const Icon(Icons.star, color: AppTheme.warning),
              onRatingUpdate: (rating) => setState(() => _reviewRating = rating),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share your experience with this product...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppTheme.background,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _submitReview,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<String> get _images {
    final p = _product!;
    final variantImages = (p['variant_images'] as List?) ?? [];
    if (variantImages.isNotEmpty) return variantImages.map((v) => ApiService.imageUrl(v['image_url']?.toString() ?? '')).toList();
    final img = p['image_url'] ?? p['image'] ?? '';
    return img.isNotEmpty ? [ApiService.imageUrl(img)] : [];
  }

  Map<String, dynamic> get _sizeColorStock {
    return (_product?['size_color_stock'] as Map<String, dynamic>?) ?? {};
  }

  List<String> get _sizes => _sizeColorStock.keys.toList();

  List<String> get _colors {
    if (_selectedSize == null) return [];
    final sizeData = _sizeColorStock[_selectedSize] as Map<String, dynamic>? ?? {};
    return sizeData.keys.toList();
  }

  double get _currentPrice {
    if (_selectedSize != null && _selectedColor != null) {
      final v = (_sizeColorStock[_selectedSize] as Map?)?[_selectedColor] as Map?;
      if (v != null) {
        final dp = v['discount_price'];
        if (dp != null) return (dp as num).toDouble();
        return (v['price'] as num?)?.toDouble() ?? 0;
      }
    }
    return (_product?['price'] as num?)?.toDouble() ?? 0;
  }

  int get _stock {
    if (_selectedSize != null && _selectedColor != null) {
      final v = (_sizeColorStock[_selectedSize] as Map?)?[_selectedColor] as Map?;
      return (v?['stock'] as num?)?.toInt() ?? 0;
    }
    return (_product?['total_stock'] as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    if (_product == null) return const Scaffold(body: Center(child: Text('Product not found')));

    final images = _images;
    final avgRating = (_product!['avg_rating'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppTheme.primaryDark,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(_wishlisted ? Icons.favorite : Icons.favorite_border, color: _wishlisted ? Colors.red : Colors.white),
                onPressed: _toggleWishlist,
              ),
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  if (images.isNotEmpty)
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _imageIndex = i),
                      itemBuilder: (_, i) => CachedNetworkImage(
                        imageUrl: images[i],
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: AppTheme.background, child: const Icon(Icons.image, size: 64, color: AppTheme.textMuted)),
                      ),
                    )
                  else
                    Container(color: AppTheme.background, child: const Icon(Icons.image, size: 64, color: AppTheme.textMuted)),
                  if (images.length > 1)
                    Positioned(
                      bottom: 12, left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (i) => Container(
                          width: i == _imageIndex ? 20 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i == _imageIndex ? AppTheme.primary : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        )),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name & price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(_product!['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textDark))),
                      Text('₱${_currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rating
                  Row(
                    children: [
                      RatingBarIndicator(rating: avgRating, itemSize: 16, itemBuilder: (_, __) => const Icon(Icons.star, color: AppTheme.warning)),
                      const SizedBox(width: 6),
                      Text('${avgRating.toStringAsFixed(1)} (${_reviews.length} reviews)', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      const Spacer(),
                      Text('Stock: $_stock', style: TextStyle(fontSize: 12, color: _stock > 0 ? AppTheme.success : AppTheme.error, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),

                  // Size selection
                  if (_sizes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Select Size', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _sizes.map((s) => GestureDetector(
                        onTap: () => setState(() { _selectedSize = s; _selectedColor = null; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedSize == s ? AppTheme.primary : AppTheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _selectedSize == s ? AppTheme.primary : AppTheme.border),
                          ),
                          child: Text(s, style: TextStyle(fontWeight: FontWeight.w600, color: _selectedSize == s ? Colors.white : AppTheme.textDark)),
                        ),
                      )).toList(),
                    ),
                  ],

                  // Color selection
                  if (_colors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Select Color', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _colors.map((c) {
                        Color? colorVal;
                        try { colorVal = Color(int.parse(c.replaceFirst('#', '0xFF'))); } catch (_) {}
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = c),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: colorVal ?? AppTheme.border,
                              shape: BoxShape.circle,
                              border: Border.all(color: _selectedColor == c ? AppTheme.primary : AppTheme.border, width: _selectedColor == c ? 3 : 1),
                            ),
                            child: _selectedColor == c ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Quantity
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null),
                            Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            IconButton(icon: const Icon(Icons.add, size: 18), onPressed: _quantity < _stock ? () => setState(() => _quantity++) : null),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Description
                  if (_product!['description'] != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(_product!['description'], style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.6)),
                  ],

                  // Seller Store Section
                  if (_product!['seller_id'] != null) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SellerShopScreen(
                              sellerId: _product!['seller_id'],
                              sellerName: _product!['seller_name'] ?? 'Shop',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: AppTheme.brandGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  (_product!['seller_name'] ?? 'Shop')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_product!['seller_name'] ?? 'Shop', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textDark)),
                                  const SizedBox(height: 2),
                                  Text('Visit Store', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Reviews
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Reviews (${_reviews.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _showReviewDialog,
                        icon: const Icon(Icons.rate_review, size: 16),
                        label: const Text('Write a Review', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_reviews.isEmpty)
                    const Text('No reviews yet. Be the first to review!', style: TextStyle(color: AppTheme.textMuted, fontSize: 13))
                  else
                    ..._reviews.take(3).map((r) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(radius: 14, backgroundColor: AppTheme.primary.withValues(alpha: 0.15), child: Text((r['user_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12))),
                              const SizedBox(width: 8),
                              Text(r['user_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const Spacer(),
                              RatingBarIndicator(rating: (r['rating'] as num?)?.toDouble() ?? 0, itemSize: 12, itemBuilder: (_, __) => const Icon(Icons.star, color: AppTheme.warning)),
                            ],
                          ),
                          if (r['comment'] != null) ...[
                            const SizedBox(height: 6),
                            Text(r['comment'], style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ],
                      ),
                    )),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: GradientButton(
          label: _stock > 0 ? 'Add to Cart — ₱${(_currentPrice * _quantity).toStringAsFixed(2)}' : 'Out of Stock',
          icon: Icons.shopping_cart_outlined,
          onPressed: _stock > 0 ? _addToCart : null,
        ),
      ),
    );
  }
}
