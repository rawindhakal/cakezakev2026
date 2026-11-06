<?php

namespace App\Http\Middleware;

use App\Helpers\CommonHelper;
use Closure;
use Illuminate\Http\Request;

/**
 * Branch-panel isolation + permission enforcement. For an authenticated branch user
 * (owner or sub-user):
 *   1. Force the branch's zone_id / country_id / branch_id onto the request,
 *      overriding any client value — every existing zone/branch filter auto-scopes.
 *   2. Block system / global modules and global-catalog mutations (default-deny).
 *   3. Enforce the user's ACTUAL permissions (role_has_permissions) per endpoint,
 *      so when an admin grants/revokes a permission on the branch, backend access
 *      changes with it — the module map is NOT a static free pass.
 * Non-branch users pass through untouched.
 */
class EnsureBranchScope
{
    /** First path segment (after `api/`) a branch user may reach at all (isolation). */
    private array $allowed = [
        // shared panel infrastructure
        'dashboard', 'admin_settings', 'get_top_notifications', 'notification_read',
        'update_fcm_token', 'logout', 'broadcasting', 'create_slug', 'active_languages',
        'change_password', 'password_policy', 'bonus_settings', 'panel_notification',
        // branch modules
        'products', 'stock', 'media', 'orders', 'order_statuses', 'return_requests', 'shipments',
        'promo_code', 'home_layouts', 'home_layout_templates', 'page_layouts', 'customers',
        'transactions', 'wallet_transactions', 'delivery_boys', 'cash_collection',
        'salary_transactions', 'chat', 'reports', 'notifications', 'emails', 'zones',
        // read-only reference data the shared filters / product form need
        'countries', 'categories', 'attributes',
        // branch-panel self-management
        'branch_users', 'branch_roles', 'branch_panel',
    ];

    /** Prefixes a branch user may only READ (GET) — shared reference data. */
    private array $readOnly = ['zones', 'customers', 'order_statuses', 'countries', 'categories', 'attributes'];

    /** Exact read-only paths under an otherwise-blocked prefix (GET only). */
    private array $allowedGetPaths = [
        '#^branches/for_channel(/|$)#',
        '#^products/brands(/|$)#',
        '#^products/addons(/|$)#',
        '#^products/taxes(/|$)#',
    ];

    /**
     * Global-catalog mutations a branch user must never perform (write methods only).
     */
    private array $deniedPatterns = [
        '#^products/(delete|multiple_delete|import|export|sample|bulk|approve_requests)(/|$)#',
        '#^products/taxes(/|$)#',
        '#^products/brands/(save|update|delete)(/|$)#',
        '#^products/addons/(save|copy|apply|upload_image)(/|$)#',
    ];

