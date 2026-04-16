// Seller Dashboard - Uses shared-auth.js exclusively
// All authentication handled by AuthManager

document.addEventListener('DOMContentLoaded', async function() {
    console.log('Seller Dashboard: Starting initialization...');
    
    try {
        // Wait for AuthManager to be available
        let retries = 0;
        while (typeof AuthManager === 'undefined' && retries < 10) {
            console.log('Waiting for AuthManager to load...');
            await new Promise(resolve => setTimeout(resolve, 100));
            retries++;
        }
        
        if (typeof AuthManager === 'undefined') {
            console.error('AuthManager failed to load after waiting');
            alert('Authentication system failed to load. Please refresh the page.');
            return;
        }
        
        console.log('AuthManager loaded successfully');
        
        // Check if user is logged in
        const isLoggedIn = AuthManager.isLoggedIn();
        const userInfo = AuthManager.getAuthUser();
        const token = AuthManager.getAuthToken();
        
        console.log('Auth Status:', {
            isLoggedIn: isLoggedIn,
            hasUser: !!userInfo,
            hasToken: !!token,
            userRole: userInfo?.role,
            userId: userInfo?.id
        });
        
        if (!isLoggedIn || !userInfo || !token) {
            console.log('Authentication failed - redirecting to login');
            alert('Please log in to access the seller dashboard.');
            window.location.href = '/templates/Authenticator/login.html';
            return;
        }

        // Check if user is a seller
        if (userInfo.role !== 'seller') {
            console.log('Access denied - user role:', userInfo.role);
            alert(`Access denied. You need a seller account to access this dashboard. Current role: ${userInfo.role}`);
            window.location.href = '/templates/Public/index.html';
            return;
        }
        
        console.log('Seller authentication successful for user:', userInfo.name);
        
        // Update UI with user info
        updateUserDisplay(userInfo);
        initializeSidebar();
        
        // Force load dashboard stats regardless of page detection
        console.log('Loading dashboard stats...');
        await loadDashboardStats();

        console.log('Loading dashboard charts...');
        try { await loadDashboardCharts(); } catch (e) { console.error('Failed to load dashboard charts:', e); }
        initSellerSalesChartControls();
        
        console.log('Loading other dashboard components...');
        // Load other components with error handling
        try { await loadRecentProducts(); } catch (e) { console.error('Failed to load recent products:', e); }
        try { await loadBestProducts(); } catch (e) { console.error('Failed to load best products:', e); }
        try { await loadRecentOrders(); } catch (e) { console.error('Failed to load recent orders:', e); }
        try { await loadTopCustomers(); } catch (e) { console.error('Failed to load top customers:', e); }
        try { await loadLowStockProducts(); } catch (e) { console.error('Failed to load low stock:', e); }
        
        console.log('Dashboard initialization completed successfully');

    } catch (error) {
        console.error('Dashboard initialization error:', error);
        alert('Failed to initialize dashboard: ' + error.message);
    }
});

function updateUserDisplay(userInfo) {
    // Update user name and role in the UI
    const userName = document.querySelector('.user-name');
    const userRole = document.querySelector('.user-role');
    
    if (userName) {
        userName.textContent = userInfo.name || userInfo.email?.split('@')[0] || 'Seller';
    }
    if (userRole) {
        userRole.textContent = userInfo.role || 'Seller';
    }
}

