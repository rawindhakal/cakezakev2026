<?php
namespace Database\Seeders;

use App\Models\PermissionCategory;
use Illuminate\Database\Seeder;
class PermissionCategoriesSeeder extends Seeder
{
    public function run()
    {
        PermissionCategory::truncate();

        $data = [
            ['name'=>'dashboard','guard_name'=>'web'],
            ['name'=>'order','guard_name'=>'web'],
            ['name'=>'chat','guard_name'=>'web'],
            ['name'=>'category','guard_name'=>'web'],
            ['name'=>'product','guard_name'=>'web'],
            ['name'=>'branch','guard_name'=>'web'],
            ['name'=>'branch_panel','guard_name'=>'web'],
            ['name'=>'home_builder','guard_name'=>'web'],
            ['name'=>'page_builder','guard_name'=>'web'],
            ['name'=>'popup_offer','guard_name'=>'web'],
            ['name'=>'promo_code','guard_name'=>'web'],
            ['name'=>'spin_wheel','guard_name'=>'web'],
            ['name'=>'return_request','guard_name'=>'web'],
            ['name'=>'withdrawal_request','guard_name'=>'web'],
            ['name'=>'delivery_boy','guard_name'=>'web'],
            ['name'=>'send_notification','guard_name'=>'web'],
            ['name'=>'email_notification','guard_name'=>'web'],
            ['name'=>'settings','guard_name'=>'web'],
            ['name'=>'blogs','guard_name'=>'web'],
            ['name'=>'location','guard_name'=>'web'],
            ['name'=>'customer','guard_name'=>'web'],
            ['name'=>'report','guard_name'=>'web'],
            ['name'=>'faq','guard_name'=>'web'],
            ['name'=>'languages','guard_name'=>'web'],
            ['name'=>'countries','guard_name'=>'web'],
        ];

        PermissionCategory::insert($data);
    }
}
