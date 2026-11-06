<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('home_layout_templates')) {
            Schema::create('home_layout_templates', function (Blueprint $table) {
                $table->id();
                $table->string('name');
                $table->string('description')->nullable();
                $table->string('icon', 16)->nullable();
                $table->string('section_type', 64);
                $table->json('section_json');
                $table->unsignedBigInteger('created_by')->nullable();
                $table->timestamps();

                $table->index('section_type');
                $table->index('created_by');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('home_layout_templates');
    }
};
