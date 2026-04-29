from flask import Flask, request, jsonify, send_from_directory, render_template, session, redirect, url_for
from dotenv import load_dotenv
import os, json, uuid, jwt, time, smtplib, ssl, secrets
from flask_cors import CORS
import requests
from datetime import datetime, timedelta, timezone
from werkzeug.utils import secure_filename
from functools import wraps
import random
from xendit_service import XenditService
from email.mime.text import  MIMEText
from email.mime.multipart import MIMEMultipart
from supabase_client import supabase_client
import asyncio

app = Flask(__name__, 
    static_folder='../static',
    static_url_path='/static',
    template_folder='../templates'
)

env_path = os.path.join(os.path.dirname(__file__), '..', '.env')
if os.path.isfile(env_path):
    load_dotenv(env_path)

app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', "your-secret-key")
CORS(app)

XENDIT_SECRET_KEY = os.getenv("XENDIT_SECRET_KEY")
XENDIT_PUBLIC_KEY = os.getenv("XENDIT_PUBLIC_KEY")
XENDIT_WEBHOOK_TOKEN = os.getenv("XENDIT_WEBHOOK_TOKEN")
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")
SMTP_SERVER = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
SMTP_PORT = int(os.getenv('SMTP_PORT', 587))
EMAIL_ADDRESS = os.getenv('EMAIL_ADDRESS')
EMAIL_PASSWORD = os.getenv('EMAIL_PASSWORD')
EMAIL_USE_TLS = os.getenv('EMAIL_USE_TLS', 'True').lower() == 'true'

# Default admin seeding config (DEV)
ADMIN_EMAIL = os.getenv('ADMIN_EMAIL', 'admin@example.com').strip().lower()
ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD', 'admin123')
ADMIN_NAME = os.getenv('ADMIN_NAME', 'Admin')

xendit = XenditService(
    secret_key=XENDIT_SECRET_KEY,
    public_key=XENDIT_PUBLIC_KEY
)

UPLOAD_FOLDER = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'static', 'uploads', 'products'))
DELIVERY_PROOF_FOLDER = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'static', 'uploads', 'delivery_proof'))
PROFILE_PHOTOS_FOLDER = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'static', 'uploads', 'profile_photos'))

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)
if not os.path.exists(DELIVERY_PROOF_FOLDER):
    os.makedirs(DELIVERY_PROOF_FOLDER)
if not os.path.exists(PROFILE_PHOTOS_FOLDER):
    os.makedirs(PROFILE_PHOTOS_FOLDER)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['DELIVERY_PROOF_FOLDER'] = DELIVERY_PROOF_FOLDER
app.config['PROFILE_PHOTOS_FOLDER'] = PROFILE_PHOTOS_FOLDER

def run_async(coro):
    """Helper to run async functions in sync context"""
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    return loop.run_until_complete(coro)

# Static file serving routes
@app.route('/static/<path:filename>')
def serve_static(filename):
    return send_from_directory(app.static_folder, filename)

@app.route('/static/uploads/products/<path:filename>')
def serve_product_image(filename):
    return send_from_directory(os.path.join(app.static_folder, 'uploads', 'products'), filename)

@app.route('/static/uploads/delivery_proof/<path:filename>')
def serve_delivery_proof(filename):
    return send_from_directory(os.path.join(app.static_folder, 'uploads', 'delivery_proof'), filename)

@app.route('/static/uploads/profile_photos/<path:filename>')
def serve_profile_photo(filename):
    return send_from_directory(os.path.join(app.static_folder, 'uploads', 'profile_photos'), filename)

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# Page serving routes
@app.route('/')
def serve_index():
    return send_from_directory('../templates/Public', 'index.html')

@app.route('/forgot-password')
def serve_forgot_password():
    return send_from_directory('../templates/Authenticator', 'forgot-password.html')

@app.route('/reset-password')
def serve_reset_password():
    return send_from_directory('../templates/Authenticator', 'reset-password.html')

@app.route('/become-seller')
def serve_become_seller():
    return send_from_directory('../templates/Public', 'become-seller.html')

@app.route('/become-rider')
def serve_become_rider():
    return send_from_directory('../templates/Public', 'become-rider.html')

@app.route('/<path:filename>')
def serve_static_files(filename):
    if filename.startswith('templates/'):
        template_path = filename.replace('templates/', '', 1)
        return send_from_directory('../templates', template_path)
    elif filename.startswith('static/'):
        static_path = filename.replace('static/', '', 1)
        return send_from_directory('../static', static_path)
    else:
        if filename.endswith('.html'):
            return send_from_directory('../templates', filename)
        return send_from_directory('../static', filename)

