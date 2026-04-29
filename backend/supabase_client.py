from supabase import create_client, Client
from dotenv import load_dotenv
import os
import json
from typing import Dict, Any, Optional, List

# Load environment variables
env_path = os.path.join(os.path.dirname(__file__), '..', '.env')
if os.path.isfile(env_path):
    load_dotenv(env_path)

class SupabaseClient:
    def __init__(self):
        self.supabase_url = os.getenv('SUPABASE_URL')
        self.supabase_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
        
        if not self.supabase_url or not self.supabase_key:
            raise ValueError("Supabase URL and Service Role Key must be set in environment variables")
        
        self.client: Client = create_client(self.supabase_url, self.supabase_key)
    
    def get_client(self) -> Client:
        """Get the Supabase client instance"""
        return self.client
    
    # User Management
    async def get_user_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """Get user by email"""
        try:
            response = self.client.table('users').select('*').eq('email', email).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error getting user by email: {e}")
            return None
    
    async def get_user_by_id(self, user_id: int) -> Optional[Dict[str, Any]]:
        """Get user by ID"""
        try:
            response = self.client.table('users').select('*').eq('id', user_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error getting user by ID: {e}")
            return None
    
    async def create_user(self, user_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create new user"""
        try:
            response = self.client.table('users').insert(user_data).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error creating user: {e}")
            return None
    
    async def update_user(self, user_id: int, user_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Update user"""
        try:
            response = self.client.table('users').update(user_data).eq('id', user_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error updating user: {e}")
            return None
    
    # Product Management
    async def get_products(self, filters: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """Get products with optional filters"""
        try:
            query = self.client.table('products').select('*')
            
            if filters:
                if 'is_active' in filters:
                    query = query.eq('is_active', filters['is_active'])
                if 'seller_id' in filters:
                    query = query.eq('seller_id', filters['seller_id'])
                if 'category' in filters:
                    query = query.eq('category', filters['category'])
            
            response = query.execute()
            return response.data or []
        except Exception as e:
            print(f"Error getting products: {e}")
            return []
    
    async def get_product_by_id(self, product_id: int) -> Optional[Dict[str, Any]]:
        """Get product by ID"""
        try:
            response = self.client.table('products').select('*').eq('id', product_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error getting product by ID: {e}")
            return None
    
    async def create_product(self, product_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create new product"""
        try:
            response = self.client.table('products').insert(product_data).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error creating product: {e}")
            return None
    
    async def update_product(self, product_id: int, product_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Update product"""
        try:
            response = self.client.table('products').update(product_data).eq('id', product_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error updating product: {e}")
            return None
    
    # Cart Management
    async def get_cart_items(self, user_id: int) -> List[Dict[str, Any]]:
        """Get cart items for user"""
        try:
            response = self.client.table('cart').select('*').eq('user_id', user_id).execute()
            return response.data or []
        except Exception as e:
            print(f"Error getting cart items: {e}")
            return []
    
    async def add_to_cart(self, cart_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Add item to cart"""
        try:
            response = self.client.table('cart').insert(cart_data).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error adding to cart: {e}")
            return None
    
    async def update_cart_item(self, cart_id: int, user_id: int, cart_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Update cart item"""
        try:
            response = self.client.table('cart').update(cart_data).eq('id', cart_id).eq('user_id', user_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error updating cart item: {e}")
            return None
    
    async def remove_cart_item(self, cart_id: int, user_id: int) -> bool:
        """Remove item from cart"""
        try:
            response = self.client.table('cart').delete().eq('id', cart_id).eq('user_id', user_id).execute()
            return len(response.data) > 0 if response.data else False
        except Exception as e:
            print(f"Error removing cart item: {e}")
            return False
    
    async def clear_cart(self, user_id: int) -> bool:
        """Clear all cart items for user"""
        try:
            response = self.client.table('cart').delete().eq('user_id', user_id).execute()
            return True
        except Exception as e:
            print(f"Error clearing cart: {e}")
            return False
    
    # Order Management
    async def create_order(self, order_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create new order"""
        try:
            response = self.client.table('orders').insert(order_data).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error creating order: {e}")
            return None
    
    async def get_orders_by_buyer(self, buyer_id: int) -> List[Dict[str, Any]]:
        """Get orders for buyer"""
        try:
            response = self.client.table('orders').select('*').eq('buyer_id', buyer_id).order('created_at', desc=True).execute()
            return response.data or []
        except Exception as e:
            print(f"Error getting buyer orders: {e}")
            return []
    
    async def get_orders_by_seller(self, seller_id: int) -> List[Dict[str, Any]]:
        """Get orders for seller"""
        try:
            response = self.client.table('orders').select('*').eq('seller_id', seller_id).order('created_at', desc=True).execute()
            return response.data or []
        except Exception as e:
            print(f"Error getting seller orders: {e}")
            return []
    
    async def update_order_status(self, order_id: int, status: str) -> Optional[Dict[str, Any]]:
        """Update order status"""
        try:
            response = self.client.table('orders').update({'status': status}).eq('id', order_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error updating order status: {e}")
            return None
    
    # Order Items
    async def create_order_items(self, order_items_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Create order items"""
        try:
            response = self.client.table('order_items').insert(order_items_data).execute()
            return response.data or []
        except Exception as e:
            print(f"Error creating order items: {e}")
            return []
    
    async def get_order_items(self, order_id: int) -> List[Dict[str, Any]]:
        """Get order items"""
        try:
            response = self.client.table('order_items').select('*').eq('order_id', order_id).execute()
            return response.data or []
        except Exception as e:
            print(f"Error getting order items: {e}")
            return []
    
    # Product Stock Management
    async def get_product_stock(self, product_id: int, size: str = None, color: str = None) -> List[Dict[str, Any]]:
        """Get product stock"""
        try:
            query = self.client.table('product_size_stock').select('*').eq('product_id', product_id)
            
            if size:
                query = query.eq('size', size)
            if color:
                query = query.eq('color', color)
            
            response = query.execute()
            return response.data or []
        except Exception as e:
            print(f"Error getting product stock: {e}")
            return []
    
    async def update_product_stock(self, stock_id: int, stock_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Update product stock"""
        try:
            response = self.client.table('product_size_stock').update(stock_data).eq('id', stock_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error updating product stock: {e}")
            return None
    
    # Chat Management
    async def get_conversations(self, user_id: int, user_type: str = None) -> List[Dict[str, Any]]:
        """Get conversations for user"""
        try:
            if user_type == 'seller':
                response = self.client.table('chat_conversations').select('*').eq('seller_id', user_id).order('last_message_time', desc=True).execute()
            else:
                response = self.client.table('chat_conversations').select('*').eq('buyer_id', user_id).order('last_message_time', desc=True).execute()
            
            return response.data or []
        except Exception as e:
            print(f"Error getting conversations: {e}")
            return []
    
    async def get_messages(self, conversation_id: int) -> List[Dict[str, Any]]:
        """Get messages for conversation"""
        try:
            response = self.client.table('chat_messages').select('*').eq('conversation_id', conversation_id).order('created_at', asc=True).execute()
            return response.data or []
        except Exception as e:
            print(f"Error getting messages: {e}")
            return []
    
    async def send_message(self, message_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Send message"""
        try:
            response = self.client.table('chat_messages').insert(message_data).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error sending message: {e}")
            return None
    
    # Notifications
    async def get_notifications(self, user_id: int) -> List[Dict[str, Any]]:
        """Get notifications for user"""
        try:
            response = self.client.table('notifications').select('*').eq('user_id', user_id).order('created_at', desc=True).execute()
            return response.data or []
        except Exception as e:
            print(f"Error getting notifications: {e}")
            return []
    
    async def create_notification(self, notification_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create notification"""
        try:
            response = self.client.table('notifications').insert(notification_data).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error creating notification: {e}")
            return None
    
    async def mark_notification_read(self, notification_id: int, user_id: int) -> bool:
        """Mark notification as read"""
        try:
            response = self.client.table('notifications').update({'is_read': True}).eq('id', notification_id).eq('user_id', user_id).execute()
            return len(response.data) > 0 if response.data else False
        except Exception as e:
            print(f"Error marking notification as read: {e}")
            return False
    
    # Applications
    async def create_application(self, application_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create application"""
        try:
            response = self.client.table('applications').insert(application_data).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"Error creating application: {e}")
            return None
    
    async def get_applications(self, filters: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """Get applications with filters"""
        try:
            query = self.client.table('applications').select('*')
            
            if filters:
                if 'user_id' in filters:
                    query = query.eq('user_id', filters['user_id'])
                if 'application_type' in filters:
                    query = query.eq('application_type', filters['application_type'])
                if 'status' in filters:
                    query = query.eq('status', filters['status'])
            
            response = query.execute()
            return response.data or []
        except Exception as e:
            print(f"Error getting applications: {e}")
            return []

# Global instance
supabase_client = SupabaseClient()
