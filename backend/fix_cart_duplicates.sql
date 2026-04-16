-- Add unique constraint to cart table to prevent duplicate entries
-- This ensures one cart entry per user/product/size/color combination

ALTER TABLE cart ADD UNIQUE KEY unique_cart_item (user_id, product_id, size, color);
