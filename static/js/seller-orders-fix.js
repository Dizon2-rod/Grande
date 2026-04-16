// Fix for seller order confirmation functionality
// Add this to your seller dashboard orders page

// Function to confirm order (change status from pending to confirmed)
async function confirmOrder(orderId) {
    try {
        const token = AuthManager.getAuthToken();
        if (!token) {
            showToast('Please log in to confirm orders', 'error');
            return;
        }

        // Show confirmation dialog
        if (!confirm('Confirm this order? This will deduct stock and notify the buyer.')) {
            return;
        }

        const response = await fetch(`/api/orders/${orderId}/status`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                status: 'confirmed'
            })
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.error || 'Failed to confirm order');
        }

        showToast('Order confirmed successfully!', 'success');
        
        // Reload orders list
        if (typeof loadOrders === 'function') {
            loadOrders();
        } else if (typeof loadRecentOrders === 'function') {
            loadRecentOrders();
        }

    } catch (error) {
        console.error('Error confirming order:', error);
        showToast(error.message || 'Failed to confirm order', 'error');
    }
}

// Function to update order status (for prepared, shipped, etc.)
async function updateOrderStatus(orderId, newStatus) {
    try {
        const token = AuthManager.getAuthToken();
        if (!token) {
            showToast('Please log in to update order status', 'error');
            return;
        }

        const statusLabels = {
            'confirmed': 'Confirm',
            'prepared': 'Mark as Prepared',
            'shipped': 'Mark as Shipped',
            'cancelled': 'Cancel'
        };

        const action = statusLabels[newStatus] || 'Update';
        
        if (!confirm(`${action} this order?`)) {
            return;
        }

        const payload = { status: newStatus };
        
        // If cancelling, ask for reason
        if (newStatus === 'cancelled') {
            const reason = prompt('Please provide a cancellation reason:');
            if (!reason || !reason.trim()) {
                showToast('Cancellation reason is required', 'error');
                return;
            }
            payload.cancel_reason = reason.trim();
        }

        const response = await fetch(`/api/orders/${orderId}/status`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.error || 'Failed to update order status');
        }

        showToast(`Order ${newStatus} successfully!`, 'success');
        
        // Reload orders list
        if (typeof loadOrders === 'function') {
            loadOrders();
        } else if (typeof loadRecentOrders === 'function') {
            loadRecentOrders();
        }

    } catch (error) {
        console.error('Error updating order status:', error);
        showToast(error.message || 'Failed to update order status', 'error');
    }
}

// Make functions globally available
window.confirmOrder = confirmOrder;
window.updateOrderStatus = updateOrderStatus;

// Toast notification helper
function showToast(message, type = 'info') {
    const colors = {
        success: '#28a745',
        error: '#dc3545',
        info: '#007bff'
    };
    
    const toast = document.createElement('div');
    toast.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        min-width: 250px;
        z-index: 1055;
        background: ${colors[type]};
        color: white;
        padding: 15px 20px;
        border-radius: 8px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        font-family: Arial, sans-serif;
    `;
    toast.textContent = message;
    
    document.body.appendChild(toast);
    
    setTimeout(() => {
        toast.remove();
    }, 4000);
}
