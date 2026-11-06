<?php

namespace App\Console\Commands;

use App\Helpers\CommonHelper;
use App\Models\Setting;
use Carbon\Carbon;
use Illuminate\Console\Command;

/**
 * Applies scheduled maintenance windows. For each surface, when a start/end
 * datetime is configured, flips the maintenance flag on at start and off at end
 * (broadcasting the change), then clears the window once it has fully passed so
 * a later manual toggle isn't overridden.
 */
class MaintenanceScheduleCommand extends Command
{
    protected $signature = 'maintenance:apply';

    protected $description = 'Enable/disable maintenance mode per the scheduled start/end times';

    public function handle(): int
    {
        // Schedule datetimes are stored in UTC (converted from the admin's local
        // time in the UI), so compare against UTC now.
        $now = Carbon::now('UTC');

        foreach (CommonHelper::MAINTENANCE_SURFACES as $toggle => $meta) {
            $this->applySchedule($toggle, $now);
        }

        return self::SUCCESS;
    }

    private function applySchedule(string $toggle, Carbon $now): void
    {
        $start = trim((string) Setting::get_value($toggle . '_start'));
        $end   = trim((string) Setting::get_value($toggle . '_end'));

        if ($start === '' && $end === '') {
            return; // no schedule for this surface
        }

        $startAt = $start !== '' ? $this->parse($start) : null;
        $endAt   = $end !== '' ? $this->parse($end) : null;
        $current = (int) (Setting::get_value($toggle) ?: 0);

        // Window finished → turn off and consume the schedule.
        if ($endAt && $now->greaterThanOrEqualTo($endAt)) {
            if ($current !== 0) {
                CommonHelper::applyMaintenance($toggle, 0);
                $this->info("{$toggle}: window ended → OFF");
            }
            $this->clearSchedule($toggle);
            return;
        }

        // Inside the window (started, not yet ended) → turn on.
        if ($startAt && $now->greaterThanOrEqualTo($startAt) && $current !== 1) {
            CommonHelper::applyMaintenance($toggle, 1);
            $this->info("{$toggle}: window started → ON");
        }
        // Before start → pending, leave as-is.
    }


    private function parse(string $value): ?Carbon
    {
        try {
            return Carbon::parse($value, 'UTC');
        } catch (\Throwable $e) {
            return null;
        }
    }

    private function clearSchedule(string $toggle): void
    {
        foreach (['_start', '_end'] as $suffix) {
            $s = Setting::where('variable', $toggle . $suffix)->first();
            if ($s) {
                $s->value = '';
                $s->save();
            }
        }
    }
}
