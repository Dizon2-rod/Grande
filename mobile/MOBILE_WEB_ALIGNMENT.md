# Mobile-Web App Alignment Checklist

## Buyer Pages to Align

### 1. Landing Page (index.html → home_screen.dart)
- ✅ Promo Carousel with gradient (FFFEE3 to FFC6BF)
- ✅ Flash Sales section with countdown
- ✅ New Arrivals grid
- ✅ Featured Categories with descriptions
- ✅ Three-dot menu on product cards (landing page only)

### 2. Shop/Market Page (market.html → market_screen.dart)
- ✅ Sidebar filters (Categories, Price Range, Size, Rating)
- ✅ Enhanced filter UI with icons and better styling
- ✅ Grid/List view toggle
- ✅ Sort options (Relevance, Price, Rating, Newest, Best Sellers)
- ✅ Product cards with Add to Cart and Wishlist buttons
- ⚠️ Breadcrumb navigation (MISSING)
- ⚠️ Active filter chips display (NEEDS IMPROVEMENT)
- ⚠️ Pagination controls (EXISTS but needs styling)

### 3. Product Detail Page (product.html → product_detail_screen.dart)
- ⚠️ NEEDS REVIEW - Check if matches web app

### 4. Cart Page (cart.html → cart_screen.dart)
- ⚠️ NEEDS REVIEW - Check if matches web app

### 5. Wishlist Page (wishlist.html → buyer_extra_screens.dart)
- ⚠️ NEEDS REVIEW - Check if matches web app

### 6. Profile Pages (UserProfile/* → buyer_extra_screens.dart)
- ✅ Profile screen redesigned to match web app
- ⚠️ My Orders - NEEDS REVIEW
- ⚠️ Addresses - NEEDS REVIEW
- ⚠️ Account Settings - NEEDS REVIEW

### 7. Checkout Flow
- ⚠️ NEEDS REVIEW - Check if exists and matches web app

## Key UI Elements to Align

### Colors & Gradients
- ✅ Brand Gradient: #FF2BAC → #FF6BCE → #FF9ED6
- ✅ Promo Gradient: #FFFEE3 → #FFC6BF
- ✅ Primary Dark: #1B0E24, #2D1B3D

### Typography
- ✅ Headers: Playfair Display (web) / Default bold (mobile)
- ✅ Body: Inter (web) / Default (mobile)
- ✅ Font sizes aligned

### Components
- ✅ ProductCard with conditional actions
- ✅ Filter modal with icons and sections
- ✅ Status badges
- ✅ Section headers with badges
- ⚠️ Breadcrumbs - MISSING
- ⚠️ Pagination - EXISTS but needs styling

## Action Items

1. Add breadcrumb navigation to market screen
2. Improve active filter chips display
3. Style pagination to match web app
4. Review and align product detail page
5. Review and align cart page
6. Review and align checkout flow
7. Ensure all buyer screens match web app pixel-perfect
