<?php

namespace App\Services;

use App\Models\Region;
use Illuminate\Support\Facades\DB;

/**
 * Jurisdiction-driven tax engine.
 *
 * There is deliberately NO country-specific branch anywhere in this class. India's
 * CGST/SGST/IGST behaviour comes entirely from seeded `tax_rules` rows: two rules
 * over the same category, one flagged `intra` with two components and one flagged
 * `inter` with one. Swap the rows and the same code produces UAE VAT or US sales tax.
 *
 * Resolution, in order:
 *   1. branch context   — which country/region is actually selling (from the BRANCH)
 *   2. tax category     — what the product is, in that jurisdiction
 *   3. rule             — what that jurisdiction charges for that category, on that date
 *   4. components       — the individual heads the rule breaks into
 *
 * Everything is memoised per request: cart and product-list code calls this inside
 * loops, and without the cache a 50-line cart would issue 50+ identical queries.
 */
class TaxService
{
    private static array $branchCtxCache = [];
    private static array $rulesByCountry = [];

    /** Wipe the per-request memo. Only needed in tests and long-running workers. */
    public static function flush(): void
    {
        self::$branchCtxCache = [];
        self::$rulesByCountry = [];
        self::$regionCache = [];
        self::$countryCodeCache = [];
        self::$ownCategoryCache = [];
    }

    // ------------------------------------------------------------------ branch

    /**
     * Who is selling, taxwise. The branch is the branch — its zone gives both the
     * country and the region, since one zone serves exactly one branch.
     *
     * Returns: branch_id, country_id, country_code, region_id, region_name,
     *          region_tax_code, tax_number (the branch's GSTIN/VAT, if registered).
     */
    public static function branchContext(?int $branchId): array
    {
        $key = (string) ($branchId ?? 0);
        if (isset(self::$branchCtxCache[$key])) {
            return self::$branchCtxCache[$key];
        }

        $empty = [
            'branch_id' => $branchId, 'country_id' => null, 'country_code' => null,
            'region_id' => null, 'region_name' => null, 'region_tax_code' => null,
            'tax_number' => null, 'registration_type' => null,
        ];
        if (!$branchId) {
            return self::$branchCtxCache[$key] = $empty;
        }

        $row = DB::table('branches')
            ->leftJoin('zones', 'zones.id', '=', 'branches.zone_id')
            ->where('branches.id', $branchId)
            ->first([
                'branches.id as branch_id',
                'branches.tax_number',
                'branches.tax_registration_type',
                'zones.country_id',
                'zones.region_id',
            ]);
        if (!$row) {
            return self::$branchCtxCache[$key] = $empty;
        }

        // One zone serves one branch, so the zone's region IS the branch's region.
        $region = $row->region_id ? self::region((int) $row->region_id) : null;

        return self::$branchCtxCache[$key] = [
            'branch_id'          => (int) $branchId,
            'country_id'        => $row->country_id ? (int) $row->country_id : null,
            'country_code'      => $row->country_id ? self::countryCode((int) $row->country_id) : null,
            'region_id'         => $row->region_id ? (int) $row->region_id : null,
            'region_name'       => $region->name ?? null,
            'region_tax_code'   => $region->tax_code ?? null,
            'tax_number'        => $row->tax_number ?: null,
            'registration_type' => $row->tax_registration_type ?: null,
        ];
    }

    /** intra = same region, inter = different region, null = buyer region unknown. */
    public static function supplyType(?int $branchRegionId, ?int $buyerRegionId): ?string
    {
        if (!$branchRegionId || !$buyerRegionId) {
            return null;
        }
        return $branchRegionId === $buyerRegionId ? 'intra' : 'inter';
    }

    // ---------------------------------------------------------------- category

    /**
     * What the product IS, for tax purposes.
     *
     * One classification per product, everywhere. The RATE still differs per country —
     * that comes from the jurisdiction's rule, not from re-classifying the product — so
     * the same category is correctly 18% from a Mumbai branch and 5% VAT from a Dubai one.
     */
    public static function categoryFor(int $productId, ?int $branchId = null, ?int $countryId = null): ?int
    {
        return self::ownCategory($productId);
    }

    // -------------------------------------------------------------------- rule

