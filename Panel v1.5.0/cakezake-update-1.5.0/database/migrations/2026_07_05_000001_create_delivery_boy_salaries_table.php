<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Delivery-boy salary payout log. Standalone ledger (does NOT touch the boy's
 * COD/earnings balance). The delivery boy is soft-deleted (never destroyed), so
 * the row always resolves via join - no identity snapshot needed here. No FK
 * cascade so history is never removed.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('delivery_boy_salaries')) {
            Schema::create('delivery_boy_salaries', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('delivery_boy_id')->nullable()->index();
                $table->decimal('amount', 12, 2)->default(0);
                $table->date('paid_on')->nullable();
                $table->text('note')->nullable();
                $table->unsignedBigInteger('created_by')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('delivery_boy_salaries');
    }
};
