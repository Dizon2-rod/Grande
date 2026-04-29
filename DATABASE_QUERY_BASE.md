# Complete Database Query Base - E-commerce System

## Database Configuration
- **Database**: MySQL/MariaDB
- **Name**: `ecommerce`
- **Connection**: Host `127.0.0.1`, User `root`, No password
- **Engine**: InnoDB
- **Charset**: utf8mb4

## Database Schema & Tables

### 1. Users Table (`users`)
**Purpose**: Core user management for all user types

```sql
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    suffix VARCHAR(50) DEFAULT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('buyer', 'seller', 'rider', 'admin') DEFAULT 'buyer',
    status ENUM('active', 'suspended', 'pending', 'available', 'busy', 'offline') DEFAULT 'active',
    suspension_expires_at DATETIME DEFAULT NULL,
    phone VARCHAR(20) DEFAULT NULL,
    address TEXT DEFAULT NULL,
    gender ENUM('male', 'female', 'other') DEFAULT NULL,
    birthday DATE DEFAULT NULL,
    id_document TEXT DEFAULT NULL,
    google_id VARCHAR(255) UNIQUE NULL,
    login_method ENUM('password', 'google') DEFAULT 'password',
    location_lat DECIMAL(10, 8) DEFAULT NULL,
    location_lng DECIMAL(11, 8) DEFAULT NULL,
    is_active TINYINT(1) DEFAULT 1,
    email_verified TINYINT(1) DEFAULT 0,
    verification_code VARCHAR(6) DEFAULT NULL,
    verification_code_expires_at DATETIME DEFAULT NULL,
    verification_attempts INT DEFAULT 0,
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    profile_picture TEXT DEFAULT NULL,
    id_document_front TEXT DEFAULT NULL,
    id_document_back TEXT DEFAULT NULL
);
```

**Key Queries**:
```sql
-- User Authentication
SELECT id, role, status FROM users WHERE email = %s
SELECT * FROM users WHERE email = %s
SELECT * FROM users WHERE id = %s

-- Profile Management
SELECT profile_picture FROM users WHERE id = %s
SELECT password FROM users WHERE id = %s
UPDATE users SET profile_picture = %s WHERE id = %s

-- Email Verification
SELECT id, status FROM users WHERE email = %s
UPDATE users SET email_verified = 1, verification_code = NULL WHERE id = %s
```

### 2. Applications Table (`applications`)
**Purpose**: Seller and rider applications

```sql
CREATE TABLE applications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT DEFAULT NULL,
    application_type ENUM('seller', 'rider') NOT NULL,
    status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
    business_name VARCHAR(255) DEFAULT NULL,
    business_registration VARCHAR(100) DEFAULT NULL,
    tax_id VARCHAR(50) DEFAULT NULL,
    experience TEXT DEFAULT NULL,
    vehicle_type VARCHAR(50) DEFAULT NULL,
    license_number VARCHAR(50) DEFAULT NULL,
    documents TEXT DEFAULT NULL,
    admin_notes TEXT DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    id_documents_json LONGTEXT DEFAULT NULL,
    business_documents_json LONGTEXT DEFAULT NULL
);
```

### 3. Products Table (`products`)
**Purpose**: Product catalog management

```sql
CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    original_price DECIMAL(10,2) DEFAULT NULL,
    category VARCHAR(100) DEFAULT NULL,
    total_stock INT DEFAULT 0,
    is_active TINYINT(1) DEFAULT 1,
    image_url VARCHAR(500) DEFAULT NULL,
    discount_percentage DECIMAL(5,2) DEFAULT 0.00,
    sizes JSON DEFAULT NULL,
    size_pricing JSON DEFAULT NULL,
    seller_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_flash_sale TINYINT(1) DEFAULT 0,
    flash_sale_start DATETIME NULL,
    flash_sale_end DATETIME NULL,
    flash_sale_status ENUM('none', 'pending', 'approved', 'declined') DEFAULT 'none',
    approval_status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending'
);
```

### 4. Cart Table (`cart`)
**Purpose**: Shopping cart management

```sql
CREATE TABLE cart (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    size VARCHAR(10) DEFAULT NULL,
    color VARCHAR(50) DEFAULT NULL,
    price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

**Key Queries**:
```sql
-- Cart Operations
SELECT * FROM cart WHERE user_id = %s
INSERT INTO cart (user_id, product_id, quantity, size, color, price) VALUES (%s,%s,%s,%s,%s,%s)
UPDATE cart SET quantity = %s WHERE id = %s AND user_id = %s
DELETE FROM cart WHERE id = %s AND user_id = %s
DELETE FROM cart WHERE user_id = %s
```

### 5. Orders Table (`orders`)
**Purpose**: Order management

```sql
CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_number VARCHAR(50) NOT NULL UNIQUE,
    buyer_id INT DEFAULT NULL,
    seller_id INT NOT NULL,
    rider_id INT DEFAULT NULL,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(100) DEFAULT 'Philippines',
    total_amount DECIMAL(10,2) NOT NULL,
    size_color_stock VARCHAR(255) DEFAULT NULL,
    payment_method VARCHAR(50) DEFAULT 'GCASH',
    payment_provider VARCHAR(50) DEFAULT 'xendit',
    payment_provider_id VARCHAR(255) DEFAULT NULL,
    status ENUM('pending', 'confirmed', 'prepared', 'shipped', 'delivered', 'cancelled', 'accepted_by_rider') DEFAULT 'pending',
    payment_status ENUM('pending', 'paid', 'failed', 'refunded') DEFAULT 'pending',
    tracking_number VARCHAR(100) DEFAULT NULL,
    special_notes TEXT DEFAULT NULL,
    cancel_reason TEXT DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

