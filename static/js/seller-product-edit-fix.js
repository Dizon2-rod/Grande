// Fix for seller product editing functionality
// Add this to your seller dashboard inventory/product management page

// Function to edit product
async function editProduct(productId) {
    try {
        const token = AuthManager.getAuthToken();
        if (!token) {
            showToast('Please log in to edit products', 'error');
            return;
        }

        // Fetch product details
        const response = await fetch(`/api/products/${productId}`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.error || 'Failed to load product');
        }

        const product = data.product;

        // Populate edit modal with product data
        document.getElementById('editProductId').value = product.id;
        document.getElementById('editName').value = product.name || '';
        document.getElementById('editDescription').value = product.description || '';
        document.getElementById('editPrice').value = parseFloat(product.price || 0);
        document.getElementById('editTotalStock').value = parseInt(product.total_stock || 0);
        document.getElementById('editCategory').value = product.category || '';
        document.getElementById('editFlashSale').checked = !!product.is_flash_sale;

        // Show edit modal
        const editModal = new bootstrap.Modal(document.getElementById('editProductModal'));
        editModal.show();

    } catch (error) {
        console.error('Error loading product for edit:', error);
        showToast(error.message || 'Failed to load product', 'error');
    }
}

// Function to save product edits
async function saveProductEdit(event) {
    event.preventDefault();

    try {
        const token = AuthManager.getAuthToken();
        if (!token) {
            showToast('Please log in to save changes', 'error');
            return;
        }

        const productId = document.getElementById('editProductId').value;
        const name = document.getElementById('editName').value.trim();
        const description = document.getElementById('editDescription').value.trim();
        const price = parseFloat(document.getElementById('editPrice').value || 0);
        const totalStock = parseInt(document.getElementById('editTotalStock').value || 0);
        const category = document.getElementById('editCategory').value.trim();
        const isFlashSale = document.getElementById('editFlashSale').checked;

        // Validation
        if (!name) {
            showToast('Product name is required', 'error');
            return;
        }

        if (price < 0) {
            showToast('Price cannot be negative', 'error');
            return;
        }

        if (totalStock < 0) {
            showToast('Stock cannot be negative', 'error');
            return;
        }

        const payload = {
            name: name,
            description: description,
            price: price,
            total_stock: totalStock,
            category: category,
            is_flash_sale: isFlashSale
        };

        const response = await fetch(`/api/products/${productId}`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.error || 'Failed to update product');
        }

        showToast('Product updated successfully!', 'success');

        // Close modal
        const editModal = bootstrap.Modal.getInstance(document.getElementById('editProductModal'));
        if (editModal) {
            editModal.hide();
        }

        // Reload products list
        if (typeof loadRecentProducts === 'function') {
            loadRecentProducts();
        }
        if (typeof loadInventory === 'function') {
            loadInventory();
        }

    } catch (error) {
        console.error('Error saving product:', error);
        showToast(error.message || 'Failed to save product', 'error');
    }
}

// Function to delete product
async function deleteProduct(productId) {
    try {
        const token = AuthManager.getAuthToken();
        if (!token) {
            showToast('Please log in to delete products', 'error');
            return;
        }

        // Fetch product name first
        const response = await fetch(`/api/products/${productId}`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        let productName = 'this product';
        if (response.ok) {
            const data = await response.json();
            productName = data.product?.name || productName;
        }

        // Confirm deletion
        if (!confirm(`Are you sure you want to delete "${productName}"? This action cannot be undone.`)) {
            return;
        }

        // Delete product
        const deleteResponse = await fetch(`/api/products/${productId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        const deleteData = await deleteResponse.json();

        if (!deleteResponse.ok) {
            throw new Error(deleteData.error || 'Failed to delete product');
        }

        showToast('Product deleted successfully!', 'success');

        // Reload products list
        if (typeof loadRecentProducts === 'function') {
            loadRecentProducts();
        }
        if (typeof loadInventory === 'function') {
            loadInventory();
        }

    } catch (error) {
        console.error('Error deleting product:', error);
        showToast(error.message || 'Failed to delete product', 'error');
    }
}

// Make functions globally available
window.editProduct = editProduct;
window.saveProductEdit = saveProductEdit;
window.deleteProduct = deleteProduct;

// Attach event listener to edit form if it exists
document.addEventListener('DOMContentLoaded', function() {
    const editForm = document.getElementById('editProductForm');
    if (editForm) {
        editForm.addEventListener('submit', saveProductEdit);
    }
});

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
