// Shared Header UI logic for notifications, messages, cart dropdown, and user auth
// Namespaced to avoid conflicts: window.HeaderUI
(function () {
  const HeaderUI = {
    state: {
      isNotificationsOpen: false,
      isCartOpen: false,
      notifications: [],
      unreadNotifCount: 0,
      unreadMsgCount: 0,
      messages: [],
      cart: { items: [], total: 0 },
    },

    getToken() {
      const keys = ['auth_token', 'jwt_token', 'token', 'authToken'];
      console.log('DEBUG: Checking for tokens in localStorage');
      for (const k of keys) {
        const val = localStorage.getItem(k);
        console.log(`DEBUG: ${k}:`, val ? 'Found' : 'Not found');
        if (val && val !== 'null' && val !== 'undefined') {
          console.log(`DEBUG: Using token from ${k}`);
          return val;
        }
      }
      console.log('DEBUG: No token found in localStorage');
      return null;
    },

    getUser() {
      const keys = ['auth_user', 'user_info', 'logged_in_user', 'user'];
      for (const k of keys) {
        const raw = localStorage.getItem(k);
        if (!raw || raw === 'null' || raw === 'undefined') continue;
        try { return typeof raw === 'string' ? JSON.parse(raw) : raw; } catch (_) {
          return { email: String(raw), name: String(raw).split('@')[0] };
        }
      }
      return null;
    },

    isLoggedIn() {
      return !!(this.getToken() && this.getUser());
    },

    initAuthUI() {
      const userSection = document.getElementById('userSection');
      const authLinks = document.getElementById('authLinks');
      const userDropdownContainer = document.getElementById('userDropdownContainer');
      if (!userSection || !authLinks) return;

      if (!this.isLoggedIn()) {
        // Show login/register
        authLinks.style.display = 'flex';
        if (userDropdownContainer) userDropdownContainer.style.display = 'none';
        // Point wishlist to login with redirect
        const wish = document.getElementById('wishlistLink');
        if (wish) {
          const target = '/templates/UserProfile/wishlist.html';
          wish.setAttribute('href', `/templates/Authenticator/login.html?redirect=${encodeURIComponent(target)}`);
        }
        return;
      }

      const user = this.getUser();
      const name = user?.name || (user?.email ? user.email.split('@')[0] : 'User');
      const role = user?.role || 'Member';

      authLinks.style.display = 'none';
      if (userDropdownContainer) {
        // Wire wishlist link
        const wish = document.getElementById('wishlistLink');
        if (wish) wish.setAttribute('href', '/templates/UserProfile/wishlist.html');
        // Fill basic info
        const nameEls = [
          document.getElementById('userName'),
          document.getElementById('dropdownUserName')
        ];
        nameEls.forEach(el => { if (el) el.textContent = name; });
        const roleEls = [
          document.getElementById('userRole'),
          document.getElementById('dropdownUserRole')
        ];
        roleEls.forEach(el => { if (el) el.textContent = role; });
        const emailEl = document.getElementById('dropdownUserEmail');
        if (emailEl && user?.email) emailEl.textContent = user.email;

        const logoutBtn = document.getElementById('logoutBtn');
        if (logoutBtn) logoutBtn.onclick = (e) => {
          e.preventDefault();
          ['auth_user','user_info','logged_in_user','user','auth_token','jwt_token','token','authToken']
            .forEach(k => localStorage.removeItem(k));
          window.location.href = '/templates/Authenticator/login.html';
        };
        userDropdownContainer.style.display = 'block';
      }
    },

    // Notifications
    async loadNotifications() {
      const list = document.getElementById('notificationList');
      const badge = this.ensureNotificationBadge();
      if (!this.isLoggedIn()) {
        if (list) list.innerHTML = '<div class="notification-empty"><i class="fas fa-bell-slash"></i><p>Login to view notifications</p></div>';
        if (badge) { badge.textContent = '0'; badge.style.display = 'flex'; }
        return;
      }
      const token = this.getToken();
      try {
        if (list) list.innerHTML = '<div class="loading-notifications"><div class="spinner"></div></div>';
        const res = await fetch('/api/notifications', { headers: { 'Authorization': `Bearer ${token}` } });
        const data = await res.json();
        if (!res.ok || !data.success) throw new Error(data.error || 'Failed');
        this.state.notifications = data.notifications || [];
        this.state.unreadNotifCount = data.unread_count || 0;
        this.renderNotifications();
      } catch (e) {
if (list) list.innerHTML = '<div class="notification-empty"><i class="fas fa-exclamation-triangle"></i><p>Failed to load notifications</p></div>';
        if (badge) { badge.textContent = '0'; badge.style.display = 'flex'; }
      }
    },

    renderNotifications() {
      const list = document.getElementById('notificationList');
      const badge = this.ensureNotificationBadge();
      const items = this.state.notifications || [];
      if (badge) {
        const cnt = Number(this.state.unreadNotifCount || 0);
        badge.textContent = cnt > 99 ? '99+' : String(cnt);
        badge.style.display = 'flex';
      }
      if (!list) return;
      if (items.length === 0) {
        list.innerHTML = `
          <div class=\"notification-empty\">
            <i class=\"fas fa-bell\"></i>
            <p style=\"margin-bottom:4px; font-weight:600;\">No notifications yet</p>
            <small>We'll notify you about order updates and important messages.</small>
          </div>`;
        return;
      }
      list.innerHTML = items.map(n => `
        <div class=\"notification-item ${n.is_read ? '' : 'unread'}\" data-id=\"${n.id}\">
          ${n.image_url ? `<img src=\"${n.image_url}\" class=\"notification-image\" alt=\"\">` : `
            <div class=\"notification-icon\"><i class=\"fas fa-bell\"></i></div>`}
          <div class=\"notification-content\">
            <div class=\"notification-message\">${n.message || ''}</div>
            <div class=\"notification-time\">${n.time_ago || ''}</div>
          </div>
        </div>`).join('');
    },

    getNotificationLink(notif) {
      if (!notif) return null;
      const type = String(notif.type || '').toLowerCase();
      const ref = notif.reference_id;
      // Product-related notifications
      if ((type === 'price_drop' || type === 'stock_alert') && ref) {
        return `/Public/product.html?id=${encodeURIComponent(ref)}`;
      }
      // Order-related notifications
      if (type.startsWith('order_') && ref) {
        // Direct to My Orders page with an anchor or query param
        return `/templates/UserProfile/my_orders.html?orderId=${encodeURIComponent(ref)}`;
      }
      // Chat notifications - handle specially
      if (type === 'chat_message') {
        return null; // Will be handled in click event
      }
      return null;
    },

    // Messages
    async loadMessages() {
      const list = document.getElementById('messageList');
      if (!this.isLoggedIn()) {
        if (list) list.innerHTML = '<div class="message-empty"><i class="fas fa-comments"></i><p>Login to view messages</p></div>';
        return;
      }
      try {
        const token = this.getToken();
        const headers = token ? { 'Authorization': `Bearer ${token}` } : {};
        if (list) list.innerHTML = '<div class="loading-messages"><div class="spinner"></div></div>';
        const res = await fetch('/api/chats', { headers });
        if (!res.ok) throw new Error('Failed');
        const data = await res.json();
        this.state.messages = Array.isArray(data.chats) ? data.chats : [];
        this.renderMessages();
      } catch (_) {
        if (list) list.innerHTML = '<div class="message-empty"><i class="fas fa-exclamation-triangle"></i><p>Failed to load messages</p></div>';
      }
    },

    renderMessages() {
      const dropdown = document.getElementById('messageDropdown');
      const list = document.getElementById('messageList');
      if (!dropdown || !list) return;
      if (!this.isLoggedIn()) {
        list.innerHTML = '<div class="message-empty"><i class="fas fa-comments"></i><p>Login to view messages</p></div>';
        return;
      }
      const chats = this.state.messages || [];
      if (!chats.length) {
        list.innerHTML = '<div class="message-empty"><i class="fas fa-comments"></i><p>No messages</p><small>Start conversations with sellers about your orders.</small></div>';
        return;
      }
      const me = this.getUser();
      list.innerHTML = chats.map(c => {
        const isSeller = (me?.role || '').toLowerCase() === 'seller';
        const isBuyer = !isSeller && (me?.role || '').toLowerCase() !== 'rider';
        let displayName = '';
        let participantRole = '';
        if (isSeller) {
          if (c.rider_id && c.rider_name) { displayName = c.rider_name; participantRole = 'rider'; }
          else { displayName = c.buyer_name || 'Buyer'; participantRole = 'buyer'; }
        } else if (isBuyer) {
          if (c.rider_id && c.rider_name) { displayName = c.rider_name; participantRole = 'rider'; }
          else { displayName = c.seller_name || c.shop_name || 'Seller'; participantRole = 'seller'; }
        } else {
          displayName = c.participant_name || c.shop_name || c.seller_name || c.buyer_name || 'Chat';
        }
        const time = c.last_message_time ? new Date(c.last_message_time).toLocaleString() : '';
        const unread = Number(c.unread_count || 0);
        const subtitle = c.order_number ? `Order: ${c.order_number}` : '';
        return `
          <div class="message-item ${unread>0 ? 'unread' : ''}" data-chat-id="${c.id}" data-participant="${(displayName||'').replace(/"/g,'&quot;')}" data-order="${c.order_number||''}" style="cursor:pointer;">
            <div class="message-content">
              <div class="message-header-row">
                <div class="message-sender">${displayName}${unread>0 ? `<span class=\"unread-badge\">${unread}</span>`:''}</div>
                <div class="message-time">${time}</div>
              </div>
              ${subtitle ? `<div class=\"message-subtitle\">${subtitle}</div>`:''}
              <div class="message-preview">${(c.last_message||'').toString().replace(/[&<>]/g, s=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[s]))}</div>
            </div>
          </div>`;
      }).join('');
    },

    ensureMessageBadge() {
      const btn = document.getElementById('messageBtn');
      if (!btn) return null;
      let badge = btn.querySelector('#messageCount');
      if (!badge) {
        badge = document.createElement('span');
        badge.id = 'messageCount';
        badge.className = 'cart-count';
        badge.style.display = 'flex';
        badge.textContent = '0';
        btn.appendChild(badge);
      } else {
        // Ensure badge is visible by default (like notification/cart icons)
        badge.style.display = 'flex';
      }
      return badge;
    },

    renderMessageBadge() {
      const badge = this.ensureMessageBadge();
      if (!badge) return;
      
      // Always show badge, even when not logged in (show "0" like notification/cart icons)
      if (!this.isLoggedIn()) {
        badge.textContent = '0';
        badge.style.display = 'flex';
        console.log('DEBUG: Message badge shown with 0 (user not logged in)');
        return;
      }
      
      const cnt = Number(this.state.unreadMsgCount || 0);
      console.log('DEBUG: renderMessageBadge - unread count:', cnt);
      badge.textContent = cnt > 0 ? (cnt > 99 ? '99+' : String(cnt)) : '0';
      badge.style.display = 'flex';
      console.log('DEBUG: Message badge shown with count:', badge.textContent);
    },

    async refreshMessageCount() {
      await this.loadMessageCount();
    },

    async loadMessageCount() {
      const list = document.getElementById('messageList');
      console.log('DEBUG: loadMessageCount called');
      
      if (!this.isLoggedIn()) {
        // Show "0" badge when not logged in (consistent with notification/cart icons)
        this.state.unreadMsgCount = 0;
        this.renderMessageBadge();
        console.log('DEBUG: User not logged in, showing message badge with 0');
        return;
      }
      
      try {
        const token = this.getToken();
        const headers = token ? { 'Authorization': `Bearer ${token}` } : {};
        console.log('DEBUG: Loading message count with token:', token ? 'Token exists' : 'No token');
        console.log('DEBUG: Making request to /api/chats');
        
        const res = await fetch('/api/chats', { headers });
        console.log('DEBUG: API response status:', res.status);
        
        if (!res.ok) {
          console.log('DEBUG: API response not OK:', res.statusText);
          throw new Error('Failed');
        }
        
        const data = await res.json();
        console.log('DEBUG: Raw API response:', data);
        
        const chats = Array.isArray(data.chats) ? data.chats : [];
        console.log('DEBUG: Chats array:', chats);
        
        this.state.unreadMsgCount = chats.reduce((s, c) => s + (Number(c.unread_count) || 0), 0);
        console.log('DEBUG: Calculated unread message count:', this.state.unreadMsgCount);
        
        this.renderMessageBadge();
        // Optionally render dropdown placeholder if empty
        if (list && list.innerHTML.trim() === '') this.renderMessages();
      } catch (e) {
        console.log('DEBUG: Error loading message count:', e);
        const badge = this.ensureMessageBadge();
        if (badge) badge.style.display = 'none';
      }
    },
    // Cart
    async loadCart() {
      const token = this.getToken();
      const itemsEl = document.getElementById('cartDropdownItems');
      const totalEl = document.getElementById('cartTotal');
      const countEl = document.getElementById('cartCount');
      try {
        const headers = token ? { 'Authorization': `Bearer ${token}` } : {};
        const res = await fetch('/api/cart', { headers });
        const data = await res.json();
        if (!res.ok || !data.success) throw new Error('Failed to load cart');
        const items = data.items || [];
        this.state.cart.items = items;
        const total = items.reduce((s, it) => s + (Number(it.price) || 0) * (Number(it.quantity) || 1), 0);
        this.state.cart.total = total;

      if (itemsEl) {
          if (items.length === 0) {
itemsEl.innerHTML = `
              <div class="cart-empty-message">
                <i class="fas fa-shopping-bag"></i>
                <p>Your cart is empty</p>
              </div>`;
          } else {
            itemsEl.innerHTML = items.map(it => `
              <div class="cart-item">
                <img src="${it.image_url || it.image || ''}" class="cart-item-image" alt="">
                <div class="cart-item-details">
                  <div class="cart-item-name">${it.name || ''}</div>
                  <div class="cart-item-price">₱${(Number(it.price)||0).toFixed(2)} × ${it.quantity}</div>
                </div>
              </div>`).join('');
          }
          const footer = document.getElementById('cartDropdownFooter');
          if (footer) footer.style.display = items.length > 0 ? 'block' : 'none';
        }
        if (totalEl) totalEl.textContent = `₱${total.toFixed(2)}`;
        if (countEl) { countEl.textContent = String(items.length); countEl.style.display = 'flex'; }
      } catch (_) {
        if (itemsEl) itemsEl.innerHTML = '<div class="cart-empty-message"><p>Unable to load cart</p></div>';
        if (countEl) { countEl.textContent = '0'; countEl.style.display = 'flex'; }
      }
    },

    bindEvents() {
      const notifBtn = document.getElementById('notificationBtn');
      const notifDropdown = document.getElementById('notificationDropdown');
      const markAllReadBtn = document.getElementById('markAllRead');
      const msgBtn = document.getElementById('messageBtn');
      const msgDropdown = document.getElementById('messageDropdown');
      const cartBtn = document.getElementById('cartBtn');
      const cartDropdown = document.getElementById('cartDropdown');

      const attachHoverDropdown = (btn, dropdown, onOpen) => {
        if (!btn || !dropdown) return;
        let hideTimer;
        const show = () => { dropdown.style.display = 'block'; try { onOpen && onOpen(); } catch(_) {} };
        const hide = () => { dropdown.style.display = 'none'; };
        btn.addEventListener('mouseenter', () => { clearTimeout(hideTimer); show(); });
        btn.addEventListener('mouseleave', () => {
          hideTimer = setTimeout(() => { if (!dropdown.matches(':hover')) hide(); }, 220);
        });
        dropdown.addEventListener('mouseenter', () => { clearTimeout(hideTimer); });
        dropdown.addEventListener('mouseleave', () => { hideTimer = setTimeout(hide, 220); });
      };

      if (notifBtn && notifDropdown) {
        const toggle = (e) => {
          e?.preventDefault(); e?.stopPropagation();
          const show = notifDropdown.style.display === 'block' ? 'none' : 'block';
          notifDropdown.style.display = show;
          if (show === 'block') this.loadNotifications();
        };
        if (window.innerWidth > 768) {
          attachHoverDropdown(notifBtn, notifDropdown, () => this.loadNotifications());
        } else {
          notifBtn.addEventListener('click', toggle);
          document.addEventListener('click', (e) => {
            if (!notifDropdown.contains(e.target) && !notifBtn.contains(e.target)) notifDropdown.style.display = 'none';
          });
        }
        // Click on a notification item -> mark read then navigate if a link is available
        const list = document.getElementById('notificationList');
        if (list) {
          list.addEventListener('click', async (e) => {
            const item = e.target.closest('.notification-item');
            if (!item) return;
            e.preventDefault(); e.stopPropagation();
            const id = item.getAttribute('data-id');
            const notif = (this.state.notifications || []).find(n => String(n.id) === String(id));
            const url = this.getNotificationLink(notif);
            try {
              const token = this.getToken();
              if (token && id) {
                await fetch(`/api/notifications/${encodeURIComponent(id)}/read`, { method: 'PUT', headers: { 'Authorization': `Bearer ${token}` } });
              }
            } catch(_) {}
            
            // Handle chat notifications specially
            if (notif && notif.type === 'chat_message') {
              // Open the chat center
              try {
                this.openGlobalChatCenter();
              } catch (_) {
                // Fallback for buyer account page
                if (window.openAccountChatCenter) {
                  window.openAccountChatCenter();
                }
              }
              return;
            }
            
            if (url) {
              window.location.href = url;
            }
          });
        }
        if (markAllReadBtn) {
          markAllReadBtn.addEventListener('click', async (e) => {
            e.preventDefault(); e.stopPropagation();
            try {
              const token = this.getToken();
              if (!token) return;
              const res = await fetch('/api/notifications/read-all', { method: 'PUT', headers: { 'Authorization': `Bearer ${token}` } });
              if (res.ok) { await this.loadNotifications(); }
            } catch(_) {}
          });
        }
      }

      // Messages: click opens Chat Center globally; hover can still show dropdown previews on desktop
      if (msgBtn) {
        // Click: open Chat Center if available, else show dropdown
        msgBtn.addEventListener('click', (e) => {
          e?.preventDefault();
          e?.stopPropagation();
          if (e?.stopImmediatePropagation) e.stopImmediatePropagation();
          this.loadMessageCount();
          // If dropdown exists, toggle it and load messages
          if (msgDropdown) {
            const show = msgDropdown.style.display === 'block' ? 'none' : 'block';
            msgDropdown.style.display = show;
            if (show === 'block') { this.loadMessages(); }
          } else {
            try { this.openGlobalChatCenter(); } catch (_) {}
          }
        });
        
        if (window.innerWidth > 768 && msgDropdown) {
          attachHoverDropdown(msgBtn, msgDropdown, () => {
            this.loadMessageCount();
            this.loadMessages();
          });
        }
        // Click on a message item -> open specific chat
        if (msgDropdown) {
          const list = document.getElementById('messageList');
          list && list.addEventListener('click', (e) => {
            const item = e.target.closest('.message-item');
            if (!item) return;
            e.preventDefault(); e.stopPropagation();
            const chatId = item.getAttribute('data-chat-id');
            const participant = item.getAttribute('data-participant') || '';
            const order = item.getAttribute('data-order') || '';
            this.openGlobalChatCenter({ chatId, participant, order });
          });
        }
      }

      if (cartBtn && cartDropdown) {
        const toggle = (e) => { e?.preventDefault(); e?.stopPropagation();
          const show = cartDropdown.style.display === 'block' ? 'none' : 'block';
          cartDropdown.style.display = show; if (show === 'block') this.loadCart(); };
        if (window.innerWidth > 768) {
          attachHoverDropdown(cartBtn, cartDropdown, () => this.loadCart());
        } else {
          cartBtn.addEventListener('click', toggle);
          document.addEventListener('click', (e) => {
            if (!cartDropdown.contains(e.target) && !cartBtn.contains(e.target)) cartDropdown.style.display = 'none';
          });
        }
      }
    },

    init() {
      this.initAuthUI();
      this.bindEvents();
      
      // initial badge/cart fetch
      this.loadNotifications();
      this.loadMessageCount();
      this.loadCart();
      // start realtime notifications (SSE) with graceful fallback to polling
      this.initRealtime();
    },

    initRealtime() {
      try {
        // Avoid conflicts if page provides its own NotificationManager
        if (window.notificationManager || window.NotificationManager) {
          // Fallback to light polling just for counts
          try { setInterval(() => { this.loadNotifications(); this.loadMessageCount(); }, 30000); } catch(_) {}
          return;
        }
        const token = this.getToken();
        if (!token || typeof EventSource === 'undefined') {
          try { setInterval(() => { this.loadNotifications(); this.loadMessageCount(); }, 30000); } catch(_) {}
          return;
        }
        // Seed lastId from current notifications if available
        const lastId = (this.state.notifications && this.state.notifications.length > 0) ? this.state.notifications[0].id : 0;
        const url = `/api/notifications/stream?token=${encodeURIComponent(token)}${lastId ? `&lastId=${lastId}` : ''}`;
        this._es && this._es.close && this._es.close();
        this._es = new EventSource(url);
        this._es.onmessage = (evt) => {
          if (!evt || !evt.data) return;
          try {
            const data = JSON.parse(evt.data);
            if (!data || !data.id) return; // ignore heartbeats
            // Prepend and clamp list
            this.state.notifications = [data, ...(this.state.notifications || [])].slice(0, 50);
            if (!data.is_read) {
              // Update notification counter
              this.state.unreadNotifCount = (Number(this.state.unreadNotifCount) || 0) + 1;
              // If this is a chat message notification, also bump the message badge
              if (String(data.type || '').toLowerCase() === 'chat_message') {
                this.state.unreadMsgCount = (Number(this.state.unreadMsgCount) || 0) + 1;
                // Ensure the message badge in the header reflects the new count
                try { this.renderMessageBadge(); } catch (_) {}
              }
            }
            this.renderNotifications();
          } catch (_) { /* ignore non-JSON events */ }
        };
        this._es.onerror = () => {
          try { this._es && this._es.close(); } catch(_) {}
          // Fallback to polling
          try { setInterval(() => { this.loadNotifications(); this.loadMessageCount(); }, 30000); } catch(_) {}
        };
      } catch (_) {
        try { setInterval(() => { this.loadNotifications(); this.loadMessageCount(); }, 30000); } catch(_) {}
      }
    },

    ensureNotificationBadge() {
      const btn = document.getElementById('notificationBtn');
      if (!btn) return null;
      let badge = btn.querySelector('#notificationCount');
      if (!badge) {
        badge = document.createElement('span');
        badge.id = 'notificationCount';
        badge.className = 'cart-count';
        badge.style.display = 'flex';
        badge.textContent = '0';
        btn.appendChild(badge);
      }
      return badge;
    },

    ensureChatStyles() {
      const id = 'chat-stylesheet';
      if (!document.getElementById(id)) {
        const link = document.createElement('link');
        link.id = id;
        link.rel = 'stylesheet';
        link.href = '/static/css/chat.css';
        document.head.appendChild(link);
      }
    },

    ensureLeafletAssets() {
      if (!document.getElementById('leaflet-css')) {
        const l = document.createElement('link');
        l.id = 'leaflet-css';
        l.rel = 'stylesheet';
        l.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
        document.head.appendChild(l);
      }
      return new Promise((resolve) => {
        if (window.L && typeof window.L.map === 'function') { resolve(); return; }
        if (!document.getElementById('leaflet-js')) {
          const s = document.createElement('script');
          s.id = 'leaflet-js';
          s.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
          s.onload = () => resolve();
          s.onerror = () => resolve();
          document.head.appendChild(s);
        } else {
          setTimeout(resolve, 50);
        }
      });
    },

    ensureRiderMapScript() {
      return new Promise((resolve) => {
        if (window.RiderMap || window.riderMap) { resolve(); return; }
        if (!document.getElementById('rider-map-js')) {
          const s = document.createElement('script');
          s.id = 'rider-map-js';
          s.src = '/static/js/rider-map.js';
          s.onload = () => resolve();
          s.onerror = () => resolve();
          document.head.appendChild(s);
        } else {
          setTimeout(resolve, 50);
        }
      });
    },

    // Opens the Chat Center globally. If the modal is not present, dynamically injects it and loads the shared script
    openGlobalChatCenter(opts) {
      const openNow = () => {
        try {
          if (window.ChatCenter && typeof window.ChatCenter.open === 'function') {
            window.ChatCenter.open();
            // If a specific chat is requested, select it after opening
            if (opts && opts.chatId && typeof window.ChatCenter.selectChat === 'function') {
              setTimeout(() => window.ChatCenter.selectChat(Number(opts.chatId), opts.participant || '', opts.order || ''), 300);
            }
            return true;
          }
        } catch (_) {}
        return false;
      };

      // Ensure chat styles present for the modal UI
      this.ensureChatStyles();
      // If ChatCenter is already loaded, just open it
      if (openNow()) return;

      // Ensure a modal container exists (ChatCenter will inject if missing)
      let modalEl = document.getElementById('chatCenterModal');
      if (!modalEl) {
        const placeholder = document.createElement('div');
        placeholder.id = 'chatCenterPlaceholder';
        document.body.appendChild(placeholder);
      }

      // Load the shared Chat Center script once then open
      const scriptId = 'chat-center-script';
      if (!document.getElementById(scriptId)) {
        const s = document.createElement('script');
        s.id = scriptId;
        s.src = '/static/js/chat-center.js';
        s.onload = () => { setTimeout(() => openNow() || (window.location.href = '/templates/Public/orders.html?openChatCenter=1'), 10); };
        s.onerror = () => { window.location.href = '/templates/Public/orders.html?openChatCenter=1'; };
        document.head.appendChild(s);
      } else {
        // Script tag exists but module not ready yet; wait briefly then open
        setTimeout(() => openNow() || (window.location.href = '/templates/Public/orders.html?openChatCenter=1'), 50);
      }
    },

    // Opens a global tracking modal by order number; injects modal if not present and fetches order/tracking details
    async openGlobalTrackingModalByOrderNumber(orderNumber) {
      if (!orderNumber) return;

      const ensureTrackingModal = () => {
        let modal = document.getElementById('globalTrackingModal');
        if (modal) return modal;
        const wrapper = document.createElement('div');
        wrapper.innerHTML = `
          <div class="modal fade" id="globalTrackingModal" tabindex="-1">
            <div class="modal-dialog">
              <div class="modal-content">
                <div class="modal-header">
                  <h5 class="modal-title"><i class="fas fa-truck me-2"></i>Track Delivery</h5>
                  <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                  <div id="trackingModalBody">
                    <div class="d-flex align-items-center gap-2 text-muted"><div class="spinner-border spinner-border-sm"></div> Loading tracking details...</div>
                  </div>
                </div>
                <div class="modal-footer">
                  <button class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
                </div>
              </div>
            </div>
          </div>`;
        document.body.appendChild(wrapper);
        return document.getElementById('globalTrackingModal');
      };

      const formatStatusDots = (status) => {
        const steps = ['pending','confirmed','prepared','shipped','delivered'];
        if (status === 'cancelled') return '<small class="text-danger"><i class="fas fa-times-circle me-1"></i>Cancelled</small>';
        const idx = steps.indexOf((status||'').toLowerCase());
        return steps.map((s, i) => {
          const active = i <= idx;
          const current = i === idx;
          const bg = active ? (current ? 'var(--shopee-orange, #ff6b63)' : '#28a745') : '#dee2e6';
          const border = current ? '2px solid var(--shopee-orange, #ff6b63)' : '1px solid #adb5bd';
          return `<span style="display:inline-block;width:8px;height:8px;border-radius:50%;margin:0 2px;background:${bg};border:${border}"></span>`;
        }).join('');
      };

      const modalEl = ensureTrackingModal();
      let modal;
      try { modal = new bootstrap.Modal(modalEl); } catch(_) {}
      if (modal) modal.show();

      // Try to resolve order from currentOrders on page first
      let order = null;
      try {
        if (Array.isArray(window.currentOrders)) {
          order = window.currentOrders.find(o => String(o.order_number) === String(orderNumber));
        }
      } catch(_) {}

      // If not found, fetch via API
      if (!order) {
        try {
          const token = (window.AuthManager && AuthManager.getAuthToken) ? AuthManager.getAuthToken() : null;
          const headers = token ? { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' } : { 'Content-Type': 'application/json' };
          // Try a filtered fetch first; if backend ignores filter, we'll filter client-side
          const res = await fetch(`/api/orders?order_number=${encodeURIComponent(orderNumber)}`, { headers });
          if (res.ok) {
            const data = await res.json();
            const list = data.orders || [];
            order = list.find(o => String(o.order_number) === String(orderNumber)) || null;
          }
          if (!order) {
            // Fallback: get all, then find (may be heavy but only on demand)
            const resAll = await fetch('/api/orders', { headers });
            if (resAll.ok) {
              const dataAll = await resAll.json();
              const listAll = dataAll.orders || [];
              order = listAll.find(o => String(o.order_number) === String(orderNumber)) || null;
            }
          }
        } catch(_) {}
      }

      const body = document.getElementById('trackingModalBody');
      if (!body) return;

      if (!order) {
        body.innerHTML = '<div class="text-danger">Unable to find order details for tracking.</div>';
        return;
      }

      const status = (order.status || 'pending').toLowerCase();
      const statusLabelMap = { pending:'Pending', confirmed:'Confirmed', prepared:'Prepared', shipped:'Shipped', delivered:'Delivered', cancelled:'Cancelled' };
      const statusLabel = statusLabelMap[status] || order.status || 'Status';
      const trackingNumber = order.tracking_number || '';
      const items = Array.isArray(order.items) ? order.items : [];
      const firstItemName = items[0]?.name || items[0]?.product_name || 'Order Items';

      body.innerHTML = `
        <div>
          <div class="d-flex justify-content-between align-items-center mb-2">
            <div class="fw-semibold">Order #${this.escapeHtml ? this.escapeHtml(order.order_number) : order.order_number}</div>
            <div><span class="badge bg-secondary">${statusLabel}</span></div>
          </div>
          <div class="mb-3">${formatStatusDots(status)}</div>
          ${trackingNumber ? `
            <div class="mb-3 p-2" style="background:#f8f9fa;border:1px solid #e9ecef;border-radius:8px;">
              <div class="small text-muted">Tracking Number</div>
              <div class="fw-semibold">${trackingNumber}</div>
            </div>` : ''}
          <div class="small text-muted">Latest item</div>
          <div class="fw-medium mb-3">${this.escapeHtml ? this.escapeHtml(firstItemName) : firstItemName}</div>
          <div class="d-flex gap-2">
            ${trackingNumber ? `<button id=\"copyTrackingBtn\" class=\"btn btn-sm btn-outline-primary\" onclick=\"HeaderUI.copyTrackingNumber('${trackingNumber}')\"><i class=\"fas fa-copy me-1\"></i>Copy Tracking</button>` : ''}
            <button class=\"btn btn-sm btn-outline-secondary\" onclick=\"(function(){ if(window.viewOrderDetails && typeof window.viewOrderDetails==='function'){ const o = (window.currentOrders||[]).find(x=>String(x.order_number)==='${orderNumber}'); if(o){ viewOrderDetails(o.id); } else { window.location.href='/templates/Public/orders.html'; } } else { window.location.href='/templates/Public/orders.html'; } })()\"><i class=\"fas fa-eye me-1\"></i>View Details</button>
          </div>
          <div class="mt-3">
            <div class="small text-muted mb-1"><i class="fas fa-stream me-1"></i>Delivery Timeline</div>
            <ul id=\"trackingTimeline\" class=\"list-unstyled mb-0\"><li class=\"text-muted\">Loading timeline...</li></ul>
          </div>
          <div class=\"mt-3\">
            <div class=\"small text-muted mb-1\"><i class=\"fas fa-map-marked-alt me-1\"></i>Live Map</div>
            <div id=\"trackingMap\" style=\"width:100%;height:280px;border-radius:8px;border:1px solid #e9ecef;background:#f8f9fa;\"></div>
          </div>
        </div>`;

      // Initialize map if coordinates are present
      try {
        await this.ensureLeafletAssets();
        await this.ensureRiderMapScript();
        const bLat = Number(order.buyer_lat || order.shipping?.lat || order.shipping?.latitude);
        const bLng = Number(order.buyer_lng || order.shipping?.lng || order.shipping?.longitude);
        const sLat = Number(order.seller_lat || order.origin?.lat);
        const sLng = Number(order.seller_lng || order.origin?.lng);
        if (isFinite(bLat) && isFinite(bLng)) {
          if (window.RiderMap) {
            const rm = new RiderMap();
            await rm.initializeMap('trackingMap');
            const deliveriesForMap = [{
              id: order.id,
              order_number: order.order_number,
              customer_name: order.buyer?.name || order.customer_name || 'Customer',
              customer_phone: order.buyer?.phone || order.customer_phone || 'N/A',
              delivery_address: order.shipping?.full_address || order.shipping?.address || '',
              status: order.status,
              buyer_lat: bLat,
              buyer_lng: bLng,
              seller_lat: isFinite(sLat) ? sLat : undefined,
              seller_lng: isFinite(sLng) ? sLng : undefined,
              seller_name: order.items && order.items[0] && (order.items[0].seller_info?.business_name || 'Shop')
            }];
            rm.loadDeliveryPins(deliveriesForMap);
            if (isFinite(sLat) && isFinite(sLng)) {
              rm.showRoute(deliveriesForMap);
            } else if (rm.map) {
              rm.map.setView([bLat, bLng], 14);
            }
          } else if (window.L) {
            const map = L.map('trackingMap').setView([bLat, bLng], 14);
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19 }).addTo(map);
            L.marker([bLat, bLng]).addTo(map).bindPopup('Customer');
            if (isFinite(sLat) && isFinite(sLng)) {
              L.marker([sLat, sLng]).addTo(map).bindPopup('Shop');
              const group = L.featureGroup([L.marker([bLat,bLng]), L.marker([sLat,sLng])]);
              map.fitBounds(group.getBounds().pad(0.2));
            }
          }
        } else {
          const mapEl = document.getElementById('trackingMap');
          if (mapEl) mapEl.style.display = 'none';
        }
      } catch(_) {}

      // Load delivery history timeline if available
      try {
        const token = (window.AuthManager && AuthManager.getAuthToken) ? AuthManager.getAuthToken() : null;
        const headers = token ? { 'Authorization': `Bearer ${token}` } : {};
        const resHist = await fetch(`/api/orders/${order.id}/history`, { headers });
        const listEl = document.getElementById('trackingTimeline');
        if (resHist.ok && listEl) {
          const histData = await resHist.json();
          const history = histData.history || [];
          if (history.length === 0) {
            listEl.innerHTML = '<li class="text-muted">No history available</li>';
          } else {
            listEl.innerHTML = history.map(h => {
              const when = h.timestamp ? new Date(h.timestamp).toLocaleString() : '';
              const label = (h.status || '').toLowerCase() === 'pending' ? 'Order Placed' : (h.status || '').replace(/_/g, ' ').replace(/\b\w/g, c=>c.toUpperCase());
              return `<li class="mb-1 d-flex align-items-start">
                        <i class="fas fa-check-circle text-success me-2 mt-1"></i>
                        <div><div class="fw-semibold">${label}</div><div class="small text-muted">${when}</div></div>
                      </li>`;
            }).join('');
          }
        }
      } catch(_) {}
    }
  
};

window.HeaderUI = HeaderUI;
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => HeaderUI.init());
  } else {
    try { HeaderUI.init(); } catch(_) {}
  }

  // Expose a tiny global helper for existing inline onclick hooks
  window.openGlobalTrackingModalByOrderNumber = function(orderNumber){
    return HeaderUI.openGlobalTrackingModalByOrderNumber(orderNumber);
  };

// Add clipboard helpers at the end of the namespace
HeaderUI.copyTextToClipboard = function(text){
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
  } catch(_) {}
  return new Promise((resolve) => {
    const ta = document.createElement('textarea');
    ta.value = text; ta.style.position='fixed'; ta.style.opacity='0';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch(_) {}
    document.body.removeChild(ta);
    resolve();
  });
};

HeaderUI.copyTrackingNumber = async function(trackingNumber){
  try {
    await HeaderUI.copyTextToClipboard(trackingNumber);
    const btn = document.getElementById('copyTrackingBtn');
    if (btn) {
      const prev = btn.innerHTML;
      btn.innerHTML = '<i class="fas fa-check me-1"></i>Copied';
      btn.disabled = true;
      setTimeout(() => { btn.innerHTML = prev; btn.disabled = false; }, 1500);
    }
  } catch(_) {}
};

})();
