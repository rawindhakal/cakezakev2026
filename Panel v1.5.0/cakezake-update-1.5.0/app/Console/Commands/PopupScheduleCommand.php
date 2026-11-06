<?php

namespace App\Console\Commands;

use App\Models\Setting;
use Carbon\Carbon;
use Illuminate\Console\Command;

/**
 * Applies the popup offer's scheduled window (Scheduled mode only):
 *   - popup_start_at reached  -> turn ON  (skipped entirely if left blank)
 *   - popup_end_at   reached  -> turn OFF (skipped entirely if left blank —
 *                                 a start-only schedule just stays on)
 * Neither timestamp is cleared once it fires, so the admin still sees what was
 * configured and can extend it. The end check always runs first and returns —
 * that ordering is what stops a stale start (still <= now, never cleared) from
 * flipping it straight back on in the same or a later tick.
 */
class PopupScheduleCommand extends Command
{
    protected $signature = 'popup:apply-schedule';

    protected $description = 'Turn the popup offer on/off per its scheduled start/end times';

    public function handle(): int
    {
        $mode = trim((string) Setting::get_value('popup_mode'));
        if ($mode !== 'scheduled') {
            return self::SUCCESS;
        }

        $start = trim((string) Setting::get_value('popup_start_at'));
        $end   = trim((string) Setting::get_value('popup_end_at'));
        if ($start === '' && $end === '') {
            return self::SUCCESS; // scheduled but no window configured yet
        }

        $now     = Carbon::now('UTC'); // stored in UTC (converted from local time in the UI)
        $startAt = $start !== '' ? $this->parse($start) : null;
        $endAt   = $end !== '' ? $this->parse($end) : null;
        $current = (int) (Setting::get_value('popup_enabled') ?: 0);

        // End passed -> off, and stop here so a still-past start can't undo it.
        if ($endAt && $now->greaterThanOrEqualTo($endAt)) {
            if ($current !== 0) {
                $this->setEnabled(0);
                $this->info('popup: scheduled window ended -> OFF');
            }
            return self::SUCCESS;
        }

        // Start reached (and not yet ended, or no end configured) -> on.
        if ($startAt && $now->greaterThanOrEqualTo($startAt) && $current !== 1) {
            $this->setEnabled(1);
            $this->info('popup: scheduled window started -> ON');
        }
        // Before start -> pending, leave as-is.

        return self::SUCCESS;
    }

    private function parse(string $value): ?Carbon
    {
        try {
            return Carbon::parse($value, 'UTC');
        } catch (\Throwable) {
            return null;
        }
    }

    private function setEnabled(int $value): void
    {
        $setting = Setting::where('variable', 'popup_enabled')->first() ?? new Setting();
        $setting->variable = 'popup_enabled';
        $setting->value = (string) $value;
        $setting->save();
    }
}
