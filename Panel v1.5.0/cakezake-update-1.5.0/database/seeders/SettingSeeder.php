<?php

namespace Database\Seeders;

use App\Models\Setting;
use Illuminate\Database\Seeder;

class SettingSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        Setting::truncate();

        $settings = [
            [
                'variable' => 'app_name',
                'value' => 'CakeZake',
            ],
            [
                'variable' => 'support_number',
                'value' => '1234567890',
            ],
            [
                'variable' => 'support_email',
                'value' => 'support@gmail.com',
            ],
            [
                'variable' => 'logo',
                'value' => '',
            ],
            [
                'variable' => 'purchase_code',
                'value' => '',
            ],
            [
                'variable' => 'max_cart_items_count',
                'value' => '10',
            ],
            [
                'variable' => 'email_login',
                'value' => '1',
            ],
            [
                'variable' => 'phone_login',
                'value' => '1',
            ],
            [
                'variable' => 'phone_auth_otp',
                'value' => '1',
            ],
            [
                'variable' => 'firebase_authentication',
                'value' => '1',
            ],
            [
                'variable' => 'google_login',
                'value' => '1',
            ],
            [
                'variable' => 'apple_login',
                'value' => '1',
            ],
            [
                'variable' => 'product_rating',
                'value' => '1',
            ],
            [
                'variable' => 'admin_theme_color',
                'value' => '#FE3C5E',
            ],
            [
                'variable' => 'password_min_length',
                'value' => '6',
            ],
            [
                'variable' => 'password_max_length',
                'value' => '',
            ],
            [
                'variable' => 'password_require_uppercase',
                'value' => '0',
            ],
            [
                'variable' => 'password_require_lowercase',
                'value' => '0',
            ],
            [
                'variable' => 'password_require_number',
                'value' => '0',
            ],
            [
                'variable' => 'password_require_special',
                'value' => '0',
            ],
            [
                'variable' => 'order_prefix',
                'value' => 'ORD-',
            ],
            [
                'variable' => 'return_request_prefix',
                'value' => 'RET-',
            ],
            [
                'variable' => 'invoice_prefix',
                'value' => 'INV-',
            ]
        ];

        foreach ($settings as $setting){
            Setting::create($setting);
        }
    }
}
