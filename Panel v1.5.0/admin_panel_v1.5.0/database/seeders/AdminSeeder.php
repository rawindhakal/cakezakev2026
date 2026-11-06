<?php

namespace Database\Seeders;

use App\Models\DeliveryBoy;
use App\Models\Role;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;

class AdminSeeder extends Seeder
{
    public function run()
    {
        Schema::disableForeignKeyConstraints();

        \App\Models\Admin::truncate();
        \App\Models\User::truncate();
        \App\Models\Branch::truncate();
        \App\Models\DeliveryBoy::truncate();

        Schema::enableForeignKeyConstraints();

        /*Admins*/
        $superAdmin = \App\Models\Admin::create([
            'username' => 'superadmin',
            'email' => 'admin@gmail.com',
            'password' => bcrypt('123456'),
            'role_id' => 1,
            'created_by' => 1,
        ]);
        $superAdmin->assignRole('Super Admin');

        $admin = \App\Models\Admin::create([
            'username' => 'Admin',
            'email' => 'admin2@gmail.com',
            'password' => bcrypt('123456'),
            'role_id' => 2,
            'created_by' => 1,
        ]);
        $admin->assignRole('Admin');

        /*Delivery Boy*/
        $deliveryBoy = \App\Models\Admin::create([
            'username' => 'Delivery Boy',
            'email' => 'delivery@gmail.com',
            'password' => bcrypt('123456'),
            'role_id' => Role::$roleDeliveryBoy,
            'created_by' => 1,
        ]);
        $deliveryBoy->assignRole(Role::$roleNameDeliveryBoy);
        $deliveryBoyData = array();
        $deliveryBoyData['admin_id'] = $deliveryBoy->id;
        $deliveryBoyData['name'] = 'Delivery Boy';
        $deliveryBoyData['mobile'] = '9558192002';
        $deliveryBoyData['balance'] = 0;
        $deliveryBoyData['address'] = "Bhuj";
        $deliveryBoyData['status'] = 1;
        DeliveryBoy::create($deliveryBoyData);

        /*Users*/
        \App\Models\User::create([
            'name' => 'Customer',
            'email' => 'customer@gmail.com',
            'password' => bcrypt('123456'),
            'mobile' => 123456789,
            'status' => 1,
        ]);
    }
}
