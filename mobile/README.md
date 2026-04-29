# Grande Mobile App

Flutter mobile app for the Grande ecommerce platform. Supports **Buyer**, **Seller**, and **Rider** roles — all connected to the same Flask backend and MySQL database as the website.

---

## Setup Instructions

### 1. Install Flutter
Download from https://flutter.dev/docs/get-started/install

### 2. Configure the Backend URL
Open `lib/core/api/api_service.dart` and change the `baseUrl` to your Flask server's IP:

```dart
static const String baseUrl = 'http://YOUR_LOCAL_IP:5000';
```

To find your local IP on Windows: run `ipconfig` in CMD and look for **IPv4 Address**.

> Your phone and PC must be on the **same Wi-Fi network**.

### 3. Enable CORS on Flask (already done)
Your `app.py` already has `CORS(app)` — no changes needed.

### 4. Install dependencies
```bash
cd mobile
flutter pub get
```

### 5. Run the app
```bash
flutter run
```

---

## Project Structure

```
mobile/
├── lib/
│   ├── main.dart                        # App entry, routing, splash
│   ├── core/
│   │   ├── api/api_service.dart         # All HTTP calls to Flask
│   │   ├── theme/app_theme.dart         # Grande brand colors & theme
│   │   └── utils/auth_provider.dart     # Login/logout state (Provider)
│   ├── features/
│   │   ├── auth/screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart     # 3-step: role → info → password
│   │   │   └── forgot_password_screen.dart
│   │   ├── buyer/screens/
│   │   │   ├── buyer_main_screen.dart   # Bottom nav shell
│   │   │   ├── home_screen.dart         # Flash sales, new arrivals, categories
│   │   │   ├── market_screen.dart       # Shop with filters, search, sort
│   │   │   ├── product_detail_screen.dart # Size/color/qty, reviews, add to cart
│   │   │   ├── cart_screen.dart
│   │   │   ├── checkout_screen.dart     # Address, payment, place order
│   │   │   └── buyer_extra_screens.dart # Orders, Wishlist, Notifications, Profile
│   │   ├── seller/screens/
│   │   │   └── seller_screens.dart      # Dashboard, Inventory, Orders, Analytics
│   │   └── rider/screens/
│   │       └── rider_screens.dart       # Dashboard, Available, My Deliveries, Earnings
│   └── shared/widgets/
│       └── common_widgets.dart          # GradientButton, ProductCard, StatusBadge, etc.
└── pubspec.yaml
```

---

## Features by Role

### Buyer
- Home: Flash sales, new arrivals, categories, promo banner
- Shop: Search, filter by category/size/price, sort, pagination
- Product Detail: Image gallery, size & color picker, quantity, reviews
- Cart: Add/remove/update quantity
- Checkout: Address form, payment method (GCash/PayMaya/COD), order placement
- My Orders: Tab by status, cancel orders, view details
- Wishlist, Notifications, Profile

### Seller
- Dashboard: Revenue, orders, products, pending stats + low stock alerts
- Inventory: Search, toggle active/inactive, delete, add product
- Orders: Tab by status, confirm/prepare/ship actions
- Analytics: Sales, commission, earnings, top products
- Add Product: Name, description, price, stock, category, flash sale request

### Rider
- Dashboard: Active deliveries, completed today, earnings, rating + status toggle
- Available Deliveries: Accept orders with pickup/delivery address and fee
- My Deliveries: Update status (Picked Up → In Transit → Delivered)
- Earnings: Today/week/month breakdown + recent history
- Delivery History

---

## Same Credentials as Website
Login uses the same `/api/auth/login` endpoint. Any account created on the website works on the app and vice versa. Role-based routing happens automatically after login.

---

## Android Permissions (add to `android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

## iOS Permissions (add to `ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>Used for uploading delivery proof photos</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used for delivery tracking</string>
```
