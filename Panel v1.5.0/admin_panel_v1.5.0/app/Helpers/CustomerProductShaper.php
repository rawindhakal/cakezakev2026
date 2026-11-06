<?php

namespace App\Helpers;

use App\Services\TaxService;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\Setting;
use App\Models\Branch;

/**
 * Shared product-card shaper for customer-facing endpoints.
 * Used by Customer\ProductsApiController + HomeLayoutResolver so listings
 * and home-builder product blocks return an identical payload.
 *
 * Required eager loads on $p: variants, variants.images, variants.branchStocks
 * (scoped to the zone's branchIds), variants.attributeValues.attribute,
 * variants.attributeValues.attributeValue, category, brand, tax, ratings.
 */
class CustomerProductShaper
{
    public static function buildVariantImages(ProductVariant $variant): array
    {
        $images = $variant->images->map(fn ($im) => [
            'image_url' => $im->image_url,
        ])->values()->all();

        if (!empty($variant->image)) {
            array_unshift($images, [
                'image_url' => CommonHelper::imageUrl($variant->image),
            ]);
        }
        return $images;
    }

    /**
     * Zone delivery info: the zone's branch name and minutes to deliver (quick
     * commerce). One zone has one branch, so this is the same for every product in
     * the zone. `time_to_deliver` = straight-line km from the branch to the customer
     * times the zone's travel_time_per_km; 0 when no branch coords / per-km time.
     * Returns ['branch_name' => ?string, 'time_to_deliver' => int].
     */
    public static function zoneDelivery($zone, $custLat, $custLng): array
    {
        $out = ['branch_name' => null, 'time_to_deliver' => 0, 'distance' => null, 'distance_unit' => 'km'];
        if (!$zone) {
            return $out;
        }
        $branch = Branch::where('status', 1)
            ->where('zone_id', $zone->id)
            ->first(['name', 'latitude', 'longitude', 'preparation_time']);
        if (!$branch) {
            return $out;
        }
        $out['branch_name'] = (string) $branch->name;

        $unit    = CommonHelper::normalizeDistanceUnit($zone->distance_unit ?? 'km');
        $out['distance_unit'] = $unit;

        if ($branch->latitude !== null && $branch->longitude !== null) {
            $km   = CommonHelper::straightLineDistanceKm($branch->latitude, $branch->longitude, $custLat, $custLng);
            $dist = CommonHelper::convertKmToUnit($km, $unit);
            if ($dist !== null) {
                $out['distance'] = round($dist, 2);
            }

            $perUnit = (float) ($zone->travel_time_per_km ?? 0);
            if ($perUnit > 0 && $dist !== null) {
                $out['time_to_deliver'] = (int) ceil($dist * $perUnit);
            }
        }
        // Gifting: the branch's preparation time is part of the promise (e.g. 60 min).
        $prep = (int) ($branch->preparation_time ?? 0);
        if ($prep > 0) {
            $out['time_to_deliver'] += $prep;
        }
        return $out;
    }

    /**
     * Human-readable delivery time from minutes.
     * $short=true  → "5 mins", "1 hr", "1 hr 30 mins"   (products)
     * $short=false → "5 minutes", "1 hour", "1 hour 30 minutes" (cart / home layout)
     * Returns '' for 0/negative.
     */
    public static function formatDeliveryTime(int $minutes, bool $short = true): string
    {
        if ($minutes <= 0) {
            return '';
        }
        // Under two hours reads better in minutes: "60 minutes", not "1 hour".
        if ($minutes < 120) {
            return $short
                ? $minutes . ' ' . ($minutes === 1 ? 'min' : 'mins')
                : $minutes . ' ' . ($minutes === 1 ? 'minute' : 'minutes');
        }
        $hours = intdiv($minutes, 60);
        $mins  = $minutes % 60;

        $parts = [];
        if ($hours > 0) {
            $parts[] = $short
                ? $hours . ' ' . ($hours === 1 ? 'hr'  : 'hrs')
                : $hours . ' ' . ($hours === 1 ? 'hour' : 'hours');
        }
        if ($mins > 0) {
            $parts[] = $short
                ? $mins . ' ' . ($mins === 1 ? 'min'  : 'mins')
                : $mins . ' ' . ($mins === 1 ? 'minute' : 'minutes');
        }
        return implode(' ', $parts);
    }

    private static array $notifyRequestedVariantIds = [];

    public static function setNotifyRequestedVariantIds(array $ids): void
    {
        self::$notifyRequestedVariantIds = array_map('intval', $ids);
    }

