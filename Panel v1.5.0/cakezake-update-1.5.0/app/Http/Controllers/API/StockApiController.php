<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Helpers\ProductHelper;
use App\Http\Controllers\Controller;
use App\Models\ProductVariantBranchStock;
use App\Models\Branch;
use App\Models\Zone;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class StockApiController extends Controller
{
    /* ---- Stock state helpers (kept consistent across endpoints) ---- */

    /** Out of stock: explicitly marked out, or nothing available. */
    /** Stock is not tracked for this branch row — it can never run out. */
    private function isUnlimited($row): bool
    {
        return (int) ($row->is_unlimited_stock ?? 0) === 1;
    }

    private function isOut($row): bool
    {
        if ($this->isUnlimited($row)) {
            return false;
        }
        return (int) $row->stock_status === 0 || (int) $row->available <= 0;
    }

    /** Low stock: in stock but at/below the min alert (alert configured). */
    private function isLow($row): bool
    {
        if ($this->isUnlimited($row)) {
            return false;
        }
        return !$this->isOut($row) && (int) $row->min_alert > 0 && (int) $row->available <= (int) $row->min_alert;
    }

    /**
     * Branch ids allowed by the global header country/zone filter, or null when no
     * filter is set. Branches reach a country via their zone FKs (quick / ecommerce).
     */
    private function filteredBranchIds(Request $request): ?array
    {
        $countryId = (int) $request->input('country_id', 0);
        $zoneId    = (int) $request->input('zone_id', 0);
        if (!$countryId && !$zoneId) {
            return null;
        }

        $zoneIds = $zoneId
            ? [$zoneId]
            : Zone::where('country_id', $countryId)->pluck('id')->all();

        return Branch::where(function ($q) use ($zoneIds) {
            $q->whereIn('zone_id', $zoneIds);
        })->pluck('id')->all();
    }

    /**
     * Overview tab: global KPI tiles + per-branch snapshot.
     */
    public function overview(Request $request)
    {
        $allowed = $this->filteredBranchIds($request);
        $branchQuery = Branch::where('status', 1)->orderBy('name');
        if ($allowed !== null) {
            $branchQuery->whereIn('id', $allowed);
        }

        $branches = $branchQuery->with('zone:id,city')->get(['id', 'name', 'zone_id']);
        $branchIds = $branches->pluck('id')->all();

        $rows = $this->baseRows()->whereIn('pvss.branch_id', $branchIds)->get();

        // Per-branch snapshot + global accumulators.
        $perBranch = [];
        foreach ($branches as $s) {
            $perBranch[$s->id] = [
                'id' => (int) $s->id, 'name' => $s->name, 'city' => $s->zone?->city,
                'in_stock' => 0, 'out' => 0, 'low' => 0, 'units' => 0, 'value' => 0.0,
            ];
        }

        $totalUnits = 0;
        $totalValue = 0.0;
        $listedSkuIds = [];
        $variantInStock = [];   // variant_id => bool (in stock anywhere)
        $variantExists  = [];   // variant_id => true
        $variantLow     = [];   // variant_id => bool

        foreach ($rows as $r) {
            $variantExists[$r->product_variant_id] = true;
            $unitPrice = (float) $r->discounted_price > 0 ? (float) $r->discounted_price : (float) $r->price;
            // Unlimited branches don't track units, so their `available` is not a real
            // quantity — counting it would inflate units and inventory value.
            $lineUnits = $this->isUnlimited($r) ? 0 : max(0, (int) $r->available);
            $lineValue = $lineUnits * $unitPrice;
            $totalUnits += $lineUnits;
            $totalValue += $lineValue;

            if ((int) $r->is_listed === 1) {
                $listedSkuIds[$r->product_variant_id] = true;
            }

            $out = $this->isOut($r);
            $low = $this->isLow($r);
            if (!$out) {
                $variantInStock[$r->product_variant_id] = true;
            }
            if ($low) {
                $variantLow[$r->product_variant_id] = true;
            }

            $ps = &$perBranch[$r->branch_id];
            if ($out) {
                $ps['out']++;
            } elseif ($low) {
                $ps['low']++;
                $ps['in_stock']++;
            } else {
                $ps['in_stock']++;
            }
            $ps['units'] += $lineUnits;
            $ps['value'] += $lineValue;
            unset($ps);
        }

        $totalSkus = count($variantExists);
        $inStock   = count($variantInStock);
        $low       = count(array_filter($variantLow, fn($v, $k) => isset($variantInStock[$k]), ARRAY_FILTER_USE_BOTH));

        $totals = [
            'total_skus'      => $totalSkus,
            'in_stock'        => $inStock,
            'out_of_stock'    => $totalSkus - $inStock,
            'low_stock'       => $low,
            'listed_skus'     => count($listedSkuIds),
            'total_units'     => $totalUnits,
            'inventory_value' => round($totalValue, 2),
            'active_branches'   => $branches->count(),
        ];

        $snapshot = array_map(function ($s) {
            $s['value'] = round($s['value'], 2);
            return $s;
        }, array_values($perBranch));

        return CommonHelper::responseWithData([
            'totals' => $totals,
            'branches' => $snapshot,
        ]);
    }

    /**
     * Inventory tab: branch view (flat rows) or product view (grouped). Filters:
     * search, branch_id, status (in_stock|out_of_stock|low_stock|unlisted).
     */
    public function inventory(Request $request)
    {
        $view    = $request->input('view') === 'product' ? 'product' : 'branch';
        $search  = trim((string) $request->input('search', ''));
        $branchId = (int) $request->input('branch_id', 0);
        $status  = $request->input('status', 'all');
        $page    = max(1, (int) $request->input('page', 1));
        $perPage = (int) $request->input('per_page', 20);
        $perPage = $perPage > 0 ? min($perPage, 100) : 20;

        $allowed = $this->filteredBranchIds($request);

        $apply = function ($q) use ($search, $branchId, $status, $allowed) {
            $q->where('branches.status', 1);
            if ($allowed !== null) {
                $q->whereIn('pvss.branch_id', $allowed);
            }
            if ($branchId) {
                $q->where('pvss.branch_id', $branchId);
            }
            if ($search !== '') {
                $like = '%' . $search . '%';
                $q->where(function ($w) use ($like) {
                    $w->where('pv.name', 'like', $like)->orWhere('pv.sku', 'like', $like);
                });
            }
            // Unlimited branch rows are always in stock and never low / out.
            switch ($status) {
                case 'in_stock':
                    $q->where(function ($w) {
                        $w->where('pvss.is_unlimited_stock', 1)
                            ->orWhere(fn($x) => $x->where('pvss.stock_status', 1)->where('pvss.available', '>', 0));
                    });
                    break;
                case 'out_of_stock':
                    $q->where('pvss.is_unlimited_stock', 0)
                        ->where(function ($w) {
                            $w->where('pvss.stock_status', 0)->orWhere('pvss.available', '<=', 0);
                        });
                    break;
                case 'low_stock':
                    $q->where('pvss.is_unlimited_stock', 0)
                        ->where('pvss.available', '>', 0)
                        ->where('pvss.min_alert', '>', 0)
                        ->whereColumn('pvss.available', '<=', 'pvss.min_alert');
                    break;
                case 'unlimited':
                    $q->where('pvss.is_unlimited_stock', 1);
                    break;
                case 'unlisted':
                    $q->where('pvss.is_listed', 0);
                    break;
            }
        };

        if ($view === 'product') {
            // Distinct products matching the filter, paginated.
            $productIdsQuery = $this->baseRows()->select('p.id')->distinct();
            $apply($productIdsQuery);
            $allProductIds = $productIdsQuery->orderBy('p.id', 'desc')->pluck('id')->all();
            $totalProducts = count($allProductIds);
            $pageProductIds = array_slice($allProductIds, ($page - 1) * $perPage, $perPage);

            $groups = [];
            if (!empty($pageProductIds)) {
                $rowsQuery = $this->baseRows()->whereIn('p.id', $pageProductIds);
                $apply($rowsQuery);
                $rows = $rowsQuery->orderBy('p.id', 'desc')->orderBy('pv.id')->get();

                $variantIds = $rows->pluck('product_variant_id')->unique()->all();
                $attrText = $this->attributesTextMap($variantIds);

                $byProduct = [];
                foreach ($rows as $r) {
                    $byProduct[$r->product_id]['rows'][] = $this->shapeRow($r, $attrText);
                    $byProduct[$r->product_id]['units'] = ($byProduct[$r->product_id]['units'] ?? 0) + max(0, (int) $r->available);
                    $byProduct[$r->product_id]['meta'] = [
                        'product_id' => (int) $r->product_id,
                        'name'       => $r->product_name,
                        'image_url'  => !empty($r->variant_image) ? asset('storage/' . $r->variant_image) : null,
                        'sku'        => $r->sku,
                        'brand'      => $r->brand_name,
                    ];
                }
                // Keep page order.
                foreach ($pageProductIds as $pid) {
                    if (isset($byProduct[$pid])) {
                        $g = $byProduct[$pid];
                        $groups[] = array_merge($g['meta'], [
                            'units_total'    => $g['units'],
                            'branch_variants' => count($g['rows']),
                            'variants'       => $g['rows'],
                        ]);
                    }
                }
            }

            return CommonHelper::responseWithData([
                'view'   => 'product',
                'groups' => $groups,
            ], $totalProducts);
        }

        // Branch view: flat paginated rows.
        $rowsQuery = $this->baseRows();
        $apply($rowsQuery);
        $total = (clone $rowsQuery)->count('pvss.id');
        $rows = $rowsQuery->orderBy('p.id', 'desc')->orderBy('pv.id')
            ->forPage($page, $perPage)->get();

        $attrText = $this->attributesTextMap($rows->pluck('product_variant_id')->unique()->all());
        $items = $rows->map(fn($r) => $this->shapeRow($r, $attrText))->all();

        return CommonHelper::responseWithData(['view' => 'branch', 'rows' => $items], $total);
    }

    /**
     * Adjust a branch-variant's available stock: add | remove | set.
     * stock_status is recomputed from the resulting available (>0 => in stock).
     */
    public function adjust(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_variant_id' => 'required|integer',
            'branch_id'           => 'required|integer',
            'action'             => 'required|in:add,remove,set',
            'quantity'           => 'required|numeric|min:0',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $row = ProductVariantBranchStock::where('product_variant_id', $request->product_variant_id)
            ->where('branch_id', $request->branch_id)
            ->first();
        if (!$row) {
            return CommonHelper::responseError('stock_record_not_found');
        }

        $qty = (int) $request->quantity;
        $available = (int) $row->available;
        switch ($request->action) {
            case 'add':
                $available += $qty;
                break;
            case 'remove':
                $available = max(0, $available - $qty);
                break;
            case 'set':
                $available = $qty;
                break;
        }

        $row->available = $available;
        $row->stock_status = $available > 0 ? 1 : 0;
        $row->save();

        ProductHelper::notifyBackInStock($row->product_variant_id, $row->branch_id);

        return CommonHelper::responseSuccessWithData('stock_updated_successfully', [
            'available'    => $available,
            'stock_status' => (int) $row->stock_status,
        ]);
    }

    /**
     * Alerts tab: out-of-stock + low-stock branch-variants (listed only).
     */
    public function alerts(Request $request)
    {
        $allowed = $this->filteredBranchIds($request);

        $rows = $this->baseRows()
            ->where('branches.status', 1)
            ->when($allowed !== null, fn($q) => $q->whereIn('pvss.branch_id', $allowed))
            ->where('pvss.is_listed', 1)
            ->where('pvss.is_unlimited_stock', 0)
            ->where(function ($w) {
                $w->where('pvss.stock_status', 0)
                    ->orWhere('pvss.available', '<=', 0)
                    ->orWhere(function ($l) {
                        $l->where('pvss.available', '>', 0)
                            ->where('pvss.min_alert', '>', 0)
                            ->whereColumn('pvss.available', '<=', 'pvss.min_alert');
                    });
            })
            ->orderBy('pvss.available')
            ->get();

        $attrText = $this->attributesTextMap($rows->pluck('product_variant_id')->unique()->all());

        $out = [];
        $low = [];
        foreach ($rows as $r) {
            $shaped = $this->shapeRow($r, $attrText);
            if ($this->isOut($r)) {
                $out[] = $shaped;
            } elseif ($this->isLow($r)) {
                $low[] = $shaped;
            }
        }

        return CommonHelper::responseWithData([
            'out_of_stock' => $out,
            'low_stock'    => $low,
            'out_count'    => count($out),
            'low_count'    => count($low),
            'total'        => count($out) + count($low),
        ]);
    }

    /* ------------------------------------------------------------------ */

    /** Base joined PVSS query with the columns every endpoint needs. */
    private function baseRows()
    {
        return ProductVariantBranchStock::query()
            ->from('product_variant_branch_stocks as pvss')
            ->join('product_variants as pv', 'pv.id', '=', 'pvss.product_variant_id')
            ->join('products as p', 'p.id', '=', 'pv.product_id')
            ->join('branches', 'branches.id', '=', 'pvss.branch_id')
            // City moved to the zone, so join it for the branch_city column below.
            ->leftJoin('zones as branch_zones', 'branch_zones.id', '=', 'branches.zone_id')
            ->leftJoin('brands', 'brands.id', '=', 'p.brand_id')
            ->select(
                'pvss.id', 'pvss.product_variant_id', 'pvss.branch_id',
                'pvss.available', 'pvss.reserved', 'pvss.min_alert',
                'pvss.stock_status', 'pvss.is_listed',
                'pvss.price', 'pvss.discounted_price', 'pvss.purchase_price',
                'pv.name as product_name', 'pv.sku',
                'pv.image as variant_image', 'pv.product_id',
                'pvss.is_unlimited_stock',
                'brands.name as brand_name',
                'branches.name as branch_name', 'branch_zones.city as branch_city'
            );
    }

    /** variant_id => "Red / Large" attribute summary. */
    private function attributesTextMap(array $variantIds): array
    {
        if (empty($variantIds)) {
            return [];
        }
        $rows = DB::table('product_variant_attribute_values as pva')
            ->join('attribute_values as av', 'av.id', '=', 'pva.attribute_value_id')
            ->whereIn('pva.product_variant_id', $variantIds)
            ->orderBy('pva.id')
            ->get(['pva.product_variant_id', 'av.value']);

        $map = [];
        foreach ($rows as $r) {
            $map[$r->product_variant_id][] = $r->value;
        }
        return array_map(fn($vals) => implode(' / ', $vals), $map);
    }

    /** Shape one PVSS row into an inventory item. */
    private function shapeRow($r, array $attrText): array
    {
        $available = (int) $r->available;
        $unlimited = $this->isUnlimited($r);
        $out = $this->isOut($r);
        $low = $this->isLow($r);
        $state = $unlimited ? 'unlimited' : ($out ? 'out_of_stock' : ($low ? 'low_stock' : 'in_stock'));

        return [
            'product_variant_id' => (int) $r->product_variant_id,
            'product_id'         => (int) $r->product_id,
            'product_name'       => $r->product_name,
            'image_url'          => !empty($r->variant_image) ? asset('storage/' . $r->variant_image) : null,
            'sku'                => $r->sku,
            'brand_name'         => $r->brand_name,
            'variant_text'       => $attrText[$r->product_variant_id] ?? '',
            'branch_id'           => (int) $r->branch_id,
            'branch_name'         => $r->branch_name,
            'branch_city'         => $r->branch_city,
            'available'          => $available,
            'reserved'           => (int) $r->reserved,
            'min_alert'          => (int) $r->min_alert,
            'is_listed'          => (int) $r->is_listed,
            'is_unlimited_stock' => $unlimited ? 1 : 0,
            'in_stock'           => !$out,
            'state'              => $state,
        ];
    }
}
