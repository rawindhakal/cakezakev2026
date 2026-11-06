<?php
namespace Database\Seeders;

use App\Models\Permission;
use App\Models\PermissionCategory;
use App\Models\Role;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
class PermissionSeeder extends Seeder
{
    public function run()
    {
        Artisan::call('cache:forget spatie.permission.cache');
        DB::statement('SET FOREIGN_KEY_CHECKS=0;');
        Permission::truncate();
        DB::statement('SET FOREIGN_KEY_CHECKS=1;');

        /*Role Wise Permissions*/

        /*Super Admin and Admin*/
        $permissionsToSeed = [ 
            [
                'name' => ['manage_dashboard'],
                'category_name' => 'dashboard',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*Orders*/
            [
                'name' => ['order_list','order_update','order_delete'],
                'category_name' => 'order',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*Self pickup orders — the same trio, scoped to orders the customer collects*/
            [
                'name' => ['self_pickup_order_list','self_pickup_order_update','self_pickup_order_delete'],
                'category_name' => 'order',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*Chat*/
            [
                'name' => ['chat'],
                'category_name' => 'chat',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*Categories*/
            [
                'name' => ['category_list','category_create','category_update','category_delete',
                    'manage_categories_order'],
                'category_name' => 'category',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*Products*/
            [
                'name' => ['product_list','product_create','product_update','product_delete',
                    'manage_media','manage_product_bulk_upload','manage_product_order','approve_requests','product_ratings','taxes','brands','stock_management',
                    'brand_list','brand_create','brand_update','brand_delete',
                    'tax_list','tax_create','tax_update','tax_delete',
                    'attribute_list','attribute_create','attribute_update','attribute_delete'],
                'category_name' => 'product',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*Branches*/
            [
                'name' => ['branch_list','branch_create','branch_update','branch_delete'],
                'category_name' => 'branch',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*home_builder*/
            [
                'name' => ['home_builder_list','home_builder_create','home_builder_update','home_builder_delete','home_builder_publish'],
                'category_name' => 'home_builder',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*page_builder*/
            [
                'name' => ['page_builder_list','page_builder_create','page_builder_update','page_builder_delete','page_builder_publish'],
                'category_name' => 'page_builder',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*new_offer_image_list*/
            [
                'name' => ['popup_offer_update'],
                'category_name' => 'popup_offer',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*promo_code*/
            [
                'name' => ['promo_code_list','promo_code_create','promo_code_update','promo_code_delete'],
                'category_name' => 'promo_code',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*spin_wheel*/
            [
                'name' => ['spin_wheel_list','spin_wheel_create','spin_wheel_update','spin_wheel_delete'],
                'category_name' => 'spin_wheel',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*return_request*/
            [
                'name' => ['return_request_list','return_request_update','return_request_delete'],
                'category_name' => 'return_request',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*withdrawal_request*/
            [
                'name' => ['withdrawal_request_list','withdrawal_request_update','withdrawal_request_delete'],
                'category_name' => 'withdrawal_request',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*delivery_boy*/
            [
                'name' => ['delivery_boy_list','delivery_boy_create','delivery_boy_update','delivery_boy_delete',
                    'delivery_boy_wallet_transactions_list','cash_collection_list','cash_collection_create',
                    'delivery_boy_salary_list','delivery_boy_salary_create','delivery_boy_salary_delete'],
                'category_name' => 'delivery_boy',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*send_notification*/
            [
                'name' => ['notification_list','send_notification','notification_delete'],
                'category_name' => 'send_notification',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*email_notification*/
            [
                'name' => ['manage_emails','send_email','delete_send_email'],
                'category_name' => 'email_notification',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*settings — one `manage_*` permission per card on the Settings hub.
              These are single-screen config pages, so there is nothing to split
              into list/create/update/delete: you can either manage the area or not.*/
            [
                'name' => [
                    // General
                    'manage_general_settings',
                    'manage_login_settings',
                    'manage_cart_settings',
                    'manage_invoice_settings',
                    'manage_plugins',
                    // Website & apps
                    'manage_website_settings',
                    'manage_app_settings',
                    'manage_deeplink_settings',
                    'manage_social_media',
                    'manage_seo_settings',
                    'manage_about_us',
                    'manage_contact_us',
                    // Communication
                    'manage_smtp_settings',
                    'manage_chat_settings',
                    'manage_firebase_settings',
                    'manage_notification_templates',
                    'manage_sms_settings',
                    'manage_sms_templates',
                    'manage_email_templates',
                    // Advanced
                    'manage_api_credentials',
                    'manage_system_updater',
                    'manage_cron_jobs',
                    'manage_activity_logs',
                ],
                'category_name' => 'settings',
                'default_roles' => ['Super Admin','Admin']
            ],
            /*blog_categories*/
            [
                'name' => ['blog_category_list','blog_category_create','blog_category_update','blog_category_delete'],
                'category_name' => 'blogs',
                'default_roles' => ['Super Admin','Admin']
            ],
            /*blogs*/
            [
                'name' => ['blog_list','blog_create','blog_update','blog_delete'],
                'category_name' => 'blogs',
                'default_roles' => ['Super Admin','Admin']
            ],
             /*languages*/
             [
                'name' => ['language_list','language_create','language_update','language_delete'],
                'category_name' => 'languages',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*countries*/
            [
                'name' => ['country_list','country_create','country_update','country_delete'],
                'category_name' => 'countries',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*location*/
            [
                'name' => [
                    'zone_list','zone_create','zone_update','zone_delete',
                    'delivery_city_list','delivery_city_create','delivery_city_update','delivery_city_delete',
                    'delivery_area_list','delivery_area_create','delivery_area_update','delivery_area_delete',
                ],
                'category_name' => 'location',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*customer*/
            [
                'name' => ['customer_list','customer_update','manage_wishlists','manage_carts','manage_stock_alerts','transaction_list','manage_customer_wallet','manage_privacy_policy'],
                'category_name' => 'customer',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*report — one permission per report so access can be granted individually*/
            [
                'name' => ['report_sales','report_orders','report_products','report_customers',
                    'report_inventory','report_returns','report_delivery','report_payment',
                    'report_category','report_promo','report_tax','report_tax_orders'],
                'category_name' => 'report',
                'default_roles' => ['Super Admin','Admin']
            ],

            /*faq*/
            [
                'name' => ['faq_list','faq_create','faq_update','faq_delete'],
                'category_name' => 'faq',
                'default_roles' => ['Super Admin','Admin']
            ],
        ];
        foreach ($permissionsToSeed as $record) {
            $category = PermissionCategory::firstOrCreate(
                ['name' => $record['category_name'], 'guard_name' => 'web']
            );

            foreach ($record['name'] as $permissionName) {
                Permission::create([
                    'name' => $permissionName,
                    'category_id' => $category->id,
                ]);
            }

            foreach ($record['default_roles'] as $roleName) {
                $adminRole = \Spatie\Permission\Models\Role::where('name', $roleName)->first();
                if ($adminRole) {
                    $adminRole->givePermissionTo($record['name']);
                }
            }
        }

/**********************************************************************************************/

        /*Delivery Boy*/
        $permissionsToSeed = [
            [
                'name' => ['manage_dashboard'],
                'category_name' => 'dashboard',
                'default_roles' => [Role::$roleNameDeliveryBoy]
            ],

            /*Orders*/
            [
                'name' => ['order_list','order_update','order_delete'],
                'category_name' => 'order',
                'default_roles' => [Role::$roleNameDeliveryBoy]
            ],

            /*return_request*/
            [
                'name' => ['return_request_list','return_request_update'],
                'category_name' => 'return_request',
                'default_roles' => [Role::$roleNameDeliveryBoy]
            ],
        ];
        foreach ($permissionsToSeed as $record) {
            foreach ($record['default_roles'] as $roleName) {
                $adminRole = \Spatie\Permission\Models\Role::where('name', $roleName)->first();
                $adminRole->givePermissionTo($record['name']);
            }
        }

/**********************************************************************************************/

        /*Branch panel — two NEW permissions the branch owner uses to manage its own
          sub-users and branch-scoped roles. Created here (don't exist elsewhere).*/
        $branchPanelCategory = PermissionCategory::firstOrCreate(
            ['name' => 'branch_panel', 'guard_name' => 'web']
        );
        foreach (['branch_user_manage', 'branch_role_manage'] as $branchPanelPerm) {
            Permission::create([
                'name' => $branchPanelPerm,
                'category_id' => $branchPanelCategory->id,
            ]);
        }

        /*Branch role — reduced set scoped to a single branch/zone. All names below
          already exist (created in the admin block) except the two branch_panel
          perms just created above.*/
        $branchRole = \Spatie\Permission\Models\Role::where('name', Role::$roleNameBranch)->first();
        if ($branchRole) {
            $branchRole->givePermissionTo(self::branchPermissionNames());
        }
    }

    /**
     * Canonical Branch-role permission set (shared with the branch-login data
     * migration so fresh installs and updates grant the same permissions).
     */
    /** Delegates to the single source of truth on the Role model. */
    public static function branchPermissionNames(): array
    {
        return Role::branchPermissionNames();
    }
}
