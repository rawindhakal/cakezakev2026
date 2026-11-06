<?php

namespace Database\Seeders;

use App\Models\Country;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Artisan;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     *
     * @return void
     */
    public function run()
    {
        $this->call(RoleSeeder::class);
        $this->call(PermissionCategoriesSeeder::class);
        $this->call(PermissionSeeder::class);
        $this->call(OrderStatusList::class);
        $this->call(SettingSeeder::class);
        $this->call(SupportedLanguageSeeder::class);
        $this->call(ApiCallTrackingSeeder::class);
        $this->call(LanguageSeeder::class);
        $this->call(DefaultCountrySeeder::class);
        $this->call(NotificationTemplatesSeeder::class);
        $this->call(SmsTemplatesSeeder::class);
        $this->call(EmailTemplatesSeeder::class);
        Artisan::call('notifications:sync');
        $this->call(HomeLayoutSeeder::class);
    }
}
