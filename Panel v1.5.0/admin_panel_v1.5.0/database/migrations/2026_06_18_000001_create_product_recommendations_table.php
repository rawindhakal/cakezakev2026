<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_recommendations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('product_id');           // owner product
            $table->unsignedBigInteger('related_product_id');   // recommended product
            $table->enum('type', ['cross_sell', 'upsell']);
            $table->integer('row_order')->default(0);
            $table->timestamps();

            $table->unique(['product_id', 'related_product_id', 'type'], 'pr_owner_related_type_unique');
            $table->index(['product_id', 'type'], 'pr_owner_type_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_recommendations');
    }
};
