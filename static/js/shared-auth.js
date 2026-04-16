/**
 * Shared Authentication System
 * Ensures consistent authentication handling across all pages
 * Usage: Include this script in all pages that need authentication
 */

// Auto-detect API origin and proxy relative /api calls when running from a static server (e.g., port 5500)
(function setupApiProxy(){
    try {
        const currentOrigin = window.location.origin;
        const isStaticDev = currentOrigin.includes(':5500') || currentOrigin.includes(':5501');
        const DEFAULT_API_ORIGIN = 'http://127.0.0.1:5000';
        const API_ORIGIN = window.API_ORIGIN || (isStaticDev ? DEFAULT_API_ORIGIN : currentOrigin);
        const nativeFetch = window.fetch.bind(window);
        window.fetch = function(input, init){
            try {
                let url = typeof input === 'string' ? input : (input && input.url);
                if (typeof url === 'string' && url.startsWith('/api')) {
                    const proxied = API_ORIGIN + url;
                    if (typeof input === 'string') {
                        return nativeFetch(proxied, init);
                    } else {
                        return nativeFetch(new Request(proxied, input), init);
                    }
                }
            } catch (_) {}
            return nativeFetch(input, init);
        };
        // Expose for debugging
        window.__API_ORIGIN__ = API_ORIGIN;
    } catch (_) {}
})();

// Session Manager - Handles token validation and user data
class SessionManager {
    static getUserInfo() {
        try {
            const userDataRaw = localStorage.getItem('auth_user');
            if (!userDataRaw) return null;
            
            const userData = JSON.parse(userDataRaw);
            
            // Validate user data structure
            if (!userData || typeof userData !== 'object') {
                console.warn('Invalid user data structure, clearing session');
                this.clearSession();
                return null;
            }
            
            return userData;
        } catch (error) {
            console.error('Error parsing user info:', error);
            this.clearSession();
            return null;
        }
    }
    
    static getValidToken() {
        const token = localStorage.getItem('auth_token');
        if (!token) return null;
        
        try {
            // Basic JWT structure validation
            const parts = token.split('.');
            if (parts.length !== 3) {
                console.warn('Invalid token format, clearing session');
                this.clearSession();
                return null;
            }
            
            // Decode payload to check expiration
            const payload = JSON.parse(atob(parts[1]));
            const currentTime = Math.floor(Date.now() / 1000);
            
            if (payload.exp && payload.exp < currentTime) {
                console.warn('Token expired, clearing session');
                this.clearSession();
                return null;
            }
            
            return token;
        } catch (error) {
            console.error('Error validating token:', error);
            this.clearSession();
            return null;
        }
    }
    
    static isAuthenticated() {
        const user = this.getUserInfo();
        const token = this.getValidToken();
        return !!(user && token);
    }
    
    static clearSession() {
        const keysToRemove = [
            'auth_user', 'user_info', 'loggedInUser', 'logged_in_user', 'user',
            'auth_token', 'jwt_token', 'token', 'authToken'
        ];
        
        keysToRemove.forEach(key => localStorage.removeItem(key));
    }
}

// AuthManager Class - Handles login state persistence and UI updates
class AuthManager {
    static saveAuthState(userData, token) {
        // Standardize storage
        localStorage.setItem('auth_user', JSON.stringify(userData));
        localStorage.setItem('auth_token', token);
        
        // Clean up any old keys for consistency
        const oldUserKeys = ['user_info', 'loggedInUser', 'logged_in_user', 'user'];
        const oldTokenKeys = ['jwt_token', 'token', 'authToken'];
        oldUserKeys.forEach(key => localStorage.removeItem(key));
        oldTokenKeys.forEach(key => localStorage.removeItem(key));
        
        // Update UI immediately
        this.updateLoginState(true);
        
        // Trigger storage event for other tabs
        window.dispatchEvent(new StorageEvent('storage', {
            key: 'auth_user',
            newValue: JSON.stringify(userData)
        }));
    }

    static clearAuthState() {
        // Get user info before clearing
        const userInfo = this.getAuthUser();
        
        // Clear user-specific profile picture
        if (userInfo && userInfo.id) {
            localStorage.removeItem(`user_profile_photo_${userInfo.id}`);
        }
        
        // Clear all auth-related data
        localStorage.removeItem('auth_user');
        localStorage.removeItem('auth_token');
        localStorage.removeItem('jwt_token');
        
        // Clear any cart data associated with the user
        if (userInfo) {
            localStorage.removeItem(`cart_${userInfo.email || userInfo.id || 'user'}`);
        }
        
        // Clear any pending redirects or cart items
        sessionStorage.removeItem('redirect_after_login');
        sessionStorage.removeItem('pending_cart_item');
        
        // Update UI state
        this.updateLoginState(false);
    }

