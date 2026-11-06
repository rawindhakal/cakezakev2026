<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('languages', function (Blueprint $table) {
            $table->id();
            $table->integer('supported_language_id')->nullable()->default(0);
            $table->string('slug', 191)->nullable()->index();
            $table->integer('system_type')->comment('1 => Customer App, 2 => Delivery Boy App, 3 => Website, 4 => Admin panel');
            $table->string('display_name')->nullable();
            $table->integer('is_default')->nullable()->default(0)->comment('0 => No, 1 => Yes');
            $table->integer('status')->nullable()->default(1)->comment('0 => Deactive, 1 => Active');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('languages');
    }
};
