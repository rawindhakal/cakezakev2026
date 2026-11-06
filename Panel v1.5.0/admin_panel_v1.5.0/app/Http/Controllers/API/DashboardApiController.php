<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Models\Country;
use App\Models\DeliveryBoy;
use App\Models\Order;
use App\Models\OrderStatusList;
use App\Models\Product;
use App\Models\PromoCode;
use App\Models\ReturnRequest;
use App\Models\ReturnStatusList;
use App\Models\Setting;
use App\Models\Branch;
use App\Models\User;
use App\Models\Zone;
use App\Services\LanguageService;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Fresh e-commerce dashboard. Country/zone scoped (header filter) + a period filter
 * (today / this_week / this_month / this_year / all) with previous-period trend %.
 * Single endpoint so the SPA makes one call and re-fetches on globalFilterChanged.
 */
class DashboardApiController extends Controller
{
    /** Confirmed-revenue order statuses (exclude payment-pending/cancelled/returned). */
    private array $revenueStatuses = [2, 3, 4, 5, 6, 9, 10, 11];
    private array $langCodeById = [];

    public function index(Request $request)
    {
        foreach (app(LanguageService::class)->getActiveLanguages() as $lang) {
            if (!empty($lang->code)) $this->langCodeById[(int) $lang->id] = (string) $lang->code;
        }

        $countryId = (int) $request->input('country_id', 0) ?: null;
        $zoneId    = (int) $request->input('zone_id', 0) ?: null;
        $period    = in_array($request->input('period'), ['today', 'this_week', 'this_month', 'this_year', 'all'], true)
            ? $request->input('period') : 'this_year';

        [$start, $end, $prevStart, $prevEnd, $gran] = $this->periodRange($period);

        $zoneIds  = $zoneId ? [$zoneId] : ($countryId ? Zone::where('country_id', $countryId)->pluck('id')->all() : null);
        $branchIds = $this->branchIdsForZones($zoneIds);

        $currency = $countryId ? (Country::where('id', $countryId)->value('currency') ?: '') : (Setting::get_value('currency') ?: '');

        $data = [
            'currency'        => $currency,
            'period'          => $period,
            'today'           => $this->todayCards($countryId, $zoneId),
            'kpis'            => $this->kpis($countryId, $zoneId, $branchIds, $start, $end, $prevStart, $prevEnd),
            'revenue_trend'   => $this->revenueTrend($countryId, $zoneId, $start, $end, $gran),
            'order_status'    => $this->orderStatus($countryId, $zoneId, $start, $end),
            'category_sales'  => $this->categorySales($countryId, $zoneId, $start, $end),
            'top_products'    => $this->topProducts($countryId, $zoneId, $start, $end),
            'brand_products'  => $this->productsByBrand($branchIds),
            'commerce_mode'   => $this->commerceMode($countryId, $zoneId, $start, $end),
            'inventory_health' => $this->inventoryHealth($branchIds),
            'top_branches'      => $this->topBranches($countryId, $zoneId, $branchIds, $start, $end),
            'top_customers'   => $this->topCustomers($countryId, $zoneId, $start, $end),
            'top_rated'       => $this->topRatedProducts($branchIds),
            'most_wishlisted' => $this->mostWishlisted($branchIds),
            'most_carted'     => $this->mostAddedToCart($branchIds),
            'platform_usage'  => $this->platformUsage($start, $end),
            'returns'         => $this->returnsSummary($countryId, $zoneId, $start, $end),
            'recent_orders'   => $this->recentOrders($countryId, $zoneId),
        ];

        return CommonHelper::responseWithData($data);
    }

    /* ===================== helpers ===================== */

    /** [start, end, prevStart, prevEnd, granularity] — nulls = no bound (all-time). */
    private function periodRange(string $period): array
    {
        $now = Carbon::now();
        switch ($period) {
            case 'today':
                $s = $now->copy()->startOfDay();
                return [$s, $now->copy()->endOfDay(), $s->copy()->subDay(), $s->copy()->subSecond(), 'hour'];
            case 'this_week':
                $s = $now->copy()->startOfWeek();
                return [$s, $now->copy()->endOfWeek(), $s->copy()->subWeek(), $s->copy()->subSecond(), 'day'];
            case 'this_year':
                $s = $now->copy()->startOfYear();
                return [$s, $now->copy()->endOfYear(), $s->copy()->subYear(), $s->copy()->subSecond(), 'month'];
            case 'all':
                return [null, null, null, null, 'month'];
            case 'this_month':
            default:
                $s = $now->copy()->startOfMonth();
                return [$s, $now->copy()->endOfMonth(), $s->copy()->subMonth(), $s->copy()->subSecond(), 'day'];
        }
    }

