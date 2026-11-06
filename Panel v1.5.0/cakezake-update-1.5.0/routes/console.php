<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Heartbeat for the admin "Cron Jobs" settings page: proves the server cron is
// actually firing schedule:run. Read by CronApiController.
Schedule::call(function () {
    Cache::put('cron_last_heartbeat', now()->toDateTimeString(), 172800);
})->everyMinute()->name('cron-heartbeat');

Schedule::command('cart:notification')->everyMinute();

// Applies scheduled maintenance windows (flips *_mode on/off at start/end).
Schedule::command('maintenance:apply')->everyMinute();

// Auto-publishes home layout drafts at their scheduled time.
Schedule::command('home-layout:publish-scheduled')->everyMinute();

// Turns the popup offer off once its scheduled end time has passed.
Schedule::command('popup:apply-schedule')->everyMinute();

// Promotes a queued spin-wheel campaign on its start date (and switches off the one it
// replaces), plus retires campaigns past their end date.
Schedule::command('spin-wheel:apply-schedule')->everyMinute();

// Retires spin-wheel coupons past their end date (deactivates, never deletes).
Schedule::command('promo:expire-spin-codes')->dailyAt('00:30');

/* Queued jobs are run by a daemon worker under Supervisor, NOT from here. Draining the
   queue on the minute boots the whole framework every minute to usually find nothing,
   leaves a new job waiting up to a minute before anything looks at it, and --max-time
   cannot cut a job short, so a slow one overlaps the next run and doubles the database
   load. A daemon boots once, picks a job up in seconds, and Supervisor restarts it if it
   dies. The panel's Cron Jobs page prints the worker command and the Supervisor block.

   The fallback below exists only for hosting where no daemon can be started. */
if (config('queue.scheduler_fallback')) {
    Schedule::command('queue:work --stop-when-empty --max-time=55')
        ->everyMinute()
        ->withoutOverlapping();
}

/* The floor under courier webhooks: asks each carrier about the parcels still in flight,
   so a status, a delivered notification, a COD settlement or an RTO refund is never
   waiting on a push that was never configured or was lost in a retry. Does nothing at
   all when no shipping plugin is installed, and skips any waybill a webhook has already
   reported on recently — so on a shop whose webhook works it costs almost nothing. */
Schedule::command('shipping:sync-tracking')
    ->everyThirtyMinutes()
    ->withoutOverlapping();
