<?php

namespace App\Console\Commands;

use App\Models\OrderItem;
use App\Models\OrderStatusList;
use App\Models\ReturnRequest;
use App\Models\ReturnStatusList;
use App\Plugins\Registries\ShippingProviderRegistry;
use App\Services\Shipping\CourierReturnStatusService;
use App\Services\Shipping\CourierStatusService;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

/**
 * Asks each courier what happened to the parcels that are still in flight.
 *
 * A carrier webhook is the fast path, not a reliable one. It needs a token the merchant
 * has to paste into the carrier's own dashboard — which we cannot verify from here, so
 * the field is optional — and even once it is wired, a push is lost whenever the carrier
 * gives up retrying: a deploy, a 500, an outage at either end. Everything that matters
 * hangs off the update arriving: the status the shopper sees, the delivered
 * notification, COD settlement, and RTO (stock returned, tax reversed, prepaid
 * refunded). None of that can wait for someone to open the order and press track.
 *
 * So the webhook stays the fast path and this is the floor underneath it: pull the
 * carrier's own state and feed it through the exact same services the webhook uses, so
 * there is one settlement path and not two.
 *
 * Deliberately generic. It knows `ShippingProvider` and the registry, never a carrier —
 * the next shipping plugin is covered by it with no further work, and an install with
 * none does nothing at all.
 *
 * Cost is the thing that makes a poll a bad idea, so it is kept small:
 *
 *  * An AWB a webhook has reported on in the last 6 hours is skipped — on a shop whose
 *    webhook is wired this command makes almost no calls, which is the point: it covers
 *    the gaps rather than duplicating the feed.
 *  * Each AWB has its own clock with exponential backoff: checked hourly while it is
 *    moving, and up to a day apart once it has gone quiet. A parcel that changes resets
 *    to hourly.
 *  * A hard cap per run, oldest-checked first, so the work round-robins instead of
 *    piling onto one run.
 *  * Nothing untouched for a month is chased at all.
 *
 * The clock lives in the cache rather than a column: a lost cursor costs one extra sweep
 * and nothing else, which is not worth a migration — and it leaves nothing behind when
 * the plugin that owns the carrier is uninstalled.
 */
class SyncCourierTrackingCommand extends Command
{
    protected $signature = 'shipping:sync-tracking
                            {--limit=100 : Most AWBs to check in one run}
                            {--provider= : Only this provider key}
                            {--awb= : Only this waybill}
                            {--force : Ignore the backoff clock and the webhook window}';

    protected $description = 'Pull courier tracking for shipments still in flight (safety net for missed webhooks)';

    /** A webhook this recent proves the push feed works for that AWB. */
    private const WEBHOOK_FRESH_HOURS = 6;

    /** First re-check after this long, doubling each time nothing changed. */
    private const BASE_INTERVAL_MINUTES = 60;

    private const MAX_INTERVAL_MINUTES = 1440;

    /** A line nobody and nothing has touched for this long is given up on. */
    private const MAX_AGE_DAYS = 30;

    private const CURSOR_TTL_SECONDS = 86400 * 45;

    public function handle(
        ShippingProviderRegistry $registry,
        CourierStatusService $forward,
        CourierReturnStatusService $reverse
    ): int {
        $keys = $registry->keys();

        if (!$keys) {
            // No shipping plugin installed: there is nothing to reconcile, and saying so
            // on every schedule tick would be noise.
            return self::SUCCESS;
        }

        $only = strtolower(trim((string) $this->option('provider')));
        if ($only !== '') {
            $keys = array_values(array_intersect($keys, [$only]));

            if (!$keys) {
                $this->error("No shipping provider '{$only}' is registered.");

                return self::INVALID;
            }
        }

        $force   = (bool) $this->option('force');
        $onlyAwb = trim((string) $this->option('awb'));
        $limit   = max(1, (int) $this->option('limit'));

        $targets = $this->targets($keys, $onlyAwb);

        if (!$targets) {
            return self::SUCCESS;
        }

        $fresh = $force ? [] : $this->awbsPushedRecently($keys, array_column($targets, 'awb'));
        $due   = $this->due($targets, $fresh, $force, $limit);

        if (!$due) {
            return self::SUCCESS;
        }

        $checked = $changed = $failed = 0;

        foreach ($due as $target) {
            ['provider' => $key, 'awb' => $awb] = $target;

            $provider = $registry->provider($key);

            if (!$provider || !$provider->isConfigured()) {
                // Disabled, unlicensed or half-configured. Leave the clock alone so it is
                // picked straight back up once the carrier is usable again.
                continue;
            }

            $checked++;

            try {
                $update = $provider->track($awb);
            } catch (\Throwable $e) {
                $failed++;
                Log::warning("[Shipping] poll failed for {$key}/{$awb}: " . $e->getMessage());
                $this->touch($key, $awb, false);
                continue;
            }

            if (!$update) {
                $failed++;
                $this->touch($key, $awb, false);
                continue;
            }

            try {
                /* Same order as the webhook door: an AWB that matches no order line may
                   be a reverse pickup, whose progress belongs on the return request. */
                $applied = $forward->apply($update)['applied'];

                if ($applied === 0) {
                    $applied = $reverse->apply($update)['applied'];
                }
            } catch (\Throwable $e) {
                $failed++;
                Log::error("[Shipping] poll could not apply {$key}/{$awb}: " . $e->getMessage());
                $this->touch($key, $awb, false);
                continue;
            }

            if ($applied > 0) {
                $changed++;
                $this->line("{$key}/{$awb}: {$update->status} applied to {$applied} line(s)");
            }

            $this->touch($key, $awb, $applied > 0);
        }

        if ($checked) {
            $this->info("tracking: checked {$checked}, advanced {$changed}, failed {$failed}");
        }

        return self::SUCCESS;
    }

