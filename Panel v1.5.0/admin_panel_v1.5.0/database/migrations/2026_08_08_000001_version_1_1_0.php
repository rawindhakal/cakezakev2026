<?php

use App\Models\Admin;
use App\Models\Role as RoleConst;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Spatie\Permission\Models\Permission as SpatiePermission;
use Spatie\Permission\Models\Role as SpatieRole;

/**
 * Release 1.1.0 — Store Login.
 *
 * All schema + data changes for this release live in this single version-named
 * migration (original create migrations are left untouched). Idempotent so it
 * runs safely via the update script on existing installs.
 *
 * Adds:
 *   admins.store_id / admins.is_store_owner  — store-panel user identity
 *   stores.owner_admin_id                    — primary store login back-ref
 *   roles.store_id                           — store-owned custom roles
 *   Store role + store-panel permissions + grant set
 *   a primary login admin back-filled for every existing store
 */
return new class extends Migration
{
    public function up(): void
    {
        // ---- Schema ----
        if (Schema::hasColumn('emails', 'type_id')) {
            Schema::table('emails', function (Blueprint $table) {
                $table->text('type_id')->change();
            });
        }

        Schema::table('admins', function (Blueprint $table) {
            if (!Schema::hasColumn('admins', 'store_id')) {
                $table->unsignedBigInteger('store_id')->nullable()->index()->after('created_by');
            }
            if (!Schema::hasColumn('admins', 'is_store_owner')) {
                $table->boolean('is_store_owner')->default(0)->after('store_id');
            }
        });

        Schema::table('stores', function (Blueprint $table) {
            if (!Schema::hasColumn('stores', 'owner_admin_id')) {
                $table->unsignedBigInteger('owner_admin_id')->nullable()->after('status');
            }
        });

        Schema::table('roles', function (Blueprint $table) {
            if (!Schema::hasColumn('roles', 'store_id')) {
                $table->unsignedBigInteger('store_id')->nullable()->index()->after('guard_name');
            }
        });

        if (DB::table('permission_categories')->count() === 0) {
            return;
        }

        // ---- Store role + permissions ----
        $storeRole = SpatieRole::firstOrCreate(
            ['name' => RoleConst::$roleNameStore, 'guard_name' => 'web']
        );

        $categoryId = DB::table('permission_categories')->where('name', 'store_panel')->value('id');
        if (!$categoryId) {
            $categoryId = DB::table('permission_categories')->insertGetId(['name' => 'store_panel', 'guard_name' => 'web']);
        }
        foreach (['store_user_manage', 'store_role_manage'] as $perm) {
            SpatiePermission::firstOrCreate(
                ['name' => $perm, 'guard_name' => 'web'],
                ['category_id' => $categoryId]
            );
        }

        // ---- Granular Brand / Tax / Attribute permissions ----
        // Previously a single "brands" / "taxes" perm (attributes reused "brands").
        // Split into list/create/update/delete so a store can be given view-only
        // access. Admins that held the old perms get the full new set.
        $productCat = DB::table('permission_categories')->where('name', 'product')->value('id')
            ?: DB::table('permission_categories')->where('name', 'category')->value('id');
        $granular = [
            'brand_list', 'brand_create', 'brand_update', 'brand_delete',
            'tax_list', 'tax_create', 'tax_update', 'tax_delete',
            'attribute_list', 'attribute_create', 'attribute_update', 'attribute_delete',
        ];
        foreach ($granular as $perm) {
            SpatiePermission::firstOrCreate(
                ['name' => $perm, 'guard_name' => 'web'],
                ['category_id' => $productCat]
            );
        }
        // Roles that held the legacy brands/taxes perm keep full CRUD on the new set.
        $legacyIds = SpatiePermission::whereIn('name', ['brands', 'taxes'])->pluck('id')->all();
        $legacyRoleIds = DB::table('role_has_permissions')->whereIn('permission_id', $legacyIds)
            ->distinct()->pluck('role_id')->all();
        foreach ($legacyRoleIds as $rid) {
            if ($role = SpatieRole::find($rid)) {
                $role->givePermissionTo($granular);
            }
        }

        // Full store permission set (the owner's default ceiling).
        $fullPerms = SpatiePermission::whereIn('name', self::storePermissionNames())->pluck('name')->all();
        if ($fullPerms) {
            $storeRole->givePermissionTo($fullPerms); // base "Store" role kept as a label
        }

        // ---- Per-store OWNER role + primary login admin, for every store ----
        // Each store gets its own role (roles.store_id) named "store{id}:__owner__"
        // seeded with the full ceiling; the owner admin sits on it. Idempotent, and
        // repairs any owner previously placed on the shared "Store" role.
        $stores = DB::table('stores')->whereNull('deleted_at')->get(['id', 'name', 'email', 'owner_admin_id']);

        foreach ($stores as $store) {
            $ownerRole = SpatieRole::firstOrCreate(
                ['name' => 'store' . $store->id . ':__owner__', 'guard_name' => 'web'],
                ['store_id' => $store->id]
            );
            if ((int) $ownerRole->store_id !== (int) $store->id) {
                $ownerRole->store_id = $store->id;
                $ownerRole->save();
            }
            if ($fullPerms) {
                $ownerRole->givePermissionTo($fullPerms);
            }

            $admin = $store->owner_admin_id ? Admin::find($store->owner_admin_id) : null;
            if (!$admin) {
                $admin = Admin::where('store_id', $store->id)->where('is_store_owner', 1)->first();
            }
            if (!$admin) {
                $email = trim((string) $store->email);
                if ($email === '' || DB::table('admins')->where('email', $email)->exists()) {
                    $email = 'store' . $store->id . '@store.local';
                }
                if (DB::table('admins')->where('email', $email)->exists()) {
                    continue; // can't provision a login for this store
                }
                $admin = Admin::create([
                    'username'       => is_string($store->name) ? $store->name : ('Store #' . $store->id),
                    'email'          => $email,
                    'password'       => bcrypt(Str::random(16)),
                    'role_id'        => $ownerRole->id,
                    'created_by'     => 0,
                    'store_id'       => $store->id,
                    'is_store_owner' => 1,
                ]);
            }

            // Point the owner admin at its per-store owner role.
            $admin->role_id        = $ownerRole->id;
            $admin->store_id       = $store->id;
            $admin->is_store_owner = 1;
            $admin->save();

            DB::table('model_has_roles')
                ->where('model_type', $admin->getMorphClass())
                ->where('model_id', $admin->id)
                ->delete();
            DB::table('model_has_roles')->insert([
                'role_id'    => $ownerRole->id,
                'model_type' => $admin->getMorphClass(),
                'model_id'   => $admin->id,
            ]);

            if ((int) $store->owner_admin_id !== (int) $admin->id) {
                DB::table('stores')->where('id', $store->id)->update(['owner_admin_id' => $admin->id]);
            }
        }

        // Repair permission -> category links. Inserting the `store_panel` category
        // mid-list shifted category ids, but permissions.category_id was never
        // remapped, so the role modal grouped perms under the wrong categories.
        // Re-point every permission at its category by name (idempotent, self-healing).
        self::repairPermissionCategories();
    }

    /** Authoritative permission -> category map (mirrors PermissionSeeder). */
    private static function repairPermissionCategories(): void
    {
        $map = [
            'dashboard' => ['manage_dashboard'],
            'order' => ['order_list', 'order_update', 'order_delete'],
            'chat' => ['chat'],
            'category' => ['category_list', 'category_create', 'category_update', 'category_delete', 'manage_categories_order'],
            'product' => ['product_list', 'product_create', 'product_update', 'product_delete', 'manage_media', 'manage_product_bulk_upload', 'manage_product_order', 'approve_requests', 'product_ratings', 'taxes', 'brands', 'stock_management', 'brand_list', 'brand_create', 'brand_update', 'brand_delete', 'tax_list', 'tax_create', 'tax_update', 'tax_delete', 'attribute_list', 'attribute_create', 'attribute_update', 'attribute_delete'],
            'store' => ['store_list', 'store_create', 'store_update', 'store_delete'],
            'store_panel' => ['store_user_manage', 'store_role_manage'],
            'home_builder' => ['home_builder_list', 'home_builder_create', 'home_builder_update', 'home_builder_delete', 'home_builder_publish'],
            'popup_offer' => ['popup_offer_update'],
            'promo_code' => ['promo_code_list', 'promo_code_create', 'promo_code_update', 'promo_code_delete'],
            'return_request' => ['return_request_list', 'return_request_update', 'return_request_delete'],
            'withdrawal_request' => ['withdrawal_request_list', 'withdrawal_request_update', 'withdrawal_request_delete'],
            'delivery_boy' => ['delivery_boy_list', 'delivery_boy_create', 'delivery_boy_update', 'delivery_boy_delete', 'delivery_boy_wallet_transactions_list', 'cash_collection_list', 'cash_collection_create', 'delivery_boy_salary_list', 'delivery_boy_salary_create', 'delivery_boy_salary_delete'],
            'send_notification' => ['notification_list', 'send_notification', 'notification_delete'],
            'email_notification' => ['manage_emails', 'send_email', 'delete_send_email'],
            'settings' => ['manage_general_settings', 'manage_login_settings', 'manage_cart_settings', 'manage_website_settings', 'manage_app_settings', 'manage_deeplink_settings', 'manage_social_media', 'manage_seo_settings', 'manage_about_us', 'manage_contact_us', 'manage_smtp_settings', 'manage_chat_settings', 'manage_firebase_settings', 'manage_notification_templates', 'manage_sms_settings', 'manage_sms_templates', 'manage_email_templates', 'manage_api_credentials', 'manage_system_updater', 'manage_cron_jobs', 'manage_activity_logs'],
            'blogs' => ['blog_category_list', 'blog_category_create', 'blog_category_update', 'blog_category_delete', 'blog_list', 'blog_create', 'blog_update', 'blog_delete'],
            'location' => ['zone_list', 'zone_create', 'zone_update', 'zone_delete', 'delivery_city_list', 'delivery_city_create', 'delivery_city_update', 'delivery_city_delete', 'delivery_area_list', 'delivery_area_create', 'delivery_area_update', 'delivery_area_delete'],
            'customer' => ['customer_list', 'customer_update', 'manage_wishlists', 'manage_carts', 'transaction_list', 'manage_customer_wallet', 'manage_privacy_policy'],
            'report' => ['report_sales', 'report_orders', 'report_products', 'report_customers', 'report_inventory', 'report_returns', 'report_delivery', 'report_payment', 'report_category', 'report_promo', 'report_tax', 'report_tax_orders'],
            'faq' => ['faq_list', 'faq_create', 'faq_update', 'faq_delete'],
            'languages' => ['language_list', 'language_create', 'language_update', 'language_delete'],
            'countries' => ['country_list', 'country_create', 'country_update', 'country_delete'],
        ];
        foreach ($map as $categoryName => $permNames) {
            $categoryId = DB::table('permission_categories')->where('name', $categoryName)->value('id');
            if ($categoryId) {
                DB::table('permissions')->whereIn('name', $permNames)->update(['category_id' => $categoryId]);
            }
        }
    }

    /**
     * The Store-role permission set — inlined here so this update migration is
     * fully self-contained (no dependency on the seeder). Kept in sync with
     * PermissionSeeder::storePermissionNames() for fresh installs.
     */
    private static function storePermissionNames(): array
    {
        return [
            'manage_dashboard',
            'product_list', 'product_create', 'product_update', 'stock_management',
            'category_list', 'brand_list', 'tax_list', 'attribute_list',
            'order_list', 'order_update',
            'return_request_list', 'return_request_update',
            'promo_code_list', 'promo_code_create', 'promo_code_update', 'promo_code_delete',
            'home_builder_list', 'home_builder_create', 'home_builder_update', 'home_builder_delete', 'home_builder_publish',
            'customer_list', 'transaction_list', 'manage_customer_wallet',
            'report_sales', 'report_orders', 'report_products', 'report_customers',
            'report_inventory', 'report_returns', 'report_delivery', 'report_payment',
            'report_category', 'report_promo', 'report_tax', 'report_tax_orders',
            'delivery_boy_list', 'delivery_boy_create', 'delivery_boy_update', 'delivery_boy_delete',
            'delivery_boy_wallet_transactions_list', 'cash_collection_list', 'cash_collection_create',
            'delivery_boy_salary_list', 'delivery_boy_salary_create', 'delivery_boy_salary_delete',
            'chat',
            'notification_list', 'send_notification', 'notification_delete',
            'manage_emails', 'send_email', 'delete_send_email',
            'store_user_manage', 'store_role_manage',
        ];
    }

    public function down(): void
    {
        // Remove back-filled store owner admins + their role grants.
        $ownerIds = DB::table('stores')->whereNotNull('owner_admin_id')->pluck('owner_admin_id');
        if ($ownerIds->isNotEmpty()) {
            DB::table('model_has_roles')->whereIn('model_id', $ownerIds)->where('model_type', Admin::class)->delete();
            DB::table('admins')->whereIn('id', $ownerIds)->delete();
            DB::table('stores')->update(['owner_admin_id' => null]);
        }

        Schema::table('admins', function (Blueprint $table) {
            foreach (['store_id', 'is_store_owner'] as $col) {
                if (Schema::hasColumn('admins', $col)) {
                    $table->dropColumn($col);
                }
            }
        });
        Schema::table('stores', function (Blueprint $table) {
            if (Schema::hasColumn('stores', 'owner_admin_id')) {
                $table->dropColumn('owner_admin_id');
            }
        });
        Schema::table('roles', function (Blueprint $table) {
            if (Schema::hasColumn('roles', 'store_id')) {
                $table->dropColumn('store_id');
            }
        });
    }
};