    private function branchIdsForZones(?array $zoneIds): array
    {
        $q = Branch::where('status', Branch::$statusActive);
        if ($zoneIds !== null) {
            $q->whereIn('zone_id', $zoneIds);
        }
        return $q->pluck('id')->all();
    }

    /** Orders scoped to country/zone + optional [start,end] on created_at. */
    private function orders(?int $countryId, ?int $zoneId, $start = null, $end = null)
    {
        $q = Order::query();
        if ($countryId) $q->where('orders.country_id', $countryId);
        if ($zoneId)    $q->where('orders.zone_id', $zoneId);
        if ($start)     $q->where('orders.created_at', '>=', $start);
        if ($end)       $q->where('orders.created_at', '<=', $end);
        return $q;
    }

    /** order_items joined to their order, scoped to country/zone/date. */
    private function itemsQuery(?int $countryId, ?int $zoneId, $start = null, $end = null)
    {
        $q = DB::table('order_items as oi')->join('orders as o', 'oi.order_id', '=', 'o.id')
            ->whereNull('o.deleted_at')->whereNull('oi.deleted_at');
        if ($countryId) $q->where('o.country_id', $countryId);
        if ($zoneId)    $q->where('o.zone_id', $zoneId);
        if ($start)     $q->where('o.created_at', '>=', $start);
        if ($end)       $q->where('o.created_at', '<=', $end);
        return $q;
    }

    /**
     * Channel-aware "confirmed" test for item-level aggregates: quick orders carry the
     * status at order level, ecommerce orders carry it per item.
     */
    private function confirmedItemsRaw(): string
    {
        $l = implode(',', $this->revenueStatuses);
        return "((o.channel = 'quick' AND o.active_status IN ($l)) OR (o.channel = 'ecommerce' AND oi.active_status IN ($l)))";
    }

    /**
     * `final_total` is stored POST-wallet on both tables:
     *   orders.final_total     = gross_total - wallet_used
     *   order_items.final_total = sub_total + delivery + addl + surge - promo - itemWallet
     * so the wallet-paid portion must be added back to get the earned order value.
     */
    private const ORDER_REVENUE_SQL = 'COALESCE(orders.final_total,0) + COALESCE(orders.wallet_balance,0)';
    private const ITEM_REVENUE_SQL  = 'COALESCE(oi.final_total,0) + COALESCE(oi.wallet_balance,0)';

    /**
     * Revenue = quick orders from `orders` (order-wise status) + ecommerce from
     * `order_items` (item-wise status; quick items carry no distributed money).
     * Both add back the wallet-paid portion.
     */
    private function revenueFor(?int $countryId, ?int $zoneId, $start, $end): float
    {
        $quick = (float) $this->orders($countryId, $zoneId, $start, $end)
            ->where('orders.channel', 'quick')
            ->whereIn('orders.active_status', $this->revenueStatuses)
            ->sum(DB::raw(self::ORDER_REVENUE_SQL));

        $ecom = (float) $this->itemsQuery($countryId, $zoneId, $start, $end)
            ->where('o.channel', 'ecommerce')
            ->whereIn('oi.active_status', $this->revenueStatuses)
            ->sum(DB::raw(self::ITEM_REVENUE_SQL));

        return $quick + $ecom;
    }

    /** Delivery + surge earned: quick at order level, ecommerce per (confirmed) item. */
    private function deliveryEarnedFor(?int $countryId, ?int $zoneId, $start, $end): float
    {
        $sum = 0.0;
        $surge = function ($json) {
            $arr = is_array($json) ? $json : (json_decode((string) $json, true) ?: []);
            $t = 0.0;
            foreach ($arr as $s) $t += (float) ($s['charge'] ?? $s['amount'] ?? 0);
            return $t;
        };

        foreach ($this->orders($countryId, $zoneId, $start, $end)
            ->where('orders.channel', 'quick')->whereIn('orders.active_status', $this->revenueStatuses)
            ->get(['delivery_charge', 'surge_charges']) as $r) {
            $sum += (float) $r->delivery_charge + $surge($r->surge_charges);
        }

        foreach ($this->itemsQuery($countryId, $zoneId, $start, $end)
            ->where('o.channel', 'ecommerce')->whereIn('oi.active_status', $this->revenueStatuses)
            ->get(['oi.delivery_charge', 'oi.surge_charges']) as $r) {
            $sum += (float) $r->delivery_charge + $surge($r->surge_charges);
        }

        return $sum;
    }