**Key Queries**:
```sql
-- Order Management
SELECT * FROM orders WHERE buyer_id = %s ORDER BY created_at DESC
SELECT * FROM orders WHERE seller_id = %s ORDER BY created_at DESC
UPDATE orders SET status = %s WHERE id = %s
INSERT INTO orders (order_number, buyer_id, seller_id, full_name, email, address, city, postal_code, total_amount) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
```

### 6. Order Items Table (`order_items`)
**Purpose**: Individual items within orders

```sql
CREATE TABLE order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    size VARCHAR(10) DEFAULT NULL,
    color VARCHAR(50) DEFAULT NULL
);
```

### 7. Deliveries Table (`deliveries`)
**Purpose**: Delivery management

```sql
CREATE TABLE deliveries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT DEFAULT NULL UNIQUE,
    rider_id INT DEFAULT NULL,
    delivery_address TEXT DEFAULT NULL,
    delivery_fee DECIMAL(10,2) DEFAULT 0.00,
    base_fee DECIMAL(10,2) DEFAULT 50.00,
    distance_bonus DECIMAL(10,2) DEFAULT 0.00,
    tips DECIMAL(10,2) DEFAULT 0.00,
    peak_bonus DECIMAL(10,2) DEFAULT 0.00,
    estimated_time VARCHAR(50) DEFAULT NULL,
    actual_time INT DEFAULT 0,
    distance DECIMAL(10,2) DEFAULT 0.00,
    pickup_address TEXT DEFAULT NULL,
    pickup_time TIMESTAMP NULL DEFAULT NULL,
    delivery_time TIMESTAMP NULL DEFAULT NULL,
    rating DECIMAL(3,2) DEFAULT 0.00,
    customer_rating DECIMAL(3,2) DEFAULT 0.00,
    customer_feedback TEXT DEFAULT NULL,
    delivery_type ENUM('standard', 'express', 'same_day', 'scheduled') DEFAULT 'standard',
    priority ENUM('low', 'normal', 'high', 'urgent') DEFAULT 'normal',
    status ENUM('pending', 'assigned', 'picked_up', 'in_transit', 'delivered', 'cancelled') DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_at TIMESTAMP NULL DEFAULT NULL,
    completed_at TIMESTAMP NULL DEFAULT NULL
);
```

### 8. Product Size Stock Table (`product_size_stock`)
**Purpose**: Product variant inventory management

```sql
CREATE TABLE product_size_stock (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    size VARCHAR(10) DEFAULT NULL,
    color VARCHAR(50) DEFAULT NULL,
    color_name VARCHAR(100) DEFAULT NULL,
    stock_quantity INT DEFAULT 0,
    price DECIMAL(10,2) DEFAULT NULL,
    discount_price DECIMAL(10,2) DEFAULT NULL,
    image_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 9. Chat Conversations Table (`chat_conversations`)
**Purpose**: Chat session management

```sql
CREATE TABLE chat_conversations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT DEFAULT NULL,
    order_number VARCHAR(50) DEFAULT NULL,
    seller_id INT NOT NULL,
    buyer_id INT NOT NULL,
    participant_name VARCHAR(255) NOT NULL,
    status ENUM('active', 'closed', 'archived') DEFAULT 'active',
    last_message_time TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 10. Chat Messages Table (`chat_messages`)
**Purpose**: Individual chat messages

```sql
CREATE TABLE chat_messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    conversation_id INT NOT NULL,
    sender_id INT NOT NULL,
    sender_type ENUM('seller', 'buyer', 'rider') NOT NULL,
    content TEXT NOT NULL,
    message_type ENUM('text', 'image', 'file', 'system') DEFAULT 'text',
    file_url VARCHAR(500) DEFAULT NULL,
    is_read TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### 11. Notifications Table (`notifications`)
**Purpose**: User notifications

```sql
CREATE TABLE notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    image_url VARCHAR(255) DEFAULT NULL,
    reference_id INT DEFAULT NULL,
    is_read TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 12. Product Reviews Table (`product_reviews`)
**Purpose**: Product rating and review system