    /**
     * The rule that applies, or null when the jurisdiction charges nothing.
     *
     * Every rule names a tax category, so anything without one (a product with no tax
     * category, an untagged charge, a legacy catch-all rule) is simply not taxed — there
     * is no fallback rate to fall into.
     *
     * The remaining candidates are scored rather than filtered, so a rule that leaves the
     * region open still applies when no region-specific rule exists:
     *   region exact  +4
     *   place_of_supply exact +3, 'any' +2, 'intra' as the unknown-buyer default +1
     * Two rules that score the same are equally specific, so the newest one wins — the
     * later edit is the admin's current intent.
     */
    public static function resolveRule(
        ?int $categoryId,
        ?int $countryId,
        ?int $branchRegionId = null,
        ?int $buyerRegionId = null
    ): ?array {
        if (!$countryId || !$categoryId) {
            return null;
        }
        $supplyType = self::supplyType($branchRegionId, $buyerRegionId);

        $best = null;
        $bestScore = -1;
        foreach (self::rulesFor($countryId) as $rule) {
            if ($rule->tax_category_id === null || (int) $rule->tax_category_id !== (int) $categoryId) {
                continue;
            }
            // A rule's region is the BRANCH's region — every jurisdiction served here is
            // origin-based, so the branch's location is what narrows a rule.
            if ($rule->region_id !== null && (int) $rule->region_id !== (int) $branchRegionId) {
                continue;
            }
            $posScore = match (true) {
                $supplyType !== null && $rule->place_of_supply === $supplyType => 3,
                $rule->place_of_supply === 'any'                              => 2,
                // Buyer region not known yet (cart before checkout). Quote the intra
                // rule: a jurisdiction's intra and inter totals are validated equal, so
                // the figure shown never moves once the address arrives.
                $supplyType === null && $rule->place_of_supply === 'intra'     => 1,
                default                                                       => -1,
            };
            if ($posScore < 0) {
                continue;
            }

            $score = ($rule->region_id !== null ? 4 : 0) + $posScore;

            if ($score > $bestScore || ($score === $bestScore && $rule->id > $best->id)) {
                $best = $rule;
                $bestScore = $score;
            }
        }

        if (!$best) {
            return null;
        }

        return [
            'rule_id'     => (int) $best->id,
            'supply_type' => $supplyType,
            'components'  => $best->components,
            'total_rate'  => $best->total_rate,
        ];
    }


    /** Combined percentage for a product at a branch. Drop-in for the old scalar rate. */
    public static function rateForProduct(int $productId, ?int $branchId, ?int $buyerRegionId = null): float
    {
        $resolved = self::forProduct($productId, $branchId, $buyerRegionId);

        return (float) ($resolved['total_rate'] ?? 0);
    }


    /**
     * The customer-facing price for a base amount: unchanged when the stored price is
     * already tax-inclusive, grossed up when it is not. Inclusivity is a property of the
     * PRICE (product_variant_branch_stocks.is_tax_inclusive), not of the tax rule — one
     * branch can quote inclusive while another quotes exclusive for the same product.
     */
    public static function applyTax(float $base, float $rate, bool $inclusive = false): float
    {
        if ($base == 0.0 || $rate <= 0) {
            return round($base, 2);
        }
        return $inclusive ? round($base, 2) : round($base * (1 + $rate / 100), 2);
    }

    /** branchContext + categoryFor + resolveRule in one call. */
    public static function forProduct(int $productId, ?int $branchId, ?int $buyerRegionId = null): ?array
    {
        $branch = self::branchContext($branchId);
        $categoryId = self::categoryFor($productId, $branchId, $branch['country_id']);
        $resolved = self::resolveRule($categoryId, $branch['country_id'], $branch['region_id'], $buyerRegionId);
        if ($resolved) {
            $resolved['branch'] = $branch;
            $resolved['tax_category_id'] = $categoryId;
        }
        return $resolved;
    }

    // --------------------------------------------------------------- arithmetic

    /**
     * Split a taxable base across the rule's components.
     *
     * The combined tax is rounded ONCE and the last component absorbs the remainder.
     * Rounding each component independently drifts a paisa against the combined
     * figure, which would make an India cart total visibly change the moment the
     * customer picks an address (CGST 9 + SGST 9 must land on exactly IGST 18).
     *
     * @return array{taxable: float, tax: float, gross: float, rate: float, lines: array}
     */
    public static function calculate(float $base, array $components, bool $inclusive = false): array
    {
        $rate = round(array_sum(array_map(fn ($c) => (float) $c->rate, $components)), 3);

        if ($rate <= 0 || empty($components)) {
            $taxable = round($base, 2);
            return ['taxable' => $taxable, 'tax' => 0.0, 'gross' => $taxable, 'rate' => 0.0, 'lines' => []];
        }

        if ($inclusive) {
            $taxable = round($base * 100 / (100 + $rate), 2);
            $tax     = round($base - $taxable, 2);
            $gross   = round($base, 2);
        } else {
            $taxable = round($base, 2);
            $tax     = round($taxable * $rate / 100, 2);
            $gross   = round($taxable + $tax, 2);
        }

        $lines = [];
        $allocated = 0.0;
        $last = count($components) - 1;
        foreach (array_values($components) as $i => $component) {
            $amount = $i === $last
                ? round($tax - $allocated, 2)
                : round($taxable * (float) $component->rate / 100, 2);
            $allocated = round($allocated + $amount, 2);
            $lines[] = [
                'name'          => $component->name,
                'rate'          => (float) $component->rate,
                'taxable_value' => $taxable,
                'amount'        => $amount,
            ];
        }

        return ['taxable' => $taxable, 'tax' => $tax, 'gross' => $gross, 'rate' => $rate, 'lines' => $lines];
    }