    private function transMap(string $table, string $fk, array $ids): array
    {
        if (!$ids) return [];
        $map = [];
        foreach (DB::table($table)->whereIn($fk, $ids)->get([$fk, 'language_id', 'name']) as $r) {
            $code = $this->langCodeById[$r->language_id] ?? null;
            if ($code !== null && $r->name !== null && $r->name !== '') $map[$r->$fk][$code] = $r->name;
        }
        return $map;
    }

    private function localized(array $map, $id, ?string $base): array|string
    {
        $obj = $map[$id] ?? null;
        return (is_array($obj) && $obj) ? $obj : ($base ?? '');
    }

    private function trend(float $cur, float $prev): array
    {
        if ($prev <= 0) return ['pct' => $cur > 0 ? 100 : 0, 'up' => $cur > 0];
        $pct = round((($cur - $prev) / $prev) * 100, 1);
        return ['pct' => abs($pct), 'up' => $pct >= 0];
    }

    /* ===================== widgets ===================== */

    private function todayCards(?int $countryId, ?int $zoneId): array
    {
        $s = Carbon::today();
        $e = Carbon::now()->endOfDay();
        $o = $this->orders($countryId, $zoneId, $s, $e);

        return [
            'orders'    => (int) (clone $o)->count(),
            'revenue'   => round($this->revenueFor($countryId, $zoneId, $s, $e), 2),
            'returned'  => (int) (clone $o)->where('active_status', OrderStatusList::$returned)->count(),
            'cancelled' => (int) (clone $o)->where('active_status', OrderStatusList::$cancelled)->count(),
        ];
    }

    private function kpis(?int $countryId, ?int $zoneId, array $branchIds, $start, $end, $ps, $pe): array
    {
        $cur = $this->orders($countryId, $zoneId, $start, $end);
        $prev = $this->orders($countryId, $zoneId, $ps, $pe);

        // Channel-aware: quick = order-level money/status, ecommerce = item-level.
        $revCur = $this->revenueFor($countryId, $zoneId, $start, $end);
        $revPrev = $this->revenueFor($countryId, $zoneId, $ps, $pe);
        $ordCur = (int) (clone $cur)->count();
        $ordPrev = (int) (clone $prev)->count();
        $custCur = (int) (clone $cur)->distinct()->count('user_id');
        $custPrev = (int) (clone $prev)->distinct()->count('user_id');

        $delCur = $this->deliveryEarnedFor($countryId, $zoneId, $start, $end);
        $delPrev = $this->deliveryEarnedFor($countryId, $zoneId, $ps, $pe);
        $taxCur = $this->taxCollected($countryId, $zoneId, $start, $end);

        // Units sold across confirmed items (channel-aware status).
        $unitsCur = (int) $this->itemsQuery($countryId, $zoneId, $start, $end)->whereRaw($this->confirmedItemsRaw())->sum('oi.quantity');
        $unitsPrev = (int) $this->itemsQuery($countryId, $zoneId, $ps, $pe)->whereRaw($this->confirmedItemsRaw())->sum('oi.quantity');

        $activeProducts = $branchIds
            ? (int) DB::table('product_variant_branch_stocks as pvss')->join('product_variants as v', 'pvss.product_variant_id', '=', 'v.id')
                ->whereIn('pvss.branch_id', $branchIds)->where('pvss.is_listed', 1)->whereNull('v.deleted_at')->distinct()->count('v.product_id')
            : Product::count();

        $boys = DeliveryBoy::where('status', DeliveryBoy::$statusActive);
        if ($countryId) $boys->where('country_id', $countryId);

        return [
            'total_revenue'    => ['value' => round($revCur, 2), 'trend' => $this->trend($revCur, $revPrev)],
            'total_orders'     => ['value' => $ordCur, 'trend' => $this->trend($ordCur, $ordPrev)],
            'delivery_earned'  => ['value' => round($delCur, 2), 'trend' => $this->trend($delCur, $delPrev)],
            'tax_collected'    => ['value' => round($taxCur, 2)],
            'units_sold'       => ['value' => $unitsCur, 'trend' => $this->trend($unitsCur, $unitsPrev)],
            'active_customers' => ['value' => $custCur, 'trend' => $this->trend($custCur, $custPrev)],
            'active_products'  => ['value' => $activeProducts],
            'active_branches'    => ['value' => count($branchIds), 'sub' => $countryId ? Zone::where('country_id', $countryId)->count() : Zone::count()],
            'active_coupons'   => ['value' => $this->activeCouponCount($countryId)],
            'delivery_staff'   => ['value' => (int) $boys->count()],
        ];
    }

