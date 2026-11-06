/**
 * Microsoft Clarity — manual tracking-code setup.
 *
 * Each surface (admin panel, delivery-boy panel, website, customer app) has its
 * own Clarity project, so the panel SPA cannot hard-code one id in the page head:
 * the same bundle serves both the admin and the delivery-boy panel. The correct
 * project is therefore booted here once the logged-in user's role is known.
 *
 * Clarity's tag can only be initialised for ONE project per page load, so if the
 * role changes (log out as admin, back in as a delivery boy) the app reloads
 * anyway — see Auth.logout(), which does a full window.location replace.
 */

let bootedProjectId = null;

/** Inject the official Clarity snippet for a project id. */
export function bootClarity(projectId) {
    const id = String(projectId || '').trim();
    if (!id || typeof window === 'undefined') return false;
    // Already running for this project (or another) — never inject twice.
    if (bootedProjectId) return bootedProjectId === id;

    (function (c, l, a, r, i, t, y) {
        c[a] = c[a] || function () { (c[a].q = c[a].q || []).push(arguments); };
        t = l.createElement(r); t.async = 1; t.src = 'https://www.clarity.ms/tag/' + i;
        y = l.getElementsByTagName(r)[0]; y.parentNode.insertBefore(t, y);
    })(window, document, 'clarity', 'script', id);

    bootedProjectId = id;
    return true;
}

export function isClarityReady() {
    return typeof window !== 'undefined' && typeof window.clarity === 'function';
}

/**
 * Boot the panel's Clarity project for the logged-in user.
 *
 * Admin and delivery boy share one SPA, so they share one project. The panel
 * side is recorded as a Clarity tag instead, which keeps the two segmentable
 * (filter on `panel` / `role`) without needing separate projects.
 */
export function bootClarityForUser(user) {
    const cfg = (typeof window !== 'undefined' && window.clarityConfig) || {};
    if (!cfg.enabled || !cfg.project_id) return false;

    const booted = bootClarity(cfg.project_id);
    if (booted && user) {
        const panel = Number(user.role_id) === 3 ? 'delivery_boy' : 'admin';
        // Ties a recording to the account and the side of the panel it came from.
        identify(String(user.id), { panel, role: user?.role?.name || panel });
    }
    return booted;
}

/** Custom event — shows up in Clarity's "Smart events" filters. */
export function trackEvent(name) {
    if (!isClarityReady() || !name) return;
    try {
        window.clarity('event', String(name));
    } catch (e) {
        // Tracking must never break a user action.
    }
}

/** Custom tag (key/value) used to segment recordings. */
export function setTag(key, value) {
    if (!isClarityReady() || !key) return;
    try {
        window.clarity('set', String(key), String(value ?? ''));
    } catch (e) { /* ignore */ }
}

/** Associate the session with a user id (+ optional tags). */
export function identify(userId, tags = {}) {
    if (!isClarityReady() || !userId) return;
    try {
        window.clarity('identify', String(userId));
        Object.entries(tags || {}).forEach(([k, v]) => setTag(k, v));
    } catch (e) { /* ignore */ }
}

/**
 * Endpoint → Clarity event name for the actions worth measuring.
 *
 * Mapped centrally instead of sprinkling trackEvent() through every view: one
 * axios interceptor then covers every "main action" in both panels, and adding a
 * new tracked action is a single line here.
 *
 * Matched as a substring of the request URL, longest match first, so
 * `products/bulk/upload` wins over `products/`.
 */
const EVENT_MAP = {
    // --- admin panel: catalogue ---
    'products/save': 'admin_product_created',
    'products/update': 'admin_product_updated',
    'products/delete': 'admin_product_deleted',
    'products/bulk/upload': 'admin_product_bulk_upload',
    'products/bulk/update': 'admin_product_bulk_update',
    'products/stock/adjust': 'admin_stock_adjusted',
    'categories/save': 'admin_category_created',
    'categories/update': 'admin_category_updated',
    'brands/save': 'admin_brand_created',
    'attributes/save': 'admin_attribute_created',

    // --- admin panel: orders & fulfilment ---
    'update_order_status': 'admin_order_status_updated',
    'orders/update_status': 'admin_order_status_updated',
    'return_requests/update': 'admin_return_request_updated',
    'withdrawal_requests/update': 'admin_withdrawal_request_updated',

    // --- admin panel: marketing / comms ---
    'promo_code/save': 'admin_promo_code_created',
    'notifications/save': 'admin_notification_sent',
    'emails/save': 'admin_email_sent',
    'home_layout/publish': 'admin_home_layout_published',

    // --- admin panel: configuration ---
    'store_settings/save_third_party_api_setting': 'admin_api_settings_saved',
    'store_settings/save_store_basic_setting': 'admin_store_settings_saved',
    'branches/save': 'admin_branch_created',
    'zones/save': 'admin_zone_saved',
    'countries/save': 'admin_country_saved',
    'languages/save': 'admin_language_created',
    'system_users/save': 'admin_system_user_created',
    'roles/save': 'admin_role_saved',

    // --- delivery boy panel ---
    'delivery_boy/update_status': 'db_order_status_updated',
    'delivery_boy/update_item_status': 'db_order_item_status_updated',
    'delivery_boy/return_request_status_update': 'db_return_status_updated',
    'delivery_boy/withdrawal_requests/add': 'db_withdrawal_requested',
    'delivery_boy/update': 'db_profile_updated',
};

const EVENT_KEYS = Object.keys(EVENT_MAP).sort((a, b) => b.length - a.length);

/** Resolve a request URL to an event name, or null when it isn't tracked. */
export function eventForUrl(url) {
    if (!url) return null;
    const key = EVENT_KEYS.find(k => url.includes(k));
    return key ? EVENT_MAP[key] : null;
}

/**
 * Fire the mapped event for a successful request. Only successes are tracked —
 * a failed save is not the action happening.
 */
export function trackRequest(url, responseData) {
    const name = eventForUrl(url);
    if (!name) return;
    // The API answers 200 with {status: 0} on business failures.
    if (responseData && typeof responseData === 'object' && 'status' in responseData
        && Number(responseData.status) === 0) {
        return;
    }
    trackEvent(name);
}

export default { bootClarity, bootClarityForUser, trackEvent, setTag, identify, trackRequest, eventForUrl, isClarityReady };