    static logout() {
        // Prevent multiple simultaneous logout calls
        if (this._loggingOut) return;
        
        // Ask for confirmation
        if (!confirm('Are you sure you want to logout?')) {
            return;
        }
        
        this._loggingOut = true;
        
        try {
            // Clear all auth data
            localStorage.removeItem('auth_user');
            localStorage.removeItem('auth_token');
            localStorage.removeItem('jwt_token');
            localStorage.removeItem('cart_data');
            
            // Clear session data
            sessionStorage.clear();
            
            // Update UI state immediately
            this.updateLoginState(false);
            
            // Show success message briefly
            if (typeof showNotification === 'function') {
                showNotification('Logging out...', 'info');
            }
            
            // Redirect to home page immediately
            setTimeout(() => {
                window.location.href = '/templates/Public/index.html';
            }, 300);
        } finally {
            // Reset flag after a short delay
            setTimeout(() => {
                this._loggingOut = false;
            }, 1000);
        }
    }

    static isLoggedIn() {
        return SessionManager.isAuthenticated();
    }

    static getAuthUser() {
        return SessionManager.getUserInfo();
    }

    static getAuthToken() {
        return SessionManager.getValidToken();
    }

    // Login method for compatibility
    static async login(email, password) {
        try {
            const response = await fetch('/api/auth/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ email, password })
            });

            const data = await response.json();

            if (response.ok && data.token) {
                this.saveAuthState(data.user, data.token);
                return { success: true, user: data.user };
            } else {
                return { success: false, error: data.error || 'Login failed' };
            }
        } catch (error) {
            console.error('Login error:', error);
            return { success: false, error: 'Network error during login' };
        }
    }

    // Compatibility methods for the old auth-manager.js interface
    static getUserInfo() {
        return this.getAuthUser();
    }

    static isAuthenticated() {
        return this.isLoggedIn();
    }

    static updateLoginState(isLoggedIn) {
        const authLinks = document.getElementById('authLinks');
        const userDropdownContainer = document.getElementById('userDropdownContainer');
        
        if (isLoggedIn) {
            const user = this.getAuthUser();
            if (!user) return;
            
            // Hide auth links, show user dropdown
            if (authLinks) authLinks.style.display = 'none';
            if (userDropdownContainer) {
                userDropdownContainer.style.display = 'block';
                this.updateUserInfo(user);
            }
            
            // Update any standalone auth links for compatibility
            this.updateStandaloneAuthLinks(user);
        } else {
            // Show auth links, hide user dropdown
            if (authLinks) authLinks.style.display = 'block';
            if (userDropdownContainer) userDropdownContainer.style.display = 'none';
            
            // Reset standalone auth links
            this.resetStandaloneAuthLinks();
        }
    }

    static updateUserInfo(user) {
        // Update user name
        const userNameElements = document.querySelectorAll('#userName, #dropdownUserName');
        userNameElements.forEach(element => {
            if (element) {
                element.textContent = user.name || (user.email ? user.email.split('@')[0] : 'User');
            }
        });

        // Update user email
        const userEmailElements = document.querySelectorAll('#dropdownUserEmail');
        userEmailElements.forEach(element => {
            if (element) {
                element.textContent = user.email || 'user@email.com';
            }
        });

        // Update user role
        const userRoleElements = document.querySelectorAll('#userRole, #dropdownUserRole');
        userRoleElements.forEach(element => {
            if (element) {
                element.textContent = user.role || 'Customer';
            }
        });

        // Update role-specific dashboard links
        this.updateRoleDashboard(user);
    }

    static updateRoleDashboard(user) {
        const roleDashboardSection = document.getElementById('roleDashboardSection');
        const roleDivider = document.getElementById('roleDivider');
        
        if (!roleDashboardSection) return;
        
        let dashboardHtml = '';
        
        switch (user.role) {
            case 'seller':
                dashboardHtml = `
                    <a href="../SellerDashboard/sellerdashboard.html" class="dropdown-item">
                        <i class="fas fa-store"></i>
                        <span>Seller Dashboard</span>
                    </a>
                    <a href="../SellerDashboard/inventory.html" class="dropdown-item">
                        <i class="fas fa-boxes"></i>
                        <span>Inventory</span>
                    </a>
                    <a href="../SellerDashboard/add_product.html" class="dropdown-item">
                        <i class="fas fa-plus-circle"></i>
                        <span>Add Product</span>
                    </a>`;
                break;
            case 'rider':
                dashboardHtml = `
                    <a href="../RiderDashboard/rider-dashboard.html" class="dropdown-item">
                        <i class="fas fa-bicycle"></i>
                        <span>Rider Dashboard</span>
                    </a>`;
                break;
            case 'admin':
                dashboardHtml = `
                    <a href="/admin/dashboard" class="dropdown-item">
                        <i class="fas fa-crown"></i>
                        <span>Admin Dashboard</span>
                    </a>`;
                break;
            default:
                // For buyers or users without specific roles
                dashboardHtml = `
                    <a href="/Public/become-seller.html" class="dropdown-item">
                        <i class="fas fa-store"></i>
                        <span>Become a Seller</span>
                    </a>
                    <a href="/Public/become-rider.html" class="dropdown-item">
                        <i class="fas fa-motorcycle"></i>
                        <span>Become a Rider</span>
                    </a>`;
        }
        
        roleDashboardSection.innerHTML = dashboardHtml;
        
        if (roleDivider) {
            roleDivider.style.display = dashboardHtml.trim() ? 'block' : 'none';
        }
    }

    // For compatibility with pages that use standalone auth links (like cart.html)
    static updateStandaloneAuthLinks(user) {
        const standaloneAuthLinks = document.querySelectorAll('#authLinks:not([style*="display: none"])');
        
        standaloneAuthLinks.forEach(authLinks => {
            if (!authLinks.querySelector('.user-dropdown-container')) {
                const userName = user.name || (user.email ? user.email.split('@')[0] : 'User');
                
                authLinks.innerHTML = `
                    <div class="dropdown">
                        <a class="action-btn dropdown-toggle" href="#" role="button" data-bs-toggle="dropdown" aria-expanded="false">
                            <div class="user-avatar">
                                ${userName.charAt(0).toUpperCase()}
                            </div>
                            <span class="user-name d-none d-lg-inline">${this.escapeHtml(userName)}</span>
                        </a>
                        <ul class="dropdown-menu dropdown-menu-end">
                            <li><a class="dropdown-item" href="../UserProfile/account.html">
                                <i class="fas fa-user-circle me-2"></i>Profile
                            </a></li>
                            <li><a class="dropdown-item" href="orders.html">
                                <i class="fas fa-shopping-bag me-2"></i>My Orders
                            </a></li>
                            <li><a class="dropdown-item" href="#">
                                <i class="fas fa-heart me-2"></i>Wishlist
                            </a></li>
                            <li><hr class="dropdown-divider"></li>
                            ${user.role === 'seller' ? `
                            <li><a class="dropdown-item" href="../SellerDashboard/sellerdashboard.html">
                                <i class="fas fa-tachometer-alt me-2"></i>Seller Dashboard
                            </a></li>
                            <li><hr class="dropdown-divider"></li>
                            ` : ''}
                            ${user.role === 'admin' ? `
                            <li><a class="dropdown-item" href="/admin/dashboard">
                                <i class="fas fa-tools me-2"></i>Admin Panel
                            </a></li>
                            <li><hr class="dropdown-divider"></li>
                            ` : ''}
                            <li><a class="dropdown-item text-danger" href="#" onclick="AuthManager.logout(); return false;">
                                <i class="fas fa-sign-out-alt me-2"></i>Logout
                            </a></li>
                        </ul>
                    </div>
                `;
                
                // Re-initialize Bootstrap dropdown
                setTimeout(() => {
                    const dropdownElement = authLinks.querySelector('[data-bs-toggle="dropdown"]');
                    if (dropdownElement && typeof bootstrap !== 'undefined') {
                        new bootstrap.Dropdown(dropdownElement);
                    }
                }, 100);
            }
        });
    }

    static resetStandaloneAuthLinks() {
        const standaloneAuthLinks = document.querySelectorAll('#authLinks:not([style*="display: none"])');
        
        standaloneAuthLinks.forEach(authLinks => {
            authLinks.innerHTML = `
                <a href="../Authenticator/login.html" class="action-btn login-btn">
                    <i class="fas fa-sign-in-alt"></i>
                    <span class="btn-text">Login</span>
                </a>
                <a href="../Authenticator/register.html" class="action-btn register-btn">
                    <i class="fas fa-user-plus"></i>
                    <span class="btn-text">Register</span>
                </a>
            `;
        });
    }

    static checkAuthAndRedirect() {
        if (!this.isLoggedIn()) {
            const currentPath = window.location.pathname + window.location.search;
            sessionStorage.setItem('redirect_after_login', currentPath);
            window.location.href = '../Authenticator/login.html';
            return false;
        }
        return true;
    }

    static escapeHtml(text) {
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

    // Initialize authentication state
    static init() {
        // Check and update auth state on load
        if (this.isLoggedIn()) {
            this.updateLoginState(true);
        } else {
            this.updateLoginState(false);
        }

        // Listen for storage changes (for multi-tab sync)
        window.addEventListener('storage', (e) => {
            if (e.key === 'auth_user' || e.key === 'auth_token') {
                const isLoggedIn = this.isLoggedIn();
                this.updateLoginState(isLoggedIn);
            }
        });

        // Listen for custom auth events
        document.addEventListener('auth:login', (e) => {
            this.updateLoginState(true);
        });

        document.addEventListener('auth:logout', (e) => {
            this.updateLoginState(false);
        });
        
        // Initialize Profile Photo Manager
        ProfilePhotoManager.init();
        
        // DEBUG: Log current authentication status
        console.log('🔐 AuthManager initialized');
        console.log('   - isLoggedIn:', this.isLoggedIn());
        console.log('   - User:', this.getAuthUser());
        console.log('   - Token:', this.getAuthToken() ? 'Present' : 'Missing');
    }
}