    /**
     * Tax collected across confirmed order items in scope (channel-aware status).
     * tax_total is the line total — oi.tax_amount is PER UNIT and under-reported
     * every line with quantity > 1.
     */
    private function taxCollected(?int $countryId, ?int $zoneId, $start, $end): float
    {
        $itemTax = (float) $this->itemsQuery($countryId, $zoneId, $start, $end)
            ->whereRaw($this->confirmedItemsRaw())
            ->sum(DB::raw('COALESCE(oi.tax_total, COALESCE(oi.tax_amount,0) * COALESCE(oi.quantity,1)) - COALESCE(oi.refund_tax_amount, 0)'));

        $chargeTax = (float) DB::table('order_item_taxes as oit')
            ->join('orders as o', 'o.id', '=', 'oit.order_id')
            ->whereNull('oit.order_item_id')
            ->whereNull('o.deleted_at')
            ->whereIn('o.active_status', $this->revenueStatuses)
            ->when($countryId, fn ($q) => $q->where('o.country_id', $countryId))
            ->when($zoneId, fn ($q) => $q->where('o.zone_id', $zoneId))
            ->when($start, fn ($q) => $q->where('o.created_at', '>=', $start))
            ->when($end, fn ($q) => $q->where('o.created_at', '<=', $end))
            ->sum('oit.amount');

        return round($itemTax + $chargeTax, 2);
    }

    /** status=1 AND (permanent OR within start/end date window). */
    private function activeCouponCount(?int $countryId): int
    {
        $today = Carbon::today()->toDateString();
        $q = PromoCode::where('status', 1)
            ->where(fn ($w) => $w->whereNull('source')->orWhere('source', '!=', 'spin_wheel'))
            ->where(function ($w) use ($today) {
                $w->where('is_permanent', 1)
                    ->orWhere(function ($x) use ($today) {
                        $x->where(fn ($a) => $a->whereNull('start_date')->orWhereDate('start_date', '<=', $today))
                            ->where(fn ($a) => $a->whereNull('end_date')->orWhereDate('end_date', '>=', $today));
                    });
            });
        if ($countryId) {
            $q->where(function ($w) use ($countryId) {
                $w->whereJsonContains('country_ids', $countryId)->orWhereJsonContains('country_ids', (string) $countryId)
                    ->orWhereNull('country_ids')->orWhereRaw('JSON_LENGTH(country_ids) = 0');
            });
        }
        return (int) $q->count();
    }

    private function revenueTrend(?int $countryId, ?int $zoneId, $start, $end, string $gran): array
    {
        // For 'all' bound to last 12 months.
        if (!$start) {
            $start = Carbon::now()->startOfMonth()->subMonths(11);
            $end = Carbon::now()->endOfMonth();
            $gran = 'month';
        }

        $fmt = ['hour' => '%Y-%m-%d %H:00', 'day' => '%Y-%m-%d', 'month' => '%Y-%m'][$gran];

        // Quick revenue is order-level; ecommerce revenue is item-level. Merge per bucket.
        $quickRev = $this->orders($countryId, $zoneId, $start, $end)
            ->where('orders.channel', 'quick')->whereIn('orders.active_status', $this->revenueStatuses)
            ->selectRaw("DATE_FORMAT(orders.created_at, '$fmt') as k")
            ->selectRaw('SUM(' . self::ORDER_REVENUE_SQL . ') as revenue')
            ->groupBy('k')->pluck('revenue', 'k');

        $ecomRev = $this->itemsQuery($countryId, $zoneId, $start, $end)
            ->where('o.channel', 'ecommerce')->whereIn('oi.active_status', $this->revenueStatuses)
            ->selectRaw("DATE_FORMAT(o.created_at, '$fmt') as k")
            ->selectRaw('SUM(' . self::ITEM_REVENUE_SQL . ') as revenue')
            ->groupBy('k')->pluck('revenue', 'k');

        $ordersByBucket = $this->orders($countryId, $zoneId, $start, $end)
            ->selectRaw("DATE_FORMAT(orders.created_at, '$fmt') as k")->selectRaw('COUNT(*) as c')
            ->groupBy('k')->pluck('c', 'k');

        $labels = [];
        $rev = [];
        $ord = [];
        $cursor = $start->copy();
        $step = ['hour' => 'addHour', 'day' => 'addDay', 'month' => 'addMonth'][$gran];
        $keyFmt = ['hour' => 'Y-m-d H:00', 'day' => 'Y-m-d', 'month' => 'Y-m'][$gran];
        $guard = 0;
        while ($cursor <= $end && $guard++ < 400) {
            $k = $cursor->format($keyFmt);
            $labels[] = $this->fmtLabel($cursor, $gran);
            $rev[] = round((float) ($quickRev[$k] ?? 0) + (float) ($ecomRev[$k] ?? 0), 2);
            $ord[] = (int) ($ordersByBucket[$k] ?? 0);
            $cursor->{$step}();
        }
        return ['labels' => $labels, 'revenue' => $rev, 'orders' => $ord];
    }

