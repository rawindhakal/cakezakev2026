<?php

namespace Database\Seeders;

use App\Models\Country;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class CountrySeeder extends Seeder
{
    /**
     * Run the database seeds.
     * Foreign key checks disabled temporarily - country_translations references countries.
     *
     * @return void
     */
    public function run()
    {
        DB::statement('SET FOREIGN_KEY_CHECKS=0;');
        if (Schema::hasTable('country_translations')) {
            DB::table('country_translations')->truncate();
        }
        Country::truncate();
        DB::statement('SET FOREIGN_KEY_CHECKS=1;');

        $countries = json_decode(file_get_contents(base_path('config/Country.json')), true);
        Country::insert($countries);
    }
}