// Profile Photo Manager Class - Handles profile photo functionality across all pages
class ProfilePhotoManager {
    static AVATAR_SELECTORS = [
        '.user-avatar',
        '.user-avatar-large',
        '.profile-photo-img'
    ];
    
    /**
     * Get user-specific storage key
     */
    static getStorageKey() {
        const user = AuthManager.getAuthUser();
        if (!user || !user.id) return 'user_profile_photo_guest';
        return `user_profile_photo_${user.id}`;
    }

    /**
     * Initialize profile photo manager
     */
    static init() {
        this.loadAndDisplayProfilePhoto();
        
        // Listen for storage changes to sync across tabs
        window.addEventListener('storage', (e) => {
            const storageKey = this.getStorageKey();
            if (e.key === storageKey) {
                this.loadAndDisplayProfilePhoto();
            }
        });
        
        console.log('📸 ProfilePhotoManager initialized');
    }

    /**
     * Load and display profile photo from localStorage or backend
     */
    static async loadAndDisplayProfilePhoto() {
        const storageKey = this.getStorageKey();
        let savedPhoto = localStorage.getItem(storageKey);
        
        // If no photo in localStorage, try loading from backend
        if (!savedPhoto) {
            try {
                const token = AuthManager.getAuthToken();
                if (token) {
                    const response = await fetch('/api/account/profile', {
                        headers: { 'Authorization': `Bearer ${token}` }
                    });
                    const data = await response.json();
                    if (data.success && data.user.profile_picture) {
                        savedPhoto = data.user.profile_picture;
                        localStorage.setItem(storageKey, savedPhoto);
                    }
                }
            } catch (error) {
                console.error('Failed to load profile picture from backend:', error);
            }
        }
        
        if (savedPhoto) {
            this.displayProfilePhoto(savedPhoto);
        }
    }