    private function fmtLabel(Carbon $c, string $gran): string
    {
        return match ($gran) {
            'hour' => $c->format('H:00'),
            'month' => $c->format('M y'),
            default => $c->format('d M'),
        };
    }

    private function orderStatus(?int $countryId, ?int $zoneId, $start, $end): array
    {
        $counts = $this->orders($countryId, $zoneId, $start, $end)
            ->selectRaw('active_status, COUNT(*) as c')->groupBy('active_status')->pluck('c', 'active_status');

        // Return ALL statuses (0 included) in canonical order for the bar list.
        $out = [];
        foreach (OrderStatusList::orderBy('id')->get() as $s) {
            $out[] = [
                'status_id' => (int) $s->id,
                'name'      => OrderStatusList::getTranslatedName((int) $s->id),
                'count'     => (int) ($counts[$s->id] ?? 0),
            ];
        }
        return $out;
    }

    private function categorySales(?int $countryId, ?int $zoneId, $start, $end): array
    {
        // product via variant: oi.product_variant_id -> product_variants.product_id -> products.category_id
        $q = $this->itemsQuery($countryId, $zoneId, $start, $end)
            ->join('product_variants as v', 'oi.product_variant_id', '=', 'v.id')
            ->join('products as p', 'v.product_id', '=', 'p.id')
            ->join('categories as c', 'p.category_id', '=', 'c.id')
            ->whereRaw($this->confirmedItemsRaw());

        $rows = $q->groupBy('c.id', 'c.name')
            ->selectRaw('c.id as category_id, c.name as name, SUM(oi.sub_total) as revenue')
            ->orderByDesc('revenue')->limit(6)->get();

        $names = $this->transMap('category_translations', 'category_id', $rows->pluck('category_id')->all());
        return $rows->map(fn ($r) => [
            'name'    => $this->localized($names, $r->category_id, $r->name),
            'revenue' => round((float) $r->revenue, 2),
        ])->all();
    }

    /**
     * Top selling products by sales value. Uses oi.sub_total (product value) — the only
     * money column populated for BOTH channels (quick items carry no distributed totals).
     */
    private function topProducts(?int $countryId, ?int $zoneId, $start, $end): array
    {
        $rows = $this->itemsQuery($countryId, $zoneId, $start, $end)
            ->join('product_variants as v', 'oi.product_variant_id', '=', 'v.id')
            ->join('products as p', 'v.product_id', '=', 'p.id')
            ->whereRaw($this->confirmedItemsRaw())
            ->groupBy('p.id', 'p.image')
            ->selectRaw('p.id, p.image, SUM(oi.sub_total) as revenue, SUM(oi.quantity) as units, MIN(v.id) as variant_id')
            ->orderByDesc('revenue')->limit(5)->get();

        if ($rows->isEmpty()) return [];
        $varNames = $this->transMap('product_variant_translations', 'product_variant_id', $rows->pluck('variant_id')->filter()->all());

        return $rows->map(fn ($r) => [
            'id'      => (int) $r->id,
            'name'    => $this->localized($varNames, $r->variant_id, null) ?: ('#' . $r->id),
            'image'   => $r->image ? asset('storage/' . $r->image) : '',
            'revenue' => round((float) $r->revenue, 2),
            'units'   => (int) $r->units,
        ])->all();
    }

    private function productsByBrand(array $branchIds): array
    {
        if (!$branchIds) return [];
        $rows = DB::table('product_variant_branch_stocks as pvss')
            ->join('product_variants as v', 'pvss.product_variant_id', '=', 'v.id')
            ->join('products as p', 'v.product_id', '=', 'p.id')
            ->join('brands as b', 'p.brand_id', '=', 'b.id')
            ->whereIn('pvss.branch_id', $branchIds)->where('pvss.is_listed', 1)->whereNull('v.deleted_at')
            ->groupBy('b.id', 'b.name')
            ->selectRaw('b.id as brand_id, b.name as name, COUNT(DISTINCT p.id) as c')
            ->orderByDesc('c')->limit(6)->get();
        $names = $this->transMap('brand_translations', 'brand_id', $rows->pluck('brand_id')->all());
        return $rows->map(fn ($r) => ['name' => $this->localized($names, $r->brand_id, $r->name), 'count' => (int) $r->c])->all();
    }

