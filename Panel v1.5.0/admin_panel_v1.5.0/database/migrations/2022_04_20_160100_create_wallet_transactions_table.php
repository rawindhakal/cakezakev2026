<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->id();
            $table->integer('order_id')->nullable();
            $table->integer('order_item_id')->nullable();
            $table->integer('user_id');
            $table->unsignedBigInteger('country_id')->nullable();
            $table->unsignedBigInteger('zone_id')->nullable();
            $table->string('type');
            $table->double('amount');
            $table->string('currency')->nullable();
            $table->string('currency_code')->nullable();
            $table->string('txn_id')->nullable();
            $table->string('payment_type')->nullable();
            $table->dateTime('transaction_date')->useCurrent();
            $table->string('message');
            $table->string('status');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallet_transactions');
    }
};