    /**
     * Tax on a delivery / surge / additional charge.
     *
     * $taxIncluded says whether the configured amount already contains the tax. When
     * it does the tax is carved OUT of it, so the customer-facing charge is unchanged;
     * when it doesn't the tax is added ON TOP and the gross grows.
     */
    public static function calculateCharge(
        float $amount,
        ?int $categoryId,
        bool $taxIncluded,
        array $branchContext,
        ?int $buyerRegionId = null
    ): array {
        $none = ['taxable' => round($amount, 2), 'tax' => 0.0, 'gross' => round($amount, 2), 'rate' => 0.0, 'lines' => []];
        if ($amount <= 0) {
            return $none;
        }
        $resolved = self::resolveRule($categoryId, $branchContext['country_id'] ?? null, $branchContext['region_id'] ?? null, $buyerRegionId);
        if (!$resolved) {
            return $none;
        }
        $result = self::calculate($amount, $resolved['components'], $taxIncluded);
        $result['rule_id'] = $resolved['rule_id'];
        return $result;
    }

    // ------------------------------------------------------------------ priming

    /**
     * Prime the caches for a whole cart in one round trip. Without this, resolving
     * tax inside a per-line loop re-queries rules, overrides and branch context.
     */
    public static function warmFor(array $productIds, array $branchIds): void
    {
        foreach (array_unique(array_filter($branchIds)) as $branchId) {
            self::branchContext((int) $branchId);
        }
        foreach (array_unique(array_filter(array_map(fn ($c) => $c['country_id'] ?? null, self::$branchCtxCache))) as $countryId) {
            self::rulesFor((int) $countryId);
        }

        $wanted = array_unique(array_filter(array_map('intval', $productIds)));

        $missingCategory = array_values(array_diff($wanted, array_keys(self::$ownCategoryCache)));
        if (!empty($missingCategory)) {
            $categories = DB::table('products')->whereIn('id', $missingCategory)
                ->pluck('tax_category_id', 'id');
            foreach ($missingCategory as $productId) {
                $value = $categories[$productId] ?? null;
                self::$ownCategoryCache[$productId] = $value ? (int) $value : null;
            }
        }
    }

    // ------------------------------------------------------------------ private

    /** All active rules for a country, components attached, loaded once per request. */
    private static function rulesFor(int $countryId): array
    {
        if (isset(self::$rulesByCountry[$countryId])) {
            return self::$rulesByCountry[$countryId];
        }

        /* A rule whose CATEGORY is deactivated must not fire — deactivating a category
           is how an admin retires it, and it would be surprising for the retired one to
           keep taxing. */
        $rules = DB::table('tax_rules')
            ->leftJoin('tax_categories', 'tax_categories.id', '=', 'tax_rules.tax_category_id')
            ->where('tax_rules.country_id', $countryId)
            ->where('tax_rules.status', 1)
            ->where(function ($q) {
                $q->whereNull('tax_rules.tax_category_id')
                  ->orWhere('tax_categories.status', 1);
            })
            ->orderByDesc('tax_rules.id')
            ->get(['tax_rules.*'])->all();

        if (!empty($rules)) {
            $components = DB::table('tax_rule_components')
                ->whereIn('tax_rule_id', array_map(fn ($r) => $r->id, $rules))
                ->orderBy('sort_order')->orderBy('id')
                ->get()->groupBy('tax_rule_id');
            foreach ($rules as $rule) {
                $rule->components = ($components[$rule->id] ?? collect())->values()->all();
                $rule->total_rate = round(array_sum(array_map(fn ($c) => (float) $c->rate, $rule->components)), 3);
            }

            $rules = array_values(array_filter($rules, fn ($rule) => !empty($rule->components)));
        }

        return self::$rulesByCountry[$countryId] = $rules;
    }

    private static array $ownCategoryCache = [];

    /** products.tax_category_id, batched by warmFor() so cart loops don't go N+1. */
    private static function ownCategory(int $productId): ?int
    {
        if (array_key_exists($productId, self::$ownCategoryCache)) {
            return self::$ownCategoryCache[$productId];
        }
        $own = DB::table('products')->where('id', $productId)->value('tax_category_id');
        return self::$ownCategoryCache[$productId] = $own ? (int) $own : null;
    }

    private static array $regionCache = [];

    private static function region(int $regionId): ?object
    {
        if (array_key_exists($regionId, self::$regionCache)) {
            return self::$regionCache[$regionId];
        }
        return self::$regionCache[$regionId] = DB::table('regions')->where('id', $regionId)
            ->first(['id', 'name', 'code', 'tax_code', 'type', 'country_id']);
    }

    private static array $countryCodeCache = [];

    private static function countryCode(int $countryId): ?string
    {
        if (array_key_exists($countryId, self::$countryCodeCache)) {
            return self::$countryCodeCache[$countryId];
        }
        $code = DB::table('countries')->where('id', $countryId)->value('code');
        return self::$countryCodeCache[$countryId] = $code ? strtoupper((string) $code) : null;
    }

    /** Human label for the invoice: "27-Maharashtra", or just the name where there is no code. */
    public static function placeOfSupplyLabel(?int $regionId): ?string
    {
        if (!$regionId) {
            return null;
        }
        $region = self::region($regionId);
        if (!$region) {
            return null;
        }
        return $region->tax_code ? $region->tax_code . '-' . $region->name : $region->name;
    }
}
