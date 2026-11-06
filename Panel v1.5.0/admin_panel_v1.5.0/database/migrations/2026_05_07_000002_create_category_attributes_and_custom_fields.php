<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('category_attribute', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('category_id');
            $table->unsignedBigInteger('attribute_id');
            $table->tinyInteger('is_overridden_off')->default(0)
                ->comment('1 = child category disabled this inherited attribute');
            $table->timestamps();

            $table->foreign('category_id')->references('id')->on('categories')->onDelete('cascade');
            $table->foreign('attribute_id')->references('id')->on('attributes')->onDelete('cascade');
            $table->unique(['category_id', 'attribute_id']);
        });

        Schema::create('category_custom_sections', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('category_id');
            $table->string('name');
            $table->tinyInteger('is_overridden_off')->default(0);
            $table->integer('sort_order')->default(0);
            $table->timestamps();

            $table->foreign('category_id')->references('id')->on('categories')->onDelete('cascade');
            $table->index(['category_id', 'sort_order']);
        });

        Schema::create('category_custom_section_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('category_custom_section_id');
            $table->unsignedBigInteger('language_id');
            $table->string('name')->nullable();
            $table->timestamps();

            $table->foreign('category_custom_section_id', 'cat_custom_section_trans_fk')
                ->references('id')->on('category_custom_sections')->onDelete('cascade');
            $table->foreign('language_id', 'cat_custom_section_trans_lang_fk')
                ->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['category_custom_section_id', 'language_id'], 'cat_custom_section_trans_unique');
        });

        Schema::create('category_custom_fields', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('category_custom_section_id');
            $table->string('field_label');
            $table->enum('field_type', ['text', 'number', 'textarea', 'dropdown', 'checkbox', 'boolean', 'date']);
            $table->json('options')->nullable();
            $table->tinyInteger('is_required')->default(0);
            $table->integer('sort_order')->default(0);
            $table->timestamps();

            $table->foreign('category_custom_section_id', 'ccf_section_fk')
                ->references('id')->on('category_custom_sections')->onDelete('cascade');
            $table->index(['category_custom_section_id', 'sort_order'], 'ccf_section_sort_idx');
        });

        Schema::create('category_custom_field_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('category_custom_field_id');
            $table->unsignedBigInteger('language_id');
            $table->string('field_label')->nullable();
            $table->json('options')->nullable();
            $table->timestamps();

            $table->foreign('category_custom_field_id', 'cat_custom_field_trans_fk')
                ->references('id')->on('category_custom_fields')->onDelete('cascade');
            $table->foreign('language_id', 'cat_custom_field_trans_lang_fk')
                ->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['category_custom_field_id', 'language_id'], 'cat_custom_field_trans_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('category_custom_field_translations');
        Schema::dropIfExists('category_custom_fields');
        Schema::dropIfExists('category_custom_section_translations');
        Schema::dropIfExists('category_custom_sections');
        Schema::dropIfExists('category_attribute');
    }
};
