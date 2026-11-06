<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\ApiCallTracking;

class ApiCallTrackingSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $apis = [
            'google_places_autocomplete',
            'google_places_details', 
            'google_maps_geocoding',
            'google_gemini'
        ];

        $sources = ['app', 'web'];

        foreach ($apis as $api) {
            foreach ($sources as $source) {
                ApiCallTracking::updateOrCreate(
                    [
                        'api_name' => $api,
                        'source' => $source
                    ],
                    [
                        'count' => 0
                    ]
                );
            }
        }
    }
} 