# Authentication middleware
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'message': 'Token is missing'}), 401
        
        try:
            if token.startswith('Bearer '):
                token = token[7:]
            
            payload = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            
            # Verify user exists in Supabase
            user = run_async(supabase_client.get_user_by_id(payload.get('user_id')))
            if not user:
                return jsonify({'message': 'Invalid token - user not found'}), 401
                
            request.current_user = user
            return f(*args, **kwargs)
        except jwt.ExpiredSignatureError:
            return jsonify({'message': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'message': 'Invalid token'}), 401
        except Exception as e:
            return jsonify({'message': f'Token validation error: {str(e)}'}), 401
    
    return decorated

def admin_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not hasattr(request, 'current_user') or request.current_user.get('role') != 'admin':
            return jsonify({'message': 'Admin access required'}), 403
        return f(*args, **kwargs)
    return decorated

def seller_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not hasattr(request, 'current_user') or request.current_user.get('role') not in ['seller', 'admin']:
            return jsonify({'message': 'Seller access required'}), 403
        return f(*args, **kwargs)
    return decorated

# Authentication Routes
@app.route('/api/auth/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['name', 'email', 'password']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'message': f'{field} is required'}), 400
        
        # Check if user already exists
        existing_user = run_async(supabase_client.get_user_by_email(data['email']))
        if existing_user:
            return jsonify({'message': 'User already exists'}), 400
        
        # Create new user
        user_data = {
            'name': data['name'],
            'email': data['email'].lower().strip(),
            'password': data['password'],  # In production, hash this password
            'role': data.get('role', 'buyer'),
            'status': 'pending',
            'email_verified': False,
            'is_active': True,
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat()
        }
        
        new_user = run_async(supabase_client.create_user(user_data))
        if not new_user:
            return jsonify({'message': 'Failed to create user'}), 500
        
        # Generate token
        token = jwt.encode({
            'user_id': new_user['id'],
            'email': new_user['email'],
            'role': new_user['role']
        }, app.config['SECRET_KEY'], algorithm='HS256')
        
        return jsonify({
            'message': 'User registered successfully',
            'token': token,
            'user': {
                'id': new_user['id'],
                'name': new_user['name'],
                'email': new_user['email'],
                'role': new_user['role'],
                'status': new_user['status']
            }
        }), 201
        
    except Exception as e:
        return jsonify({'message': f'Registration error: {str(e)}'}), 500

@app.route('/api/auth/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        
        if not data.get('email') or not data.get('password'):
            return jsonify({'message': 'Email and password are required'}), 400
        
        # Get user by email
        user = run_async(supabase_client.get_user_by_email(data['email']))
        if not user:
            return jsonify({'message': 'Invalid credentials'}), 401
        
        # Check password (in production, use proper password hashing)
        if user['password'] != data['password']:
            return jsonify({'message': 'Invalid credentials'}), 401
        
        # Update last login
        run_async(supabase_client.update_user(user['id'], {
            'last_login': datetime.utcnow().isoformat()
        }))
        
        # Generate token
        token = jwt.encode({
            'user_id': user['id'],
            'email': user['email'],
            'role': user['role']
        }, app.config['SECRET_KEY'], algorithm='HS256')
        
        return jsonify({
            'message': 'Login successful',
            'token': token,
            'user': {
                'id': user['id'],
                'name': user['name'],
                'email': user['email'],
                'role': user['role'],
                'status': user['status']
            }
        }), 200
        
    except Exception as e:
        return jsonify({'message': f'Login error: {str(e)}'}), 500

@app.route('/api/auth/me', methods=['GET'])
@token_required
def get_current_user():
    return jsonify({
        'user': {
            'id': request.current_user['id'],
            'name': request.current_user['name'],
            'email': request.current_user['email'],
            'role': request.current_user['role'],
            'status': request.current_user['status']
        }
    })

# Product Routes
@app.route('/api/products', methods=['GET'])
def get_products():
    try:
        filters = {}
        if request.args.get('is_active'):
            filters['is_active'] = request.args.get('is_active').lower() == 'true'
        if request.args.get('seller_id'):
            filters['seller_id'] = int(request.args.get('seller_id'))
        if request.args.get('category'):
            filters['category'] = request.args.get('category')
        
        products = run_async(supabase_client.get_products(filters))
        
        # Get seller information for each product
        for product in products:
            seller = run_async(supabase_client.get_user_by_id(product['seller_id']))
            if seller:
                product['seller_name'] = seller['name']
        
        return jsonify({'products': products}), 200
        
    except Exception as e:
        return jsonify({'message': f'Error getting products: {str(e)}'}), 500

@app.route('/api/products/<int:product_id>', methods=['GET'])
def get_product(product_id):
    try:
        product = run_async(supabase_client.get_product_by_id(product_id))
        if not product:
            return jsonify({'message': 'Product not found'}), 404
        
        # Get seller information
        seller = run_async(supabase_client.get_user_by_id(product['seller_id']))
        if seller:
            product['seller_name'] = seller['name']
        
        return jsonify({'product': product}), 200
        
    except Exception as e:
        return jsonify({'message': f'Error getting product: {str(e)}'}), 500

@app.route('/api/products', methods=['POST'])
@token_required
@seller_required
def create_product():
    try:
        data = request.get_json()
        
        required_fields = ['name', 'price', 'seller_id']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'message': f'{field} is required'}), 400
        
        # Verify seller can only create products for themselves
        if request.current_user['role'] != 'admin' and data['seller_id'] != request.current_user['id']:
            return jsonify({'message': 'Cannot create products for other sellers'}), 403
        
        product_data = {
            'name': data['name'],
            'description': data.get('description', ''),
            'price': float(data['price']),
            'original_price': data.get('original_price'),
            'category': data.get('category'),
            'total_stock': data.get('total_stock', 0),
            'is_active': data.get('is_active', True),
            'image_url': data.get('image_url'),
            'discount_percentage': data.get('discount_percentage', 0.0),
            'sizes': data.get('sizes'),
            'size_pricing': data.get('size_pricing'),
            'seller_id': data['seller_id'],
            'is_flash_sale': data.get('is_flash_sale', False),
            'flash_sale_start': data.get('flash_sale_start'),
            'flash_sale_end': data.get('flash_sale_end'),
            'flash_sale_status': data.get('flash_sale_status', 'none'),
            'approval_status': data.get('approval_status', 'pending'),
            'created_at': datetime.utcnow().isoformat()
        }
        
        new_product = run_async(supabase_client.create_product(product_data))
        if not new_product:
            return jsonify({'message': 'Failed to create product'}), 500
        
        return jsonify({
            'message': 'Product created successfully',
            'product': new_product
        }), 201
        
    except Exception as e:
        return jsonify({'message': f'Error creating product: {str(e)}'}), 500

