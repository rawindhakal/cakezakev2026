<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('api_call_tracking', function (Blueprint $table) {
            $table->id();
            $table->string('api_name');
            $table->string('source'); // 'app' or 'web'
            $table->unsignedBigInteger('count')->default(0);
            $table->timestamps();
            
            // Create unique index to prevent duplicate entries for same api_name and source
            $table->unique(['api_name', 'source']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('api_call_tracking');
    }
}; 