    /**
     * Per-endpoint permission map: ordered [regex, ['GET'=>[perms], 'WRITE'=>[perms]]].
     * '*' applies to both method classes. First matching rule decides. The user must
     * hold ANY of the listed permissions for the matched method class. A path with no
     * matching rule needs no permission (infra + reference reads).
     */
    private array $permissionRules = [
        ['#^dashboard(/|$)#', ['*' => ['manage_dashboard']]],


        // Products (per-branch, auto-scoped) + stock
        ['#^products/save(/|$)#', ['WRITE' => ['product_create']]],
        ['#^products/update(/|$)#', ['WRITE' => ['product_update']]],
        ['#^products/stock#', ['*' => ['stock_management']]],
        ['#^products#', ['GET' => ['product_list'], 'WRITE' => ['product_update']]],
        ['#^stock(/|$)#', ['*' => ['stock_management']]],

        // Orders
        // Either order family opens the endpoints; OrdersApiController then scopes what a
        // user without the other family's permission may see or change.
        ['#^orders#', ['GET' => ['order_list', 'self_pickup_order_list'], 'WRITE' => ['order_update', 'self_pickup_order_update']]],

        ['#^shipments#', ['GET' => ['order_list'], 'WRITE' => ['order_update']]],

        // Return requests
        ['#^return_requests#', ['GET' => ['return_request_list'], 'WRITE' => ['return_request_update']]],

        // Promo codes
        ['#^promo_code/save(/|$)#', ['WRITE' => ['promo_code_create']]],
        ['#^promo_code/update(/|$)#', ['WRITE' => ['promo_code_update']]],
        ['#^promo_code/delete(/|$)#', ['WRITE' => ['promo_code_delete']]],
        ['#^promo_code#', ['GET' => ['promo_code_list'], 'WRITE' => ['promo_code_create', 'promo_code_update', 'promo_code_delete']]],

        // Page builder (the picker options are also needed while editing a home layout)
        ['#^page_layouts/options(/|$)#', ['GET' => ['page_builder_list', 'home_builder_create', 'home_builder_update']]],
        ['#^page_layouts/save(/|$)#', ['WRITE' => ['page_builder_create', 'page_builder_update']]],
        ['#^page_layouts/publish(/|$)#', ['WRITE' => ['page_builder_publish']]],
        ['#^page_layouts/delete(/|$)#', ['WRITE' => ['page_builder_delete']]],
        ['#^page_layouts/(clone|toggle_active|upload_image)(/|$)#', ['WRITE' => ['page_builder_update']]],
        ['#^page_layouts#', ['GET' => ['page_builder_list'], 'WRITE' => ['page_builder_create', 'page_builder_update', 'page_builder_delete', 'page_builder_publish']]],

        // Home builder
        ['#^home_layouts/save(/|$)#', ['WRITE' => ['home_builder_create']]],
        ['#^home_layouts/(publish|schedule)(/|$)#', ['WRITE' => ['home_builder_publish']]],
        ['#^home_layouts/delete(/|$)#', ['WRITE' => ['home_builder_delete']]],
        ['#^home_layouts/(clone|toggle_active|upload_image)(/|$)#', ['WRITE' => ['home_builder_update']]],
        ['#^home_layouts#', ['GET' => ['home_builder_list'], 'WRITE' => ['home_builder_create', 'home_builder_update', 'home_builder_delete', 'home_builder_publish']]],
        ['#^home_layout_templates/save(/|$)#', ['WRITE' => ['home_builder_create']]],
        ['#^home_layout_templates/delete(/|$)#', ['WRITE' => ['home_builder_delete']]],
        ['#^home_layout_templates#', ['GET' => ['home_builder_list'], 'WRITE' => ['home_builder_create', 'home_builder_delete']]],

        // Customers / transactions / wallet
        ['#^customers#', ['GET' => ['customer_list'], 'WRITE' => ['customer_list']]],
        ['#^transactions#', ['GET' => ['transaction_list']]],
        ['#^wallet_transactions#', ['*' => ['manage_customer_wallet']]],

        // Reports — each report type gated by its own permission (…/export included).
        ['#^reports/sales(/|$)#', ['*' => ['report_sales']]],
        ['#^reports/orders(/|$)#', ['*' => ['report_orders']]],
        ['#^reports/products(/|$)#', ['*' => ['report_products']]],
        ['#^reports/customers(/|$)#', ['*' => ['report_customers']]],
        ['#^reports/inventory(/|$)#', ['*' => ['report_inventory']]],
        ['#^reports/returns(/|$)#', ['*' => ['report_returns']]],
        ['#^reports/delivery(/|$)#', ['*' => ['report_delivery']]],
        ['#^reports/payment(/|$)#', ['*' => ['report_payment']]],
        ['#^reports/category(/|$)#', ['*' => ['report_category']]],
        ['#^reports/promo(/|$)#', ['*' => ['report_promo']]],
        ['#^reports#', ['*' => [
            'report_sales', 'report_orders', 'report_products', 'report_customers',
            'report_inventory', 'report_returns', 'report_delivery', 'report_payment',
            'report_category', 'report_promo',
        ]]],

        // Delivery boys
        ['#^delivery_boys/save(/|$)#', ['WRITE' => ['delivery_boy_create']]],
        ['#^delivery_boys/(update|update_delivery_boy_status)(/|$)#', ['WRITE' => ['delivery_boy_update']]],
        ['#^delivery_boys/delete(/|$)#', ['WRITE' => ['delivery_boy_delete']]],
        ['#^delivery_boys#', ['GET' => ['delivery_boy_list'], 'WRITE' => ['delivery_boy_create', 'delivery_boy_update', 'delivery_boy_delete']]],

        // Cash collection
        ['#^cash_collection/save(/|$)#', ['WRITE' => ['cash_collection_create']]],
        ['#^cash_collection#', ['GET' => ['cash_collection_list'], 'WRITE' => ['cash_collection_create']]],

        // Delivery-boy salary
        ['#^salary_transactions/(add|update)(/|$)#', ['WRITE' => ['delivery_boy_salary_create']]],
        ['#^salary_transactions/delete(/|$)#', ['WRITE' => ['delivery_boy_salary_delete']]],
        ['#^salary_transactions#', ['GET' => ['delivery_boy_salary_list'], 'WRITE' => ['delivery_boy_salary_create', 'delivery_boy_salary_delete']]],

        // Chat
        ['#^chat#', ['*' => ['chat']]],

        // Manual send notification / email
        ['#^notifications/save(/|$)#', ['WRITE' => ['send_notification']]],
        ['#^notifications/delete(/|$)#', ['WRITE' => ['notification_delete']]],
        ['#^notifications#', ['GET' => ['notification_list'], 'WRITE' => ['send_notification', 'notification_delete']]],
        ['#^emails/save(/|$)#', ['WRITE' => ['send_email']]],
        ['#^emails/delete(/|$)#', ['WRITE' => ['delete_send_email']]],
        ['#^emails#', ['GET' => ['manage_emails'], 'WRITE' => ['send_email', 'delete_send_email']]],

        // Branch-panel self-management
        ['#^branch_users#', ['*' => ['branch_user_manage']]],
        ['#^branch_roles#', ['*' => ['branch_role_manage']]],
    ];

    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();
        // A branch user is any admin bound to a branch (owner or sub-user).
        if (!$user || !$user->isBranchUser()) {
            return $next($request);
        }

