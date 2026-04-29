# Supabase Setup Guide for E-commerce System

## Overview
This guide walks you through setting up Supabase for your e-commerce system, replacing the existing MySQL database.

## Files Created/Modified

### Backend Changes
1. **`backend/requirements.txt`** - Added Supabase Python client
2. **`backend/supabase_client.py`** - Supabase client wrapper with all database operations
3. **`backend/app_supabase.py`** - New Flask app using Supabase instead of MySQL

### Mobile Changes
1. **`mobile/pubspec.yaml`** - Added Supabase Flutter SDK
2. **`mobile/lib/core/supabase/supabase_client.dart`** - Supabase client wrapper
3. **`mobile/lib/core/supabase/supabase_service.dart`** - Service classes for auth, products, cart, orders
4. **`mobile/lib/main.dart`** - Updated to initialize Supabase

## Database Schema
The Supabase schema matches your existing MySQL structure with these key tables:
- `users` - User management
- `products` - Product catalog
- `cart` - Shopping cart
- `orders` & `order_items` - Order management
- `applications` - Seller/rider applications
- `notifications` - User notifications
- `chat_conversations` & `chat_messages` - Chat system
- And all other supporting tables

## Setup Steps

### 1. Apply Schema to Supabase
1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Run the schema SQL provided in your query
4. This will create all necessary tables with proper relationships

### 2. Backend Setup
```bash
cd backend
pip install -r requirements.txt
```

### 3. Mobile Setup
```bash
cd mobile
flutter pub get
```

### 4. Environment Variables
Ensure your `.env` file has:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

## Migration from MySQL to Supabase

### Option 1: Use the New Supabase Backend
1. Replace `app.py` with `app_supabase.py`
2. Update your server startup script to use the new file
3. All API endpoints remain the same, just the database backend changes

### Option 2: Gradual Migration
1. Keep `app.py` for MySQL operations
2. Use `app_supabase.py` for testing
3. Gradually migrate endpoints one by one

## API Endpoints (Unchanged)
All existing API endpoints work the same way:
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `GET /api/products` - Get products
- `GET /api/cart` - Get cart items
- `POST /api/orders` - Create order
- And all other existing endpoints

## Mobile App Integration

### Authentication
```dart
import 'package:grande_mobile/core/supabase/supabase_service.dart';

// Register
final authService = SupabaseAuthService();
final result = await authService.register(
  name: 'John Doe',
  email: 'john@example.com',
  password: 'password123',
);

// Login
final result = await authService.login(
  email: 'john@example.com',
  password: 'password123',
);
```

### Products
```dart
final productService = SupabaseProductService();
final products = await productService.getProducts(isActive: true);
```

### Cart
```dart
final cartService = SupabaseCartService();
final cartItems = await cartService.getCartItems(userId);
```

## Key Differences from MySQL

### Backend
- **Async Operations**: All database operations are now async
- **No SQL Queries**: Uses Supabase client methods instead of raw SQL
- **Better Type Safety**: TypeScript-like data structures

### Mobile
- **Direct Database Access**: Can optionally bypass REST API for some operations
- **Real-time Updates**: Supabase supports real-time subscriptions
- **Built-in Auth**: Leverages Supabase Authentication

## Testing the Setup

### Backend Testing
```bash
cd backend
python app_supabase.py
```

### Mobile Testing
```bash
cd mobile
flutter run
```

## Data Migration (If needed)

To migrate existing data from MySQL to Supabase:
1. Export MySQL data to CSV/JSON
2. Use Supabase's import functionality
3. Or write a migration script using the Supabase client

## Benefits of Supabase

1. **Real-time**: Automatic real-time updates
2. **Authentication**: Built-in auth system
3. **File Storage**: Easy file uploads
4. **Edge Functions**: Serverless functions
5. **Dashboard**: Visual database management
6. **Security**: Row Level Security (RLS)

## Troubleshooting

### Common Issues
1. **Connection Errors**: Check Supabase URL and keys in `.env`
2. **CORS Issues**: Configure CORS in Supabase settings
3. **Permission Errors**: Check RLS policies in Supabase
4. **Schema Mismatches**: Ensure schema matches exactly

### Debug Mode
Enable debug logging by setting:
```python
# In backend
import logging
logging.basicConfig(level=logging.DEBUG)
```

## Next Steps

1. **Test All Features**: Ensure all CRUD operations work
2. **Implement RLS**: Add Row Level Security policies
3. **Set Up Real-time**: Enable real-time subscriptions for chat/notifications
4. **File Storage**: Migrate file uploads to Supabase Storage
5. **Edge Functions**: Move some logic to Supabase Edge Functions

## Support

- Supabase Documentation: https://supabase.com/docs
- Flutter SDK: https://supabase.com/docs/reference/dart
- Python Client: https://supabase.com/docs/reference/python
