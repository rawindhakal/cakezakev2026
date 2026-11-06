<?php

namespace App\Console\Commands;

use App\Services\SpinWheelService;
use Illuminate\Console\Command;

/**
 * Applies the spin-wheel calendar.
 *
 * Only one wheel runs at a time, so lining up the next campaign by hand would mean being
 * at the keyboard at midnight: switch the old one off, the new one on. Instead the admin
 * schedules a campaign ("activate on its start date") and this promotes it when the time
 * comes — which also switches off whatever was running. A campaign past its end date is
 * retired the same way.
 */
class SpinWheelScheduleCommand extends Command
{
    protected $signature = 'spin-wheel:apply-schedule';

    protected $description = 'Activate a scheduled spin-wheel campaign at its start time and retire expired ones';

    public function handle(SpinWheelService $service): int
    {
        $result = $service->applySchedule();

        if ($result['expired']) {
            $this->info("Retired {$result['expired']} expired campaign(s).");
        }
        if ($result['activated']) {
            $this->info("Activated campaign #{$result['activated']}.");
        }

        return self::SUCCESS;
    }
}
