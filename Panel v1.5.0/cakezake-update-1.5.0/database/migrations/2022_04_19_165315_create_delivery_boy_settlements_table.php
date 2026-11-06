<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateDeliveryBoySettlementsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('delivery_boy_settlements', function (Blueprint $table) {
            $table->id();
            $table->integer('delivery_boy_id');
            $table->integer('country_id')->nullable();
            $table->string('currency')->nullable();
            $table->string('currency_code')->nullable();
            $table->string('type')->comment('credit | debit');
            $table->double('opening_balance');
            $table->double('closing_balance');
            $table->double('amount');
            $table->string('message');
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
        Schema::dropIfExists('delivery_boy_settlements');
    }
}
