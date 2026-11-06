<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('delivery_boys', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('admin_id')->nullable();
            $table->unsignedBigInteger('country_id')->nullable();
            $table->unsignedBigInteger('zone_id')->nullable()->index();
            $table->string('name');
            $table->string('profile')->nullable();
            $table->string('country_code')->nullable();
            $table->string('mobile');
            $table->text('address');
            $table->integer('bonus_type')->default(0)->nullable()->comment('0 -> fixed/Salaried, 1 -> Commission');
            $table->double('bonus_percentage')->default(0)->nullable();
            $table->double('bonus_min_amount')->default(0)->nullable();
            $table->double('bonus_max_amount')->default(0)->nullable();
            $table->integer('return_bonus_type')->default(0)->nullable()->comment('0 -> fixed/Salaried, 1 -> Commission');
            $table->double('return_bonus_percentage')->default(0)->nullable();
            $table->double('return_bonus_min_amount')->default(0)->nullable();
            $table->double('return_bonus_max_amount')->default(0)->nullable();
            $table->double('balance')->nullable()->default(0);
            $table->text('driving_license')->nullable();
            $table->text('national_identity_card')->nullable();
            $table->date('dob')->nullable();
            $table->text('bank_account_number')->nullable();
            $table->text('bank_name')->nullable();
            $table->text('account_name')->nullable();
            $table->text('ifsc_code')->nullable();
            $table->text('other_payment_information')->nullable();
            $table->tinyInteger('status')->default(1);
            $table->double('cash_received')->default(0);
            $table->text('remark')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('delivery_boys');
    }
};
