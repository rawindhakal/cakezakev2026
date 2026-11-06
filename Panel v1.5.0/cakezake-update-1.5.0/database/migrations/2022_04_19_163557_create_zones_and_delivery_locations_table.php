<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('delivery_cities', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('state')->nullable();
            $table->unsignedBigInteger('country_id')->nullable();
            $table->json('boundary_points')->nullable();
            $table->decimal('latitude', 11, 8)->nullable();
            $table->decimal('longitude', 11, 8)->nullable();
            $table->tinyInteger('status')->default(1);
            $table->timestamps();
        });

        Schema::create('delivery_areas', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('delivery_city_id');
            $table->string('name');
            $table->json('boundary_points')->nullable();
            $table->decimal('latitude', 11, 8)->nullable();
            $table->decimal('longitude', 11, 8)->nullable();
            $table->tinyInteger('status')->default(1);
            $table->timestamps();

            $table->foreign('delivery_city_id')->references('id')->on('delivery_cities')->onDelete('cascade');
        });

        Schema::create('zones', function (Blueprint $table) {
            $table->id();

            // Common
            $table->string('name');
            $table->string('slug')->nullable()->index();
            $table->string('city')->nullable();
            $table->string('state')->nullable();
            $table->unsignedBigInteger('country_id')->nullable();
            $table->tinyInteger('status')->default(1);
            $table->string('sales_channel', 20)->default('quick')->comment('quick | ecommerce | both');
            $table->json('polygon_boundary_quick')->nullable();
            $table->json('polygon_boundary_ecommerce')->nullable();

            // Quick commerce
            $table->string('distance_unit', 8)->default('km');
            $table->decimal('base_delivery_charge', 11, 2)->default(0);
            $table->decimal('base_distance', 11, 2)->default(0);
            $table->decimal('charge_per_km', 11, 2)->default(0);
            $table->decimal('travel_time_per_km', 8, 2)->default(0);
            $table->decimal('minimum_order_amount', 11, 2)->default(0);
            $table->decimal('free_delivery_above', 11, 2)->default(0);
            $table->json('surge_slots')->nullable();
            $table->json('additional_charges_quick')->nullable();
            $table->json('additional_charges_ecommerce')->nullable();

            // eCommerce
            $table->enum('pricing_strategy', ['flat', 'slab', 'city', 'area'])->default('flat');
            $table->decimal('default_delivery_charge', 11, 2)->default(0);
            $table->decimal('free_delivery_threshold', 11, 2)->default(0);
            $table->decimal('flat_delivery_charge', 11, 2)->default(0);
            $table->decimal('flat_free_delivery_above', 11, 2)->default(0);
            $table->json('slab_pricing')->nullable();
            $table->json('city_pricing')->nullable();
            $table->json('area_pricing')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('zones');
        Schema::dropIfExists('delivery_areas');
        Schema::dropIfExists('delivery_cities');
    }
};
