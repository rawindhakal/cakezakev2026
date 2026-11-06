<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stores', function (Blueprint $table) {
            $table->id();

            // Basic details
            $table->string('name');
            $table->string('provider')->nullable();

            // Type
            $table->string('fulfillment_type', 20)->default('quick');
            $table->unsignedBigInteger('zone_id')->nullable()->index();

            // Location
            $table->text('address')->nullable();
            $table->string('latitude')->nullable();
            $table->string('longitude')->nullable();
            $table->string('formatted_address')->nullable();
            $table->string('place_id')->nullable();

            // Contact
            $table->string('contact_number')->nullable();
            $table->string('email')->nullable();

            // Operations
            $table->json('operating_hours')->nullable();

            // Status
            $table->tinyInteger('status')->default(1);

            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stores');
    }
};
