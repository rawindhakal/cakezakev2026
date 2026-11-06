<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_items', function (Blueprint $table) {
            $table->id();
            $table->string('invoice_number')->nullable()->index();
            $table->unsignedBigInteger('user_id')->index();
            $table->unsignedBigInteger('order_id');
            $table->text('product_name')->nullable();
            $table->string('hsn_code')->nullable();
            $table->json('variant_attributes')->nullable();
            $table->unsignedBigInteger('product_variant_id');
            $table->string('prescription')->nullable()->comment('relative storage path of the uploaded prescription (image or pdf)');
            $table->integer('delivery_boy_id')->nullable()->default(0);
            $table->json('delivery_boy_bonus_details')->nullable();
            $table->decimal('delivery_boy_bonus_amount', 12, 2)->default(0);
            $table->integer('quantity');
            $table->decimal('price', 12, 2);
            $table->decimal('discounted_price', 12, 2);
            $table->decimal('purchase_price', 12, 2)->default(0)->comment('Cost snapshot from the fulfilling store PVSS at order time (for profit/margin reports)');
            $table->decimal('tax_amount', 12, 2)->default(0);
            $table->decimal('tax_percentage', 8, 2)->default(0);
            $table->decimal('sub_total', 12, 2);
            $table->decimal('delivery_charge', 12, 2)->default(0)->comment('Ecommerce orders only (per-item split of the order delivery charge)');
            $table->json('additional_charges')->nullable()->comment('Ecommerce orders only (per-item split of order additional charges)');
            $table->json('surge_charges')->nullable()->comment('Ecommerce orders only (per-item split of order surge charges)');
            $table->decimal('promo_discount', 12, 2)->default(0)->comment('Ecommerce orders only (per-item split of the order promo discount)');
            $table->decimal('wallet_balance', 12, 2)->default(0)->comment('Ecommerce orders only (per-item split of wallet used)');
            $table->decimal('final_total', 12, 2)->default(0)->comment('Ecommerce orders only (per-item payable total)');
            $table->decimal('refund_amount', 12, 2)->nullable();
            $table->text('status');
            $table->string('active_status');
            $table->integer('otp')->default(0);
            $table->text('cancellation_reason')->nullable();
            $table->timestamp('canceled_at')->nullable();
            $table->unsignedBigInteger('store_id');
            $table->tinyInteger('cancelable_status')->default(0);
            $table->string('till_status')->nullable();
            $table->tinyInteger('return_status')->default(0);
            $table->integer('return_days')->default(0);
            $table->tinyInteger('is_credited')->nullable()->default(0);
            $table->string('courier_agency')->nullable();
            $table->string('tracking_id')->nullable();
            $table->string('tracking_url', 1000)->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index('order_id');
            $table->index('product_variant_id');
            $table->index('store_id');
            $table->index('active_status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_items');
    }
};
