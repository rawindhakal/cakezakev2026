<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_tokens', function (Blueprint $table) {
            $table->id();
            $table->integer('user_id');
            $table->string('type');
            $table->string('fcm_token', 255);
            $table->string('platform')->nullable();
            $table->unsignedBigInteger('language_id')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_tokens');
    }
};
