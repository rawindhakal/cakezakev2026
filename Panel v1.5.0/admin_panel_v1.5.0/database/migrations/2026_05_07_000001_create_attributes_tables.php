<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('attributes', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug')->unique();
            $table->tinyInteger('status')->default(1);
            $table->timestamps();
            $table->softDeletes();

            $table->index('status');
        });

        Schema::create('attribute_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('attribute_id');
            $table->unsignedBigInteger('language_id');
            $table->string('name')->nullable();
            $table->timestamps();

            $table->foreign('attribute_id')->references('id')->on('attributes')->onDelete('cascade');
            $table->foreign('language_id')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['attribute_id', 'language_id']);
        });

        Schema::create('attribute_values', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('attribute_id');
            $table->string('value');
            $table->timestamps();
            $table->softDeletes();

            $table->foreign('attribute_id')->references('id')->on('attributes')->onDelete('cascade');
            $table->index('attribute_id');
        });

        Schema::create('attribute_value_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('attribute_value_id');
            $table->unsignedBigInteger('language_id');
            $table->string('value')->nullable();
            $table->timestamps();

            $table->foreign('attribute_value_id', 'attr_val_trans_val_fk')
                ->references('id')->on('attribute_values')->onDelete('cascade');
            $table->foreign('language_id', 'attr_val_trans_lang_fk')
                ->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['attribute_value_id', 'language_id'], 'attr_val_trans_val_lang_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attribute_value_translations');
        Schema::dropIfExists('attribute_values');
        Schema::dropIfExists('attribute_translations');
        Schema::dropIfExists('attributes');
    }
};
