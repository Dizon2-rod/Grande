// Wishlist Management
const WishlistManager = {
  API_BASE: '/api',
  
  state: {
    items: [],
    filters: { category: 'all', status: 'all', priceCut: false, lowStock: false, backInStock: false },
    sortBy: 'recent',
    selectMode: false,
    selected: new Set(),
    categories: []
  },
  
  init() {
    this.bindControls();
    // Initialize labels to reflect default filter state
    const f = this.state.filters;
    const catLbl = document.getElementById('filterCategoryLabel');
    if (catLbl) catLbl.textContent = `Category: ${f.category==='all'?'All':f.category}`;
    const stLbl = document.getElementById('filterStatusLabel');
    if (stLbl) stLbl.textContent = `Status: ${f.status==='all'?'All':f.status==='in'?'In stock':'Out of stock'}`;
    this.loadWishlist();
  },

  getAuthToken() {
    try {
      if (window.AuthManager && typeof window.AuthManager.getAuthToken === 'function') {
        const t = window.AuthManager.getAuthToken();
        if (t) return t;
      }
    } catch (_) {}
    const keys = ['auth_token', 'jwt_token', 'token'];
    for (const k of keys) {
      const v = localStorage.getItem(k);
      if (v && v !== 'null' && v !== 'undefined') return v;
    }
    return null;
  },

  async loadWishlist() {
    const token = this.getAuthToken();
    
    if (!token) {
      window.location.href = '/templates/Authenticator/login.html';
      return;
    }

    try {
      const response = await fetch(`${this.API_BASE}/wishlist`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });

      if (response.status === 401) {
        // Token invalid/expired - redirect to login and come back
        window.location.href = '/templates/Authenticator/login.html?redirect=' + encodeURIComponent(window.location.pathname);
        return;
      }

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to load wishlist');
      }

      this.renderWishlist(data.items, data.count);
      
    } catch (error) {
      console.error('Error loading wishlist:', error);
      document.getElementById('loading-state').style.display='none';
      document.getElementById('empty-state').style.display='block';
      this.showError('Failed to load wishlist. Please refresh or try again.');
    }
  },

  renderWishlist(items, count) {
    document.getElementById('loading-state').style.display = 'none';

    // keep originals
    this.state.items = Array.isArray(items) ? items : [];
    this.deriveCategories();
    this.populateCategoryMenu();

    const cnt = count || (items ? items.length : 0);
    const cntEl = document.getElementById('wishlist-count');
    if (cntEl) cntEl.textContent = cnt;

    // Apply filters and sort
    const visible = this.applyFiltersAndSort(this.state.items);

    if (!visible || visible.length === 0) {
      document.getElementById('empty-state').style.display = 'block';
      const grid = document.getElementById('wishlistGrid');
      if (grid) grid.style.display = 'none';
      const tableWrap = document.getElementById('wishlistTableWrap');
      if (tableWrap) tableWrap.style.display = 'none';
      return;
    }

    document.getElementById('empty-state').style.display = 'none';
    // Card grid view
    const grid = document.getElementById('wishlistGrid');
    if (grid) {
      grid.style.display = 'grid';
      grid.innerHTML = visible.map(item => this.createWishlistCardHTML(item)).join('');
    }

    this.attachCardEventListeners();
    this.updateSelectUI();
  },

  createWishlistCardHTML(item) {
    const priceNow = Number(item.price || 0);
    const hasDiscount = item.original_price && Number(item.original_price) > priceNow;
    const ratingUsers = item.rating_count || item.total_reviews || 0;
    const hearts = item.likes || item.favorites || '';
    const img = item.image_url || item.image || '/static/uploads/products/placeholder.svg';

    const discountPct = hasDiscount ? Math.round(((Number(item.original_price) - priceNow) / Number(item.original_price)) * 100) : 0;
    return `
      <div class="wishlist-card${this.state.selectMode ? ' selecting' : ''}" data-product-id="${item.product_id}">
        <div class="wl-img-box">
          ${hasDiscount ? `<div class=\"wl-discount-ribbon\">-${discountPct}%</div>` : ''}
          ${this.state.selectMode ? `<div style=\"position:absolute;top:8px;left:8px;z-index:2\"><input type=\"checkbox\" class=\"wl-select\" data-product-id=\"${item.product_id}\" ${this.state.selected.has(String(item.product_id))?'checked':''}></div>` : ''}
          <img src="${img}" alt="${item.name||''}" class="wl-img" onerror="this.src='/static/uploads/products/placeholder.svg'">
          <div class="wl-like">${hearts ? `${hearts}k` : ''} <i class="fas fa-heart"></i></div>
          <div class="wl-hover">
            <button class="btn-ghost find-similar" data-name="${(item.name||'').replace(/"/g,'&quot;')}">FIND SIMILAR</button>
            <button class="btn-ghost delete wl-remove" data-product-id="${item.product_id}">DELETE</button>
          </div>
        </div>
        <div class="wl-body">
          <div class="wl-name">${item.name || ''}</div>
          ${ratingUsers ? `<div class="wl-meta">${ratingUsers}+ users gave 5-star</div>` : ''}
          <div class="wl-price-row">
            <div class="wl-price">
              ${hasDiscount ? `<del>₱${Number(item.original_price).toFixed(2)}</del>` : ''}
              <span class="now">₱${priceNow.toFixed(2)}</span>
            </div>
            <button class="wl-cart-btn add-cart-icon" title="Add to cart" data-product-id="${item.product_id}"><i class="fas fa-shopping-bag"></i></button>
          </div>
          <div class="wl-badges"><span class="wl-badge">Estimated</span></div>
        </div>
      </div>`;
  },

  attachCardEventListeners() {
    // Selection checkboxes
    document.querySelectorAll('.wl-select').forEach(cb => {
      cb.addEventListener('click', (e) => {
        e.stopPropagation();
        const id = String(cb.getAttribute('data-product-id'));
        if (cb.checked) this.state.selected.add(id); else this.state.selected.delete(id);
        this.updateSelectUI();
      });
    });

    // Remove
    document.querySelectorAll('.wl-remove').forEach(btn => {
      btn.addEventListener('click', (e) => { e.stopPropagation(); this.removeFromWishlist(btn.dataset.productId); });
    });
    // Add to cart (qty 1)
    document.querySelectorAll('.add-cart-icon').forEach(btn => {
      btn.addEventListener('click', async (e) => { e.stopPropagation(); await this.addToCart(btn.dataset.productId, 1); });
    });
    // Find similar
    document.querySelectorAll('.find-similar').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const name = btn.getAttribute('data-name') || '';
        window.location.href = `/templates/Public/market.html?search=${encodeURIComponent(name)}`;
      });
    });
    // Navigate to product page on card click
    document.querySelectorAll('.wishlist-card').forEach(card => {
      card.addEventListener('click', () => {
        const pid = card.getAttribute('data-product-id');
        if (pid) window.location.href = `/templates/Public/product.html?id=${pid}`;
      });
    });
  },

  bindControls() {
    // All Filters drawer toggle
    const allBtn = document.getElementById('filterAllBtn');
    const overlay = document.getElementById('allFiltersOverlay');
    const closeBtn = document.getElementById('filtersClose');
    const applyBtn = document.getElementById('filtersApply');
    const resetBtn = document.getElementById('filtersReset');
    if (allBtn && overlay) {
      allBtn.addEventListener('click', () => { this.openFiltersDrawer(); });
      overlay.addEventListener('click', (e) => { if (e.target === overlay) this.closeFiltersDrawer(); });
    }
    if (closeBtn) closeBtn.addEventListener('click', ()=> this.closeFiltersDrawer());
    if (applyBtn) applyBtn.addEventListener('click', ()=> { this.applyDrawerSelections(); this.closeFiltersDrawer(); });
    if (resetBtn) resetBtn.addEventListener('click', ()=> { this.resetDrawer(true); });

    // Category menu populated later; delegate
    document.getElementById('filterStatusMenu')?.addEventListener('click', (e) => {
      const el = e.target.closest('.wl-status-option');
      if (!el) return;
      e.preventDefault();
      this.state.filters.status = el.getAttribute('data-status');
      document.getElementById('filterStatusLabel').textContent = `Status: ${this.state.filters.status==='all'?'All':this.state.filters.status==='in'?'In stock':'Out of stock'}`;
      this.renderWishlist(this.state.items, this.state.items.length);
    });
    document.getElementById('chipPriceCut')?.addEventListener('click', (e)=>{ e.preventDefault(); e.target.classList.toggle('active'); this.state.filters.priceCut = e.target.classList.contains('active'); this.renderWishlist(this.state.items, this.state.items.length); });
    document.getElementById('chipLowStock')?.addEventListener('click', (e)=>{ e.preventDefault(); e.target.classList.toggle('active'); this.state.filters.lowStock = e.target.classList.contains('active'); this.renderWishlist(this.state.items, this.state.items.length); });
    document.getElementById('chipBackInStock')?.addEventListener('click', (e)=>{ e.preventDefault(); e.target.classList.toggle('active'); this.state.filters.backInStock = e.target.classList.contains('active'); this.renderWishlist(this.state.items, this.state.items.length); });

    document.getElementById('sortMenu')?.addEventListener('click', (e)=>{
      const el = e.target.closest('.wl-sort'); if (!el) return; e.preventDefault();
      this.state.sortBy = el.getAttribute('data-sort');
      document.getElementById('sortLabel').textContent = el.textContent;
      this.renderWishlist(this.state.items, this.state.items.length);
    });

    // Select mode
    const selectToggle = document.getElementById('selectToggle');
    if (selectToggle) selectToggle.addEventListener('click', ()=>{ this.state.selectMode = !this.state.selectMode; this.updateSelectUI(true); });
    document.getElementById('selectAll')?.addEventListener('change', (e)=>{
      if (e.target.checked) this.state.items.forEach(it=> this.state.selected.add(String(it.product_id)));
      else this.state.selected.clear();
      this.updateSelectUI();
    });
    document.getElementById('bulkDelete')?.addEventListener('click', async ()=>{
      const ids = Array.from(this.state.selected);
      for (const id of ids) { await this.removeFromWishlist(id); }
    });
    document.getElementById('bulkAddCart')?.addEventListener('click', async ()=>{
      const ids = Array.from(this.state.selected);
      for (const id of ids) { try { await this.addToCart(id, 1); } catch(_){} }
    });
  },

  deriveCategories() {
    const set = new Set();
    (this.state.items||[]).forEach(it=>{ if (it.category) set.add(it.category); });
    this.state.categories = Array.from(set).sort();
  },

  populateCategoryMenu() {
    const menu = document.getElementById('filterCategoryMenu');
    if (menu) {
      const items = [`<li><a class=\"dropdown-item wl-category-option\" data-category=\"all\" href=\"#\">All</a></li>`]
        .concat(this.state.categories.map(c=>`<li><a class=\"dropdown-item wl-category-option\" data-category=\"${c}\">${c}</a></li>`));
      menu.innerHTML = items.join('');
      menu.querySelectorAll('.wl-category-option').forEach(a=>{
        a.addEventListener('click',(e)=>{ e.preventDefault(); this.state.filters.category = a.getAttribute('data-category'); document.getElementById('filterCategoryLabel').textContent = `Category: ${this.state.filters.category==='all'?'All':this.state.filters.category}`; this.renderWishlist(this.state.items, this.state.items.length); });
      });
    }

    // Drawer list
    const list = document.getElementById('fltCategories');
    if (list) {
      const html = [`<label class=\"form-check form-chip\"><input class=\"form-check-input\" type=\"radio\" name=\"fltCategory\" value=\"all\"> All</label>`]
        .concat(this.state.categories.map(c=>`<label class=\"form-check form-chip\"><input class=\"form-check-input\" type=\"radio\" name=\"fltCategory\" value=\"${c}\"> ${c}</label>`));
      list.innerHTML = html.join('');
    }

    this.syncDrawerFromState();
  },

  openFiltersDrawer(){
    const overlay = document.getElementById('allFiltersOverlay');
    if (!overlay) return; this.syncDrawerFromState(); overlay.classList.add('show');
    try { document.body.style.overflow = 'hidden'; } catch(_) {}
    // Close on ESC while drawer is open
    const onKey = (e)=>{ if(e.key==='Escape'){ this.closeFiltersDrawer(); document.removeEventListener('keydown', onKey); } };
    document.addEventListener('keydown', onKey);
  },
  closeFiltersDrawer(){
    const overlay = document.getElementById('allFiltersOverlay');
    if (!overlay) return; overlay.classList.remove('show');
    try { document.body.style.overflow = ''; } catch(_) {}
  },
  syncDrawerFromState(){
    // toggle checkboxes/radios based on state
    const f = this.state.filters;
    const setChecked = (id, v)=>{ const el = document.getElementById(id); if (el) el.checked = !!v; };
    setChecked('fltPriceCut', f.priceCut);
    setChecked('fltLowStock', f.lowStock);
    setChecked('fltBackInStock', f.backInStock);
    // status
    const st = (document.querySelector(`input[name='fltStatus'][value='${f.status}']`) || document.querySelector("input[name='fltStatus'][value='all']"));
    if (st) st.checked = true;
    // category
    const cat = (document.querySelector(`input[name='fltCategory'][value='${f.category}']`) || document.querySelector("input[name='fltCategory'][value='all']"));
    if (cat) cat.checked = true;
  },
  applyDrawerSelections(){
    this.state.filters.priceCut = !!document.getElementById('fltPriceCut')?.checked;
    this.state.filters.lowStock = !!document.getElementById('fltLowStock')?.checked;
    this.state.filters.backInStock = !!document.getElementById('fltBackInStock')?.checked;
    const st = document.querySelector("input[name='fltStatus']:checked");
    if (st) this.state.filters.status = st.value;
    const cat = document.querySelector("input[name='fltCategory']:checked");
    if (cat) this.state.filters.category = cat.value;
    // reflect chips labels
    document.getElementById('filterStatusLabel').textContent = `Status: ${this.state.filters.status==='all'?'All':this.state.filters.status==='in'?'In stock':'Out of stock'}`;
    document.getElementById('filterCategoryLabel').textContent = `Category: ${this.state.filters.category==='all'?'All':this.state.filters.category}`;
    // sync chip active states
    const setChip = (id, v)=>{ const el = document.getElementById(id); if (el) el.classList.toggle('active', v); };
    setChip('chipPriceCut', this.state.filters.priceCut);
    setChip('chipLowStock', this.state.filters.lowStock);
    setChip('chipBackInStock', this.state.filters.backInStock);
    this.renderWishlist(this.state.items, this.state.items.length);
  },
  resetDrawer(applyNow=false){
    this.state.filters = { category: 'all', status: 'all', priceCut: false, lowStock: false, backInStock: false };
    this.syncDrawerFromState();
    // Update visible chip/buttons labels to defaults
    const catLbl = document.getElementById('filterCategoryLabel');
    if (catLbl) catLbl.textContent = 'Category: All';
    const stLbl = document.getElementById('filterStatusLabel');
    if (stLbl) stLbl.textContent = 'Status: All';
    ['chipPriceCut','chipLowStock','chipBackInStock'].forEach(id=>{
      const el = document.getElementById(id);
      if (el) el.classList.remove('active');
    });
    if (applyNow) this.renderWishlist(this.state.items, this.state.items.length);
  },

  applyFiltersAndSort(list) {
    let arr = Array.from(list||[]);
    const f = this.state.filters;
    arr = arr.filter(it=>{
      if (f.category !== 'all' && String(it.category||'') !== String(f.category)) return false;
      if (f.status === 'in' && it.in_stock === false) return false;
      if (f.status === 'out' && it.in_stock !== false) return false;
      if (f.priceCut && !(Number(it.original_price||0) > Number(it.price||0))) return false;
      if (f.lowStock && !(Number(it.stock||0) > 0 && Number(it.stock||0) <= 5)) return false;
      if (f.backInStock && !it.back_in_stock) return false;
      return true;
    });

    switch (this.state.sortBy) {
      case 'priceLow':
        arr.sort((a,b)=> Number(a.price||0) - Number(b.price||0)); break;
      case 'priceHigh':
        arr.sort((a,b)=> Number(b.price||0) - Number(a.price||0)); break;
      default:
        arr.sort((a,b)=> new Date(b.added_at||b.created_at||0) - new Date(a.added_at||a.created_at||0));
    }
    return arr;
  },

  updateSelectUI(forceRerender=false) {
    const toggle = document.getElementById('selectToggle');
    const bulk = document.getElementById('bulkBar');
    if (toggle) toggle.textContent = this.state.selectMode ? 'Cancel' : 'Select';
    if (bulk) bulk.style.display = this.state.selectMode ? 'block' : 'none';
    document.getElementById('selectedCount')?.replaceChildren(document.createTextNode(`${this.state.selected.size} selected`));
    if (forceRerender) this.renderWishlist(this.state.items, this.state.items.length);
  },

  // Previous UI: table row template and handlers
  createWishlistRowHTML(item) {
    const discount = item.discount_percentage || 0;
    const hasDiscount = discount > 0 && item.original_price;
    const priceNow = item.price || 0;
    const isOut = !item.in_stock;
    const dateAdded = item.added_at ? new Date(item.added_at).toLocaleDateString() : '';

    return `
      <tr data-product-id="${item.product_id}">
        <td><button class="wl-remove" title="Remove" data-product-id="${item.product_id}"><i class="fas fa-times"></i></button></td>
        <td>
          <div class="wl-product">
            <img src="${item.image_url}" class="wl-thumb" onerror="this.src='/static/uploads/products/placeholder.svg'"/>
            <div>
              <div class="wl-name">${item.name}</div>
              <div class="wl-meta">${item.category || ''} ${dateAdded ? `· Added on ${dateAdded}`: ''}</div>
            </div>
          </div>
        </td>
        <td>
          <div class="qty-box">
            <button class="qty-btn qty-minus" ${isOut ? 'disabled':''}>-</button>
            <input class="qty-input" type="number" min="1" value="1" ${isOut ? 'disabled':''} />
            <button class="qty-btn qty-plus" ${isOut ? 'disabled':''}>+</button>
          </div>
        </td>
        <td class="wl-price">
          ${hasDiscount ? `<del>₱${Number(item.original_price).toFixed(2)}</del>` : ''}
          <span class="now">₱${Number(priceNow).toFixed(2)}</span>
        </td>
        <td>
          ${isOut ? `<span class="wl-stock out">Out of stock</span>` : `<span class="wl-stock ok">In stock</span>`}
        </td>
        <td class="wl-action">
          <button class="add-cart" ${isOut ? 'disabled':''} data-product-id="${item.product_id}">Add To Cart</button>
        </td>
      </tr>
    `;
  },

  attachRowEventListeners() {
    // Remove
    document.querySelectorAll('.wl-remove').forEach(btn => {
      btn.addEventListener('click', () => this.removeFromWishlist(btn.dataset.productId));
    });
    // Qty +/-
    document.querySelectorAll('.qty-minus').forEach(btn => {
      btn.addEventListener('click', () => {
        const input = btn.parentElement.querySelector('.qty-input');
        const v = Math.max(1, parseInt(input.value||'1')-1); input.value = v;
      });
    });
    document.querySelectorAll('.qty-plus').forEach(btn => {
      btn.addEventListener('click', () => {
        const input = btn.parentElement.querySelector('.qty-input');
        const v = Math.max(1, parseInt(input.value||'1')+1); input.value = v;
      });
    });
    // Add to cart
    document.querySelectorAll('.add-cart').forEach(btn => {
      btn.addEventListener('click', async () => {
        const row = btn.closest('tr');
        const qty = parseInt(row.querySelector('.qty-input').value) || 1;
        await this.addToCart(btn.dataset.productId, qty);
      });
    });
  },

  async removeFromWishlist(productId) {
    const token = this.getAuthToken();

    try {
      const response = await fetch(`${this.API_BASE}/wishlist/${productId}`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to remove from wishlist');
      }

      // Show success message
      this.showSuccess('Removed from wishlist');

      // Reload wishlist
      this.loadWishlist();

    } catch (error) {
      console.error('Error removing from wishlist:', error);
      this.showError('Failed to remove from wishlist');
    }
  },

  async addToCart(productId, quantity = 1) {
    const token = this.getAuthToken();

    try {
      // Get product details first to determine if it has variants
      const productResponse = await fetch(`${this.API_BASE}/products/${productId}`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });

      const productData = await productResponse.json();

      if (!productResponse.ok) {
        throw new Error('Failed to fetch product details');
      }

      const product = productData.product;

      // Decide variant to add
      const stockMap = product.size_color_stock || {};
      let chosen = null; let availableCount = 0;
      for (const [size, colors] of Object.entries(stockMap)) {
        for (const [colorHex, v] of Object.entries(colors || {})) {
          const qty = Number(v && v.stock || v && v.stock_quantity || 0);
          availableCount += qty > 0 ? 1 : 0;
          if (!chosen && qty > 0) chosen = { size, color: colorHex };
        }
      }
      // If no variant or multiple choices, send user to product page to select
      if (!chosen || availableCount !== 1) {
        window.location.href = `/templates/Public/product.html?id=${productId}`;
        return;
      }

      // Add to cart with selected variant
      const response = await fetch(`${this.API_BASE}/cart`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          product_id: productId,
          size: chosen.size,
          color: chosen.color,
          quantity: quantity
        })
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to add to cart');
      }

      // Show success message
      this.showSuccess('Added to cart!');

      // Update cart count in header if available
      if (window.updateCartCount) {
        window.updateCartCount();
      }

    } catch (error) {
      console.error('Error adding to cart:', error);
      this.showError(error.message || 'Failed to add to cart');
    }
  },

  showSuccess(message) {
    this.showNotification(message, 'success');
  },

  showError(message) {
    this.showNotification(message, 'error');
  },

  showNotification(message, type = 'success') {
    // Create notification element
    const notification = document.createElement('div');
    notification.style.cssText = `
      position: fixed;
      top: 100px;
      right: 20px;
      background: ${type === 'success' ? 'linear-gradient(135deg, #10ac84 0%, #0abde3 100%)' : 'linear-gradient(135deg, #ee5a6f 0%, #f7b731 100%)'};
      color: white;
      padding: 15px 25px;
      border-radius: 12px;
      box-shadow: 0 6px 20px rgba(0,0,0,0.15);
      z-index: 10000;
      animation: slideIn 0.3s ease;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 10px;
    `;

    const icon = type === 'success' ? '✓' : '✕';
    notification.innerHTML = `<span style="font-size: 1.2rem;">${icon}</span> ${message}`;

    document.body.appendChild(notification);

    // Add CSS animation
    const style = document.createElement('style');
    style.textContent = `
      @keyframes slideIn {
        from {
          transform: translateX(400px);
          opacity: 0;
        }
        to {
          transform: translateX(0);
          opacity: 1;
        }
      }
    `;
    if (!document.querySelector('style[data-notification]')) {
      style.setAttribute('data-notification', 'true');
      document.head.appendChild(style);
    }

    // Remove after 3 seconds
    setTimeout(() => {
      notification.style.animation = 'slideIn 0.3s ease reverse';
      setTimeout(() => {
        notification.remove();
      }, 300);
    }, 3000);
  }
};

// Initialize wishlist manager when page loads
document.addEventListener('DOMContentLoaded', () => {
  WishlistManager.init();
});