function initializeSidebar() {
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

window.loadDashboardStats = async function() {
    console.log('loadDashboardStats: Starting...');
    
    try {
        const token = AuthManager.getAuthToken();
        console.log('loadDashboardStats: Token available:', !!token);
        
        if (!token) {
            console.error('loadDashboardStats: No token available');
            throw new Error('Authentication token not found');
        }
        
        console.log('loadDashboardStats: Making API request to /api/seller/dashboard-stats');
        
        const response = await fetch('/api/seller/dashboard-stats', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('loadDashboardStats: Response received:', {
            status: response.status,
            statusText: response.statusText,
            ok: response.ok
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            console.error('loadDashboardStats: API error response:', errorText);
            throw new Error(`API request failed: ${response.status} - ${errorText}`);
        }

        const data = await response.json();
        console.log('loadDashboardStats: Data received:', data);
        
        // Update dashboard stats - with defensive checks
        const revenueEl = document.getElementById('statRevenue');
        const ordersEl = document.getElementById('statOrders');
        const productsEl = document.getElementById('statProducts');
        const pendingEl = document.getElementById('statPending');
        
        console.log('loadDashboardStats: Updating UI elements...');
        
        if (revenueEl) {
            revenueEl.textContent = `₱${(data.total_revenue || 0).toFixed(2)}`;
            console.log('Updated revenue:', revenueEl.textContent);
        } else {
            console.warn('Revenue element not found');
        }
        
        if (ordersEl) {
            ordersEl.textContent = data.total_orders || 0;
            console.log('Updated orders:', ordersEl.textContent);
        } else {
            console.warn('Orders element not found');
        }
        
        if (productsEl) {
            productsEl.textContent = data.total_products || 0;
            console.log('Updated products:', productsEl.textContent);
        } else {
            console.warn('Products element not found');
        }
        
        if (pendingEl) {
            pendingEl.textContent = data.pending_orders || 0;
            console.log('Updated pending:', pendingEl.textContent);
        } else {
            console.warn('Pending element not found');
        }
        
        console.log('loadDashboardStats: Successfully completed');

    } catch (error) {
        console.error('loadDashboardStats: Error occurred:', error);
        
        // Show error in UI
        const statsCards = document.querySelectorAll('.stat-value');
        statsCards.forEach(card => {
            if (card.textContent.includes('0') || card.textContent === '₱0.00') {
                card.textContent = 'Error';
                card.style.color = 'red';
            }
        });
        
        // Show detailed error message
        const dashboardSection = document.getElementById('dashboardSection');
        if (dashboardSection) {
            const existingError = dashboardSection.querySelector('.alert-danger');
            if (!existingError) {
                const errorDiv = document.createElement('div');
                errorDiv.className = 'alert alert-danger mt-3';
                errorDiv.innerHTML = `
                    <strong>Failed to load dashboard statistics</strong><br>
                    <small>Error: ${error.message}</small><br>
                    <small>Please check the browser console for more details and try refreshing the page.</small>
                `;
                dashboardSection.insertBefore(errorDiv, dashboardSection.firstChild);
            }
        }
        
        throw error; // Re-throw for parent error handling
    }
};

window.loadDashboardCharts = async function() {
    console.log('loadDashboardCharts: Starting...');
    const salesCanvas = document.getElementById('sellerSalesTrendChart');
    const statusCanvas = document.getElementById('sellerOrderStatusChart');

    if (!salesCanvas && !statusCanvas) {
        console.log('loadDashboardCharts: No chart canvases found, skipping.');
        return;
    }

    try {
        const token = AuthManager.getAuthToken();
        if (!token) {
            throw new Error('Authentication token not found');
        }

        // Initialize sales chart with default range
        if (salesCanvas) {
            try {
                await fetchAndRenderSellerSalesTrend('30d');
            } catch (e) {
                console.error('loadDashboardCharts: Failed to load sales timeseries', e);
            }
        }

        // Order status distribution based on recent orders
        if (statusCanvas) {
            try {
                const recent = await DashboardUtils.makeApiCall('/api/seller/recent-orders?limit=50');
                if (recent && recent.success && Array.isArray(recent.orders)) {
                    renderSellerOrderStatusChart(recent.orders);
                } else {
                    console.warn('loadDashboardCharts: recent orders data missing or invalid', recent);
                }
            } catch (e) {
                console.error('loadDashboardCharts: Failed to load recent orders for status chart', e);
            }
        }

        console.log('loadDashboardCharts: Completed');
    } catch (error) {
        console.error('loadDashboardCharts: Error occurred:', error);
    }
};

async function fetchAndRenderSellerSalesTrend(rangeKey) {
    const canvas = document.getElementById('sellerSalesTrendChart');
    if (!canvas) {
        console.warn('fetchAndRenderSellerSalesTrend: canvas not found');
        return;
    }

    const helper = document.getElementById('sellerSalesTrendMessage');
    if (helper) {
        helper.textContent = 'Loading total sales data...';
    }

    let daysBack;
    switch (rangeKey) {
        case '7d':
            daysBack = 6; // last 7 days including today
            break;
        case '90d':
            daysBack = 89;
            break;
        case '30d':
        default:
            daysBack = 29;
            break;
    }

    const today = new Date();
    const from = new Date();
    from.setDate(today.getDate() - daysBack);
    const fromStr = from.toISOString().slice(0, 10);
    const toStr = today.toISOString().slice(0, 10);

    let labels = [];
    let salesSeries = [];

    try {
        const ts = await DashboardUtils.makeApiCall(`/api/seller/analytics/timeseries?from=${fromStr}&to=${toStr}&granularity=day`);
        if (ts && ts.success && Array.isArray(ts.labels) && Array.isArray(ts.sales) && ts.labels.length) {
            labels = ts.labels;
            salesSeries = ts.sales;
            if (helper) {
                helper.textContent = '';
            }
        } else {
            console.warn('fetchAndRenderSellerSalesTrend: timeseries data missing or invalid', ts);
            throw new Error('No sales data available for the selected range');
        }
    } catch (e) {
        console.error('fetchAndRenderSellerSalesTrend: error loading sales timeseries', e);
        // Fallback: build zero-data series so chart still renders and explain to the user
        labels = [];
        salesSeries = [];
        for (let i = daysBack; i >= 0; i--) {
            const d = new Date();
            d.setDate(today.getDate() - i);
            labels.push(d.toISOString().slice(5, 10)); // MM-DD
            salesSeries.push(0);
        }
        if (helper) {
            helper.textContent = 'No sales data yet for this range. Once you start receiving orders, your total sales will appear here.';
        }
    }

    renderSellerSalesTrendChart(labels, salesSeries);
}

function initSellerSalesChartControls() {
    const salesCanvas = document.getElementById('sellerSalesTrendChart');
    if (!salesCanvas) return;

    const buttons = document.querySelectorAll('[data-sales-range]');
    if (!buttons.length) return;

    buttons.forEach(btn => {
        btn.addEventListener('click', async () => {
            const range = btn.getAttribute('data-sales-range') || '30d';
            buttons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            try {
                await fetchAndRenderSellerSalesTrend(range);
            } catch (e) {
                console.error('initSellerSalesChartControls: failed to update sales chart range', e);
            }
        });
    });
}

let sellerDashboardCharts = {};

function renderSellerSalesTrendChart(labels, series) {
    const canvas = document.getElementById('sellerSalesTrendChart');
    if (!canvas) {
        console.warn('renderSellerSalesTrendChart: canvas not found');
        return;
    }
    if (typeof Chart === 'undefined') {
        console.warn('renderSellerSalesTrendChart: Chart.js not loaded');
        return;
    }

    const ctx = canvas.getContext('2d');
    if (sellerDashboardCharts.sales) {
        sellerDashboardCharts.sales.destroy();
    }

    sellerDashboardCharts.sales = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Total Sales (₱)',
                data: series,
                borderColor: '#10b981',
                backgroundColor: 'rgba(16, 185, 129, 0.18)',
                tension: 0.35,
                fill: true,
                pointRadius: 2,
                pointHoverRadius: 4,
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: '#0f172a',
                    titleColor: '#e5e7eb',
                    bodyColor: '#e5e7eb',
                    callbacks: {
                        label: function(context) {
                            const v = context.parsed.y || 0;
                            return '₱' + v.toFixed(2);
                        }
                    }
                }
            },
            scales: {
                x: {
                    grid: { display: false },
                    ticks: {
                        color: '#6b7280',
                        maxTicksLimit: 7,
                        autoSkip: true
                    }
                },
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(148, 163, 184, 0.35)' },
                    ticks: {
                        color: '#6b7280',
                        callback: function(value) {
                            return '₱' + value.toLocaleString('en-PH');
                        }
                    }
                }
            }
        }
    });
}

