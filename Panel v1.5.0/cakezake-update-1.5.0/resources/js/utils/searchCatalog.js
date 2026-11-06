import { settingsGroups } from './settingsCatalog';

/**
 * What the global search can find.
 *
 * Three sources, all permission-filtered by the palette:
 *   menu      — the sidebar, passed in so there is only one definition of it
 *   settings  — the Settings hub, shared with the hub page
 *   actions   — the create/manage screens people jump to by name ("add product")
 *
 * `keywords` carries the words that live ON the page — field labels, synonyms and
 * the odd misspelling — so searching "thermal" or "smtp password" lands on the
 * right screen even though neither word is in its title.
 *
 * Labels run through __(), so every list is built at call time, not on import.
 */

/** Flatten the sidebar tree into one entry per destination. */
export function menuEntries(groups) {
    const out = [];

    (groups || []).forEach(group => {
        (group.items || []).forEach(item => {
            if (Array.isArray(item.submenu) && item.submenu.length) {
                item.submenu.forEach(sub => out.push({
                    type: 'menu',
                    title: sub.name,
                    group: group.title + ' · ' + item.name,
                    to: sub.url,
                    permission: sub.permission,
                    role: sub.role,
                    icon: item.icon,
                }));
                return;
            }
            if (!item.url) return;
            out.push({
                type: 'menu',
                title: item.name,
                group: group.title,
                to: item.url,
                permission: item.permission,
                role: item.role,
                icon: item.icon,
            });
        });
    });

    return out;
}

/** Every card on the Settings hub, with the fields each page holds. */
export function settingsEntries() {
    const out = [];

    settingsGroups().forEach(group => {
        (group.items || []).forEach(item => out.push({
            type: 'setting',
            title: item.title,
            group: __('settings') + ' · ' + group.title,
            desc: item.desc,
            keywords: item.keywords,
            to: item.to,
            permission: item.permission,
            icon: item.icon,
        }));
    });

    return out;
}

/** Screens people reach for by name — mostly "create X" forms. */
export function actionEntries() {
    return [
        { title: __('add_product'), to: '/products/create', permission: 'product_create',
            keywords: 'new product create item variant sku price stock' },
        { title: __('bulk_upload'), to: '/bulk_upload', permission: 'product_create',
            keywords: 'import products csv excel sheet' },
        { title: __('bulk_update'), to: '/bulk_update', permission: 'product_update',
            keywords: 'edit many products price stock csv' },
        { title: __('add_category'), to: '/manage_categories', permission: 'category_create',
            keywords: 'new category subcategory' },
        { title: __('create_coupon'), to: '/promo_code/create', permission: 'promo_code_create',
            keywords: 'new promo code discount offer voucher' },
        { title: __('add_branch'), to: '/branches/create', permission: 'branch_create',
            keywords: 'new branch branch outlet pickup timing' },
        { title: __('add_zone'), to: '/zones/create', permission: 'zone_create',
            keywords: 'new zone delivery area polygon charge surge' },
        { title: __('add_delivery_boy'), to: '/delivery_boys/create', permission: 'delivery_boy_create',
            keywords: 'new rider driver salary' },
        { title: __('self_pickup_orders'), to: '/orders/pickup', permission: 'self_pickup_order_list',
            keywords: 'pickup collect branch orders' },
        { title: __('send_notification'), to: '/notifications', permission: 'send_notification',
            keywords: 'push message customers broadcast' },
        { title: __('stock_alerts'), to: '/stock_alerts', permission: 'manage_stock_alerts',
            keywords: 'back in stock waiting notify me out of stock' },
        { title: __('spin_wheel'), to: '/spin_wheel', permission: 'spin_wheel_list',
            keywords: 'spin win prize wheel campaign reward' },
        { title: __('reports'), to: '/reports/sales', permission: 'report_sales',
            keywords: 'sales orders products customers revenue profit export' },
        { title: __('roles'), to: '/role', permission: 'role_list',
            keywords: 'permission access staff admin user rights' },
    ].map(a => ({ ...a, type: 'action', group: __('actions') }));
}