    /* ---------------------------------------------------------------- selection */

    /**
     * Every waybill still worth asking about, forward and reverse.
     *
     * One entry per provider+AWB, not per line: a consignment's lines share a waybill,
     * and `CourierStatusService::apply()` resolves the lines from the AWB itself.
     *
     * @param  array<int,string>  $keys
     * @return array<int,array{provider:string,awb:string}>
     */
    private function targets(array $keys, string $onlyAwb): array
    {
        $cutoff = Carbon::now()->subDays(self::MAX_AGE_DAYS);

        $forward = OrderItem::query()
            ->whereIn('courier_provider', $keys)
            ->whereNotNull('tracking_id')
            ->where('tracking_id', '<>', '')
            ->whereNotIn('active_status', [
                OrderStatusList::$delivered,
                OrderStatusList::$cancelled,
                OrderStatusList::$returned,
            ])
            ->where('updated_at', '>=', $cutoff)
            ->when($onlyAwb !== '', fn ($q) => $q->where('tracking_id', $onlyAwb))
            ->distinct()
            ->get(['courier_provider', 'tracking_id']);

        $reverse = ReturnRequest::query()
            ->whereIn('courier_provider', $keys)
            ->whereNotNull('tracking_id')
            ->where('tracking_id', '<>', '')
            ->whereNotIn('status', [
                ReturnStatusList::$rReturnToBranch,
                ReturnStatusList::$rRefundCompleted,
                ReturnStatusList::$rRejected,
            ])
            ->where('updated_at', '>=', $cutoff)
            ->when($onlyAwb !== '', fn ($q) => $q->where('tracking_id', $onlyAwb))
            ->distinct()
            ->get(['courier_provider', 'tracking_id']);

        $targets = [];

        foreach ($forward->concat($reverse) as $row) {
            $key = strtolower((string) $row->courier_provider);
            $awb = trim((string) $row->tracking_id);

            if ($key === '' || $awb === '') {
                continue;
            }

            $targets[$key . '|' . $awb] = ['provider' => $key, 'awb' => $awb];
        }

        return array_values($targets);
    }

    /**
     * The AWBs a verified webhook has already reported on recently.
     *
     * A row only exists once a delivery passed signature verification, so its presence
     * is proof the push feed is actually working for that carrier — which is exactly when
     * polling would be waste. Scoped to the shipping plugins in hand, because the same
     * column carries payment transaction ids.
     *
     * @param  array<int,string>  $keys
     * @param  array<int,string>  $awbs
     * @return array<string,true>
     */
    private function awbsPushedRecently(array $keys, array $awbs): array
    {
        if (!$awbs || !Schema::hasTable('plugin_webhook_events')) {
            return [];
        }

        $slugs = array_values(array_unique(array_filter(array_map(
            fn (string $key) => app(ShippingProviderRegistry::class)->ownerOf($key),
            $keys
        ))));

        return DB::table('plugin_webhook_events')
            ->whereIn('slug', $slugs ?: $keys)
            ->whereIn('external_id', array_values(array_unique($awbs)))
            ->where('created_at', '>=', Carbon::now()->subHours(self::WEBHOOK_FRESH_HOURS))
            ->pluck('external_id')
            ->filter()
            ->mapWithKeys(fn ($awb) => [trim((string) $awb) => true])
            ->all();
    }

    /**
     * Whose clock has come round, oldest first, capped.
     *
     * Oldest-first is what makes the cap fair: a backlog bigger than one run's limit
     * round-robins through it instead of starving the tail.
     *
     * @param  array<int,array{provider:string,awb:string}>  $targets
     * @param  array<string,true>  $fresh
     * @return array<int,array{provider:string,awb:string}>
     */
    private function due(array $targets, array $fresh, bool $force, int $limit): array
    {
        $due = [];

        foreach ($targets as $target) {
            if (isset($fresh[$target['awb']])) {
                continue;
            }

            $cursor = $force ? null : Cache::get($this->cursorKey($target['provider'], $target['awb']));

            if (!is_array($cursor)) {
                // Never polled: goes to the front, with a sort value nothing can beat.
                $due[] = $target + ['_at' => 0];
                continue;
            }

            $at     = Carbon::parse((string) ($cursor['at'] ?? 'now'));
            $misses = max(0, (int) ($cursor['misses'] ?? 0));

            if ($at->copy()->addMinutes($this->interval($misses))->isFuture()) {
                continue;
            }

            $due[] = $target + ['_at' => $at->getTimestamp()];
        }

        usort($due, fn (array $a, array $b) => $a['_at'] <=> $b['_at']);

        return array_map(
            fn (array $t) => ['provider' => $t['provider'], 'awb' => $t['awb']],
            array_slice($due, 0, $limit)
        );
    }

    /** Hourly while a parcel is moving, doubling to daily once it goes quiet. */
    private function interval(int $misses): int
    {
        return (int) min(self::MAX_INTERVAL_MINUTES, self::BASE_INTERVAL_MINUTES * (2 ** min($misses, 10)));
    }

    /** Record the poll — and reset the backoff whenever the parcel actually moved. */
    private function touch(string $provider, string $awb, bool $advanced): void
    {
        $key = $this->cursorKey($provider, $awb);

        $previous = Cache::get($key);
        $misses = $advanced
            ? 0
            : max(0, (int) (is_array($previous) ? ($previous['misses'] ?? 0) : 0)) + 1;

        Cache::put(
            $key,
            ['at' => Carbon::now()->toDateTimeString(), 'misses' => $misses],
            self::CURSOR_TTL_SECONDS
        );
    }

    private function cursorKey(string $provider, string $awb): string
    {
        return 'shipping_track_cursor:' . $provider . ':' . sha1($awb);
    }
}
