<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('return_request_statuses')) {
            return;
        }
        Schema::create('return_request_statuses', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('return_request_id')->index();
            $table->tinyInteger('status');
            $table->unsignedBigInteger('created_by')->nullable();
            $table->integer('user_type')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('return_request_statuses');
    }
};