        $branch = $user->branch;
        if (!$branch || (int) $branch->status !== 1) {
            return CommonHelper::responseError('your_branch_is_inactive_or_unavailable');
        }

        // 1. Force scope — overrides any client value.
        $request->merge([
            'branch_id'   => $branch->id,
            'zone_id'    => $branch->zone_id,
            'country_id' => optional($branch->zone)->country_id,
        ]);

        $path = ltrim($request->path(), '/');
        if (str_starts_with($path, 'api/')) {
            $path = substr($path, 4);
        }
        $first = explode('/', $path)[0] ?? '';
        $isGet = in_array($request->method(), ['GET', 'HEAD'], true);

        // 2a. Explicit read-only sub-paths win over the first-segment block.
        foreach ($this->allowedGetPaths as $pattern) {
            if (preg_match($pattern, $path)) {
                return $isGet
                    ? $next($request)
                    : CommonHelper::responseError('you_do_not_have_access_to_this_section');
            }
        }

        // 2b. Isolation: only reachable prefixes, reference data read-only.
        if (!in_array($first, $this->allowed, true)) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }
        if (in_array($first, $this->readOnly, true) && !$isGet) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }

        // 2c. Global-catalog mutations are never allowed (writes only).
        if (!$isGet) {
            foreach ($this->deniedPatterns as $pattern) {
                if (preg_match($pattern, $path)) {
                    return CommonHelper::responseError('you_do_not_have_access_to_this_section');
                }
            }
        }

        // 3. Permission enforcement — driven by the user's real permission set, so an
        //    admin adding/removing a branch permission changes access immediately.
        $required = $this->requiredPermissions($path, $isGet);
        if ($required !== null) {
            $held = $user->allPermissions ?? [];
            if (empty(array_intersect($required, $held))) {
                return CommonHelper::responseError('you_do_not_have_access_to_this_section');
            }
        }

        return $next($request);
    }

    /**
     * Permissions accepted for this path+method (ANY one grants access), or null
     * when the endpoint needs no permission (infra + reference reads).
     */
    private function requiredPermissions(string $path, bool $isGet): ?array
    {
        $key = $isGet ? 'GET' : 'WRITE';
        foreach ($this->permissionRules as [$pattern, $map]) {
            if (!preg_match($pattern, $path)) {
                continue;
            }
            if (isset($map['*'])) {
                return $map['*'];
            }
            if (isset($map[$key])) {
                return $map[$key];
            }
            // Rule matched but not for this method class -> not permitted.
            return ['__no_such_permission__'];
        }
        return null;
    }
}
