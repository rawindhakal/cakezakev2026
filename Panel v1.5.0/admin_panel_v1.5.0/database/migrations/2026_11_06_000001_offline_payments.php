<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Manual payments: customer proof + admin verification on the order. */
return new class extends Migration {
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $t) {
            if (!Schema::hasColumn('orders', 'payment_proof')) {
                $t->string('payment_proof', 500)->nullable();
                $t->string('payment_reference', 191)->nullable();
                // null = not a manual payment | pending | verified | rejected
                $t->string('payment_verification', 20)->nullable()->index();
                $t->timestamp('payment_verified_at')->nullable();
                $t->unsignedBigInteger('payment_verified_by')->nullable();
                $t->string('payment_verification_note', 500)->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $t) {
            $t->dropColumn(['payment_proof', 'payment_reference', 'payment_verification', 'payment_verified_at', 'payment_verified_by', 'payment_verification_note']);
        });
    }
};
