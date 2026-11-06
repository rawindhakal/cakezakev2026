<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_addresses', function (Blueprint $table) {
            $table->id();
            $table->integer('user_id');
            $table->string('type');
            $table->string('name');
            $table->string('mobile');
            $table->string('country_code')->nullable();
            $table->string('alternate_mobile')->nullable();
            $table->string('alternate_country_code')->nullable();
            $table->text('address');
            $table->text('landmark');
            $table->string('area');
            $table->string('pincode');
            $table->string('zone_id');
            $table->string('city');
            $table->string('state');
            $table->string('country');
            $table->tinyInteger('is_default')->default(0);
            $table->string('latitude')->nullable();
            $table->string('longitude')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_addresses');
    }
};
