<?php

namespace App\Http\Middleware;

use App\Helpers\CommonHelper;
use Closure;
use Illuminate\Support\Facades\Route;

/**
 * Blocks write/mutating admin routes while the app runs in demo mode, so demo
 * users can browse but not create/update/delete. Attached to the `api` group so
 * it actually covers the admin panel (routes/api.php). The super admin (id 1) is
 * exempt. Customer/delivery routes inherit `api` too, but only the names listed
 * below are blocked — their normal flows (place order, edit profile, chat) stay
 * allowed because they are not in the list.
 */
class DemoMode
{
    /** Route names blocked in demo mode (create/update/delete/config/AI/destructive). */
    private array $restrictedUrls = [
        // Categories
        'categories.save', 'categories.update', 'categories.delete', 'categories.updateOrder',
        // Products
        'products.save', 'products.update', 'products.delete',
        'products.change', 'products.bulk_upload', 'products.bulk_update',
        'products.recommendations.save', 'products.stock.adjust',
        'products.generate_description', 'products.generate_seo', 'generate_seo',
        // Attributes
        'attributes.save', 'attributes.update', 'attributes.delete',
        // Taxes / Brands / Branches
        'tax_categories.save', 'tax_categories.delete',
        'tax_rules.save', 'tax_rules.delete',
        'product_addons.save', 'product_addons.copy', 'product_addons.apply', 'product_addons.upload_image',
        'brands.save', 'brands.update', 'brands.delete',
        'branches.save', 'branches.delete',
        // Promo / SEO
        'promo_code.save', 'promo_code.update', 'promo_code.delete',
        // Spin wheel (admin writes only — customers may still spin in a demo)
        'spin_wheel.save', 'spin_wheel.delete',
        'seo_settings.save', 'seo_settings.update', 'seo_settings.delete',
        // Delivery locations
        'delivery_cities.save', 'delivery_cities.delete',
        'delivery_areas.save', 'delivery_areas.delete',
        // Branch settings (all "save_*" write endpoints)
        'store_settings.save_store_basic_setting', 'store_settings.save_address_setting',
        'store_settings.save_other_setting', 'store_settings.save_app_setting',
        'store_settings.save_delivery_boy_setting', 'store_settings.save_smtp_mail_setting',
        'store_settings.save_third_party_api_setting', 'store_settings.save_login_setting',
        'store_settings.save_cart_setting', 'store_settings.save_maintenance_setting',
        'store_settings.save_deeplink_setting', 'store_settings.save_broadcast_setting',
        'store_settings.system_update',
        // Firebase / popup / contact / about
        'firebase.save', 'popup.save', 'contact_us.save', 'about_us.save',
        // Notifications
        'notifications.save', 'notifications.delete',
        'notification_settings.save_event', 'notification_settings.toggle',
        // Emails / templates
        'emails.save', 'emails.delete', 'email_templates.update_translation',
        // SMS
        'sms_settings.save', 'sms_templates.update',
        // Home layout builder
        'home_layouts.save', 'home_layouts.publish', 'home_layouts.schedule',
        'home_layouts.clone', 'home_layouts.toggle_active', 'home_layouts.delete',
        'page_layouts.save', 'page_layouts.publish', 'page_layouts.clone', 'page_layouts.toggle_active', 'page_layouts.delete',
        // Delivery boys
        'delivery_boys.save', 'delivery_boys.update', 'delivery_boys.delete',
        'delivery_boys.update_delivery_boy_status',
        'salary_transactions.add', 'salary_transactions.update', 'salary_transactions.delete',
        'cash_collection.save',
        // Front end / web / social
        'web_settings.save',
        'social_media.save', 'social_media.update', 'social_media.delete',
        // Wallet / withdrawal
        'wallet_transactions.save',
        'withdrawal_requests.update', 'withdrawal_requests.delete',
        // Customers
        'customers.set_status',
        // System users / roles
        'system_users.save', 'system_users.update', 'system_users.delete', 'system_users.change_password',
        'role.save', 'role.update', 'role.delete',
        // Return requests
        'return_requests.save', 'return_requests.update', 'return_requests.delete',
        'return_requests.delivery_boy',
        // Orders — deletions only (status/assign/cancel updates are ALLOWED in demo)
        'orders.delete', 'orders.deleteItem',
        // Media
        'media.save', 'media.delete', 'media.multiple_delete',
        'storage_cleanup.trash', 'storage_cleanup.restore', 'storage_cleanup.empty_trash',
        // Carts (admin remove releases stock)
        'carts.remove',
        // Zones
        'zones.save', 'zones.delete',
        // FAQs
        'faqs.save', 'faqs.update', 'faqs.delete',
        // Languages
        'languages.save', 'languages.update', 'languages.delete',
        'languages.translate', 'languages.update_json',
        // Blogs
        'blog_categories.save', 'blog_categories.update', 'blog_categories.delete',
        'blogs.save', 'blogs.update', 'blogs.delete', 'blogs.google_gemini',
        // Countries
        'countries.save', 'countries.update', 'countries.delete',
        'countries.import', 'countries.set_default',
        /* Plugins — installing writes files, calls a licence validator with a real
           purchase code and changes what the whole panel can do. Also guarded inside
           the controller; listed here so the block does not depend on that. */
        'plugins.install', 'plugins.toggle', 'plugins.uninstall',
        'plugins.settings_save',

        /* Anything that reaches a courier's account for real. Booking a parcel,
           cancelling one, calling a pickup or generating a label all happen on OUR
           Shiprocket account and some of them cost money, so a demo visitor must not
           be able to trigger them. Quotes and tracking stay allowed: they are
           read-only at the carrier and are most of what a demo is for. */
        'branches.register_pickup',
        'orders.shipping_create', 'orders.shipping_cancel', 'orders.shipping_schedule_pickup',
        'orders.shipping_resolve_exception',
        'orders.shipping_label', 'orders.shipping_labels', 'orders.shipping_manifest',
        'shipments.schedule_pickup', 'shipments.labels', 'shipments.manifest', 'shipments.receipts',

        // Courier notification + RTO config, same class as the other notification saves.
        'notification_settings.save_courier_notifications',
        'notification_settings.save_courier_rto_action',

        // Misc destructive / utility
        'activity_logs.clear', 'cron.run', 'panel_notification.delete',
        // Branch panel (admin-side per-branch permission edit + branch-owner self-management)
        'branches.save_permissions',
        'branch_users.save', 'branch_users.update', 'branch_users.delete',
        'branch_roles.save', 'branch_roles.update', 'branch_roles.delete',
        'branch_panel.profile.save',
        'branch_panel.notification_preferences.save',
        'branch_panel.change_password',
    ];

    public function handle($request, Closure $next)
    {
        if (isDemoMode()) {
            try {
                $route = Route::getRoutes()->match($request);
                $currentRoute = $route->getName() ?? '';
            } catch (\Throwable $e) {
                $currentRoute = '';
            }

            if ($currentRoute !== '' && in_array($currentRoute, $this->restrictedUrls, true)) {
                // Admin auth is Passport (auth:api); default guard is web. Resolve the
                // admin explicitly so the super-admin (id 1) exemption still works.
                $user = auth('api')->user() ?? auth()->user();
                if ((int) ($user->id ?? 0) !== 1) {
                    return CommonHelper::responseError('This function is not available in demo mode!');
                }
            }
        }

        return $next($request);
    }
}