    /**
     * Display profile photo in all avatar elements
     * @param {string} photoDataUrl - Base64 data URL of the photo
     */
    static displayProfilePhoto(photoDataUrl) {
        this.AVATAR_SELECTORS.forEach(selector => {
            const avatars = document.querySelectorAll(selector);
            avatars.forEach(avatar => {
                this.updateAvatarWithPhoto(avatar, photoDataUrl);
            });
        });
    }

    /**
     * Update a single avatar element with the photo
     * @param {HTMLElement} avatar - The avatar element
     * @param {string} photoDataUrl - Base64 data URL of the photo
     */
    static updateAvatarWithPhoto(avatar, photoDataUrl) {
        // Ensure avatar has proper styling for image containment
        avatar.style.overflow = 'hidden';
        
        // Hide existing icon
        const icon = avatar.querySelector('i');
        if (icon) icon.style.display = 'none';
        
        // Create or update image element
        let img = avatar.querySelector('img');
        if (!img) {
            img = document.createElement('img');
            img.style.width = '100%';
            img.style.height = '100%';
            img.style.borderRadius = '0';
            img.style.objectFit = 'cover';
            img.style.objectPosition = 'center';
            img.style.position = 'absolute';
            img.style.top = '0';
            img.style.left = '0';
            img.alt = 'Profile Photo';
            avatar.appendChild(img);
        } else {
            // Update existing image styles
            img.style.width = '100%';
            img.style.height = '100%';
            img.style.borderRadius = '0';
            img.style.objectFit = 'cover';
            img.style.objectPosition = 'center';
            img.style.position = 'absolute';
            img.style.top = '0';
            img.style.left = '0';
        }
        
        // Ensure avatar container is positioned relatively
        if (getComputedStyle(avatar).position === 'static') {
            avatar.style.position = 'relative';
        }
        
        img.src = photoDataUrl;
        img.style.display = 'block';
        
        // Special handling for profile photo display page
        if (avatar.id === 'profilePhotoDisplay') {
            const defaultIcon = avatar.querySelector('#defaultIcon');
            const removeBtn = document.getElementById('removePhotoBtn');
            
            if (defaultIcon) defaultIcon.style.display = 'none';
            if (removeBtn) removeBtn.style.display = 'inline-block';
        }
    }

