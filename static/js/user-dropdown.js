/**
 * User Dropdown Functionality
 * Handles user profile dropdown interactions on public pages
 */

function setupUserDropdown() {
    const userProfileBtn = document.getElementById('userProfileBtn');
    const userDropdownMenu = document.getElementById('userDropdownMenu');
    
    if (!userProfileBtn || !userDropdownMenu) {
        console.log('User dropdown elements not found, skipping setup');
        return;
    }
    
    let isDropdownOpen = false;
    
    // Remove any existing event listeners to prevent duplicates
    const newBtn = userProfileBtn.cloneNode(true);
    userProfileBtn.parentNode.replaceChild(newBtn, userProfileBtn);
    
    // Toggle dropdown on button click
    newBtn.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        console.log('User dropdown clicked, current state:', isDropdownOpen);
        
        if (isDropdownOpen) {
            userDropdownMenu.classList.remove('show');
            newBtn.classList.remove('active');
            isDropdownOpen = false;
        } else {
            userDropdownMenu.classList.add('show');
            newBtn.classList.add('active');
            isDropdownOpen = true;
        }
    });
    
    // Close dropdown when clicking outside
    document.addEventListener('click', function(e) {
        if (!newBtn.contains(e.target) && !userDropdownMenu.contains(e.target)) {
            if (isDropdownOpen) {
                userDropdownMenu.classList.remove('show');
                newBtn.classList.remove('active');
                isDropdownOpen = false;
            }
        }
    });
    
    // Prevent dropdown from closing when clicking inside it
    userDropdownMenu.addEventListener('click', function(e) {
        e.stopPropagation();
    });
    
    console.log('User dropdown setup completed');
}

// Initialize when DOM is ready and after auth changes
function initializeUserDropdown() {
    // Setup immediately if DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
            setTimeout(setupUserDropdown, 100);
        });
    } else {
        setTimeout(setupUserDropdown, 100);
    }
    
    // Setup after auth state changes
    window.addEventListener('storage', function(e) {
        if (e.key === 'auth_user' || e.key === 'auth_token') {
            setTimeout(setupUserDropdown, 100);
        }
    });
    
    // Listen for custom auth events
    document.addEventListener('auth:login', function() {
        setTimeout(setupUserDropdown, 100);
    });
    
    document.addEventListener('auth:logout', function() {
        setTimeout(setupUserDropdown, 100);
    });
}

// Auto-initialize
initializeUserDropdown();

// Make available globally
window.setupUserDropdown = setupUserDropdown;
window.initializeUserDropdown = initializeUserDropdown;