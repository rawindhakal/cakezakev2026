<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('countries', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('dial_code');
            $table->unsignedTinyInteger('min_mobile_length')->default(7);
            $table->unsignedTinyInteger('max_mobile_length')->default(15);
            $table->string('code');
            $table->text('logo')->nullable();
            $table->string('currency')->nullable();
            $table->string('currency_code')->nullable();
            $table->unsignedTinyInteger('decimal_point')->default(2);
            $table->json('payment_gateways')->nullable();
            $table->string('date_format')->nullable();
            $table->string('time_format')->nullable();
            $table->string('timezone', 64)->default('UTC');
            $table->decimal('referral_min_order_amount', 12, 2)->default(0);
            $table->decimal('referral_credit_first_order', 12, 2)->default(0);
            $table->decimal('referral_credit_referred', 12, 2)->default(0);
            $table->unsignedInteger('referral_usage_limit')->nullable();
            $table->longText('privacy_policy')->nullable();
            $table->longText('return_policy')->nullable();
            $table->longText('shipping_policy')->nullable();
            $table->longText('cancellation_policy')->nullable();
            $table->longText('terms_conditions')->nullable();
            $table->longText('privacy_policy_delivery_boy')->nullable();
            $table->longText('terms_conditions_delivery_boy')->nullable();
            $table->tinyInteger('status')->default(1);
            $table->boolean('is_default')->default(0);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('countries');
    }
};
