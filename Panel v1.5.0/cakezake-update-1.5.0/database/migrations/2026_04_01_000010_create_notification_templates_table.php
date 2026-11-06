<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notification_templates', function (Blueprint $table) {
            $table->id();
            $table->string('type', 100)->unique();
            $table->string('audience', 20)->nullable()->index();
            $table->string('category', 40)->nullable();
            $table->string('title');
            $table->text('message')->nullable();
            $table->json('placeholders')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_templates');
    }
};