```sql
CREATE TABLE product_reviews (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    order_id INT NOT NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 13. User Addresses Table (`user_addresses`)
**Purpose**: User delivery addresses

```sql
CREATE TABLE user_addresses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    label VARCHAR(50) DEFAULT NULL,
    contact_name VARCHAR(255) DEFAULT NULL,
    contact_phone VARCHAR(50) DEFAULT NULL,
    region_code VARCHAR(20) DEFAULT NULL,
    region VARCHAR(255) DEFAULT NULL,
    province_code VARCHAR(20) DEFAULT NULL,
    province VARCHAR(255) DEFAULT NULL,
    city_code VARCHAR(20) DEFAULT NULL,
    city VARCHAR(255) DEFAULT NULL,
    barangay_code VARCHAR(20) DEFAULT NULL,
    barangay VARCHAR(255) DEFAULT NULL,
    street TEXT DEFAULT NULL,
    postal_code VARCHAR(20) DEFAULT NULL,
    latitude DECIMAL(10,8) DEFAULT NULL,
    longitude DECIMAL(11,8) DEFAULT NULL,
    is_default TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 14. Wishlist Table (`wishlist`)
**Purpose**: User wishlist management

```sql
CREATE TABLE wishlist (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### 15. Additional Tables
- `delivery_proof`: Delivery confirmation photos and signatures
- `delivery_ratings`: Rider performance ratings
- `order_status_history`: Order status change tracking
- `password_reset_tokens`: Password reset functionality
- `product_review_media`: Review images/videos
- `product_variant_images`: Product variant images
- `refund_requests`: Order refund management
- `rider_payments`: Rider payment tracking
- `stock_alerts`: Low stock notifications
- `price_drop_alerts`: Price drop notifications
- `user_enforcement_actions`: User suspension/warning tracking

## Common Query Patterns

### Authentication Queries
```sql
-- Login
SELECT id, name, email, role, status FROM users WHERE email = %s AND password = %s

-- Google OAuth
SELECT id, name, email, role FROM users WHERE google_id = %s
INSERT INTO users (name, email, google_id, login_method, email_verified) VALUES (%s,%s,%s,'google',1)

-- Email Verification
UPDATE users SET email_verified = 1, verification_code = NULL WHERE id = %s
```

### Product Queries
```sql
-- Get Products
SELECT p.*, u.name as seller_name FROM products p JOIN users u ON p.seller_id = u.id WHERE p.is_active = 1

-- Product Search
SELECT * FROM products WHERE name LIKE %s OR category LIKE %s

-- Stock Management
SELECT * FROM product_size_stock WHERE product_id = %s AND size = %s AND color = %s
UPDATE product_size_stock SET stock_quantity = stock_quantity - %s WHERE product_id = %s AND size = %s AND color = %s
```

### Order Queries
```sql
-- Create Order
INSERT INTO orders (order_number, buyer_id, seller_id, full_name, email, address, city, postal_code, total_amount) 
VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)

-- Order Status Updates
UPDATE orders SET status = %s WHERE id = %s
INSERT INTO order_status_history (order_id, status) VALUES (%s, %s)

-- Order History
SELECT o.*, oi.product_name, oi.quantity, oi.price 
FROM orders o 
LEFT JOIN order_items oi ON o.id = oi.order_id 
WHERE o.buyer_id = %s 
ORDER BY o.created_at DESC
```

### Cart Queries
```sql
-- Get Cart Items
SELECT c.*, p.name, p.image_url FROM cart c 
JOIN products p ON c.product_id = p.id 
WHERE c.user_id = %s

-- Add to Cart
INSERT INTO cart (user_id, product_id, quantity, size, color, price) 
VALUES (%s,%s,%s,%s,%s,%s)

-- Update Cart Quantity
UPDATE cart SET quantity = %s WHERE id = %s AND user_id = %s

-- Remove from Cart
DELETE FROM cart WHERE id = %s AND user_id = %s
```

### Chat Queries
```sql
-- Get Conversations
SELECT * FROM chat_conversations 
WHERE (seller_id = %s OR buyer_id = %s) 
ORDER BY last_message_time DESC

-- Get Messages
SELECT * FROM chat_messages 
WHERE conversation_id = %s 
ORDER BY created_at ASC

-- Send Message
INSERT INTO chat_messages (conversation_id, sender_id, sender_type, content) 
VALUES (%s,%s,%s,%s)
```

### Notification Queries
```sql
-- Get User Notifications
SELECT * FROM notifications 
WHERE user_id = %s 
ORDER BY created_at DESC

-- Mark as Read
UPDATE notifications SET is_read = 1 WHERE id = %s AND user_id = %s

-- Create Notification
INSERT INTO notifications (user_id, type, message, reference_id) 
VALUES (%s,%s,%s,%s)
```

## Database Indexes
- Primary keys on all `id` columns
- Foreign key indexes on `user_id`, `product_id`, `order_id`, etc.
- Composite indexes for frequently queried combinations
- Unique constraints on emails, order numbers, and other unique identifiers

## Connection Function
```python
def get_db_connection():
    try:
        connection = mysql.connect(
            host="127.0.0.1",
            user="root",
            password="",
            database="ecommerce"
        )
        return connection
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None
```

This database query base provides a comprehensive foundation for the e-commerce system with all essential tables, relationships, and common query patterns for user management, product catalog, shopping cart, order processing, delivery tracking, and communication features.