    private function commerceMode(?int $countryId, ?int $zoneId, $start, $end): array
    {
        $counts = $this->orders($countryId, $zoneId, $start, $end)->whereIn('orders.channel', ['quick', 'ecommerce'])
            ->selectRaw("CASE WHEN orders.delivery_type = 'pickup' THEN 'pickup' ELSE orders.channel END as bucket, COUNT(*) as orders")
            ->groupBy('bucket')->pluck('orders', 'bucket');

        // Revenue: quick from orders, ecommerce from its (confirmed) items. Wallet added back.
        $quickRev = (float) $this->orders($countryId, $zoneId, $start, $end)
            ->where('orders.channel', 'quick')->where('orders.delivery_type', 'delivery')
            ->whereIn('orders.active_status', $this->revenueStatuses)
            ->sum(DB::raw(self::ORDER_REVENUE_SQL));
        $ecomRev = (float) $this->itemsQuery($countryId, $zoneId, $start, $end)
            ->where('o.channel', 'ecommerce')->where('o.delivery_type', 'delivery')
            ->whereIn('oi.active_status', $this->revenueStatuses)
            ->sum(DB::raw(self::ITEM_REVENUE_SQL));
        $pickupRev = (float) $this->orders($countryId, $zoneId, $start, $end)
            ->where('orders.channel', 'quick')->where('orders.delivery_type', 'pickup')
            ->whereIn('orders.active_status', $this->revenueStatuses)
            ->sum(DB::raw(self::ORDER_REVENUE_SQL))
            + (float) $this->itemsQuery($countryId, $zoneId, $start, $end)
            ->where('o.channel', 'ecommerce')->where('o.delivery_type', 'pickup')
            ->whereIn('oi.active_status', $this->revenueStatuses)
            ->sum(DB::raw(self::ITEM_REVENUE_SQL));

        return [
            'quick'     => ['orders' => (int) ($counts['quick'] ?? 0), 'revenue' => round($quickRev, 2)],
            'ecommerce' => ['orders' => (int) ($counts['ecommerce'] ?? 0), 'revenue' => round($ecomRev, 2)],
            'pickup'    => ['orders' => (int) ($counts['pickup'] ?? 0), 'revenue' => round($pickupRev, 2)],
        ];
    }

    private function inventoryHealth(array $branchIds): array
    {
        if (!$branchIds) return ['in_stock' => 0, 'low_stock' => 0, 'out_of_stock' => 0, 'total' => 0];
        $base = DB::table('product_variant_branch_stocks')->whereIn('branch_id', $branchIds)->where('is_listed', 1);
        $in = (int) (clone $base)->where('stock_status', 1)->where('available', '>', 0)->count();
        $out = (int) (clone $base)->where(fn ($w) => $w->where('stock_status', 0)->orWhere('available', '<=', 0))->count();
        $low = (int) (clone $base)->where('stock_status', 1)->where('available', '>', 0)->where('min_alert', '>', 0)->whereColumn('available', '<=', 'min_alert')->count();
        return ['in_stock' => $in, 'low_stock' => $low, 'out_of_stock' => $out, 'total' => (int) (clone $base)->count()];
    }

    private function topBranches(?int $countryId, ?int $zoneId, array $branchIds, $start, $end): array
    {
        if (!$branchIds) return [];
        $q = $this->itemsQuery($countryId, $zoneId, $start, $end)
            ->whereIn('oi.branch_id', $branchIds)
            ->whereRaw($this->confirmedItemsRaw());
        $rows = $q->groupBy('oi.branch_id')->selectRaw('oi.branch_id, SUM(oi.sub_total) as revenue, COUNT(DISTINCT oi.order_id) as orders')
            ->orderByDesc('revenue')->limit(5)->get();

        $branchRows = Branch::whereIn('id', $rows->pluck('branch_id')->all())->get()->keyBy('id');
        $names = $this->transMap('branch_translations', 'branch_id', $rows->pluck('branch_id')->all());
        return $rows->map(fn ($r) => [
            'id'      => $r->branch_id,
            'name'    => $this->localized($names, $r->branch_id, optional($branchRows[$r->branch_id] ?? null)->getAttributeValue('name')),
            'revenue' => round((float) $r->revenue, 2),
            'orders'  => (int) $r->orders,
        ])->all();
    }