    /**
     * The `product_rating` setting, read once rather than once per card. Held for a
     * minute so a long-running worker still picks up a change.
     */
    private static function productRatingEnabled(): bool
    {
        static $value = null, $readAt = 0;
        if ($value === null || time() - $readAt > 60) {
            $value = (int) (Setting::get_value('product_rating') ?: 0) === 1;
            $readAt = time();
        }

        return $value;
    }

    public static function shapeCard(Product $p, array $favoriteIds, int $timeToDeliver = 0, ?string $branchName = null, ?array $currency = null, ?int $representativeVariantId = null): array
    {
        // Price is per-branch (PVSS). branchStocks is eager-loaded already scoped to the
        // zone's branch(s); copy that branch's pricing onto each variant (no branch → the
        // cheapest listed row, i.e. the "from" price) so all reads below are branch-priced.
        foreach ($p->variants as $vv) {
            ProductHelper::applyBranchPrice($vv);
        }

        $listedVariants = $p->variants->filter(function ($v) {
            return $v->branchStocks->where('is_listed', 1)->count() > 0;
        });

        $cheapest = $listedVariants
            ->sortBy(fn ($v) => $v->discounted_price > 0 ? (float) $v->discounted_price : (float) $v->price)
            ->first();

        // The representative variant (data shown outside `variants`) is the one
        // pinned by the caller (e.g. the variant that matched a filter), falling
        // back to the cheapest listed variant.
        $variant = $representativeVariantId !== null
            ? ($listedVariants->firstWhere('id', $representativeVariantId) ?: $cheapest)
            : $cheapest;

        $taxPct       = TaxService::rateForProduct((int) $p->id, ProductHelper::priceBranchId($variant));
        $inclusive    = (bool) ($variant->is_tax_inclusive ?? false);
        $priceRaw     = $variant ? (float) $variant->price : 0;
        $discRaw      = $variant ? (float) $variant->discounted_price : 0;
        $priceWithTax = TaxService::applyTax($priceRaw, $taxPct, $inclusive);
        $discWithTax  = $discRaw > 0 ? TaxService::applyTax($discRaw, $taxPct, $inclusive) : 0;
        $finalPrice   = $discWithTax > 0 ? $discWithTax : $priceWithTax;

        $discountPct = ($priceWithTax > 0 && $discWithTax > 0)
            ? (int) round((($priceWithTax - $discWithTax) / $priceWithTax) * 100)
            : 0;

        $productUnlimited = 0;
        $defaultStock = 0;
        $defaultInStock = false;
        $defaultIsMinAlert = false;
        if ($variant) {
            $listedStocks = $variant->branchStocks->where('is_listed', 1);
            $hasListedBranch = $listedStocks->count() > 0;
            $hasInStockBranch = $listedStocks->where('stock_status', 1)->count() > 0;
            $productUnlimited = self::unlimitedFromStocks($variant->branchStocks);
            $defaultStock = (int) $listedStocks->where('stock_status', 1)->sum('available');
            $defaultInStock = $hasListedBranch
                && ($productUnlimited === 1 || ($hasInStockBranch && $defaultStock > 0));
            $defaultMinAlert = (int) $listedStocks->sum('min_alert');
            $defaultIsMinAlert = $productUnlimited === 0
                && $hasListedBranch
                && $defaultStock > 0
                && $defaultStock <= $defaultMinAlert;
        }

        $representativeId = $variant ? $variant->id : null;
        $variantsPayload = $listedVariants
            ->sortBy(fn ($v) => $v->id === $representativeId ? 0 : 1)
            ->map(fn ($v) => self::shapeVariant($v, $taxPct, 0, null))
            ->values()->all();

        $price           = (float) CommonHelper::doubleNumber($priceWithTax);
        $discountedPrice = (float) CommonHelper::doubleNumber($finalPrice);

        // min_price is the lowest final price across all listed variants — kept
        // independent of the representative variant so pinning a non-cheapest
        // variant (e.g. a filter match) still shows the true "from" price.
        $minPrice = $listedVariants->isNotEmpty()
            ? (float) CommonHelper::doubleNumber($listedVariants->map(function ($v) use ($taxPct) {
                $vi = (bool) ($v->is_tax_inclusive ?? false);
                $pw = TaxService::applyTax((float) $v->price, $taxPct, $vi);
                $dw = (float) $v->discounted_price > 0 ? TaxService::applyTax((float) $v->discounted_price, $taxPct, $vi) : 0;
                return $dw > 0 ? $dw : $pw;
            })->min())
            : $price;

        return [
            'id'                 => (int) $p->id,
            'name'               => $variant ? (string) $variant->name : '',
            'product_name'       => (string) ($p->name ?? ''),
            'slug'               => (string) $p->slug,
            'images'             => $variant ? self::buildVariantImages($variant) : [],
            'short_description'  => (string) ($p->short_description ?? ''),
            'product_type'       => (int) ($p->product_type ?? 0),
            'is_food'            => (int) ($p->is_food ?? 0),
            'has_addons'         => $p->relationLoaded('addonGroups')
                ? $p->addonGroups->isNotEmpty()
                : (isset($p->addon_groups_count)
                    ? (bool) $p->addon_groups_count
                    : AddonHelper::productHasAddons((int) $p->id)),
            'is_prescription_required' => (int) ($p->is_prescription_required ?? 0),
            'is_personalizable'  => (int) ($p->is_personalizable ?? 0),
            'occasions'          => json_decode((string) ($p->occasions ?? '[]'), true) ?: [],
            'relationships'      => json_decode((string) ($p->relationships ?? '[]'), true) ?: [],
            'delivery_types'     => json_decode((string) ($p->delivery_types ?? '[]'), true) ?: [],
            'sales_channel'      => $p->sales_channel,
            'cod_allowed'        => (int) ($p->cod_allowed ?? 0),
            'category_id'        => (int) $p->category_id,
            'category_name'      => $p->category ? (string) $p->category->name : null,
            'brand_id'           => $p->brand_id ? (int) $p->brand_id : null,
            'brand_name'         => $p->brand ? (string) $p->brand->name : null,
            'is_unlimited_stock' => $productUnlimited,
            'total_allowed_quantity' => (int) ($p->total_allowed_quantity ?? 0),
            'in_stock'           => $defaultInStock,
            'is_min_alert'       => $defaultIsMinAlert,
            'is_favorite'        => in_array((int) $p->id, array_map('intval', $favoriteIds), true),
            'product_rating'     => self::productRatingEnabled(),
            'rating'             => round((float) $p->ratings->avg('rate'), 1),
            'rating_count'       => $p->ratings->count(),
            'variants_count'     => $listedVariants->count(),
            'min_price'          => $minPrice,
            'discount_percent'   => $discountPct,
            'variant_id'         => $variant ? (int) $variant->id : null,
            'sku'                => $variant ? $variant->sku : null,
            'price'              => $price,
            'discounted_price'   => $discountedPrice,
            'stock'              => $defaultStock,
            'branch_name'         => $branchName,
            'time_to_deliver'    => self::formatDeliveryTime($timeToDeliver),
            'currency'           => $currency['currency'] ?? null,
            'currency_code'      => $currency['currency_code'] ?? null,
            'decimal_point'      => $currency['decimal_point'] ?? null,
            'variants'           => $variantsPayload,
        ];
    }

