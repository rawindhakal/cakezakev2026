<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('product_variant_store_stocks')) {
            Schema::create('product_variant_store_stocks', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('product_variant_id');
                $table->unsignedBigInteger('store_id');
                $table->tinyInteger('is_listed')->default(1);
                $table->tinyInteger('is_unlimited_stock')->default(0)->comment('0 = Limited & 1 = Unlimited (per store)');
                $table->tinyInteger('stock_status')->default(1)->comment('1 = In stock, 0 = Out of stock');
                $table->integer('available')->default(0);
                $table->integer('reserved')->default(0);
                $table->integer('min_alert')->default(0);
                $table->decimal('price', 12, 2)->nullable();
                $table->decimal('discounted_price', 12, 2)->nullable();
                $table->json('pricing_slabs')->nullable();
                $table->decimal('purchase_price', 12, 2)->nullable()->comment('Cost per store (differs by store country)');
                $table->timestamps();

                $table->unique(['product_variant_id', 'store_id'], 'pvss_variant_store_unique');
                $table->index('store_id');
                $table->foreign('product_variant_id', 'pvss_variant_fk')
                    ->references('id')->on('product_variants')->onDelete('cascade');
                $table->foreign('store_id', 'pvss_store_fk')
                    ->references('id')->on('stores')->onDelete('cascade');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('product_variant_store_stocks');

        if (Schema::hasTable('products') && Schema::hasColumn('products', 'sales_channel')) {
            Schema::table('products', function (Blueprint $table) {
                $table->dropColumn('sales_channel');
            });
        }
    }
};