    /**
     * Reset all avatars to default state (show icons, hide images)
     */
    static resetAllAvatars() {
        this.AVATAR_SELECTORS.forEach(selector => {
            const avatars = document.querySelectorAll(selector);
            avatars.forEach(avatar => {
                this.resetSingleAvatar(avatar);
            });
        });
    }

    /**
     * Reset a single avatar to default state
     * @param {HTMLElement} avatar - The avatar element
     */
    static resetSingleAvatar(avatar) {
        // Show icon
        const icon = avatar.querySelector('i');
        if (icon) icon.style.display = 'block';
        
        // Hide image
        const img = avatar.querySelector('img');
        if (img) img.style.display = 'none';
        
        // Special handling for profile photo display page
        if (avatar.id === 'profilePhotoDisplay') {
            const defaultIcon = avatar.querySelector('#defaultIcon');
            const removeBtn = document.getElementById('removePhotoBtn');
            
            if (defaultIcon) defaultIcon.style.display = 'block';
            if (removeBtn) removeBtn.style.display = 'none';
        }
    }

    /**
     * Save profile photo to localStorage
     * @param {string} photoDataUrl - Base64 data URL of the photo
     */
    static async saveProfilePhoto(photoDataUrl) {
        const storageKey = this.getStorageKey();
        localStorage.setItem(storageKey, photoDataUrl);
        this.displayProfilePhoto(photoDataUrl);
        
        // Save to backend database
        try {
            const token = AuthManager.getAuthToken();
            if (token) {
                await fetch('/api/account/profile', {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${token}`
                    },
                    body: JSON.stringify({ profile_picture: photoDataUrl })
                });
                console.log('✅ Profile picture saved to database');
            }
        } catch (error) {
            console.error('Failed to save profile picture to database:', error);
        }
        
        // Trigger custom event for other components
        window.dispatchEvent(new CustomEvent('profile:photoUpdated', {
            detail: { photoDataUrl }
        }));
    }

    /**
     * Remove profile photo from localStorage and database
     */
    static async removeProfilePhoto() {
        const storageKey = this.getStorageKey();
        localStorage.removeItem(storageKey);
        this.resetAllAvatars();
        
        // Remove from backend database
        try {
            const token = AuthManager.getAuthToken();
            if (token) {
                await fetch('/api/account/profile', {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${token}`
                    },
                    body: JSON.stringify({ profile_picture: null })
                });
                console.log('✅ Profile picture removed from database');
            }
        } catch (error) {
            console.error('Failed to remove profile picture from database:', error);
        }
        
        // Trigger custom event for other components
        window.dispatchEvent(new CustomEvent('profile:photoRemoved'));
    }

    /**
     * Get current profile photo from localStorage
     * @returns {string|null} Base64 data URL of the photo or null
     */
    static getCurrentPhoto() {
        return localStorage.getItem(this.STORAGE_KEY);
    }

    /**
     * Check if user has a profile photo
     * @returns {boolean}
     */
    static hasProfilePhoto() {
        const storageKey = this.getStorageKey();
        return !!localStorage.getItem(storageKey);
    }
}

// Utility functions for backward compatibility
function getStoredUser() {
    return AuthManager.getAuthUser();
}

function getStoredToken() {
    return AuthManager.getAuthToken();
}

function isUserLoggedIn() {
    return AuthManager.isLoggedIn();
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    AuthManager.init();
});

// Also initialize immediately if DOM is already loaded
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
        AuthManager.init();
    });
} else {
    AuthManager.init();
}

// Prevent conflicts with old auth-manager.js
if (window.AuthManager && window.AuthManager.constructor.name === 'AuthManager') {
    console.warn('⚠️ Old AuthManager detected, overriding with new version');
}

// Make globally available
window.SessionManager = SessionManager;
window.AuthManager = AuthManager;
window.ProfilePhotoManager = ProfilePhotoManager;
window.getStoredUser = getStoredUser;
window.getStoredToken = getStoredToken;
window.isUserLoggedIn = isUserLoggedIn;

// Mark this as the new AuthManager
window.AuthManager._isNewAuthManager = true;
