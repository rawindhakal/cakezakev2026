<?php

namespace App\Services;

use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Delivery date / time-slot rules shared by the customer API (slot picker, order validation) and the
 * admin planner. Dates are in the store's local timezone; *_at timestamps are stored in UTC.
 */
class DeliverySchedulingService
{
    /** Orders in these statuses no longer occupy a slot (cancelled, returned). */
    public const RELEASED_STATUSES = [7, 8];

    public function tz(): string
    {
        return (string) (DB::table('countries')->where('is_default', 1)->value('timezone') ?: 'Asia/Kathmandu');
    }

    public function now(): Carbon
    {
        return Carbon::now($this->tz());
    }

    public function settings(): array
    {
        $get = fn ($k, $d) => DB::table('settings')->where('variable', $k)->value('value') ?? $d;
        return [
            'required' => (int) $get('scheduling_required', 1) === 1,
            'max_advance_days' => max(1, (int) $get('scheduling_max_advance_days', 60)),
            'min_lead_minutes' => max(0, (int) $get('scheduling_min_lead_minutes', 60)),
        ];
    }

    /** Whole-day closures within the booking window, for the date picker. */
    public function closedDates(): array
    {
        $from = $this->now()->toDateString();
        return DB::table('delivery_blackout_dates')->whereNull('slot_id')->where('date', '>=', $from)
            ->orderBy('date')->pluck('date')->map(fn ($d) => Carbon::parse($d)->toDateString())->values()->all();
    }

    public function config(): array
    {
        $s = $this->settings();
        $today = $this->now()->startOfDay();
        return [
            'required' => $s['required'],
            'timezone' => $this->tz(),
            'today' => $today->toDateString(),
            'min_date' => $today->toDateString(),
            'max_date' => $today->copy()->addDays($s['max_advance_days'])->toDateString(),
            'min_lead_minutes' => $s['min_lead_minutes'],
            'closed_dates' => $this->closedDates(),
        ];
    }

    private function booked(string $date): array
    {
        return DB::table('orders')->where('delivery_date', $date)->whereNotNull('delivery_slot_id')
            ->whereNotIn('active_status', self::RELEASED_STATUSES)
            ->select('delivery_slot_id', DB::raw('COUNT(*) as c'))->groupBy('delivery_slot_id')->pluck('c', 'delivery_slot_id')->all();
    }

    /** Slots for a date with availability, so the app can grey out unavailable ones. */
    public function slotsFor(string $date): array
    {
        $cfg = $this->config();
        $d = Carbon::parse($date, $this->tz())->startOfDay();
        $dateStr = $d->toDateString();
        $outOfRange = $dateStr < $cfg['min_date'] || $dateStr > $cfg['max_date'];
        $closedDay = in_array($dateStr, $cfg['closed_dates'], true);
        $slotClosures = DB::table('delivery_blackout_dates')->where('date', $dateStr)->whereNotNull('slot_id')->pluck('slot_id')->all();
        $booked = $this->booked($dateStr);
        $earliest = $this->now()->addMinutes($cfg['min_lead_minutes']);

        $out = [];
        foreach (DB::table('delivery_slots')->where('status', 1)->orderBy('sort_order')->orderBy('start_time')->get() as $s) {
            $reason = null;
            if ($outOfRange) $reason = 'date_unavailable';
            elseif ($closedDay || in_array($s->id, $slotClosures)) $reason = 'closed';
            else {
                $start = Carbon::parse($dateStr . ' ' . $s->start_time, $this->tz());
                if ($start->lt($earliest)) $reason = 'too_late';
                elseif ($s->capacity !== null && ($booked[$s->id] ?? 0) >= (int) $s->capacity) $reason = 'full';
            }
            $out[] = [
                'id' => (int) $s->id, 'label' => $s->label,
                'start_time' => substr($s->start_time, 0, 5), 'end_time' => substr($s->end_time, 0, 5),
                'extra_charge' => (float) $s->extra_charge,
                'capacity' => $s->capacity === null ? null : (int) $s->capacity,
                'booked' => (int) ($booked[$s->id] ?? 0),
                'available' => $reason === null, 'unavailable_reason' => $reason,
            ];
        }
        return $out;
    }