function renderSellerOrderStatusChart(orders) {
    const canvas = document.getElementById('sellerOrderStatusChart');
    if (!canvas) {
        console.warn('renderSellerOrderStatusChart: canvas not found');
        return;
    }
    if (typeof Chart === 'undefined') {
        console.warn('renderSellerOrderStatusChart: Chart.js not loaded');
        return;
    }

    const counts = {};
    (orders || []).forEach(o => {
        const status = (o.status || 'unknown').toLowerCase();
        counts[status] = (counts[status] || 0) + 1;
    });

    const labels = Object.keys(counts);
    const data = labels.map(k => counts[k]);

    if (!labels.length) {
        console.warn('renderSellerOrderStatusChart: no status data to display');
        return;
    }

    const ctx = canvas.getContext('2d');
    if (sellerDashboardCharts.status) {
        sellerDashboardCharts.status.destroy();
    }

    const colors = [
        '#f97316', '#22c55e', '#0ea5e9',
        '#6366f1', '#16a34a', '#ef4444',
        '#eab308', '#8b5cf6'
    ];

    sellerDashboardCharts.status = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: labels,
            datasets: [{
                data: data,
                backgroundColor: labels.map((_, idx) => colors[idx % colors.length])
            }]
        },
        options: {
            plugins: {
                legend: { display: false }
            }
        }
    });

    // Build custom legend next to the chart if container exists
    const legendContainer = document.getElementById('orderStatusLegend');
    if (legendContainer) {
        const total = data.reduce((sum, v) => sum + v, 0);
        legendContainer.innerHTML = labels.map((label, idx) => {
            const count = data[idx];
            const color = colors[idx % colors.length];
            const prettyLabel = label.charAt(0).toUpperCase() + label.slice(1);
            const percentage = total ? Math.round((count / total) * 100) : 0;
            return `
                <div class="legend-item">
                    <span class="legend-color" style="background:${color};"></span>
                    <span class="text-capitalize">${prettyLabel}</span>
                    <span class="ms-auto text-muted small">${count} (${percentage}%)</span>
                </div>
            `;
        }).join('');
    }
}

function checkAuthentication() {
    if (!AuthManager.isLoggedIn()) {
        window.location.href = '/templates/Authenticator/login.html';
        return false;
    }

    const userInfo = AuthManager.getAuthUser();
    if (!userInfo || userInfo.role !== 'seller') {
        window.location.href = '/templates/Public/index.html';
        return false;
    }

    return true;
}

function logout() {
    AuthManager.logout();
}