# Cart Routes
@app.route('/api/cart', methods=['GET'])
@token_required
def get_cart():
    try:
        cart_items = run_async(supabase_client.get_cart_items(request.current_user['id']))
        
        # Get product information for each cart item
        for item in cart_items:
            product = run_async(supabase_client.get_product_by_id(item['product_id']))
            if product:
                item['product_name'] = product['name']
                item['product_image'] = product['image_url']
        
        return jsonify({'cart_items': cart_items}), 200
        
    except Exception as e:
        return jsonify({'message': f'Error getting cart: {str(e)}'}), 500

@app.route('/api/cart', methods=['POST'])
@token_required
def add_to_cart():
    try:
        data = request.get_json()
        
        required_fields = ['product_id', 'quantity', 'price']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'message': f'{field} is required'}), 400
        
        cart_data = {
            'user_id': request.current_user['id'],
            'product_id': data['product_id'],
            'quantity': data['quantity'],
            'size': data.get('size'),
            'color': data.get('color'),
            'price': float(data['price']),
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat()
        }
        
        new_item = run_async(supabase_client.add_to_cart(cart_data))
        if not new_item:
            return jsonify({'message': 'Failed to add to cart'}), 500
        
        return jsonify({
            'message': 'Item added to cart',
            'cart_item': new_item
        }), 201
        
    except Exception as e:
        return jsonify({'message': f'Error adding to cart: {str(e)}'}), 500

@app.route('/api/cart/<int:cart_id>', methods=['PUT'])
@token_required
def update_cart_item(cart_id):
    try:
        data = request.get_json()
        
        updated_item = run_async(supabase_client.update_cart_item(
            cart_id, 
            request.current_user['id'], 
            data
        ))
        
        if not updated_item:
            return jsonify({'message': 'Cart item not found or update failed'}), 404
        
        return jsonify({
            'message': 'Cart item updated',
            'cart_item': updated_item
        }), 200
        
    except Exception as e:
        return jsonify({'message': f'Error updating cart item: {str(e)}'}), 500

@app.route('/api/cart/<int:cart_id>', methods=['DELETE'])
@token_required
def remove_cart_item(cart_id):
    try:
        success = run_async(supabase_client.remove_cart_item(cart_id, request.current_user['id']))
        if not success:
            return jsonify({'message': 'Cart item not found'}), 404
        
        return jsonify({'message': 'Item removed from cart'}), 200
        
    except Exception as e:
        return jsonify({'message': f'Error removing cart item: {str(e)}'}), 500

@app.route('/api/cart/clear', methods=['DELETE'])
@token_required
def clear_cart():
    try:
        success = run_async(supabase_client.clear_cart(request.current_user['id']))
        if not success:
            return jsonify({'message': 'Failed to clear cart'}), 500
        
        return jsonify({'message': 'Cart cleared'}), 200
        
    except Exception as e:
        return jsonify({'message': f'Error clearing cart: {str(e)}'}), 500

