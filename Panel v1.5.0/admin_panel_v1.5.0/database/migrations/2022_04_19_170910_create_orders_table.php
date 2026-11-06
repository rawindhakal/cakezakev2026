<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->string('order_number')->nullable()->index();
            $table->string('invoice_number')->nullable()->index();
            $table->unsignedBigInteger('user_id');
            $table->unsignedBigInteger('delivery_boy_id')->nullable();
            $table->json('delivery_boy_bonus_details')->nullable()->comment('Delivery boy bonus Details for bonus commission amount');
            $table->double('delivery_boy_bonus_amount')->nullable();
            $table->unsignedBigInteger('transaction_id')->nullable();
            $table->integer('otp')->default(0);
            $table->string('mobile');
            $table->text('order_note')->nullable();
            $table->decimal('total', 12, 2);
            $table->decimal('delivery_charge', 12, 2);
            $table->decimal('tax_amount', 12, 2)->default(0);
            $table->decimal('tax_percentage', 8, 2)->default(0);
            $table->decimal('paid_wallet', 12, 2)->default(0);
            $table->decimal('discount', 12, 2)->default(0);
            $table->integer('promo_code_id')->default(0);
            $table->string('promo_code')->nullable();
            $table->decimal('promo_discount', 12, 2)->default(0);
            $table->decimal('cashback_amount', 12, 2)->default(0);
            $table->tinyInteger('cashback_credited')->default(0);
            $table->json('additional_charges')->nullable();
            $table->json('surge_charges')->nullable();
            $table->decimal('final_total', 12, 2)->nullable();
            $table->decimal('saved_amount', 12, 2)->default(0);
            $table->string('currency')->nullable();
            $table->string('currency_code')->nullable();
            $table->string('payment_method');
            $table->integer('address_id')->default(0);
            $table->text('address');
            $table->string('active_status');
            $table->enum('channel', ['quick', 'ecommerce'])->nullable();
            $table->unsignedBigInteger('country_id')->nullable();
            $table->unsignedBigInteger('zone_id')->nullable();
            $table->decimal('wallet_balance', 12, 2);
            $table->decimal('remaining_total', 12, 2)->nullable();
            $table->decimal('remaining_final', 12, 2)->nullable();
            $table->decimal('refund_amount', 12, 2)->default(0);
            $table->timestamps();
            $table->softDeletes();

            $table->index('user_id');
            $table->index('delivery_boy_id');
            $table->index('channel');
            $table->index('active_status');
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