// Additional dashboard functions (moved to global scope)
window.loadBestProducts = async function() {
    try {
        const token = AuthManager.getAuthToken();
        const tbody = document.getElementById('bestProductsBody');
        if (!tbody || !token) {
            console.log('Skipping loadBestProducts: missing elements or token');
            return;
        }

        const resp = await fetch('/api/seller/best-products?limit=5', {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.error || 'Failed to load best products');
        
        const products = data.products || [];
        if (products.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-muted text-center py-4">No sales data available yet</td></tr>';
            return;
        }
        
        tbody.innerHTML = products.map(p => `
            <tr>
                <td>
                    <div class="d-flex align-items-center gap-2">
                        <img src="${p.image_url}" class="rounded" alt="Product" style="width: 40px; height: 40px; object-fit: cover;">
                        <div class="fw-medium">${escapeHtml(p.name)}</div>
                    </div>
                </td>
                <td>${escapeHtml(p.category)}</td>
                <td><span class="badge bg-success">${p.total_sold}</span></td>
                <td class="fw-bold text-success">₱${p.total_revenue.toFixed(2)}</td>
                <td>₱${p.current_price.toFixed(2)}</td>
            </tr>
        `).join('');
    } catch (e) {
        const tbody = document.getElementById('bestProductsBody');
        if (tbody) tbody.innerHTML = `<tr><td colspan="5" class="text-danger text-center py-4">${e.message}</td></tr>`;
    }
};

window.loadRecentOrders = async function() {
    try {
        const token = AuthManager.getAuthToken();
        const tbody = document.getElementById('recentOrdersBody');
        if (!tbody || !token) {
            console.log('Skipping loadRecentOrders: missing elements or token');
            return;
        }

        const resp = await fetch('/api/seller/recent-orders?limit=8', {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.error || 'Failed to load recent orders');
        
        const orders = data.orders || [];
        if (orders.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-muted text-center py-4">No orders found</td></tr>';
            return;
        }
        
        tbody.innerHTML = orders.map(o => {
            const statusColors = {
                'pending': 'warning',
                'confirmed': 'info', 
                'prepared': 'primary',
                'shipped': 'secondary',
                'delivered': 'success',
                'cancelled': 'danger'
            };
            
            return `
                <tr>
                    <td class="fw-medium">${escapeHtml(o.order_number || `#${o.id}`)}</td>
                    <td>${escapeHtml(o.customer_name)}</td>
                    <td class="fw-bold">₱${o.total_amount.toFixed(2)}</td>
                    <td><span class="badge bg-${statusColors[o.status] || 'secondary'}">${o.status}</span></td>
                    <td><small class="text-muted">${o.time_ago}</small></td>
                </tr>
            `;
        }).join('');
    } catch (e) {
        const tbody = document.getElementById('recentOrdersBody');
        if (tbody) tbody.innerHTML = `<tr><td colspan="5" class="text-danger text-center py-4">${e.message}</td></tr>`;
    }
};

window.loadLowStockProducts = async function() {
    try {
        const token = AuthManager.getAuthToken();
        const tbody = document.getElementById('lowStockBody');
        if (!tbody || !token) {
            console.log('Skipping loadLowStockProducts: missing elements or token');
            return;
        }

        const resp = await fetch('/api/seller/low-stock?threshold=10&limit=8', {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.error || 'Failed to load low stock products');
        
        const products = data.products || [];
        if (products.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-success text-center py-4"><i class="fas fa-check-circle me-2"></i>All products are well stocked!</td></tr>';
            return;
        }
        
        tbody.innerHTML = products.map(p => {
            const stockColor = p.total_stock === 0 ? 'danger' : p.total_stock <= 5 ? 'warning' : 'info';
            
            return `
                <tr>
                    <td>
                        <div class="d-flex align-items-center gap-2">
                            <img src="${p.image_url}" class="rounded" alt="Product" style="width: 40px; height: 40px; object-fit: cover;">
                            <div class="fw-medium">${escapeHtml(p.name)}</div>
                        </div>
                    </td>
                    <td>${escapeHtml(p.category)}</td>
                    <td><span class="badge bg-${stockColor}">${p.total_stock}</span></td>
                    <td>₱${p.price.toFixed(2)}</td>
                    <td class="text-end">
                        <a href="inventory.html" class="btn btn-sm btn-outline-primary">
                            <i class="fas fa-plus me-1"></i>Restock
                        </a>
                    </td>
                </tr>
            `;
        }).join('');
    } catch (e) {
        const tbody = document.getElementById('lowStockBody');
        if (tbody) tbody.innerHTML = `<tr><td colspan="5" class="text-danger text-center py-4">${e.message}</td></tr>`;
    }
};

window.loadTopCustomers = async function() {
    try {
        const token = AuthManager.getAuthToken();
        const tbody = document.getElementById('topCustomersBody');
        if (!tbody || !token) {
            console.log('Skipping loadTopCustomers: missing elements or token');
            return;
        }

        const resp = await fetch('/api/seller/top-customers?limit=8', {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.error || 'Failed to load top customers');
        
        const customers = data.customers || [];
        if (customers.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-muted text-center py-4">No customer data available yet</td></tr>';
            return;
        }
        
        tbody.innerHTML = customers.map(customer => {
            // Format last order date
            const lastOrderDate = customer.last_order_date ? 
                new Date(customer.last_order_date).toLocaleDateString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    year: 'numeric'
                }) : 'Never';
            
            // Get customer initials for avatar
            const initials = customer.customer_name ? 
                customer.customer_name.split(' ').map(n => n[0]).join('').toUpperCase().substring(0, 2) : 
                '??';
            
            return `
                <tr>
                    <td>
                        <div class="d-flex align-items-center gap-2">
                            <div class="d-flex align-items-center justify-content-center" 
                                 style="width: 32px; height: 32px; background: linear-gradient(135deg, #8b5cf6, #a855f7); 
                                        border-radius: 50%; color: white; font-size: 12px; font-weight: 600;">
                                ${initials}
                            </div>
                            <div>
                                <div class="fw-medium">${escapeHtml(customer.customer_name)}</div>
                                <small class="text-muted">${escapeHtml(customer.customer_email)}</small>
                            </div>
                        </div>
                    </td>
                    <td>
                        <span class="badge bg-primary">${customer.total_orders} order${customer.total_orders !== 1 ? 's' : ''}</span>
                    </td>
                    <td class="fw-bold text-success">₱${(customer.total_spent || 0).toFixed(2)}</td>
                    <td>
                        <div class="text-truncate" style="max-width: 150px;" title="${escapeHtml(customer.favorite_product || 'None')}">
                            ${customer.favorite_product ? escapeHtml(customer.favorite_product) : '<em class="text-muted">None</em>'}
                        </div>
                        ${customer.favorite_product_count > 1 ? `<small class="text-muted">${customer.favorite_product_count}x bought</small>` : ''}
                    </td>
                    <td>
                        <small class="text-muted">${lastOrderDate}</small>
                    </td>
                </tr>
            `;
        }).join('');
    } catch (e) {
        console.error('Error loading top customers:', e);
        const tbody = document.getElementById('topCustomersBody');
        if (tbody) tbody.innerHTML = `<tr><td colspan="5" class="text-danger text-center py-4">${e.message}</td></tr>`;
    }
};

// Utility function
function escapeHtml(text) {
    if (!text) return '';
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.toString().replace(/[&<>"']/g, function(m) { return map[m]; });
}

// Additional initialization for dashboard features
if (window.location.pathname.includes('sellerdashboard.html') || document.getElementById('dashboardSection')) {
  // All functions now use AuthManager from shared-auth.js
  document.addEventListener('DOMContentLoaded', function() {
      // Sidebar functionality
      const adminSidebar = document.getElementById('adminSidebar');
      const sidebarToggle = document.getElementById('sidebarToggle');
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

      // Navigation
      const navLinks = document.querySelectorAll('.admin-sidebar .nav-item[data-section]');
      const contentSections = document.querySelectorAll('.content-section');
      
      navLinks.forEach(link => {
        link.addEventListener('click', (e) => {
          e.preventDefault();
          const clickable = e.target.closest('.nav-item');
          const targetSection = clickable.dataset.section;
          
          // Update active nav
          navLinks.forEach(nl => nl.classList.remove('active'));
          clickable.classList.add('active');
          
          // Update active section
          contentSections.forEach(section => section.classList.remove('active'));
          const targetElement = document.getElementById(targetSection + 'Section');
          if (targetElement) {
            targetElement.classList.add('active');
          }

          // On mobile just collapse sidebar
          const adminSidebar = document.getElementById('adminSidebar');
          if (window.innerWidth < 992 && adminSidebar) {
            adminSidebar.classList.add('collapsed');
          }
        });
      });

      // Highlight active sidebar item by current URL
      (function setActiveLinkByURL() {
        const links = document.querySelectorAll('.admin-sidebar a.nav-item');
        let matched = false;
        links.forEach(link => {
          const href = link.getAttribute('href');
          if (!href) return;
          // Normalize case and compare end of path to support absolute paths
          try {
            const current = window.location.pathname.toLowerCase();
            const target = href.toLowerCase();
            if (current.endsWith(target)) {
              links.forEach(l => l.classList.remove('active'));
              link.classList.add('active');
              matched = true;
            }
          } catch (err) {}
        });
        // If no match, keep existing active (e.g., dashboard by default)
      })();

      // Recent Products (Dashboard quick manage)
      window.loadRecentProducts = async function() {
        try {
          const token = AuthManager.getAuthToken();
          const user = AuthManager.getAuthUser();
          const tbody = document.getElementById('recentProductsBody');
          if (!tbody || !user) {
            console.log('Skipping loadRecentProducts: missing elements or user');
            return;
          }

          const resp = await fetch(`/api/products?seller_id=${user.id}&sort_by=created_at&page=1&per_page=5`, {
            headers: token ? { 'Authorization': `Bearer ${token}` } : {}
          });
          
          const data = await resp.json();
          
          if (!resp.ok) {
            throw new Error(data.error || 'Failed to load products');
          }
          
          const products = data.products || [];
          if (products.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-muted text-center py-4"><i class="fas fa-box-open me-2"></i>No products yet. <a href="add_product.html" class="btn btn-sm btn-primary ms-2"><i class="fas fa-plus me-1"></i>Add your first product</a></td></tr>';
            return;
          }
          
          tbody.innerHTML = products.map(p => {
            const totalStock = p.total_stock ?? 0;
            const created = p.created_at ? new Date(p.created_at).toLocaleDateString() : '-';
            const stockClass = totalStock > 0 ? 'text-success' : 'text-danger';
            const stockIcon = totalStock > 0 ? 'fas fa-check-circle' : 'fas fa-exclamation-triangle';
            
            return `
              <tr>
                <td class="fw-medium">${escapeHtml(p.name)}</td>
                <td><span class="badge bg-light text-dark">${escapeHtml(p.category || 'Uncategorized')}</span></td>
                <td><span class="${stockClass}"><i class="${stockIcon} me-1"></i>${totalStock}</span></td>
                <td><small class="text-muted">${created}</small></td>
                <td class="text-end">
                  <button class="btn btn-sm btn-outline-primary me-1" onclick="editProduct(${p.id})" title="Edit product">
                    <i class="fas fa-edit"></i>
                  </button>
                  <button class="btn btn-sm btn-outline-danger" onclick="deleteProduct(${p.id})" title="Delete product">
                    <i class="fas fa-trash"></i>
                  </button>
                </td>
              </tr>
            `;
          }).join('');
        } catch (e) {
          console.error('Error loading recent products:', e);
          const tbody = document.getElementById('recentProductsBody');
          if (tbody) {
            tbody.innerHTML = `<tr><td colspan="5" class="text-danger text-center py-4"><i class="fas fa-exclamation-circle me-2"></i>Unable to load products: ${e.message}</td></tr>`;
          }
        }
      };

      // IMPROVED PRODUCT FORM FUNCTIONALITY
      const PRESET_COLORS = {
        'Black': '#000000', 'White': '#FFFFFF', 'Gray': '#808080', 'Navy': '#000080',
        'Red': '#FF0000', 'Blue': '#0000FF', 'Green': '#008000', 'Yellow': '#FFFF00',
        'Pink': '#FFC0CB', 'Purple': '#800080', 'Orange': '#FFA500', 'Brown': '#8B4513',
        'Beige': '#F5DEB3', 'Khaki': '#F0E68C', 'Maroon': '#800000', 'Teal': '#008080'
      };

      let currentStep = 1;
      let selectedSizes = new Set();
      let productVariants = new Map(); // size -> [{color, price, stock}]

      // Step navigation
      const steps = document.querySelectorAll('.step');
      const formSteps = document.querySelectorAll('.form-step');
      const prevBtn = document.getElementById('prevStep');
      const nextBtn = document.getElementById('nextStep');
      const submitBtn = document.getElementById('submitProduct');

      function updateStepDisplay() {
        // Update step indicators
        steps.forEach((step, index) => {
          const stepNum = index + 1;
          step.classList.remove('active', 'completed');
          if (stepNum < currentStep) {
            step.classList.add('completed');
          } else if (stepNum === currentStep) {
            step.classList.add('active');
          }
        });

        // Update form steps
        formSteps.forEach((step, index) => {
          step.classList.remove('active');
          if (index + 1 === currentStep) {
            step.classList.add('active');
          }
        });

        // Update navigation buttons (guard against missing buttons on some pages)
        if (prevBtn) {
          prevBtn.style.visibility = currentStep > 1 ? 'visible' : 'hidden';
        }
        if (nextBtn) {
          nextBtn.style.display = currentStep < 3 ? 'inline-block' : 'none';
        }
        if (submitBtn) {
          submitBtn.style.display = currentStep === 3 ? 'inline-block' : 'none';
        }
      }

      if (nextBtn) {
        nextBtn.addEventListener('click', () => {
          if (validateCurrentStep()) {
            if (currentStep === 2) {
              generateProductSummary();
            }
            currentStep = Math.min(3, currentStep + 1);
            updateStepDisplay();
          }
        });
      }

      if (prevBtn) {
        prevBtn.addEventListener('click', () => {
          currentStep = Math.max(1, currentStep - 1);
          updateStepDisplay();
        });
      }

      function validateCurrentStep() {
        if (currentStep === 1) {
          const name = document.querySelector('[name="name"]').value.trim();
          const image = document.querySelector('[name="image"]').files[0];
          if (!name) {
            showToast('Please enter a product name', 'error');
            return false;
          }
          if (!image) {
            showToast('Please select a product image', 'error');
            return false;
          }
          return true;
        } else if (currentStep === 2) {
          if (selectedSizes.size === 0) {
            showToast('Please select at least one size', 'error');
            return false;
          }
          
          let hasVariants = false;
          for (const size of selectedSizes) {
            const variants = productVariants.get(size) || [];
            if (variants.length > 0) {
              hasVariants = true;
              break;
            }
          }
          
          if (!hasVariants) {
            showToast('Please add at least one color variant with price and stock', 'error');
            return false;
          }
          return true;
        }
        return true;
      }

      // Size selection
      const sizePills = document.querySelectorAll('.size-pill');
      const sizeColorGrid = document.getElementById('sizeColorGrid');

      sizePills.forEach(pill => {
        pill.addEventListener('click', () => {
          const size = pill.dataset.size;
          
          if (pill.classList.contains('selected')) {
            // Deselect size
            pill.classList.remove('selected');
            selectedSizes.delete(size);
            productVariants.delete(size);
          } else {
            // Select size
            pill.classList.add('selected');
            selectedSizes.add(size);
            if (!productVariants.has(size)) {
              productVariants.set(size, []);
            }
          }
          
          updateSizeColorGrid();
        });
      });

      function updateSizeColorGrid() {
        // If the grid isn't present on this page, do nothing safely
        if (!sizeColorGrid) {
          return;
        }

        if (selectedSizes.size === 0) {
          sizeColorGrid.innerHTML = `
            <div class="empty-state">
              <i class="fas fa-tshirt"></i>
              <p>Select sizes above to start configuring colors, prices, and stock</p>
            </div>
          `;
          return;
        }

        sizeColorGrid.innerHTML = '';
        
        selectedSizes.forEach(size => {
          const sizeSection = createSizeSection(size);
          sizeColorGrid.appendChild(sizeSection);
        });
      }

      function createSizeSection(size) {
        const variants = productVariants.get(size) || [];
        const hasColors = variants.length > 0;
        
        const section = document.createElement('div');
        section.className = `size-section ${hasColors ? 'has-colors' : ''}`;
        section.innerHTML = `
          <div class="size-header">
            <div class="size-title">
              <span class="size-badge">${escapeHtml(size)}</span>
              <span class="variant-count">${variants.length} variant${variants.length !== 1 ? 's' : ''}</span>
            </div>
            <button type="button" class="btn btn-sm btn-outline-danger" onclick="removeSize('${escapeHtml(size)}')">
              <i class="fas fa-times"></i>
            </button>
          </div>
          
          <div class="color-variants" id="variants-${escapeHtml(size)}">
            ${variants.map((variant, index) => createVariantHTML(size, variant, index)).join('')}
            <div class="add-color-btn" onclick="showColorSelector('${escapeHtml(size)}')">
              <i class="fas fa-plus"></i>
              <span>Add Color Variant</span>
            </div>
          </div>
        `;
        
        return section;
      }

      function createVariantHTML(size, variant, index) {
        return `
          <div class="color-variant" style="position: relative;">
            <div class="color-header">
              <div class="color-dot" style="background: ${variant.color};"></div>
              <div class="color-name">${variant.colorName}</div>
            </div>
            <div class="variant-inputs">
              <div class="input-group input-group-sm">
                <span class="input-group-text">$</span>
                <input type="number" class="form-control" step="0.01" min="0" 
                       value="${variant.price}" placeholder="Price"
                       onchange="updateVariant('${size}', ${index}, 'price', this.value)">
              </div>
              <input type="number" class="form-control form-control-sm" min="0" 
                     value="${variant.stock}" placeholder="Stock"
                     onchange="updateVariant('${size}', ${index}, 'stock', this.value)">
            </div>
            <button type="button" class="remove-variant-btn" onclick="removeVariant('${size}', ${index})">
              <i class="fas fa-times"></i>
            </button>
          </div>
        `;
      }

      // Global functions for onclick handlers
      window.removeSize = function(size) {
        selectedSizes.delete(size);
        productVariants.delete(size);
        document.querySelector(`[data-size="${size}"]`).classList.remove('selected');
        updateSizeColorGrid();
      };

      window.showColorSelector = function(size) {
        // Create modal for color selection
        const colorModal = document.createElement('div');
        colorModal.className = 'modal fade';
        colorModal.innerHTML = `
          <div class="modal-dialog">
            <div class="modal-content">
              <div class="modal-header">
                <h6 class="modal-title">Add Color for ${size}</h6>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
              </div>
              <div class="modal-body">
                <div class="preset-colors">
                  ${Object.entries(PRESET_COLORS).map(([name, hex]) => `
                    <div class="preset-color-btn" data-color-name="${name}" data-color-hex="${hex}">
                      <div class="color-preview" style="background: ${hex};"></div>
                      <span>${name}</span>
                    </div>
                  `).join('')}
                </div>
                <hr>
                <div class="d-flex gap-2 align-items-center">
                  <input type="color" id="customColor" class="form-control" style="width: 60px;">
                  <input type="text" id="customColorName" class="form-control" placeholder="Custom color name">
                  <button type="button" class="btn btn-sm btn-outline-primary" onclick="addCustomColor('${size}')">Add</button>
                </div>
              </div>
            </div>
          </div>
        `;
        
        document.body.appendChild(colorModal);
        const modal = new bootstrap.Modal(colorModal);
        modal.show();
        
        // Add event listeners for preset colors
        colorModal.querySelectorAll('.preset-color-btn').forEach(btn => {
          btn.addEventListener('click', () => {
            addColorVariant(size, btn.dataset.colorName, btn.dataset.colorHex);
            modal.hide();
          });
        });
        
        colorModal.addEventListener('hidden.bs.modal', () => {
          document.body.removeChild(colorModal);
        });
      };

      window.addCustomColor = function(size) {
        const colorInput = document.getElementById('customColor');
        const nameInput = document.getElementById('customColorName');
        const colorName = nameInput.value.trim();
        
        if (!colorName) {
          showToast('Please enter a color name', 'error');
          return;
        }
        
        addColorVariant(size, colorName, colorInput.value);
        bootstrap.Modal.getInstance(document.querySelector('.modal.show')).hide();
      };

      function addColorVariant(size, colorName, colorHex) {
        const variants = productVariants.get(size) || [];
        
        // Check if color already exists
        if (variants.some(v => v.colorName === colorName)) {
          showToast('This color already exists for this size', 'error');
          return;
        }
        
        variants.push({
          colorName: colorName,
          color: colorHex,
          price: 0,
          stock: 0
        });
        
        productVariants.set(size, variants);
        updateSizeColorGrid();
      }

      window.updateVariant = function(size, index, field, value) {
        const variants = productVariants.get(size);
        if (variants && variants[index]) {
          variants[index][field] = parseFloat(value) || 0;
        }
      };

      window.removeVariant = function(size, index) {
        const variants = productVariants.get(size);
        if (variants) {
          variants.splice(index, 1);
          updateSizeColorGrid();
        }
      };

      function generateProductSummary() {
        const addProductFormEl = document.getElementById('addProductForm');
        if (!addProductFormEl) {
          return;
        }

        const formData = new FormData(addProductFormEl);
        const name = formData.get('name');
        const category = formData.get('category');
        const description = formData.get('description');
        
        let totalVariants = 0;
        let totalStock = 0;
        let minPrice = Infinity;
        let maxPrice = 0;
        
        const variantsList = [];
        
        productVariants.forEach((variants, size) => {
          variants.forEach(variant => {
            if (variant.price > 0) {
              totalVariants++;
              totalStock += variant.stock || 0;
              minPrice = Math.min(minPrice, variant.price);
              maxPrice = Math.max(maxPrice, variant.price);
              
              variantsList.push(`
                <div class="d-flex justify-content-between align-items-center py-1">
                  <div class="d-flex align-items-center gap-2">
                    <div class="color-dot" style="background: ${variant.color}; width: 16px; height: 16px;"></div>
                    <span>${size} - ${variant.colorName}</span>
                  </div>
                  <div class="text-end">
                    <div>${variant.price.toFixed(2)}</div>
                    <small class="text-muted">${variant.stock} in stock</small>
                  </div>
                </div>
              `);
            }
          });
        });
        
        const priceRange = minPrice === maxPrice ? 
          `${minPrice.toFixed(2)}` : 
          `${minPrice.toFixed(2)} - ${maxPrice.toFixed(2)}`;

        const summaryEl = document.getElementById('productSummary');
        if (!summaryEl) {
          return;
        }

        summaryEl.innerHTML = `
          <div class="summary-item">
            <strong>Product Name:</strong>
            <span>${escapeHtml(name)}</span>
          </div>
          <div class="summary-item">
            <strong>Category:</strong>
            <span>${escapeHtml(category || 'Not specified')}</span>
          </div>
          <div class="summary-item">
            <strong>Description:</strong>
            <span>${escapeHtml(description || 'No description')}</span>
          </div>
          <div class="summary-item">
            <strong>Total Variants:</strong>
            <span>${totalVariants}</span>
          </div>
          <div class="summary-item">
            <strong>Total Stock:</strong>
            <span>${totalStock} items</span>
          </div>
          <div class="summary-item">
            <strong>Price Range:</strong>
            <span>${priceRange}</span>
          </div>
          <div class="mt-3">
            <strong>Variants:</strong>
            <div class="mt-2" style="max-height: 200px; overflow-y: auto;">
              ${variantsList.join('')}
            </div>
          </div>
        `;
      }

      // Form submission (only if the form exists on this page)
      const addProductForm = document.getElementById('addProductForm');
      if (addProductForm) {
        addProductForm.addEventListener('submit', async function(e) {
          e.preventDefault();
          
          const token = AuthManager.getAuthToken();
          if (!token) {
            showToast('Please log in to add products', 'error');
            return;
          }
          
          const formData = new FormData(this);
          
          // Add variant data - this matches your Flask API structure
          const sizeColorData = {};
          productVariants.forEach((variants, size) => {
            const colorEntries = {};
            variants.forEach(variant => {
              if (variant.price > 0) {
                colorEntries[variant.colorName] = {
                  price: variant.price,
                  stock: variant.stock || 0,
                  color: variant.color
                };
              }
            });
            if (Object.keys(colorEntries).length > 0) {
              sizeColorData[size] = colorEntries;
            }
          });
          
          formData.set('size_color_data', JSON.stringify(sizeColorData));
          
          const submitBtn = document.getElementById('submitProduct');
          submitBtn.disabled = true;
          const prevText = submitBtn.innerHTML;
          submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-1"></i> Saving...';
          
          try {
            // Make actual API call to your Flask backend
            const response = await fetch('/api/products', {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${token}`
              },
              body: formData
            });
            
            const data = await response.json();
            
            if (response.ok) {
              showToast('Product added successfully! It will now appear in the market.', 'success');
              
              // Reset form
              this.reset();
              currentStep = 1;
              selectedSizes.clear();
              productVariants.clear();
              updateStepDisplay();
              updateSizeColorGrid();
              
              // Reset size pills
              sizePills.forEach(pill => pill.classList.remove('selected'));
              
              // Close modal (if present)
              const addProductModalEl = document.getElementById('addProductModal');
              if (addProductModalEl) {
                const addProductModal = bootstrap.Modal.getInstance(addProductModalEl) || new bootstrap.Modal(addProductModalEl);
                addProductModal.hide();
              }
              
              // Refresh inventory if we're on that page
              const inventorySection = document.getElementById('inventorySection');
              if (inventorySection && inventorySection.classList.contains('active')) {
                loadInventory();
              }
              
              // Update dashboard stats
              loadDashboardStats();
              
            } else {
              throw new Error(data.error || 'Failed to add product');
            }
            
          } catch (error) {
            console.error('Product submission error:', error);
            showToast('Failed to add product: ' + error.message, 'error');
          } finally {
            submitBtn.disabled = false;
            submitBtn.innerHTML = prevText;
          }
        });
      }

      // Load seller's inventory
      async function loadInventory() {
        const token = AuthManager.getAuthToken();
        const user = AuthManager.getAuthUser() || {};
        
        if (!token || !user.id) return;
        
        try {
          const response = await fetch(`/api/products?seller_id=${user.id}`, {
            headers: {
              'Authorization': `Bearer ${token}`
            }
          });
          
          const data = await response.json();
          
          if (response.ok) {
            displayInventory(data.products || []);
          } else {
            console.error('Failed to load inventory:', data.error);
          }
        } catch (error) {
          console.error('Error loading inventory:', error);
        }
      }

      function displayInventory(products) {
        const tbody = document.querySelector('#inventorySection tbody');
        if (!tbody) return;
        
        if (products.length === 0) {
          tbody.innerHTML = `
            <tr>
              <td colspan="6" class="text-center text-muted py-4">
                <i class="fas fa-box-open fa-3x mb-3 d-block"></i>
                No products found. Add your first product to get started!
              </td>
            </tr>
          `;
          return;
        }
        
        tbody.innerHTML = products.map(product => {
          const variantCount = Object.keys(product.size_color_stock || {}).reduce((total, size) => {
            return total + Object.keys(product.size_color_stock[size] || {}).length;
          }, 0);
          
          const totalStock = Object.values(product.size_color_stock || {}).reduce((total, sizeData) => {
            return total + Object.values(sizeData).reduce((sizeTotal, colorData) => {
              return sizeTotal + (colorData.stock || 0);
            }, 0);
          }, 0);
          
          const prices = [];
          Object.values(product.size_color_stock || {}).forEach(sizeData => {
            Object.values(sizeData).forEach(colorData => {
              if (colorData.price > 0) prices.push(colorData.price);
            });
          });
          
          const minPrice = prices.length > 0 ? Math.min(...prices) : 0;
          const maxPrice = prices.length > 0 ? Math.max(...prices) : 0;
          const priceRange = minPrice === maxPrice ? 
            `${minPrice.toFixed(2)}` : 
            `${minPrice.toFixed(2)} - ${maxPrice.toFixed(2)}`;
          
          return `
            <tr>
              <td>
                <div class="d-flex align-items-center gap-2">
                  <img src="${product.image_url || '/static/images/placeholder.jpg'}" 
                       class="rounded" alt="Product" style="width: 48px; height: 48px; object-fit: cover;">
                  <div>
                    <div class="fw-medium">${escapeHtml(product.name)}</div>
                    <small class="text-muted">Created ${formatDate(product.created_at)}</small>
                  </div>
                </div>
              </td>
              <td>${escapeHtml(product.category || 'Uncategorized')}</td>
              <td>
                <span class="badge bg-light text-dark">${variantCount} variant${variantCount !== 1 ? 's' : ''}</span>
              </td>
              <td>
                <span class="text-${totalStock > 0 ? 'success' : 'danger'} fw-medium">
                  ${totalStock} in stock
                </span>
              </td>
              <td>${priceRange}</td>
              <td>
                <button class="btn btn-sm btn-outline-primary me-1" onclick="editProduct(${product.id})">
                  <i class="fas fa-edit"></i> Edit
                </button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteProduct(${product.id})">
                  <i class="fas fa-trash"></i> Delete
                </button>
              </td>
            </tr>
          `;
        }).join('');
      }

      function formatDate(dateString) {
        if (!dateString) return 'Unknown';
        const date = new Date(dateString);
        const now = new Date();
        const diffTime = Math.abs(now - date);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        
        if (diffDays === 1) return 'today';
        if (diffDays === 2) return 'yesterday';
        if (diffDays <= 7) return `${diffDays - 1} days ago`;
        return date.toLocaleDateString();
      }

      // This loadDashboardStats function is redundant - main one is defined earlier

      // Global functions for inventory management
      window.editProduct = async function(productId) {
        try {
          const token = AuthManager.getAuthToken();
          const headers = token ? { 'Authorization': `Bearer ${token}` } : {};
          const resp = await fetch(`/api/products/${productId}`, { headers });
          const data = await resp.json();
          if (!resp.ok || !data.success) throw new Error(data.error || 'Failed to load product');
          const p = data.product;

          document.getElementById('editProductId').value = p.id;
          document.getElementById('editName').value = p.name || '';
          document.getElementById('editDescription').value = p.description || '';
          document.getElementById('editPrice').value = parseFloat(p.price || 0);
          document.getElementById('editTotalStock').value = parseInt(p.total_stock || 0);
          document.getElementById('editCategory').value = p.category || '';
          document.getElementById('editFlashSale').checked = !!p.is_flash_sale;

          new bootstrap.Modal(document.getElementById('editProductModal')).show();
        } catch (e) {
          showToast('Failed to open edit modal: ' + e.message, 'error');
        }
      };

      // Submit handler for edit (dashboard scope)
      const dashEditForm = document.getElementById('editProductForm');
      if (dashEditForm) {
        dashEditForm.addEventListener('submit', async (e) => {
          e.preventDefault();
          const token = AuthManager.getAuthToken();
          if (!token) return showToast('Please login', 'error');
          const id = document.getElementById('editProductId').value;
          const payload = {
            name: document.getElementById('editName').value.trim(),
            description: document.getElementById('editDescription').value.trim(),
            price: parseFloat(document.getElementById('editPrice').value || 0),
            total_stock: parseInt(document.getElementById('editTotalStock').value || 0),
            category: document.getElementById('editCategory').value.trim(),
            is_flash_sale: document.getElementById('editFlashSale').checked
          };
          try {
            const resp = await fetch(`/api/products/${id}`, {
              method: 'PUT',
              headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
              },
              body: JSON.stringify(payload)
            });
            const data = await resp.json();
            if (!resp.ok) throw new Error(data.error || 'Update failed');
            showToast('Product updated', 'success');
            bootstrap.Modal.getInstance(document.getElementById('editProductModal')).hide();
            loadRecentProducts();
          } catch (err) {
            showToast('Failed to update: ' + err.message, 'error');
          }
        });
      }

      window.deleteProduct = async function(productId) {
        try {
          const headers = {};
          const token = AuthManager.getAuthToken();
          if (token) headers['Authorization'] = `Bearer ${token}`;
          const resp = await fetch(`/api/products/${productId}`, { headers });
          let name = 'this product';
          if (resp.ok) {
            const data = await resp.json();
            name = data.product?.name || name;
          }
          document.getElementById('deleteProductName').textContent = name;
          const confirmBtn = document.getElementById('confirmDeleteProductBtn');
          const modalEl = document.getElementById('deleteProductModal');
          const modal = new bootstrap.Modal(modalEl);
          modal.show();

          const onConfirm = async () => {
            confirmBtn.disabled = true;
            try {
              const delResp = await fetch(`/api/products/${productId}`, {
                method: 'DELETE',
                headers: { 'Authorization': `Bearer ${AuthManager.getAuthToken()}` }
              });
              const delData = await delResp.json();
              if (!delResp.ok) throw new Error(delData.error || 'Delete failed');
              showToast('Product deleted', 'success');
              modal.hide();
              loadRecentProducts();
            } catch (err) {
              showToast('Failed to delete: ' + err.message, 'error');
            } finally {
              confirmBtn.disabled = false;
              confirmBtn.removeEventListener('click', onConfirm);
            }
          };
          confirmBtn.addEventListener('click', onConfirm);
          modalEl.addEventListener('hidden.bs.modal', () => {
            confirmBtn.removeEventListener('click', onConfirm);
          }, { once: true });
        } catch (e) {
          showToast('Failed to open delete dialog', 'error');
        }
      };

      // Load initial data when switching to inventory section
      const inventoryNavLink = document.querySelector('[data-section="inventory"]');
      if (inventoryNavLink) {
        inventoryNavLink.addEventListener('click', () => {
          setTimeout(loadInventory, 100); // Small delay to ensure section is active
        });
      }

      // Load dashboard stats on page load
      loadDashboardStats();

// Functions are now defined globally above

      // Utility functions
      function showToast(message, type = 'info') {
        const colors = {
          success: 'var(--accent-coral)',
          error: 'var(--accent-pink)', 
          info: 'var(--primary-dark)'
        };
        
        const toast = document.createElement('div');
        toast.className = 'toast align-items-center text-white';
        toast.style = `position:fixed;top:20px;right:20px;min-width:250px;z-index:1055;background:${colors[type]};border-radius:8px;`;
        toast.innerHTML = `
          <div class="d-flex">
            <div class="toast-body">${message}</div>
            <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
          </div>
        `;
        
        document.body.appendChild(toast);
        const bsToast = new bootstrap.Toast(toast, { delay: 4000 });
        bsToast.show();
        
        toast.addEventListener('hidden.bs.toast', () => toast.remove());
      }

      function escapeHtml(text) {
        const map = {
          '&': '&amp;',
          '<': '&lt;',
          '>': '&gt;',
          '"': '&quot;',
          "'": '&#039;'
        };
        return text.replace(/[&<>"']/g, function(m) { return map[m]; });
      }
      // Initialize
      updateStepDisplay();
    });
}
