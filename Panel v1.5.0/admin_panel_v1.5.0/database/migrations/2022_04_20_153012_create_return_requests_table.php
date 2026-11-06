<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('return_requests', function (Blueprint $table) {
            $table->id();
            $table->string('return_number')->nullable()->index();
            $table->integer('user_id');
            $table->integer('product_variant_id');
            $table->integer('order_id');
            $table->integer('order_item_id')->unique();
            $table->integer('address_id')->nullable();
            $table->text('address')->nullable();
            $table->text('return_reason');
            $table->tinyInteger('status')->default(0);
            $table->text('remarks')->nullable();
            $table->text('reject_reason')->nullable();
            $table->integer('delivery_boy_id');
            $table->json('delivery_boy_bonus_details')->nullable();
            $table->decimal('delivery_boy_bonus_amount', 12, 2)->default(0);
            $table->integer('bonus_credited')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('return_requests');
    }
};