# Order Routes
@app.route('/api/orders', methods=['POST'])
@token_required
def create_order():
    try:
        data = request.get_json()
        
        required_fields = ['seller_id', 'full_name', 'email', 'address', 'city', 'postal_code', 'total_amount', 'order_items']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'message': f'{field} is required'}), 400
        
        # Generate order number
        order_number = f"ORD-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"
        
        order_data = {
            'order_number': order_number,
            'buyer_id': request.current_user['id'],
            'seller_id': data['seller_id'],
            'full_name': data['full_name'],
            'email': data['email'],
            'address': data['address'],
            'city': data['city'],
            'postal_code': data['postal_code'],
            'country': data.get('country', 'Philippines'),
            'total_amount': float(data['total_amount']),
            'size_color_stock': data.get('size_color_stock'),
            'payment_method': data.get('payment_method', 'GCASH'),
            'payment_provider': data.get('payment_provider', 'xendit'),
            'payment_provider_id': data.get('payment_provider_id'),
            'status': 'pending',
            'payment_status': 'pending',
            'tracking_number': data.get('tracking_number'),
            'special_notes': data.get('special_notes'),
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat()
        }
        
        new_order = run_async(supabase_client.create_order(order_data))
        if not new_order:
            return jsonify({'message': 'Failed to create order'}), 500
        
        # Create order items
        order_items_data = []
        for item in data['order_items']:
            order_items_data.append({
                'order_id': new_order['id'],
                'product_id': item['product_id'],
                'product_name': item['product_name'],
                'quantity': item['quantity'],
                'price': float(item['price']),
                'size': item.get('size'),
                'color': item.get('color'),
                'subtotal': float(item['quantity']) * float(item['price'])
            })
        
        created_items = run_async(supabase_client.create_order_items(order_items_data))
        
        return jsonify({
            'message': 'Order created successfully',
            'order': new_order,
            'order_items': created_items
        }), 201
        
    except Exception as e:
        return jsonify({'message': f'Error creating order: {str(e)}'}), 500

@app.route('/api/orders/buyer', methods=['GET'])
@token_required
def get_buyer_orders():
    try:
        orders = run_async(supabase_client.get_orders_by_buyer(request.current_user['id']))
        
        # Get order items for each order
        for order in orders:
            order['items'] = run_async(supabase_client.get_order_items(order['id']))
        
        return jsonify({'orders': orders}), 200
        
    except Exception as e:
        return jsonify({'message': f'Error getting orders: {str(e)}'}), 500

@app.route('/api/orders/seller', methods=['GET'])
@token_required
@seller_required
def get_seller_orders():
    try:
        orders = run_async(supabase_client.get_orders_by_seller(request.current_user['id']))
        
        # Get order items for each order
        for order in orders:
            order['items'] = run_async(supabase_client.get_order_items(order['id']))
        
        return jsonify({'orders': orders}), 200
        
    except Exception as e:
        return jsonify({'message': f'Error getting orders: {str(e)}'}), 500

@app.route('/api/orders/<int:order_id>/status', methods=['PUT'])
@token_required
def update_order_status(order_id):
    try:
        data = request.get_json()
        new_status = data.get('status')
        
        if not new_status:
            return jsonify({'message': 'Status is required'}), 400
        
        updated_order = run_async(supabase_client.update_order_status(order_id, new_status))
        if not updated_order:
            return jsonify({'message': 'Order not found or update failed'}), 404
        
        return jsonify({
            'message': 'Order status updated',
            'order': updated_order
        }), 200
        
    except Exception as e:
        return jsonify({'message': f'Error updating order status: {str(e)}'}), 500

# Notification Routes
@app.route('/api/notifications', methods=['GET'])
@token_required
def get_notifications():
    try:
        notifications = run_async(supabase_client.get_notifications(request.current_user['id']))
        return jsonify({'notifications': notifications}), 200
        
    except Exception as e:
        return jsonify({'message': f'Error getting notifications: {str(e)}'}), 500

@app.route('/api/notifications/<int:notification_id>/read', methods=['PUT'])
@token_required
def mark_notification_read(notification_id):
    try:
        success = run_async(supabase_client.mark_notification_read(notification_id, request.current_user['id']))
        if not success:
            return jsonify({'message': 'Notification not found'}), 404
        
        return jsonify({'message': 'Notification marked as read'}), 200
        
    except Exception as e:
        return jsonify({'message': f'Error marking notification as read: {str(e)}'}), 500

# Initialize database (create tables if they don't exist)
@app.before_first_request
def initialize():
    """Initialize the database with required tables"""
    try:
        # This would typically be handled by Supabase migrations
        # The schema should be applied via Supabase dashboard or SQL editor
        print("Supabase backend initialized successfully")
    except Exception as e:
        print(f"Initialization error: {e}")

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
