# Cart Stock Management Implementation

## Overview
This implementation ensures that product stock is decreased immediately when items are added to the cart, and restored when items are removed or quantities are reduced.

## Changes Made

### 1. Add to Cart (POST /api/cart)
**Location:** `backend/app.py` - Line ~9100

**What Changed:**
- When a product is added to cart, the stock is immediately decreased
- Both `product_size_stock.stock_quantity` and `products.total_stock` are updated

**Code Added:**
```python
# Decrease stock when adding to cart
cursor.execute("""
    UPDATE product_size_stock 
    SET stock_quantity = stock_quantity - %s
    WHERE product_id = %s AND size = %s AND color = %s
""", (quantity, product_id, size, color))

# Update total stock in products table
cursor.execute("""
    UPDATE products 
    SET total_stock = (
        SELECT COALESCE(SUM(stock_quantity), 0) 
        FROM product_size_stock 
        WHERE product_id = %s
    )
    WHERE id = %s
""", (product_id, product_id))
```

### 2. Remove from Cart (DELETE /api/cart/<product_id>)
**Location:** `backend/app.py` - Line ~9260

**What Changed:**
- Before removing an item from cart, the stock is restored
- The cart item's quantity is added back to the product stock

**Code Added:**
```python
# Get cart item details first
cursor.execute("""
    SELECT id, quantity, size, color FROM cart 
    WHERE user_id = %s AND product_id = %s AND (size = %s OR (size IS NULL AND %s = ''))
""", (current_user['id'], product_id, size, size))
cart_item = cursor.fetchone()

if cart_item:
    # Restore stock before removing item
    cursor.execute("""
        UPDATE product_size_stock 
        SET stock_quantity = stock_quantity + %s  
        WHERE product_id = %s AND size = %s AND color = %s
    """, (cart_item['quantity'], product_id, cart_item['size'], cart_item['color']))
    
    # Update total stock in products table
    cursor.execute("""
        UPDATE products 
        SET total_stock = (
            SELECT COALESCE(SUM(stock_quantity), 0) 
            FROM product_size_stock 
            WHERE product_id = %s
        )
        WHERE id = %s
    """, (product_id, product_id))
```

### 3. Update Cart Quantity (PUT /api/cart/<product_id>)
**Location:** `backend/app.py` - Line ~9180

**What Changed:**
- When quantity is updated, the stock difference is calculated and adjusted
- If quantity increases: stock decreases by the difference
- If quantity decreases: stock increases by the difference
- If quantity is set to 0 or negative: stock is fully restored and item is removed

**Code Added:**
```python
# Get current cart quantity to calculate difference
cursor.execute("""
    SELECT quantity, size, color FROM cart 
    WHERE user_id = %s AND product_id = %s AND (size = %s OR (size IS NULL AND %s = ''))
""", (current_user['id'], product_id, size, size))
current_cart = cursor.fetchone()

if current_cart:
    qty_diff = quantity - current_cart['quantity']
    
    # Adjust stock based on quantity difference
    if qty_diff != 0:
        cursor.execute("""
            UPDATE product_size_stock 
            SET stock_quantity = stock_quantity - %s
            WHERE product_id = %s AND size = %s AND color = %s
        """, (qty_diff, product_id, current_cart['size'], current_cart['color']))
        
        # Update total stock
        cursor.execute("""
            UPDATE products 
            SET total_stock = (
                SELECT COALESCE(SUM(stock_quantity), 0) 
                FROM product_size_stock 
                WHERE product_id = %s
            )
            WHERE id = %s
        """, (product_id, product_id))
```

## How It Works

### Scenario 1: User adds 2 items to cart
- Product has 10 items in stock
- User adds 2 to cart
- **Result:** Stock becomes 8

### Scenario 2: User increases quantity from 2 to 5
- Current cart quantity: 2
- New quantity: 5
- Difference: +3
- **Result:** Stock decreases by 3 (8 → 5)

### Scenario 3: User decreases quantity from 5 to 3
- Current cart quantity: 5
- New quantity: 3
- Difference: -2
- **Result:** Stock increases by 2 (5 → 7)

### Scenario 4: User removes item from cart
- Cart quantity: 3
- **Result:** Stock increases by 3 (7 → 10)

## Important Notes

1. **Stock is reserved when added to cart** - This prevents overselling
2. **Stock is released when removed from cart** - Makes items available to other users
3. **Both mobile and web apps use the same API** - Changes apply to both platforms
4. **Existing checkout logic remains unchanged** - Stock is already reduced, so no additional reduction at checkout

## Testing Recommendations

1. Test adding items to cart and verify stock decreases
2. Test removing items from cart and verify stock increases
3. Test updating quantities (both increase and decrease)
4. Test with multiple users to ensure no race conditions
5. Verify that checkout doesn't double-reduce stock

## Mobile App Compatibility

The mobile app (Flutter) already uses these API endpoints:
- `POST /api/cart` - Add to cart
- `PUT /api/cart/<id>` - Update quantity
- `DELETE /api/cart/<id>` - Remove from cart

No changes needed in the mobile app code - it will automatically benefit from the backend changes.
