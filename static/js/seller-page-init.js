// Minimal seller page initialization
// For use on seller dashboard sub-pages (orders, delivery-tracking, etc.)

document.addEventListener('DOMContentLoaded', async function() {
    try {
        // Wait for AuthManager to be available
        let retries = 0;
        while (typeof AuthManager === 'undefined' && retries < 10) {
            await new Promise(resolve => setTimeout(resolve, 100));
            retries++;
        }
        
        if (typeof AuthManager === 'undefined') {
            console.error('AuthManager failed to load');
            window.location.href = '../Authenticator/login.html';
            return;
        }
        
        // Check authentication
        if (!AuthManager.isLoggedIn()) {
            window.location.href = '../Authenticator/login.html';
            return;
        }
        
        const userInfo = AuthManager.getAuthUser();
        if (!userInfo || userInfo.role !== 'seller') {
            window.location.href = '../Public/index.html';
            return;
        }
        
        // Update user display in header
        const userName = document.querySelector('.user-name');
        const userRole = document.querySelector('.user-role');
        
        if (userName) {
            userName.textContent = userInfo.name || userInfo.email?.split('@')[0] || 'Seller';
        }
        if (userRole) {
            userRole.textContent = userInfo.role || 'Seller';
        }
        
        // Initialize sidebar functionality
        initializeBasicSidebar();
        
        // Initialize navigation
        if (typeof DashboardUtils !== 'undefined') {
            const currentPage = window.location.pathname.split('/').pop();
            DashboardUtils.initializeNavigation(currentPage);
        }
        
        console.log('Seller page initialized successfully');
        
    } catch (error) {
        console.error('Failed to initialize seller page:', error);
        if (typeof DashboardUtils !== 'undefined') {
            DashboardUtils.showErrorToast('Failed to initialize page: ' + error.message);
        }
    }
});

function initializeBasicSidebar() {
    const sidebarToggle = document.getElementById('sidebarToggle');
    const adminSidebar = document.getElementById('adminSidebar');
    const mobileToggle = document.getElementById('mobileToggle');

    if (sidebarToggle && adminSidebar) {
        sidebarToggle.addEventListener('click', () => {
            adminSidebar.classList.toggle('collapsed');
        });
    }

    if (mobileToggle && adminSidebar) {
        mobileToggle.addEventListener('click', () => {
            adminSidebar.classList.toggle('collapsed');
        });
    }
}

// Simple toast function if DashboardUtils is not available
function showToast(message, type = 'info') {
    const colors = {
        success: '#28a745',
        error: '#dc3545', 
        info: '#17a2b8'
    };
    
    const toast = document.createElement('div');
    toast.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: ${colors[type]};
        color: white;
        padding: 12px 20px;
        border-radius: 4px;
        z-index: 9999;
        font-size: 14px;
        max-width: 300px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    `;
    toast.textContent = message;
    
    document.body.appendChild(toast);
    
    setTimeout(() => {
        toast.remove();
    }, 4000);
}

// Make available globally
window.SellerPageInit = {
    initializeBasicSidebar,
    showToast
};