    private function topCustomers(?int $countryId, ?int $zoneId, $start, $end): array
    {
        // Order counts per customer (order-level, both channels).
        $rows = $this->orders($countryId, $zoneId, $start, $end)
            ->selectRaw('user_id, COUNT(*) as orders')
            ->whereNotNull('user_id')->groupBy('user_id')->orderByDesc('orders')->limit(5)->get();

        $userIds = $rows->pluck('user_id')->all();
        if (!$userIds) return [];

        // Spend: quick from orders, ecommerce from its confirmed items.
        $quickSpent = $this->orders($countryId, $zoneId, $start, $end)
            ->where('orders.channel', 'quick')->whereIn('orders.active_status', $this->revenueStatuses)
            ->whereIn('orders.user_id', $userIds)
            ->selectRaw('user_id, SUM(' . self::ORDER_REVENUE_SQL . ') as s')->groupBy('user_id')->pluck('s', 'user_id');
        $ecomSpent = $this->itemsQuery($countryId, $zoneId, $start, $end)
            ->where('o.channel', 'ecommerce')->whereIn('oi.active_status', $this->revenueStatuses)
            ->whereIn('o.user_id', $userIds)
            ->selectRaw('o.user_id as user_id, SUM(' . self::ITEM_REVENUE_SQL . ') as s')->groupBy('o.user_id')->pluck('s', 'user_id');

        $users = User::whereIn('id', $userIds)->get(['id', 'name', 'mobile', 'country_code', 'email', 'profile'])->keyBy('id');
        return $rows->map(function ($r) use ($users, $quickSpent, $ecomSpent) {
            $u = $users[$r->user_id] ?? null;
            $p = $u ? $u->getAttributes()['profile'] ?? '' : '';
            $spent = (float) ($quickSpent[$r->user_id] ?? 0) + (float) ($ecomSpent[$r->user_id] ?? 0);
            return [
                'id'     => (int) $r->user_id,
                'name'   => $u->name ?? ('#' . $r->user_id),
                'country_code' => $u->country_code ?? '',
                'mobile' => $u ? ($u->getAttributes()['mobile'] ?? '') : '',
                'email'  => $u->email ?? '',
                'image'  => $p ? (str_contains($p, '://') ? $p : asset('storage/' . $p)) : '',
                'orders' => (int) $r->orders,
                'spent'  => round($spent, 2),
            ];
        })->all();
    }

    /** Products listed in the given branches — the pool every product ranking draws from. */
    private function listedProductIds(array $branchIds): array
    {
        if (!$branchIds) return [];
        return DB::table('product_variant_branch_stocks as pvss')->join('product_variants as v', 'pvss.product_variant_id', '=', 'v.id')
            ->whereIn('pvss.branch_id', $branchIds)->where('pvss.is_listed', 1)->whereNull('v.deleted_at')
            ->distinct()->pluck('v.product_id')->all();
    }

    /**
     * id => ['name', 'image'] for a set of products. Name comes from the first
     * variant's translations, image from the product itself.
     */
    private function productLabels(array $productIds): array
    {
        if (!$productIds) return [];
        $prodInfo = DB::table('products')->whereIn('id', $productIds)->get(['id', 'image'])->keyBy('id');
        $firstVar = DB::table('product_variants')->whereIn('product_id', $productIds)->whereNull('deleted_at')
            ->selectRaw('product_id, MIN(id) as vid')->groupBy('product_id')->pluck('vid', 'product_id')->all();
        $varNames = $this->transMap('product_variant_translations', 'product_variant_id', array_values($firstVar));

        $out = [];
        foreach ($productIds as $pid) {
            $vid = $firstVar[$pid] ?? null;
            $img = optional($prodInfo[$pid] ?? null)->image;
            $out[$pid] = [
                'name'  => $vid ? ($this->localized($varNames, $vid, null) ?: ('#' . $pid)) : ('#' . $pid),
                'image' => $img ? asset('storage/' . $img) : '',
            ];
        }
        return $out;
    }

    private function topRatedProducts(array $branchIds): array
    {
        $prodIds = $this->listedProductIds($branchIds);
        if (!$prodIds) return [];

        $rows = DB::table('product_ratings')->whereIn('product_id', $prodIds)->where('status', 1)
            ->groupBy('product_id')->selectRaw('product_id, AVG(rate) as avg_rate, COUNT(*) as cnt')
            ->havingRaw('COUNT(*) > 0')->orderByDesc('avg_rate')->orderByDesc('cnt')->limit(5)->get();
        if ($rows->isEmpty()) return [];

        $labels = $this->productLabels($rows->pluck('product_id')->all());

        return $rows->map(fn ($r) => [
            'id'     => (int) $r->product_id,
            'name'   => $labels[$r->product_id]['name'] ?? ('#' . $r->product_id),
            'image'  => $labels[$r->product_id]['image'] ?? '',
            'rating' => round((float) $r->avg_rate, 1),
            'count'  => (int) $r->cnt,
        ])->all();
    }

