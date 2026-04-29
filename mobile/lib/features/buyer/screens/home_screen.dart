import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'market_screen.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'chat_screen.dart';
import 'buyer_extra_screens.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  List _flashSales = [];
  List _newArrivals = [];
  int _cartCount = 0;
  int _notifCount = 0;
  int _msgCount = 0;
  bool _loading = true;

  final PageController _promoCtrl = PageController();
  int _promoIndex = 0;
  Timer? _promoTimer;
  Timer? _countdownTimer;
  String _countdown = '--:--:--';

  static const _promoSlides = [
    {'badge': 'Today Only', 'title': 'Flash Sale — Up to 70% Off!', 'icon': Icons.local_fire_department},
    {'badge': 'Limited Time', 'title': 'Free Shipping on All Orders!', 'icon': Icons.local_shipping},
    {'badge': 'Just Dropped', 'title': 'New Arrivals Collection!', 'icon': Icons.star},
  ];

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Dresses & Skirts', 'icon': Icons.checkroom, 'color': const Color(0xFFFF2BAC), 'desc': 'Elegant pieces for every occasion'},
    {'name': 'Tops & Blouses', 'icon': Icons.dry_cleaning, 'color': const Color(0xFF8B5CF6), 'desc': 'Stylish tops for any style'},
    {'name': 'Activewear & Yoga Pants', 'icon': Icons.fitness_center, 'color': const Color(0xFF10B981), 'desc': 'Move in comfort and style'},
    {'name': 'Lingerie & Sleepwear', 'icon': Icons.bedtime, 'color': const Color(0xFFF59E0B), 'desc': 'Soft, cozy essentials'},
    {'name': 'Jackets & Coats', 'icon': Icons.layers, 'color': const Color(0xFF3B82F6), 'desc': 'Layer up with confidence'},
    {'name': 'Shoes & Accessories', 'icon': Icons.shopping_bag, 'color': const Color(0xFFEF4444), 'desc': 'Complete your look'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _startPromoCarousel();
    _startCountdown();
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _countdownTimer?.cancel();
    _promoCtrl.dispose();
    super.dispose();
  }

  void _startPromoCarousel() {
    _promoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_promoCtrl.hasClients) return;
      final next = (_promoIndex + 1) % _promoSlides.length;
      _promoCtrl.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    });
  }

  DateTime _nextSixHourBoundary() {
    final now = DateTime.now();
    final h = now.hour + now.minute / 60.0 + now.second / 3600.0;
    final nextBlock = (h / 6).ceil() * 6;
    var end = DateTime(now.year, now.month, now.day, nextBlock % 24);
    if (nextBlock >= 24 && !end.isAfter(now)) end = end.add(const Duration(days: 1));
    return end;
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final diff = _nextSixHourBoundary().difference(DateTime.now());
      if (diff.isNegative) {
        setState(() => _countdown = '00:00:00');
        return;
      }
      final h = diff.inHours.toString().padLeft(2, '0');
      final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
      setState(() => _countdown = '$h:$m:$s');
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        final results = await Future.wait([
          ApiService.get('/api/products/flash-sale?per_page=8'),
          ApiService.get('/api/products/new-arrivals?per_page=12'),
          ApiService.get('/api/cart'),
          ApiService.get('/api/notifications/count'),
          ApiService.get('/api/buyer/chats'),
        ]);
        if (mounted) {
          final chatList = results[4]['chats'] as List<dynamic>? ?? [];
          var unreadMessages = 0;
          for (final item in chatList) {
            if (item is Map<String, dynamic>) {
              unreadMessages += item['unread_count'] as int? ?? 0;
            }
          }

          setState(() {
            _flashSales = results[0]['products'] ?? [];
            _newArrivals = results[1]['products'] ?? [];
            _cartCount = results[2]['count'] ?? 0;
            _notifCount = results[3]['unread_count'] ?? 0;
            _msgCount = unreadMessages;
            _loading = false;
          });
        }
      } else {
        final results = await Future.wait([
          ApiService.get('/api/products/flash-sale?per_page=8'),
          ApiService.get('/api/products/new-arrivals?per_page=12'),
        ]);
        if (mounted) {
          setState(() {
            _flashSales = results[0]['products'] ?? [];
            _newArrivals = results[1]['products'] ?? [];
            _cartCount = 0;
            _notifCount = 0;
            _msgCount = 0;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToCart(int productId) async {
    final res = await ApiService.post('/api/cart', {'product_id': productId, 'quantity': 1});
    if (res['success'] == true && mounted) {
      setState(() => _cartCount = res['count'] ?? _cartCount + 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart!'), backgroundColor: AppTheme.success, duration: Duration(seconds: 1)),
      );
    }
  }

  Widget _headerBadgeBtn(IconData icon, int count, Color badgeColor, VoidCallback onTap) {
    return Stack(
      children: [
        IconButton(
          onPressed: onTap,
          padding: EdgeInsets.zero,
          splashRadius: 20,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: Icon(icon, color: Colors.white, size: 21),
        ),
        if (count > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final screen = MediaQuery.sizeOf(context);
    final isCompact = screen.width < 360;
    final horizontalPadding = isCompact ? 12.0 : 16.0;
    final sectionTitleSize = isCompact ? 18.0 : 20.0;
    final promoAspectRatio = screen.width < 340
        ? 0.95
        : screen.width < 390
            ? 1.08
            : 1.24;
    final flashCardWidth = (screen.width * 0.42).clamp(138.0, 172.0).toDouble();
    final flashListHeight = (flashCardWidth / 0.64).clamp(210.0, 270.0).toDouble();
    final newArrivalsAspectRatio = screen.width < 340
        ? 0.65
        : screen.width < 390
            ? 0.72
            : 0.80;
    final categoriesAspectRatio = screen.width < 340
        ? 0.75
        : screen.width < 390
            ? 0.82
            : 0.92;
    final categoryIconBox = isCompact ? 54.0 : 64.0;
    final categoryIconSize = isCompact ? 26.0 : 32.0;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: true,
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1B0E24), Color(0xFF2D1B3D)],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Hello, ${auth.name.split(' ').first}! 👋',
                              style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Grande',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isCompact ? 22 : 24,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _headerBadgeBtn(
                            Icons.chat_bubble_outline,
                            _msgCount,
                            AppTheme.info,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ChatCenterScreen()),
                            ).then((_) => _loadData()),
                          ),
                          _headerBadgeBtn(
                            Icons.notifications_outlined,
                            _notifCount,
                            AppTheme.error,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                            ),
                          ),
                          _headerBadgeBtn(
                            Icons.shopping_bag_outlined,
                            _cartCount,
                            AppTheme.primary,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CartScreen()),
                            ).then((_) => _loadData()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_loading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: (screen.height * 0.2).clamp(80.0, 150.0).toDouble()),
                    child: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  )
                else ...[
                  // Promo Carousel Section
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AspectRatio(
                              aspectRatio: promoAspectRatio,
                              child: PageView.builder(
                                controller: _promoCtrl,
                                itemCount: _promoSlides.length,
                                onPageChanged: (i) => setState(() => _promoIndex = i),
                                itemBuilder: (_, i) {
                                  final slide = _promoSlides[i];
                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isSlideCompact = constraints.maxWidth < 340;
                                      final slidePadding = isSlideCompact ? 16.0 : 24.0;
                                      final titleSize = isSlideCompact ? 18.0 : 22.0;
                                      final badgeSize = isSlideCompact ? 10.0 : 11.0;
                                      final buttonFont = isSlideCompact ? 12.0 : 13.0;

                                      return Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [Color(0xFFFFFEE3), Color(0xFFFFC6BF)],
                                          ),
                                        ),
                                        padding: EdgeInsets.all(slidePadding),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                gradient: AppTheme.brandGradient,
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                slide['badge'] as String,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: Colors.white, fontSize: badgeSize, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            SizedBox(height: isSlideCompact ? 10 : 12),
                                            Expanded(
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  slide['title'] as String,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: AppTheme.primaryDark,
                                                    fontSize: titleSize,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: ElevatedButton.icon(
                                                onPressed: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => const MarketScreen(flashSale: true)),
                                                ),
                                                icon: Icon(Icons.bolt, size: isSlideCompact ? 16 : 18),
                                                label: const Text('Shop Now'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppTheme.primary,
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: isSlideCompact ? 14 : 18,
                                                    vertical: isSlideCompact ? 8 : 10,
                                                  ),
                                                  textStyle: TextStyle(fontSize: buttonFont, fontWeight: FontWeight.w600),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              color: Colors.white,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _promoSlides.length,
                                  (i) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: i == _promoIndex ? 18 : 10,
                                    height: 10,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: i == _promoIndex ? AppTheme.primary : AppTheme.border,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Flash Sales Section
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.error.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                                    ),
                                    child: const Text(
                                      'Limited Time',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Flash Sales',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: sectionTitleSize, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MarketScreen(flashSale: true)),
                              ),
                              child: Text(
                                'View all',
                                style: TextStyle(color: AppTheme.primary, fontSize: isCompact ? 12 : 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Ends in',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: isCompact ? 11 : 12, color: AppTheme.textMuted),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _countdown,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                              style: TextStyle(
                                fontSize: isCompact ? 16 : 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.error,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _flashSales.isEmpty
                        ? Padding(
                            padding: EdgeInsets.symmetric(vertical: (screen.width * 0.15).clamp(30.0, 50.0).toDouble()),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_fire_department, size: 44, color: AppTheme.textMuted),
                                  SizedBox(height: 8),
                                  Text('No flash deals right now', style: TextStyle(color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.zero,
                            itemCount: _flashSales.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => SizedBox(
                              width: flashCardWidth,
                              child: ProductCard(
                                product: _flashSales[i],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: _flashSales[i]['id'])),
                                ),
                                onAddToCart: () => _addToCart(_flashSales[i]['id']),
                              ),
                            ),
                          ),
                  ),

                  // New Arrivals Section
                  if (_newArrivals.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.info.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'Just In',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: AppTheme.info, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'New Arrivals',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: sectionTitleSize, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Added in the last 7 days',
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: isCompact ? 10 : 11, color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate optimal card width
                          final cardWidth = (constraints.maxWidth - 8) / 2;
                          
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_newArrivals.length, (i) => SizedBox(
                              width: cardWidth,
                              child: ProductCard(
                                product: _newArrivals[i],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: _newArrivals[i]['id'])),
                                ),
                                onAddToCart: () => _addToCart(_newArrivals[i]['id']),
                              ),
                            )),
                          );
                        },
                      ),
                    ),
                  ],

                  // Categories Section
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 28, horizontalPadding, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AppTheme.brandGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Shop by Category',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Featured Categories',
                          style: TextStyle(fontSize: sectionTitleSize, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Explore our carefully curated collection',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: isCompact ? 12 : 13, color: AppTheme.textMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate optimal card width
                        final cardWidth = (constraints.maxWidth - 8) / 2;
                        
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(_categories.length, (i) {
                            final cat = _categories[i];
                            return SizedBox(
                              width: cardWidth,
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => MarketScreen(category: cat['name'] as String)),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.border),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 10 : 12),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: categoryIconBox,
                                          height: categoryIconBox,
                                          decoration: BoxDecoration(
                                            color: (cat['color'] as Color).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: (cat['color'] as Color).withValues(alpha: 0.3)),
                                          ),
                                          child: Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: categoryIconSize),
                                        ),
                                        SizedBox(height: isCompact ? 8 : 12),
                                        Text(
                                          cat['name'] as String,
                                          style: TextStyle(
                                            fontSize: isCompact ? 12 : 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textDark,
                                            height: 1.2,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          cat['desc'] as String,
                                          style: TextStyle(fontSize: isCompact ? 10.5 : 11, color: AppTheme.textMuted, height: 1.25),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
