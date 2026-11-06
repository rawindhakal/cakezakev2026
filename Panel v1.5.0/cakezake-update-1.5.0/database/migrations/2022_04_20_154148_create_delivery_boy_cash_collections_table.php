<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateDeliveryBoyCashCollectionsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('delivery_boy_cash_collections', function (Blueprint $table) {
            $table->id();
            $table->integer('user_id')->nullable();
            $table->integer('order_id')->nullable();
            $table->integer('delivery_boy_id')->nullable();
            $table->string('currency')->nullable();
            $table->string('currency_code')->nullable();
            $table->text('type')->nullable();
            $table->string('payment_mode')->nullable();
            $table->unsignedBigInteger('wallet_transaction_id')->nullable();
            $table->double('amount')->default(0.00);
            $table->text('status')->nullable();
            $table->text('message')->nullable();
            $table->dateTime('transaction_date')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('delivery_boy_cash_collections');
    }
}
