<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->string('name')->nullable();
            $table->string('sales_channel', 20)->default('both')->comment('quick | ecommerce | both');
            $table->text('tags')->nullable();
            $table->tinyInteger('tax_id')->nullable()->default(0);
            $table->integer('brand_id')->nullable()->default(0);
            $table->string('slug')->nullable();
            $table->integer('category_id');
            $table->tinyInteger('product_type')->nullable()->comment('0 - none | 1 - veg | 2 - non-veg | 3 - chemical | 4 - eggetarian | 5 - medical');
            $table->tinyInteger('is_prescription_required')->default(0)->comment('1 - customer must upload a prescription (product_type = 5 only)');
            $table->string('manufacturer')->nullable();
            $table->string('made_in')->nullable();
            $table->tinyInteger('return_status')->nullable();
            $table->tinyInteger('cancelable_status')->nullable();
            $table->string('till_status_quick')->nullable();
            $table->string('till_status_ecommerce')->nullable();
            $table->text('image')->nullable();
            $table->text('short_description')->nullable();
            $table->text('description')->nullable();
            $table->integer('status')->default(0);
            $table->tinyInteger('is_draft')->default(0);
            $table->integer('return_days')->default(0);
            $table->tinyInteger('cod_allowed')->nullable();
            $table->integer('total_allowed_quantity')->nullable();
            $table->tinyInteger('tax_included_in_price')->default(0);
            $table->string('meta_title')->nullable();
            $table->text('meta_keywords')->nullable();
            $table->text('schema_markup')->nullable();
            $table->text('meta_description')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
