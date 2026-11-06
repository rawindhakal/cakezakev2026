<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_variant_attribute_values', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('product_variant_id');
            $table->unsignedBigInteger('attribute_id');
            $table->unsignedBigInteger('attribute_value_id');
            $table->timestamps();

            $table->foreign('product_variant_id', 'pvav_variant_fk')
                ->references('id')->on('product_variants')->onDelete('cascade');
            $table->foreign('attribute_id', 'pvav_attr_fk')
                ->references('id')->on('attributes')->onDelete('cascade');
            $table->foreign('attribute_value_id', 'pvav_value_fk')
                ->references('id')->on('attribute_values')->onDelete('cascade');

            $table->unique(['product_variant_id', 'attribute_id'], 'pvav_variant_attr_unique');
            $table->index(['attribute_value_id', 'product_variant_id'], 'pvav_value_variant_idx');
            $table->index(['attribute_id', 'attribute_value_id'], 'pvav_attr_value_idx');
        });

        Schema::create('product_variant_custom_values', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('product_variant_id');
            $table->unsignedBigInteger('category_custom_field_id');
            $table->text('value_text')->nullable();
            $table->decimal('value_number', 18, 4)->nullable();
            $table->date('value_date')->nullable();
            $table->json('value_json')->nullable();
            $table->timestamps();

            $table->foreign('product_variant_id', 'pvcv_variant_fk')
                ->references('id')->on('product_variants')->onDelete('cascade');
            $table->foreign('category_custom_field_id', 'pvcv_field_fk')
                ->references('id')->on('category_custom_fields')->onDelete('cascade');

            $table->unique(['product_variant_id', 'category_custom_field_id'], 'pvcv_variant_field_unique');
            $table->index(['category_custom_field_id', 'value_number'], 'pvcv_field_number_idx');
            $table->index(['category_custom_field_id', 'value_date'], 'pvcv_field_date_idx');
            $table->index('category_custom_field_id', 'pvcv_field_idx');
        });

        Schema::create('product_variant_custom_value_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('product_variant_custom_value_id');
            $table->unsignedBigInteger('language_id');
            $table->text('value_text')->nullable();
            $table->json('value_json')->nullable();
            $table->timestamps();

            $table->foreign('product_variant_custom_value_id', 'pvcvt_value_fk')
                ->references('id')->on('product_variant_custom_values')->onDelete('cascade');
            $table->foreign('language_id', 'pvcvt_lang_fk')
                ->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['product_variant_custom_value_id', 'language_id'], 'pvcvt_value_lang_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_variant_custom_value_translations');
        Schema::dropIfExists('product_variant_custom_values');
        Schema::dropIfExists('product_variant_attribute_values');
    }
};
