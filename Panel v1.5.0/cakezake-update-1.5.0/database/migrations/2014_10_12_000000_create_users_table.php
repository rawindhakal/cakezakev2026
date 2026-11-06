<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('name')->nullable();
            $table->string('email')->nullable();
            $table->string('password')->nullable();
            $table->boolean('is_verified')->default(false);
            $table->string('email_verification_code')->nullable();
            $table->string('profile')->nullable();
            $table->string('country_code')->default('+91');
            $table->unsignedBigInteger('country_id')->nullable();
            $table->string('mobile')->nullable();
            $table->unsignedBigInteger('language_id')->nullable();
            $table->string('referral_code')->nullable();
            $table->string('friends_code')->nullable();
            $table->integer('status')->default(0);
            $table->enum('type', ['email', 'google', 'apple', 'phone'])->default('phone');
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
