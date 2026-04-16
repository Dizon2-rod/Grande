# Cart Fixes Summary

## Issues Fixed

### 1. Duplicate Cart Entries (Two Carts Issue)
**Problem**: Users could have multiple cart entries for the same product/size/color combination, causing duplicate items to appear in the cart.

**Root Cause**: The cart table lacked a unique constraint on (user_id, product_id, size, color).

**Solution**: 
- Created SQL migration file `fix_cart_duplicates.sql` to add unique constraint
- Run this SQL to fix: `ALTER TABLE cart ADD UNIQUE KEY unique_cart_item (user_id, product_id, size, color);`

### 2. Add/Minus Quantity Not Working
**Problem**: The +/- buttons in the mobile app cart screen didn't update quantities.

**Root Cause**: 
- Backend endpoint used `/api/cart/<int:product_id>` but mobile app was sending cart item `id`
- Backend was matching by `product_id + size` instead of cart `id`
- This caused the backend to not find the cart item to update

**Solution**:
- Changed route from `/api/cart/<int:product_id>` to `/api/cart/<int:cart_id>`
- Updated function parameter from `product_id` to `cart_id`
- Modified logic to:
  1. Fetch cart item by `cart_id` and verify ownership
  2. Extract product_id, size, color from the fetched cart item
  3. Use cart `id` for all UPDATE/DELETE operations
  4. Properly track stock changes based on quantity difference

## Files Modified

### Backend
- `backend/app.py` - Fixed the `/api/cart/<int:cart_id>` endpoint (PUT and DELETE methods)

### Database Migration
- `backend/fix_cart_duplicates.sql` - SQL to add unique constraint

## How to Apply Fixes

### Step 1: Apply Database Migration
```bash
cd backend
mysql -u root -p ecommerce < fix_cart_duplicates.sql
```

Or run directly in MySQL:
```sql
ALTER TABLE cart ADD UNIQUE KEY unique_cart_item (user_id, product_id, size, color);
```

### Step 2: Restart Backend Server
```bash
cd backend
python app.py
```

### Step 3: Test Mobile App
1. Add items to cart
2. Try increasing/decreasing quantities using +/- buttons
3. Verify no duplicate cart entries appear
4. Test removing items from cart

## Technical Details

### Before Fix
```python
@app.route('/api/cart/<int:product_id>', methods=['PUT', 'DELETE'])
def manage_cart_item(current_user, product_id):
    # Matched by: user_id + product_id + size
    # Problem: Mobile app sends cart.id, not product_id
```

### After Fix
```python
@app.route('/api/cart/<int:cart_id>', methods=['PUT', 'DELETE'])
def manage_cart_item(current_user, cart_id):
    # Fetch cart item by cart_id
    # Extract product_id, size, color from cart item
    # Update using cart.id directly
```

## Mobile App Compatibility
The mobile app (`cart_screen.dart`) already sends the correct cart `id`:
```dart
_updateQty(item['id'], item['quantity'] + 1, size, color)
```

No mobile app changes needed - the fix is backend-only.
