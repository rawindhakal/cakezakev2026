<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('blog_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name')->nullable();
            $table->string('slug')->unique();
            $table->string('meta_title')->nullable();
            $table->text('meta_keywords')->nullable();
            $table->text('meta_description')->nullable();
            $table->text('schema_markup')->nullable();
            $table->tinyInteger('status')->default(1)->comment('1=Active, 0=Inactive');
            $table->timestamps();
        });

        Schema::create('blogs', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->string('slug')->unique();
            $table->unsignedBigInteger('category_id');
            $table->string('image')->nullable();
            $table->text('description');
            $table->text('short_description')->nullable();
            $table->text('tags')->nullable();
            $table->string('meta_title')->nullable();
            $table->text('meta_keywords')->nullable();
            $table->text('meta_description')->nullable();
            $table->text('schema_markup')->nullable();
            $table->integer('views_count')->default(0)->comment('Total view count for this blog');
            $table->tinyInteger('status')->default(1)->comment('1=Active, 0=Inactive');
            $table->timestamps();

            $table->foreign('category_id')->references('id')->on('blog_categories')->onDelete('cascade');
        });

         Schema::create('blog_views', function (Blueprint $table) {
            $table->unsignedBigInteger('blog_id');
            $table->string('ip_address');
            $table->foreign('blog_id')->references('id')->on('blogs')->onDelete('cascade');
            $table->unique(['blog_id', 'ip_address']);
            $table->index(['blog_id', 'ip_address']);
        });

         Schema::create('blog_tag', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->unsignedBigInteger('language_id')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('blog_categories');
        Schema::dropIfExists('blogs');
        Schema::dropIfExists('blog_views');
        Schema::dropIfExists('blog_tag');
    }
};
