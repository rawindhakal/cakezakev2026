<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('home_layouts')) {
            Schema::create('home_layouts', function (Blueprint $table) {
                $table->id();
                $table->string('name');
                $table->enum('status', ['draft', 'published'])->default('draft');
                $table->enum('mode', ['quick', 'ecommerce'])->default('quick');
                $table->json('channel_label')->nullable();
                $table->enum('home_type', ['single', 'category_wise'])->default('single');

                // Zone scoping:
                $table->string('zone_scope', 10)->default('global')->comment('global | zone');
                $table->unsignedBigInteger('zone_id')->nullable()->index();

                // Category-wise tab lists
                $table->enum('category_scope', ['same', 'split'])->default('same');
                $table->json('category_ids')->nullable();
                $table->json('category_ids_quick')->nullable();
                $table->json('category_ids_ecommerce')->nullable();
                $table->string('category_build_method')->nullable()->default('independent');


                // Layout trees
                $table->json('draft_json')->nullable();
                $table->json('published_json')->nullable();
                $table->json('category_layouts_draft')->nullable();
                $table->json('category_layouts_published')->nullable();
                $table->json('category_tabs_draft')->nullable();
                $table->json('category_tabs_published')->nullable();

                $table->boolean('is_active')->default(1);
                $table->timestamp('published_at')->nullable();
                $table->timestamp('scheduled_publish_at')->nullable();
                $table->timestamps();

                $table->index(['status', 'mode', 'is_active', 'zone_id'], 'home_layouts_resolution_idx');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('home_layouts');
    }
};