    /**
     * Cart-card shape: identical schema to shapeCard(), but driven by the cart line's
     * specific variant instead of the cheapest one. The `variants` array holds ONLY
     * that cart variant, and the variant carries a `quantity` (the cart qty).
     *
     * Eager loads on $p: same as shapeCard, but `variants.branchStocks` should be
     * scoped to the cart line's branch (so stock reflects that branch).
     */
    /**
     * $addonOptionIds are the addon options chosen on this cart line. They are priced at
     * $branchId and folded into the unit price, never shown beside it, so the line's
     * price * qty still equals what the customer is charged.
     */
    public static function shapeCartItem(Product $p, int $variantId, int $qty, array $favoriteIds, int $timeToDeliver = 0, ?string $branchName = null, ?array $currency = null, ?int $branchId = null, array $addonOptionIds = []): array
    {
        $addons = AddonHelper::describe($addonOptionIds, $branchId);
        $addonUnit = (float) $addons['unit'];
        $variant = $p->variants->firstWhere('id', $variantId);
        // Price is per-branch (PVSS): price by the cart line's exact fulfilling branch.
        if ($variant) {
            ProductHelper::applyBranchPrice($variant, $branchId);
        }

        $taxPct       = TaxService::rateForProduct((int) $p->id, ProductHelper::priceBranchId($variant, $branchId));
        $inclusive    = (bool) ($variant->is_tax_inclusive ?? false);

        $priceRaw     = $variant ? (float) $variant->price + $addonUnit : 0;
        $priceWithTax = TaxService::applyTax($priceRaw, $taxPct, $inclusive);
        // Slab-aware effective unit price for the cart quantity, addons included.
        $effUnit      = $variant ? ProductHelper::lineUnitPrice($variant, $qty > 0 ? $qty : 1, $addonUnit) : 0;
        $finalPrice   = TaxService::applyTax($effUnit, $taxPct, $inclusive);

        $discountPct = ($priceWithTax > 0 && $finalPrice > 0 && $finalPrice < $priceWithTax)
            ? (int) round((($priceWithTax - $finalPrice) / $priceWithTax) * 100)
            : 0;

        $productUnlimited = 0;
        $stock = 0;
        $inStock = false;
        $isMinAlert = false;
        if ($variant) {
            $scopedStocks = $branchId !== null
                ? $variant->branchStocks->where('branch_id', $branchId)
                : $variant->branchStocks;
            $listedStocks = $scopedStocks->where('is_listed', 1);
            $hasListedBranch = $listedStocks->count() > 0;
            $productUnlimited = self::unlimitedFromStocks($scopedStocks);

            $stock = (int) $listedStocks->where('stock_status', 1)->sum('available');

            $ownReserved = $branchId !== null ? max(0, (int) $qty) : 0;
            $stockForCart = (int) $listedStocks->sum('available') + $ownReserved;
            $inStock = $hasListedBranch && ($productUnlimited === 1 || $stockForCart > 0);

            $minAlert = (int) $listedStocks->sum('min_alert');
            $isMinAlert = $productUnlimited === 0 && $hasListedBranch && $stock > 0 && $stock <= $minAlert;
        }

        // Upsell message: nearest higher-qty slab that beats the current unit price.
        // Only shown when the branch can actually fulfil the extra units — `available`
        // already excludes what's reserved, so we need available >= the units to add.
        // Unlimited-stock products always qualify. Empty string otherwise.
        $slabDiscountMessage = '';
        if ($variant) {
            $hint = ProductHelper::nextSlabHint($variant, $qty > 0 ? $qty : 1, $taxPct, $inclusive);
            $canAddMore = $productUnlimited === 1 || ($hint && $stock >= (int) $hint['add_qty']);
            if ($hint && $canAddMore) {
                $cur = $currency['currency'] ?? '';
                $slabDiscountMessage = str_replace(
                    [':qty', ':price'],
                    [$hint['add_qty'], $cur . $hint['price']],
                    __('slab_upsell_message')
                );
            }
        }

        // Only the cart variant is returned, with its quantity.
        $variantPayload = [];
        if ($variant) {
            $variantPayload[] = self::shapeVariant($variant, $taxPct, (int) $qty, $branchId);
        }

        $price           = (float) CommonHelper::doubleNumber($priceWithTax);
        $discountedPrice = (float) CommonHelper::doubleNumber($finalPrice);

        return [
            'id'                 => (int) $p->id,
            'name'               => $variant ? (string) $variant->name : '',
            'product_name'       => (string) ($p->name ?? ''),
            'slug'               => (string) $p->slug,
            'images'             => $variant ? self::buildVariantImages($variant) : [],
            'short_description'  => (string) ($p->short_description ?? ''),
            'product_type'       => (int) ($p->product_type ?? 0),
            'is_food'            => (int) ($p->is_food ?? 0),
            'has_addons'         => $p->relationLoaded('addonGroups')
                ? $p->addonGroups->isNotEmpty()
                : (isset($p->addon_groups_count)
                    ? (bool) $p->addon_groups_count
                    : AddonHelper::productHasAddons((int) $p->id)),
            'is_prescription_required' => (int) ($p->is_prescription_required ?? 0),
            'is_personalizable'  => (int) ($p->is_personalizable ?? 0),
            'occasions'          => json_decode((string) ($p->occasions ?? '[]'), true) ?: [],
            'relationships'      => json_decode((string) ($p->relationships ?? '[]'), true) ?: [],
            'delivery_types'     => json_decode((string) ($p->delivery_types ?? '[]'), true) ?: [],
            'sales_channel'      => $p->sales_channel,
            'cod_allowed'        => (int) ($p->cod_allowed ?? 0),
            'category_id'        => (int) $p->category_id,
            'category_name'      => $p->category ? (string) $p->category->name : null,
            'brand_id'           => $p->brand_id ? (int) $p->brand_id : null,
            'brand_name'         => $p->brand ? (string) $p->brand->name : null,
            'is_unlimited_stock' => $productUnlimited,
            'total_allowed_quantity' => (int) ($p->total_allowed_quantity ?? 0),
            'in_stock'           => $inStock,
            'is_min_alert'       => $isMinAlert,
            'is_favorite'        => in_array((int) $p->id, array_map('intval', $favoriteIds), true),
            // Display only: the money is already inside price / discounted_price.
            // Pictures are attached here rather than inside describe(), whose lines are
            // what order history branches.
            'addons'             => AddonHelper::withImages($addons['lines']),
            'addon_total'        => (float) CommonHelper::doubleNumber($addonUnit * max(1, $qty)),

            'has_unavailable_addons' => empty($addons['unavailable']) ? 0 : 1,
            'rating'             => round((float) $p->ratings->avg('rate'), 1),
            'rating_count'       => $p->ratings->count(),
            'variants_count'     => 1,
            'min_price'          => $price,
            'discount_percent'   => $discountPct,
            'variant_id'         => $variant ? (int) $variant->id : null,
            'sku'                => $variant ? $variant->sku : null,
            'price'              => $price,
            'discounted_price'   => $discountedPrice,
            'slab_discount_message' => $slabDiscountMessage,
            'stock'              => $stock,
            'branch_name'         => $branchName,
            'time_to_deliver'    => self::formatDeliveryTime($timeToDeliver),
            'currency'           => $currency['currency'] ?? null,
            'currency_code'      => $currency['currency_code'] ?? null,
            'decimal_point'      => $currency['decimal_point'] ?? null,
            'variants'           => $variantPayload,
        ];
    }

