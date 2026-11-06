<?php

namespace App\Helpers;

use App\Services\TaxService;
use App\Models\Cart;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Jobs\SendBackInStockNotification;
use App\Models\ProductStockAlert;
use App\Models\ProductVariantBranchStock;
use App\Models\Branch;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class ProductHelper
{
    /**
     * Normalize a variant's pricing_slabs (array or JSON string) to a clean list:
     * [ ['min_qty'=>int, 'max_qty'=>int|null, 'price'=>float], ... ] sorted by min_qty.
     */
    public static function normalizeSlabs($slabs): array
    {
        if (is_string($slabs)) {
            $slabs = json_decode($slabs, true);
        }
        if (!is_array($slabs)) {
            return [];
        }
        $out = [];
        foreach ($slabs as $s) {
            if (!is_array($s)) {
                continue;
            }
            $min = isset($s['min_qty']) && $s['min_qty'] !== '' ? (int) $s['min_qty'] : 0;
            $max = isset($s['max_qty']) && $s['max_qty'] !== '' && $s['max_qty'] !== null ? (int) $s['max_qty'] : null;
            $price = isset($s['price']) && $s['price'] !== '' ? (float) $s['price'] : 0;
            if ($min < 1 || $price <= 0) {
                continue; // invalid slab — ignore
            }
            $out[] = ['min_qty' => $min, 'max_qty' => $max, 'price' => $price];
        }
        usort($out, fn ($a, $b) => $a['min_qty'] <=> $b['min_qty']);
        return $out;
    }

    /**
     * Effective PRE-TAX unit price for a variant at a given quantity.
     * Slab match wins; otherwise discounted_price (if set) else base price.
     * $variant may be an object/array with price, discounted_price, pricing_slabs.
     */
    public static function slabUnitPrice($variant, int $qty): float
    {
        $price = (float) (is_array($variant) ? ($variant['price'] ?? 0) : ($variant->price ?? 0));
        $disc  = (float) (is_array($variant) ? ($variant['discounted_price'] ?? 0) : ($variant->discounted_price ?? 0));
        $base  = $disc > 0 ? $disc : $price;

        $slabs = is_array($variant) ? ($variant['pricing_slabs'] ?? null) : ($variant->pricing_slabs ?? null);
        foreach (self::normalizeSlabs($slabs) as $s) {
            if ($qty >= $s['min_qty'] && ($s['max_qty'] === null || $qty <= $s['max_qty'])) {
                return $s['price'];
            }
        }
        return $base;
    }

    /**
     * What one unit of a cart or order LINE costs before tax: the slab-aware product
     * price plus whatever addons the customer chose on that line.
     *
     * The addon amount lives inside the unit price rather than beside it, because
     * `qty * unit_price == sub_total` is assumed by both invoices, the delivery receipt,
     * order emails, refunds, report net sales, dashboard revenue, the ecommerce per-item
     * charge splits and the courier declared value. Put it in a side column and all of
     * them quietly disagree with the total the customer paid.
     *
     * Slab matching stays on the BASE price: a quantity tier must not be reached sooner
     * because someone added cheese.
     */
    public static function lineUnitPrice($variant, int $qty, float $addonUnit = 0): float
    {
        return self::slabUnitPrice($variant, $qty) + $addonUnit;
    }

    /**
     * Upsell hint: the nearest higher-quantity slab that beats the current unit
     * price. Returns ['add_qty','min_qty','price'] or null.
     */
    public static function nextSlabHint($variant, int $qty, float $taxPct = 0, bool $taxInclusive = false): ?array
    {
        $currentUnit = self::slabUnitPrice($variant, $qty);
        $slabs = is_array($variant) ? ($variant['pricing_slabs'] ?? null) : ($variant->pricing_slabs ?? null);
        $best = null;
        foreach (self::normalizeSlabs($slabs) as $s) {
            if ($s['min_qty'] > $qty && $s['price'] < $currentUnit) {
                if ($best === null || $s['min_qty'] < $best['min_qty']) {
                    $best = $s;
                }
            }
        }
        if (!$best) {
            return null;
        }
        return [
            'add_qty' => $best['min_qty'] - $qty,
            'min_qty' => $best['min_qty'],
            'price'   => (float) CommonHelper::doubleNumber(TaxService::applyTax($best['price'], $taxPct, $taxInclusive)),
        ];
    }

    /**
     * The PVSS pricing row for a variant at a branch. Customer & cost pricing
     * (price / discounted_price / pricing_slabs / purchase_price) live here.
     * With no branch context, returns the cheapest listed branch row (used for
     * "from" prices / representative displays).
     */
    public static function branchPriceRow($product_variant_id, $branch_id = null)
    {
        $q = ProductVariantBranchStock::where('product_variant_id', $product_variant_id);
        if ($branch_id) {
            return $q->where('branch_id', $branch_id)->first();
        }
        return $q->where('is_listed', 1)
            ->orderByRaw('COALESCE(NULLIF(discounted_price, 0), price) ASC')
            ->first();
    }

    /**
     * Copy a branch's PVSS pricing onto an in-memory variant (object or array)
     * so downstream calculators (slabUnitPrice, shapers) read the branch price
     * transparently. Prefers an eager-loaded branchStocks relation to avoid a
     * query. With no branch, uses the cheapest listed branch row.
     */
    public static function applyBranchPrice($variant, $branch_id = null)
    {
        if (!$variant) {
            return $variant;
        }
        $vid = is_array($variant) ? ($variant['id'] ?? null) : ($variant->id ?? null);

        $row = null;
        if (!is_array($variant) && method_exists($variant, 'relationLoaded') && $variant->relationLoaded('branchStocks')) {
            $stocks = $variant->branchStocks;
            if ($branch_id) {
                $row = $stocks->firstWhere('branch_id', (int) $branch_id);
            } else {
                $row = $stocks->where('is_listed', 1)
                    ->sortBy(fn ($s) => ((float) $s->discounted_price > 0 ? (float) $s->discounted_price : (float) $s->price) ?: INF)
                    ->first();
            }
        }
        if (!$row && $vid) {
            $row = self::branchPriceRow($vid, $branch_id);
        }

        $price    = $row ? (float) $row->price : 0.0;
        $disc     = $row ? (float) $row->discounted_price : 0.0;
        $slabs    = $row ? $row->pricing_slabs : null;
        $purchase = $row ? (float) $row->purchase_price : 0.0;
        $inclusive = $row ? (bool) ($row->is_tax_inclusive ?? false) : false;

        if (is_array($variant)) {
            $variant['price'] = $price;
            $variant['discounted_price'] = $disc;
            $variant['pricing_slabs'] = $slabs;
            $variant['purchase_price'] = $purchase;
            $variant['is_tax_inclusive'] = $inclusive;
        } else {
            $variant->price = $price;
            $variant->discounted_price = $disc;
            $variant->pricing_slabs = $slabs;
            $variant->purchase_price = $purchase;
            $variant->is_tax_inclusive = $inclusive;
        }
        return $variant;
    }

    /**
     * Which branch's price row applyBranchPrice() would use for this variant — i.e.
     * who is actually selling it. Tax must be resolved against that same branch,
     */
    public static function priceBranchId($variant, $branch_id = null): ?int
    {
        if ($branch_id) {
            return (int) $branch_id;
        }
        if (!$variant) {
            return null;
        }
        if (!is_array($variant) && method_exists($variant, 'relationLoaded') && $variant->relationLoaded('branchStocks')) {
            $row = $variant->branchStocks->where('is_listed', 1)
                ->sortBy(fn ($s) => ((float) $s->discounted_price > 0 ? (float) $s->discounted_price : (float) $s->price) ?: INF)
                ->first();
            if ($row) {
                return (int) $row->branch_id;
            }
        }
        $vid = is_array($variant) ? ($variant['id'] ?? null) : ($variant->id ?? null);
        $row = $vid ? self::branchPriceRow($vid, null) : null;
        return $row ? (int) $row->branch_id : null;
    }

    /**
     * Resolve which branch a cart row should be pinned to. With products.branch_id
     * gone, the branch is derived from the variant's PVSS rows: prefer a branch
     * inside the customer's zone (if lat/lng passed), otherwise fall back to
     * the first listed-and-active branch stocking the variant.
     */
    public static function resolveCartBranch($product_variant_id, $latitude = null, $longitude = null, $channel = null): ?int
    {
        $branchIds = [];
        if ($latitude !== null && $longitude !== null) {
            $zone = CommonHelper::getDeliverableCity($latitude, $longitude, $channel);
            if ($zone) {
                // The matched zone's own channel decides which branch slot to look in.
                $branchIds = Branch::where('status', 1)
                    ->where('zone_id', $zone->id)
                    ->pluck('id')->all();
            }
        }

        $q = ProductVariantBranchStock::where('product_variant_id', $product_variant_id)
            ->where('is_listed', 1);
        if (!empty($branchIds)) {
            $q->whereIn('branch_id', $branchIds);
        }

        $row = $q->orderByDesc('is_unlimited_stock')
            ->orderByDesc('stock_status')
            ->orderByDesc('available')
            ->first();
        return $row ? (int) $row->branch_id : null;
    }

    /* ----------------------------------------------------------------------
     * Per-branch inventory reservation (PVSS = source of truth).
     *
     *   reserve (cart add):       available -= q, reserved += q
     *   release (cart remove):    available += q, reserved -= q
     *   commit  (order placed):   reserved  -= q   (available already reduced)
     *
     * Each reserved unit ends in exactly ONE of commit or release, so stock
     * never double-counts. Unlimited-stock products skip reservation entirely.
     * All updates are atomic (single UPDATE with column expressions) to avoid
     * lost updates under concurrency.
     * -------------------------------------------------------------------- */

    /**
     * The catalogue's own in-stock rule, applied to ONE already-fetched PVSS row.
     *
     * Available units are not the whole answer: an operator can mark a branch row out of
     * stock while units remain on it, and every customer-facing surface honours that.
     * Unlimited stock wins over both. Callers that already hold the row use this so the
     * rule lives in one place instead of being spelled out at each reader.
     */
    public static function isStockRowInStock($row): bool
    {
        // No inventory: every item is made to order, so a listed row is always available.
        return (bool) $row;
    }

    /** Units a variant has available to reserve in a given branch (0 if no row). */
    public static function branchAvailableStock($product_variant_id, $branch_id): int
    {
        return 999999; // no inventory tracking
        if (!$branch_id) {
            return 0;
        }
        $row = ProductVariantBranchStock::where('product_variant_id', $product_variant_id)
            ->where('branch_id', $branch_id)
            ->first(['available']);
        return $row ? (int) $row->available : 0;
    }

    /** Total available units of a variant across all its branches (PVSS sum). */
    public static function totalStock($product_variant_id): int
    {
        return 999999; // no inventory tracking
        return (int) ProductVariantBranchStock::where('product_variant_id', $product_variant_id)
            ->sum('available');
    }

    public static function isVariantUnlimited($product_variant_id, $branch_id = null): bool
    {
        return true; // no inventory tracking: stock is never reserved, released or restocked
        if (!$branch_id) {
            return false;
        }
        return (int) (ProductVariantBranchStock::where('product_variant_id', $product_variant_id)
            ->where('branch_id', $branch_id)
            ->value('is_unlimited_stock') ?? 0) === 1;
    }

    /** Does the variant have at least one branch where stock is unlimited? */
    public static function isVariantUnlimitedAnywhere($product_variant_id): bool
    {
        return true; // no inventory tracking
        return ProductVariantBranchStock::where('product_variant_id', $product_variant_id)
            ->where('is_unlimited_stock', 1)
            ->exists();
    }

    /** Reserve $qty: available -= qty, reserved += qty. No-op for unlimited / missing row. */
    public static function reserveStock($product_variant_id, $branch_id, $qty): void
    {
        if (!$branch_id || $qty <= 0 || self::isVariantUnlimited($product_variant_id, $branch_id)) {
            return;
        }
        ProductVariantBranchStock::where('product_variant_id', $product_variant_id)
            ->where('branch_id', $branch_id)
            ->update([
                'available'    => DB::raw('GREATEST(available - ' . (int) $qty . ', 0)'),
                'reserved'     => DB::raw('reserved + ' . (int) $qty),
                'stock_status' => DB::raw('IF(available - ' . (int) $qty . ' > 0, 1, 0)'),
            ]);
    }

    /** Release $qty back (cart remove): available += qty, reserved -= qty. */
    public static function releaseStock($product_variant_id, $branch_id, $qty): void
    {
        if (!$branch_id || $qty <= 0 || self::isVariantUnlimited($product_variant_id, $branch_id)) {
            return;
        }
        ProductVariantBranchStock::where('product_variant_id', $product_variant_id)
            ->where('branch_id', $branch_id)
            ->update([
                'available'    => DB::raw('available + ' . (int) $qty),
                'reserved'     => DB::raw('GREATEST(reserved - ' . (int) $qty . ', 0)'),
                'stock_status' => DB::raw('1'),
            ]);
        self::notifyBackInStock($product_variant_id, $branch_id);
    }

    /** Restock $qty back to available (order cancel/return after commit): available += qty. */
    public static function restockStock($product_variant_id, $branch_id, $qty): void
    {
        if (!$branch_id || $qty <= 0 || self::isVariantUnlimited($product_variant_id, $branch_id)) {
            return;
        }
        ProductVariantBranchStock::where('product_variant_id', $product_variant_id)
            ->where('branch_id', $branch_id)
            ->update([
                'available'    => DB::raw('available + ' . (int) $qty),
                'stock_status' => DB::raw('1'),
            ]);
        self::notifyBackInStock($product_variant_id, $branch_id);
    }

    public static function notifyBackInStock($product_variant_id, $branch_id): void
    {
        if (!$product_variant_id || !$branch_id) {
            return;
        }
        try {
            if (!ProductStockAlert::waiting()->where('product_variant_id', (int) $product_variant_id)->exists()) {
                return;
            }
            $row = ProductVariantBranchStock::where('product_variant_id', (int) $product_variant_id)
                ->where('branch_id', (int) $branch_id)
                ->first();
            if (!$row || (int) $row->is_listed !== 1) {
                return;
            }
            $inStock = (int) $row->is_unlimited_stock === 1
                || ((int) $row->stock_status === 1 && (int) $row->available > 0);
            if (!$inStock) {
                return;
            }

            $job = new SendBackInStockNotification((int) $product_variant_id, (int) $branch_id);
            config('queue.default') === 'sync' ? dispatch($job)->afterResponse() : dispatch($job);
        } catch (\Throwable $e) {
            // Never let a notification stop a stock write.
            Log::error('notifyBackInStock: ' . $e->getMessage());
        }
    }

    /** Commit $qty at checkout: reserved -= qty (available already reduced at reserve). */
    public static function commitReservedStock($product_variant_id, $branch_id, $qty): void
    {
        if (!$branch_id || $qty <= 0 || self::isVariantUnlimited($product_variant_id, $branch_id)) {
            return;
        }
        $qty = (int) $qty;
        ProductVariantBranchStock::where('product_variant_id', $product_variant_id)
            ->where('branch_id', $branch_id)
            ->update([
                'available'    => DB::raw('GREATEST(available - GREATEST(' . $qty . ' - reserved, 0), 0)'),
                'reserved'     => DB::raw('GREATEST(reserved - ' . $qty . ', 0)'),
                'stock_status' => DB::raw('IF(available > 0, 1, 0)'),
            ]);
    }

    public static function isItemAvailable($product_id, $product_variant_id)
    {

        $variant = ProductVariant::where('product_id', $product_id)->where('id', $product_variant_id)->first();
        if ($variant) {
            $product = Product::where('id', $product_id)->where('status', 1)->first();
            return !empty($product);
        } else {
            return false;
        }
    }

    public static function isItemAvailableWithStock($product_id = null, $product_variant_id = null, $qty = 0, $branch_id = null, $alreadyReserved = 0)
    {
        // Fetch the variant first
        $variant = ProductVariant::where('id', $product_variant_id)
            ->first();

        if (!$variant) {
            return false;
        }

        // Use product_id from the variant if not provided
        $product_id = $product_id ?? $variant->product_id;

        // Fetch the product
        $product = Product::where('id', $product_id)->where('status', 1)->first();

        if (!$product) {
            return false;
        }

        $unlimited = $branch_id
            ? self::isVariantUnlimited($product_variant_id, $branch_id)
            : self::isVariantUnlimitedAnywhere($product_variant_id);
        if ($unlimited) {
            return true;
        }

        // Stock is per-branch (PVSS). When a branch is given, check that branch's
        // availability; otherwise fall back to the sum across all branches.
        $stock = $branch_id
            ? self::branchAvailableStock($product_variant_id, $branch_id)
            : self::totalStock($product_variant_id);

        return ($stock + max(0, (int) $alreadyReserved)) >= $qty;
    }

    /**
     * A cart line's identity beyond its variant: the sha1 of its sorted option id:qty
     * pairs, and the empty string when there are none. The quantity is part of the
     * identity — one burger with two cheeses is a different line from one with one.
     *
     * This is what lets one pizza with cheese and one without be two rows of the same
     * variant. An app that sends no addons produces '' and keeps exactly today's
     * behaviour, which is why every existing row carries '' and nothing had to migrate.
     */
    public static function addonSignature(array $selections): string
    {
        $pairs = [];
        foreach ($selections as $key => $value) {
            // Accepts [3, 5], [['id'=>3,'qty'=>2]] and [3 => 2] alike.
            if (is_array($value)) {
                $id  = (int) ($value['id'] ?? $value['option_id'] ?? 0);
                $qty = (int) ($value['qty'] ?? $value['quantity'] ?? 1);
            } elseif (is_int($key) && !is_array($value)) {
                $id  = (int) $value;
                $qty = 1;
            } else {
                $id  = (int) $key;
                $qty = (int) $value;
            }
            if ($id > 0) {
                $pairs[$id] = max(1, $qty);
            }
        }

        if (empty($pairs)) {
            return '';
        }

        ksort($pairs, SORT_NUMERIC);
        $parts = [];
        foreach ($pairs as $id => $qty) {
            $parts[] = $id . ':' . $qty;
        }

        return sha1(implode(',', $parts));
    }

    /**
     * $addonSignature narrows the check to one addon variation of the variant. Left null
     * it asks the looser question — "is this variant in the cart at all" — which is what
     * every caller that does not care about addons wants.
     */
    public static function isItemAvailableInUserCart($user_id, $product_variant_id = "", $channel = null, ?string $addonSignature = null)
    {
        $cart = Cart::where('user_id', $user_id);
        if ($product_variant_id != '') {
            $cart->where('product_variant_id', $product_variant_id);
        }
        if ($addonSignature !== null) {
            $cart->where('addon_signature', $addonSignature);
        }
        // Quick and ecommerce carts are separate lines; a variant in the ecommerce
        // cart must not count as "already in cart" for a quick add. Legacy null rows
        // match either channel.
        if (in_array($channel, ['quick', 'ecommerce'], true)) {
            $cart->where(function ($q) use ($channel) {
                $q->where('channel', $channel)->orWhereNull('channel');
            });
        }
        return $cart->exists();
    }

    /**
     * Tax-inclusive pricing for a variant. Price is per-branch (PVSS): pass the
     * fulfilling $branch_id; with none, the cheapest listed branch row is used.
     *
     * The rate is resolved through TaxService, so the SAME variant is taxed
     * differently by an India branch and a Dubai branch. When no branch is passed the
     * branch behind the chosen price row is used — the price and the tax must come
     * from the same branch or they describe two different offers.
     *
     * $buyer_region_id only affects how the total splits into components (India
     * CGST+SGST vs IGST); the total itself is identical either way, which is what
     * lets the cart quote tax before an address is chosen.
     *
     * Returns the same stdClass shape callers rely on (price, discounted_price,
     * percentage, taxable_amount, taxable_price, taxable_discounted_price) plus the
     * resolved components for anything that needs the breakdown.
     */
    public static function getTaxableAmount($product_variant_id, $branch_id = null, $buyer_region_id = null)
    {
        $variant = DB::table('product_variants')->where('id', $product_variant_id)->first(['id', 'product_id']);
        if (!$variant) {
            return null;
        }

        $row = self::branchPriceRow($product_variant_id, $branch_id);
        $price = (float) ($row->price ?? 0);
        $disc  = (float) ($row->discounted_price ?? 0);

        $branchBranchId = $branch_id ?: ($row->branch_id ?? null);
        $resolved = $branchBranchId
            ? TaxService::forProduct((int) $variant->product_id, (int) $branchBranchId, $buyer_region_id)
            : null;
        $percentage = (float) ($resolved['total_rate'] ?? 0);
        // Inclusivity belongs to this branch's price row, not to the rule.
        $inclusive = (bool) ($row->is_tax_inclusive ?? false);

        $result = new \stdClass();
        $result->id = (int) $variant->id;
        $result->price = $price;
        $result->discounted_price = $disc;
        $result->percentage = $percentage;
        $result->taxable_price = TaxService::applyTax($price, $percentage, $inclusive);
        $result->taxable_discounted_price = TaxService::applyTax($disc, $percentage, $inclusive);

        // Effective taxable amount: discounted (if set) else base, tax applied.
        $base = $disc != 0 ? $disc : $price;
        $result->taxable_amount = TaxService::applyTax($base, $percentage, $inclusive);

        // Breakdown for callers that snapshot or display it. Empty when untaxed.
        $result->tax_rule_id = $resolved['rule_id'] ?? null;
        $result->tax_category_id = $resolved['tax_category_id'] ?? null;
        $result->tax_components = $resolved['components'] ?? [];
        $result->tax_inclusive = $inclusive;
        $result->supply_type = $resolved['supply_type'] ?? null;
        $result->branch = $resolved['branch'] ?? null;

        return $result;
    }
}
