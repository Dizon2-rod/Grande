import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/auth_provider.dart';
import 'core/api/api_service.dart';
import 'core/supabase/supabase_client.dart';
import 'shared/widgets/common_widgets.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/buyer/screens/buyer_main_screen.dart';
import 'features/buyer/screens/buyer_extra_screens.dart';
import 'features/buyer/screens/cart_screen.dart';
import 'features/buyer/screens/market_screen.dart';
import 'features/buyer/screens/product_review_screen.dart';
import 'features/seller/screens/seller_screens.dart';
import 'features/seller/screens/edit_product_screen.dart';
import 'features/seller/screens/improved_add_product_screen.dart';
import 'features/rider/screens/rider_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Initialize Supabase
  await SupabaseService.initialize();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..loadUser(),
      child: const GrandeApp(),
    ),
  );
}

class GrandeApp extends StatelessWidget {
  const GrandeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grande',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/seller/edit-product') {
          final product = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(builder: (_) => EditProductScreen(product: product));
        }
        return null;
      },
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/buyer': (_) => const BuyerMainScreen(),
        '/seller': (_) => const SellerMainScreen(),
        '/rider': (_) => const RiderMainScreen(),
        '/orders': (_) => const MyOrdersScreen(),
        '/wishlist': (_) => const WishlistScreen(),
        '/notifications': (_) => const NotificationsScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/addresses': (_) => const AddressesScreen(),
        '/edit-profile': (_) => const EditProfileScreen(),
        '/change-password': (_) => const ChangePasswordScreen(),
        '/cart': (_) => const CartScreen(),
        '/shop': (_) => const MarketScreen(),
        '/seller/orders': (_) => const SellerOrdersScreen(),
        '/seller/inventory': (_) => const SellerInventoryScreen(),
        '/seller/add-product': (_) => const ImprovedAddProductScreen(),
        '/seller/analytics': (_) => const SellerAnalyticsScreen(),
        '/seller/delivery-tracking': (_) => const SellerDeliveryTrackingScreen(),
        '/seller/awaiting-pickup': (_) => const SellerAwaitingPickupScreen(),
        '/rider/available': (_) => const AvailableDeliveriesScreen(),
        '/rider/deliveries': (_) => const MyDeliveriesScreen(),
        '/rider/earnings': (_) => const RiderEarningsScreen(),
        '/rider/history': (_) => const RiderDeliveryHistoryScreen(),
        '/logout': (_) => const LogoutScreen(),
      },
    );
  }
}

// ─── Splash Screen ─────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _checkAuth();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.loadUser();
    if (!mounted) return;
    if (auth.isLoggedIn) {
      switch (auth.role) {
        case 'seller': Navigator.pushReplacementNamed(context, '/seller'); break;
        case 'rider': Navigator.pushReplacementNamed(context, '/rider'); break;
        default: Navigator.pushReplacementNamed(context, '/buyer');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.sidebarGradient),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.shopping_bag, color: Colors.white, size: 52),
                ),
                const SizedBox(height: 20),
                const Text('Grande', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 8),
                const Text('Your Fashion Destination', style: TextStyle(color: Colors.white60, fontSize: 14)),
                const SizedBox(height: 48),
                const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Logout Screen ─────────────────────────────────────────────────────────
class LogoutScreen extends StatefulWidget {
  const LogoutScreen({super.key});

  @override
  State<LogoutScreen> createState() => _LogoutScreenState();
}

class _LogoutScreenState extends State<LogoutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthProvider>().logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
}

// ─── Rider Delivery History ────────────────────────────────────────────────
class RiderDeliveryHistoryScreen extends StatefulWidget {
  const RiderDeliveryHistoryScreen({super.key});
  @override
  State<RiderDeliveryHistoryScreen> createState() => _RiderDeliveryHistoryScreenState();
}

class _RiderDeliveryHistoryScreenState extends State<RiderDeliveryHistoryScreen> {
  List _history = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/rider/deliveries/history');
    if (mounted) setState(() { _history = res['deliveries'] ?? []; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Delivery History'), backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _history.isEmpty
              ? const EmptyState(icon: Icons.history, title: 'No delivery history yet')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (_, i) {
                    final d = _history[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                      child: Row(
                        children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.check_circle, color: AppTheme.success, size: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                Text(d['delivery_address'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                Text(d['completed_at'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          Text('₱${((d['delivery_fee'] ?? 0) as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.success, fontSize: 14)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
