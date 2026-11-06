<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Country-wise wallet balance. One row per (user, country); supersedes users.balance.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('user_wallets')) {
            Schema::create('user_wallets', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('country_id');
                $table->decimal('balance', 14, 2)->default(0);
                $table->timestamps();
                $table->unique(['user_id', 'country_id']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('user_wallets');
    }
};
