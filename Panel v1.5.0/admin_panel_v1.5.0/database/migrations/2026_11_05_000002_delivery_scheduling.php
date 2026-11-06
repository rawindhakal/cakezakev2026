<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Scheduled delivery: customers pick a delivery date and time slot at checkout; admins define slots,
 * capacity and blocked dates, and filter / plan orders by delivery date.
 */
return new class extends Migration {
    public function up(): void
    {
        Schema::create('delivery_slots', function (Blueprint $table) {
            $table->id();
            $table->string('label');
            $table->time('start_time');
            $table->time('end_time');
            $table->unsignedInteger('capacity')->nullable()->comment('Max orders per date for this slot; null = unlimited');
            $table->decimal('extra_charge', 10, 2)->default(0);
            $table->unsignedInteger('sort_order')->default(0);
            $table->boolean('status')->default(true);
            $table->timestamps();
        });

        Schema::create('delivery_blackout_dates', function (Blueprint $table) {
            $table->id();
            $table->date('date')->index();
            $table->unsignedBigInteger('slot_id')->nullable()->comment('null = whole day closed');
            $table->string('reason')->nullable();
            $table->timestamps();
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->unsignedBigInteger('delivery_slot_id')->nullable()->after('delivery_slot');
            $table->dateTime('delivery_starts_at')->nullable()->after('delivery_slot_id')->comment('UTC');
            $table->dateTime('delivery_ends_at')->nullable()->after('delivery_starts_at')->comment('UTC');
            $table->index('delivery_date');
            $table->index(['delivery_date', 'delivery_slot_id']);
        });

        $now = now();
        $slots = [
            ['09:00 AM - 12:00 PM', '09:00', '12:00', 15],
            ['12:00 PM - 03:00 PM', '12:00', '15:00', 15],
            ['03:00 PM - 06:00 PM', '15:00', '18:00', 15],
            ['06:00 PM - 09:00 PM', '18:00', '21:00', 15],
        ];
        foreach ($slots as $i => [$label, $s, $e, $cap]) {
            DB::table('delivery_slots')->insert(['label' => $label, 'start_time' => $s, 'end_time' => $e, 'capacity' => $cap,
                'extra_charge' => 0, 'sort_order' => $i, 'status' => 1, 'created_at' => $now, 'updated_at' => $now]);
        }
        foreach ([
            'scheduling_required' => '1',
            'scheduling_max_advance_days' => '60',
            'scheduling_min_lead_minutes' => '60',
        ] as $k => $v) {
            DB::table('settings')->updateOrInsert(['variable' => $k], ['value' => $v]);
        }
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropIndex(['delivery_date', 'delivery_slot_id']);
            $table->dropIndex(['delivery_date']);
            $table->dropColumn(['delivery_slot_id', 'delivery_starts_at', 'delivery_ends_at']);
        });
        Schema::dropIfExists('delivery_blackout_dates');
        Schema::dropIfExists('delivery_slots');
        DB::table('settings')->whereIn('variable', ['scheduling_required', 'scheduling_max_advance_days', 'scheduling_min_lead_minutes'])->delete();
    }
};
