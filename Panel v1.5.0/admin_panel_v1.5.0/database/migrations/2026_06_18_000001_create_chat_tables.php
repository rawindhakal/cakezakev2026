<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Chat module.
 * Conversation types:
 *   - admin_customer       : general (not order-scoped), one per customer
 *   - admin_delivery_boy   : general, one per delivery boy
 *   - delivery_boy_customer: order-scoped, one per order (ties customer + assigned delivery boy)
 *   - order_admin          : order-scoped customer <-> admin thread
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('conversations', function (Blueprint $table) {
            $table->id();
            $table->enum('type', ['admin_customer', 'admin_delivery_boy', 'delivery_boy_customer', 'order_admin']);
            $table->unsignedBigInteger('order_id')->nullable();
            $table->unsignedBigInteger('user_id')->nullable();          // customer
            $table->unsignedBigInteger('delivery_boy_id')->nullable();
            $table->text('last_message')->nullable();
            $table->string('last_sender_type')->nullable();             // admin | customer | delivery_boy
            $table->timestamp('last_message_at')->nullable();
            $table->timestamps();

            $table->index('type');
            $table->index('order_id');
            $table->index('user_id');
            $table->index('delivery_boy_id');
            $table->index('last_message_at');
        });

        Schema::create('messages', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('conversation_id');
            $table->enum('sender_type', ['admin', 'customer', 'delivery_boy']);
            $table->unsignedBigInteger('sender_id');
            $table->text('message')->nullable();
            $table->string('attachment')->nullable();
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            $table->index('conversation_id');
            $table->index(['conversation_id', 'id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('messages');
        Schema::dropIfExists('conversations');
    }
};
