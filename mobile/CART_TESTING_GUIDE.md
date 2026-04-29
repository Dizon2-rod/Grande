# Cart Testing Guide - Web & Mobile

## ✅ What Was Fixed

### Issues:
1. **Duplicate Cart Entries** - Users could have multiple entries for same product/size/color
2. **Add/Minus Buttons Not Working** - Quantity controls didn't update in mobile app

### Solutions:
1. Added database unique constraint on `(user_id, product_id, size, color)`
2. Aligned mobile app to match web app's approach (use `product_id` + `size` + `color`)

---

## 🔧 Current Implementation

### Backend (`/api/cart/<int:product_id>`)
- **PUT Method**: Updates quantity by matching `user_id` + `product_id` + `size` + `color`
- **DELETE Method**: Removes item by matching `user_id` + `product_id` + `size` + `color`
- **Stock Management**: Automatically adjusts stock when quantity changes

### Web App (`cart.html`)
- Sends: `product_id`, `size`, `color`, `quantity`
- Functions: `updateQuantity(productId, size, color, qty)`, `removeItem(productId, size, color)`

### Mobile App (`cart_screen.dart`)
- Sends: `product_id`, `size`, `color`, `quantity`
- Functions: `_updateQty(productId, qty, size, color)`, `_remove(productId, size, color)`

---

## 🧪 Testing Checklist

### Web App Testing

#### 1. Add Items to Cart
- [ ] Go to market page
- [ ] Add a product with specific size/color
- [ ] Verify item appears in cart
- [ ] Try adding same product/size/color again
- [ ] **Expected**: Quantity increases, no duplicate entry

#### 2. Update Quantity (Web)
- [ ] Click minus (-) button
- [ ] **Expected**: Quantity decreases by 1
- [ ] Click plus (+) button
- [ ] **Expected**: Quantity increases by 1
- [ ] Type a number directly in quantity input
- [ ] **Expected**: Quantity updates to typed value
- [ ] Try to set quantity to 0
- [ ] **Expected**: Item is removed from cart

#### 3. Remove Items (Web)
- [ ] Click trash icon on cart item
- [ ] Confirm removal in dialog
- [ ] **Expected**: Item removed, cart updates

#### 4. Multiple Items (Web)
- [ ] Add multiple different products
- [ ] Add same product with different sizes
- [ ] Add same product with different colors
- [ ] **Expected**: Each unique combination appears as separate item
- [ ] Update quantities on different items
- [ ] **Expected**: Only selected item updates

#### 5. Checkout (Web)
- [ ] Select items using checkboxes
- [ ] Click "Proceed to Checkout"
- [ ] **Expected**: Only selected items go to checkout

---

### Mobile App Testing

#### 1. Add Items to Cart (Mobile)
- [ ] Open mobile app
- [ ] Navigate to product detail
- [ ] Select size and color
- [ ] Add to cart
- [ ] **Expected**: Success message, cart count updates

#### 2. View Cart (Mobile)
- [ ] Open cart screen
- [ ] **Expected**: All cart items display correctly
- [ ] Verify product images load
- [ ] Verify size/color badges show correctly

#### 3. Update Quantity (Mobile)
- [ ] Tap minus (-) button
- [ ] **Expected**: Quantity decreases, UI updates immediately
- [ ] Tap plus (+) button
- [ ] **Expected**: Quantity increases, UI updates immediately
- [ ] Try decreasing to 0
- [ ] **Expected**: Item remains (minimum quantity is 1)

#### 4. Remove Items (Mobile)
- [ ] Tap delete icon
- [ ] Confirm removal
- [ ] **Expected**: Item removed, cart refreshes

#### 5. Select Items (Mobile)
- [ ] Tap checkboxes to select/deselect items
- [ ] **Expected**: Total updates based on selected items
- [ ] Tap "Select All"
- [ ] **Expected**: All items selected
- [ ] Proceed to checkout with selected items
- [ ] **Expected**: Only selected items in checkout

---

## 🐛 Common Issues & Solutions

### Issue: "Cart item not found" error
**Cause**: Size or color parameter missing or incorrect
**Solution**: Ensure size and color are always sent with requests

### Issue: Duplicate cart entries
**Cause**: Unique constraint not applied
**Solution**: Run migration SQL:
```sql
ALTER TABLE cart ADD UNIQUE KEY unique_cart_item (user_id, product_id, size, color);
```

### Issue: Stock not updating
**Cause**: Stock management logic not executing
**Solution**: Check backend logs for errors in stock update queries

### Issue: Quantity doesn't update in UI
**Cause**: Frontend not refreshing after API call
**Solution**: Ensure `_load()` or `loadCartFromServer()` is called after update

---

## 📊 Database Verification

### Check for Duplicates
```sql
SELECT user_id, product_id, size, color, COUNT(*) as count
FROM cart
GROUP BY user_id, product_id, size, color
HAVING count > 1;
```
**Expected**: No results (no duplicates)

### Check Unique Constraint
```sql
SHOW CREATE TABLE cart;
```
**Expected**: Should see `UNIQUE KEY unique_cart_item (user_id, product_id, size, color)`

### View Cart Contents
```sql
SELECT c.*, p.name, u.email
FROM cart c
JOIN products p ON c.product_id = p.id
JOIN users u ON c.user_id = u.id
ORDER BY c.created_at DESC;
```

---

## 🔍 API Testing (Postman/cURL)

### Update Quantity
```bash
curl -X PUT http://localhost:5000/api/cart/123 \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"quantity": 3, "size": "M", "color": "red"}'
```

### Remove Item
```bash
curl -X DELETE http://localhost:5000/api/cart/123 \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"size": "M", "color": "red"}'
```

### Get Cart
```bash
curl -X GET http://localhost:5000/api/cart \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## ✨ Expected Behavior Summary

### Web App
✅ Uses `product_id` + `size` + `color` to identify items
✅ Quantity controls work smoothly
✅ No duplicate entries
✅ Stock updates automatically
✅ Checkbox selection for checkout

### Mobile App
✅ Uses `product_id` + `size` + `color` to identify items
✅ Quantity controls work smoothly
✅ No duplicate entries
✅ Stock updates automatically
✅ Checkbox selection for checkout
✅ Pull to refresh works

### Backend
✅ Matches items by `product_id` + `size` + `color`
✅ Prevents duplicates via unique constraint
✅ Manages stock automatically
✅ Returns proper error messages
✅ Validates stock availability

---

## 🚀 Ready to Test!

1. Start backend: `python backend/app.py`
2. Open web app: `http://localhost:5000/Public/cart.html`
3. Run mobile app: `flutter run` in mobile directory
4. Follow testing checklist above
5. Report any issues found

---

## 📝 Notes

- Both web and mobile apps now work identically
- Database constraint prevents duplicate entries
- Stock is managed automatically on all cart operations
- All cart operations require authentication
- Size and color are required parameters for all operations