    private function mostWishlisted(array $branchIds): array
    {
        $prodIds = $this->listedProductIds($branchIds);
        if (!$prodIds) return [];

        $rows = DB::table('favorites')->whereIn('product_id', $prodIds)
            ->groupBy('product_id')->selectRaw('product_id, COUNT(*) as cnt')
            ->orderByDesc('cnt')->limit(5)->get();
        if ($rows->isEmpty()) return [];

        $labels = $this->productLabels($rows->pluck('product_id')->all());

        return $rows->map(fn ($r) => [
            'id'    => (int) $r->product_id,
            'name'  => $labels[$r->product_id]['name'] ?? ('#' . $r->product_id),
            'image' => $labels[$r->product_id]['image'] ?? '',
            'count' => (int) $r->cnt,
        ])->all();
    }

    /** Same snapshot idea for `carts`: how many open carts hold each product. */
    private function mostAddedToCart(array $branchIds): array
    {
        $prodIds = $this->listedProductIds($branchIds);
        if (!$prodIds) return [];

        $rows = DB::table('carts')->whereIn('product_id', $prodIds)
            ->groupBy('product_id')->selectRaw('product_id, COUNT(*) as cnt, SUM(qty) as units')
            ->orderByDesc('cnt')->limit(5)->get();
        if ($rows->isEmpty()) return [];

        $labels = $this->productLabels($rows->pluck('product_id')->all());

        return $rows->map(fn ($r) => [
            'id'    => (int) $r->product_id,
            'name'  => $labels[$r->product_id]['name'] ?? ('#' . $r->product_id),
            'image' => $labels[$r->product_id]['image'] ?? '',
            'count' => (int) $r->cnt,
            'units' => (int) $r->units,
        ])->all();
    }

    /** App usage by device/platform, optionally scoped to the country's orders. */
    private function platformUsage($start, $end): array
    {
        // Platform usage is global (app_usages has no country link) — period-filtered only.
        $q = DB::table('app_usages');
        if ($start) $q->where('created_at', '>=', $start);
        if ($end)   $q->where('created_at', '<=', $end);
        $rows = $q->selectRaw('device_type as device, COUNT(*) as c')->groupBy('device_type')->orderByDesc('c')->get();
        return $rows->map(fn ($r) => ['device' => $r->device ?: 'unknown', 'count' => (int) $r->c])->all();
    }

    private function returnsSummary(?int $countryId, ?int $zoneId, $start, $end): array
    {
        $base = ReturnRequest::query()->join('orders', 'return_requests.order_id', '=', 'orders.id');
        if ($countryId) $base->where('orders.country_id', $countryId);
        if ($zoneId)    $base->where('orders.zone_id', $zoneId);
        if ($start)     $base->where('return_requests.created_at', '>=', $start);
        if ($end)       $base->where('return_requests.created_at', '<=', $end);

        $total    = (int) (clone $base)->count();
        $pending  = (int) (clone $base)->whereNotIn('return_requests.status', [ReturnStatusList::$rRefundCompleted, ReturnStatusList::$rRejected])->count();
        $refunded = (int) (clone $base)->where('return_requests.status', ReturnStatusList::$rRefundCompleted)->count();
        $rejected = (int) (clone $base)->where('return_requests.status', ReturnStatusList::$rRejected)->count();

        return ['total' => $total, 'pending' => $pending, 'refunded' => $refunded, 'rejected' => $rejected];
    }

    private function recentOrders(?int $countryId, ?int $zoneId): array
    {
        $rows = $this->orders($countryId, $zoneId)
            ->leftJoin('users', 'orders.user_id', '=', 'users.id')
            ->orderByDesc('orders.id')->limit(8)
            ->get([
                'orders.id', 'orders.order_number', 'orders.channel', 'orders.delivery_type', 'orders.active_status', 'orders.final_total',
                'orders.payment_method', 'orders.created_at', 'orders.mobile',
                'users.name as user_name',
            ]);

        return $rows->map(fn ($o) => [
            'id'          => $o->id,
            'order_number' => $o->order_number,
            'customer'    => $o->user_name ?: '',
            'mobile'      => $o->mobile ?: '',
            'channel'     => $o->channel,
            'delivery_type' => $o->delivery_type ?: 'delivery',
            'payment'     => $o->payment_method,
            'status_id'   => (int) $o->active_status,
            'status_name' => OrderStatusList::getCustomerTranslatedName((int) $o->active_status, $o->delivery_type ?: 'delivery'),
            'amount'      => round((float) $o->final_total, 2),
            'date'        => optional($o->created_at)->format('d M Y') ?? '',
        ])->all();
    }
}
