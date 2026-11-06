<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('withdrawal_requests', function (Blueprint $table) {
            $table->id();
            $table->string('type')->comment('user, delivery_boy');
            $table->integer('type_id');
            $table->double('amount');
            $table->unsignedBigInteger('country_id')->nullable();
            $table->string('currency')->nullable();
            $table->string('currency_code')->nullable();
            $table->text('message');
            $table->tinyInteger('status')->default(0);
            $table->text('remark')->nullable()->comment('This is store reject request');
            $table->string('receipt_image')->nullable()->comment('If status: approved (1) then upload receipt as proof');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('withdrawal_requests');
    }
};
