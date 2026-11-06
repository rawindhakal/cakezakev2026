<?php

namespace App\Console\Commands;

use App\Models\PromoCode;
use Illuminate\Console\Command;

/**
 * Retires spin-wheel coupons whose validity has run out.
 *
 * Every win issues its own coupon row, so the table grows with the campaign. Expired ones
 * are switched OFF rather than deleted: an order that used one still points at it, and
 * the cancel path dereferences that coupon without a null check — deleting the row would
 * turn an old cancellation into a 500. Deactivating keeps the record and takes the row
 * out of every customer-facing query.
 */
class ExpireSpinWheelCodesCommand extends Command
{
    protected $signature = 'promo:expire-spin-codes {--days=30 : Also retire codes that expired this many days ago or earlier}';

    protected $description = 'Deactivate spin-wheel coupons past their end date';

    public function handle(): int
    {
        $count = PromoCode::where('source', 'spin_wheel')
            ->where('status', 1)
            ->whereNotNull('end_date')
            ->whereDate('end_date', '<', now()->toDateString())
            ->update(['status' => 0]);

        if ($count) {
            $this->info("Deactivated {$count} expired spin-wheel coupon(s).");
        }

        return self::SUCCESS;
    }
}