    /**
     * Validate a customer's choice. Returns ['ok'=>bool, 'message'=>?string, 'data'=>[...order columns], 'extra'=>float, 'extra_name'=>?string].
     * $lock = true re-checks capacity under a row lock (call inside the order transaction).
     */
    public function resolve(?string $date, $slotId, ?string $giftType, bool $lock = false): array
    {
        $settings = $this->settings();
        $now = $this->now();
        $giftType = $giftType ?: null;
        $fail = fn (string $m) => ['ok' => false, 'message' => $m, 'data' => [], 'extra' => 0.0, 'extra_name' => null];

        // Express: delivered within the lead time today, no slot needed.
        if ($giftType === 'express') {
            $today = $now->toDateString();
            if ($date && $date !== $today) return $fail('Express delivery is only available for today.');
            if (in_array($today, $this->closedDates(), true)) return $fail('We are not delivering today.');
            $mins = max(60, $settings['min_lead_minutes']);
            return ['ok' => true, 'message' => null, 'extra' => 0.0, 'extra_name' => null, 'data' => [
                'delivery_date' => $today, 'delivery_slot' => "Express (within {$mins} minutes)", 'delivery_slot_id' => null,
                'delivery_starts_at' => $now->copy()->utc()->toDateTimeString(),
                'delivery_ends_at' => $now->copy()->addMinutes($mins)->utc()->toDateTimeString(),
            ]];
        }

        if (!$date) {
            return $settings['required'] ? $fail('Please choose a delivery date and time.') : ['ok' => true, 'message' => null, 'data' => [], 'extra' => 0.0, 'extra_name' => null];
        }
        try {
            $d = Carbon::createFromFormat('Y-m-d', $date, $this->tz())->startOfDay();
        } catch (\Throwable $e) {
            return $fail('Invalid delivery date.');
        }
        $dateStr = $d->toDateString();
        $cfg = $this->config();
        if ($dateStr < $cfg['min_date']) return $fail('Delivery date cannot be in the past.');
        if ($dateStr > $cfg['max_date']) return $fail("Delivery can be scheduled up to {$settings['max_advance_days']} days ahead.");
        if (in_array($dateStr, $cfg['closed_dates'], true)) return $fail('We are not delivering on the selected date. Please pick another day.');

        // Midnight delivery: a fixed late-night window from the delivery type.
        if ($giftType === 'midnight') {
            $gt = DB::table('gift_delivery_types')->where('slug', 'midnight')->first();
            [$ws, $we] = array_pad(explode('-', (string) ($gt->time_window ?? '23:00-23:59')), 2, '23:59');
            $start = Carbon::parse("$dateStr $ws", $this->tz());
            $end = Carbon::parse("$dateStr $we", $this->tz());
            if ($start->lt($now->copy()->addMinutes($settings['min_lead_minutes']))) return $fail('Midnight delivery for this date is no longer available.');
            return ['ok' => true, 'message' => null, 'extra' => 0.0, 'extra_name' => null, 'data' => [
                'delivery_date' => $dateStr, 'delivery_slot' => 'Midnight (' . trim($ws) . ' - ' . trim($we) . ')', 'delivery_slot_id' => null,
                'delivery_starts_at' => $start->copy()->utc()->toDateTimeString(), 'delivery_ends_at' => $end->copy()->utc()->toDateTimeString(),
            ]];
        }

        if (!$slotId) return $fail('Please choose a delivery time slot.');
        $q = DB::table('delivery_slots')->where('id', (int) $slotId)->where('status', 1);
        $slot = $lock ? $q->lockForUpdate()->first() : $q->first();
        if (!$slot) return $fail('The selected time slot is not available.');

        $closedSlot = DB::table('delivery_blackout_dates')->where('date', $dateStr)->where('slot_id', $slot->id)->exists();
        if ($closedSlot) return $fail('That time slot is closed on the selected date.');
        $start = Carbon::parse($dateStr . ' ' . $slot->start_time, $this->tz());
        $end = Carbon::parse($dateStr . ' ' . $slot->end_time, $this->tz());
        if ($start->lt($now->copy()->addMinutes($settings['min_lead_minutes']))) return $fail('That time slot is no longer available. Please choose a later slot.');
        if ($slot->capacity !== null) {
            $used = DB::table('orders')->where('delivery_date', $dateStr)->where('delivery_slot_id', $slot->id)
                ->whereNotIn('active_status', self::RELEASED_STATUSES)->count();
            if ($used >= (int) $slot->capacity) return $fail('That time slot is fully booked. Please choose another.');
        }
        return ['ok' => true, 'message' => null, 'extra' => (float) $slot->extra_charge, 'extra_name' => $slot->extra_charge > 0 ? 'Time slot: ' . $slot->label : null, 'data' => [
            'delivery_date' => $dateStr, 'delivery_slot' => $slot->label, 'delivery_slot_id' => (int) $slot->id,
            'delivery_starts_at' => $start->copy()->utc()->toDateTimeString(), 'delivery_ends_at' => $end->copy()->utc()->toDateTimeString(),
        ]];
    }
}