    private static function unlimitedFromStocks($branchStocks): int
    {
        return $branchStocks->where('is_listed', 1)->where('is_unlimited_stock', 1)->count() > 0 ? 1 : 0;
    }

    /**
     * Per-variant shape for the card payload: main image + attribute summary
     * ("Red / Large") + per-variant prices (tax-applied).
     */
    private static function shapeVariant(ProductVariant $v, float $taxPct, int $qty = 0, ?int $branchId = null): array
    {
        // Ensure branch pricing is applied (idempotent; callers pre-apply for the card).
        // $branchId pins a specific branch (cart line); null → cheapest listed (card "from").
        ProductHelper::applyBranchPrice($v, $branchId);
        $taxInclusive = (bool) ($v->is_tax_inclusive ?? false);
        $priceWithTax = TaxService::applyTax((float) $v->price, $taxPct, $taxInclusive);
        // Slab-aware effective unit price for the requested quantity (qty 0 → 1 for
        // display). Slab match wins over discounted_price / base price.
        $qtyForPrice = $qty > 0 ? $qty : 1;
        $effUnit     = ProductHelper::slabUnitPrice($v, $qtyForPrice);
        $finalPrice  = TaxService::applyTax($effUnit, $taxPct, $taxInclusive);

        $variantAttributes = $v->attributeValues->map(fn ($av) => [
            'name'  => $av->attribute ? (string) $av->attribute->name : '',
            'value' => $av->attributeValue ? (string) $av->attributeValue->value : '',
        ])->filter(fn ($a) => $a['name'] !== '' || $a['value'] !== '')->values()->all();

        $attributesText = implode(' / ', array_values(array_filter(
            array_column($variantAttributes, 'value')
        )));

        $scopedStocks = $branchId !== null
            ? $v->branchStocks->where('branch_id', $branchId)
            : $v->branchStocks;
        $listedStocks = $scopedStocks->where('is_listed', 1);
        $hasListedBranch = $listedStocks->count() > 0;
        $hasInStockBranch = $listedStocks->where('stock_status', 1)->count() > 0;
        $stock = (int) $listedStocks->where('stock_status', 1)->sum('available');
        $unlimited = self::unlimitedFromStocks($scopedStocks) === 1;
        $inStock = $hasListedBranch && ($unlimited || ($hasInStockBranch && $stock > 0));

        return [
            'id'                 => (int) $v->id,
            'name'               => (string) $v->name,
            'sku'                => $v->sku,
            'image'              => CommonHelper::imageUrl($v->image),
            'attributes_text'    => $attributesText,
            'variant_attributes' => $variantAttributes,
            'price'              => (float) CommonHelper::doubleNumber($priceWithTax),
            'discounted_price'   => (float) CommonHelper::doubleNumber($finalPrice),
            'stock'              => $stock,
            'in_stock'           => $inStock,
            'is_notify_requested' => in_array((int) $v->id, self::$notifyRequestedVariantIds, true) ? 1 : 0,
            // 0 in product listing; the actual cart quantity in cart responses.
            'quantity'           => $qty,
        ];
    }
}
