<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\TaxRule;
use App\Services\TaxService;
use App\Models\TaxRuleComponent;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * Tax rules: WHAT a jurisdiction charges for a tax category.
 *
 * A rule has no rate of its own — it has COMPONENTS, which are additive and all apply
 * to the same base. That is the whole reason India needs no special-casing: one rule
 * flagged `intra` carrying CGST 9 + SGST 9, another flagged `inter` carrying IGST 18.
 *
 * The one rule that must be enforced is that the intra and inter variants of the same
 * category TOTAL THE SAME. The cart quotes tax before the customer picks an address;
 * if those two totals differed, the order total would visibly jump at checkout.
 */
class TaxRuleApiController extends Controller
{
    public function index(Request $request)
    {
        $query = TaxRule::with(['components', 'country:id,name,code', 'region:id,name,code,tax_code', 'taxCategory:id,name,code']);

        foreach (['country_id', 'region_id', 'tax_category_id', 'status'] as $filter) {
            if ($request->filled($filter)) {
                $query->where($filter, (int) $request->input($filter));
            }
        }
        if ($request->filled('place_of_supply')) {
            $query->where('place_of_supply', $request->input('place_of_supply'));
        }
        if ($request->filled('search')) {
            $search = trim((string) $request->input('search'));
            $query->whereHas('taxCategory', fn ($q) => $q->where('name', 'like', "%{$search}%"));
        }

        $total = (clone $query)->count();

        $limit = (int) $request->get('limit', 0);
        if ($limit > 0) {
            $query->skip((int) $request->get('offset', 0))->take($limit);
        }

        $rules = $query->orderBy('country_id')->orderByDesc('id')->get();
        foreach ($rules as $rule) {
            $rule->total_rate = $rule->totalRate();
        }

        return CommonHelper::responseWithData($rules, $total);
    }

    /**
     * The tax rate each BRANCH would charge for a given tax category.
     *
     * The admin product form shows a customer price per branch, and those branches can sit
     * in different countries — so a single rate would be wrong for all but one of them.
     * Resolved through the same engine checkout uses, so the preview and the real charge
     * cannot disagree.
     */
    public function branchRates(Request $request)
    {
        $categoryId = $request->filled('tax_category_id') ? (int) $request->input('tax_category_id') : null;

        $branches = DB::table('branches')
            ->leftJoin('zones', 'zones.id', '=', 'branches.zone_id')
            ->leftJoin('countries', 'countries.id', '=', 'zones.country_id')
            ->whereNull('branches.deleted_at')
            ->get(['branches.id', 'branches.name', 'countries.name as country_name']);

        $out = [];
        $variesByCountry = [];
        foreach ($branches as $branch) {
            $branch = TaxService::branchContext((int) $branch->id);
            // Buyer region left null: an admin preview has no customer, and the total is
            // identical either way — an intra rule and an inter rule sum to the same rate.
            $resolved = TaxService::resolveRule($categoryId, $branch['country_id'], $branch['region_id'], null);

            $countryId = $branch['country_id'];
            if ($countryId && !array_key_exists($countryId, $variesByCountry)) {
                $variesByCountry[$countryId] = $this->rateDependsOnCustomerRegion((int) $countryId, $categoryId);
            }

            $out[] = [
                'branch_id'     => (int) $branch->id,
                'branch_name'   => $branch->name,
                'country_name' => $branch->country_name,
                'region_name'  => $branch['region_name'],
                'rate'         => (float) ($resolved['total_rate'] ?? 0),
                'configured'   => $resolved !== null,
                'region_wise'  => $countryId ? (bool) $variesByCountry[$countryId] : false,
            ];
        }

        return CommonHelper::responseWithData($out, count($out));
    }

    /**
     * Does this country's tax for a category depend on where the CUSTOMER is? True when
     * its rules split intra/inter, or when any of them is scoped to a region — in both
     * cases the rule that fires is chosen once the delivery address is known.
     */
    private function rateDependsOnCustomerRegion(int $countryId, ?int $categoryId): bool
    {
        $rules = DB::table('tax_rules')
            ->where('country_id', $countryId)
            ->where('status', 1)
            ->when($categoryId, fn ($q) => $q->where('tax_category_id', $categoryId))
            ->whereExists(fn ($q) => $q->select(DB::raw(1))->from('tax_rule_components')
                ->whereColumn('tax_rule_components.tax_rule_id', 'tax_rules.id'))
            ->get(['region_id', 'place_of_supply']);

        if ($rules->isEmpty()) {
            return false;
        }

        return $rules->contains(fn ($r) => $r->region_id !== null)
            || $rules->pluck('place_of_supply')->unique()->diff(['any'])->count() > 1;
    }

    /**
     * Where tax is NOT configured but goods are actually being sold.
     *
     * An unresolved rule is not an error — the engine correctly charges nothing when a
     * jurisdiction has no rule. That is right for a tax-free country and badly wrong for
     * one you simply forgot to configure, and the two look identical on an invoice. This
     * only reports countries that have an active branch, so it stays silent about the 200
     * countries in the list nobody sells from.
     */
    public function coverage()
    {
        $categories = DB::table('tax_categories')->where('status', 1)->get(['id', 'name']);
        if ($categories->isEmpty()) {
            return CommonHelper::responseWithData([]);
        }

        $sellingCountries = DB::table('branches')
            ->join('zones', 'zones.id', '=', 'branches.zone_id')
            ->join('countries', 'countries.id', '=', 'zones.country_id')
            ->whereNull('branches.deleted_at')
            ->where('branches.status', 1)
            ->distinct()
            ->get(['countries.id', 'countries.name']);

        $gaps = [];
        foreach ($sellingCountries as $country) {
            $missing = [];
            foreach ($categories as $category) {
                $covered = DB::table('tax_rules')
                    ->where('country_id', $country->id)->where('status', 1)
                    ->where('tax_category_id', $category->id)
                    ->whereExists(fn ($q) => $q->select(DB::raw(1))->from('tax_rule_components')
                        ->whereColumn('tax_rule_components.tax_rule_id', 'tax_rules.id'))
                    ->exists();
                if (!$covered) {
                    $missing[] = $category->name;
                }
            }
            if ($missing) {
                $gaps[] = [
                    'country_id'   => (int) $country->id,
                    'country_name' => $country->name,
                    'categories'   => $missing,
                    'product_count' => DB::table('products')
                        ->whereIn('tax_category_id', $categories->whereIn('name', $missing)->pluck('id'))
                        ->whereNull('deleted_at')->count(),
                ];
            }
        }

        return CommonHelper::responseWithData($gaps, count($gaps));
    }

    public function save(Request $request)
    {
        $components = $this->components($request);

        $validator = Validator::make(
            array_merge($request->all(), ['components' => $components]),
            [
                'country_id'        => 'required|exists:countries,id',
                'region_id'         => 'nullable|exists:regions,id',
                'tax_category_id'   => 'required|exists:tax_categories,id',
                'place_of_supply'   => 'required|in:any,intra,inter',
                'components'        => 'required|array|min:1',
                'components.*.name' => 'required|string|max:64',
                'components.*.rate' => 'required|numeric|min:0|max:100',
            ]
        );
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $rule = $request->filled('id') ? TaxRule::find((int) $request->id) : new TaxRule();
        if ($request->filled('id') && !$rule) {
            return CommonHelper::responseError('tax_rule_not_found');
        }

        $totalRate = round(array_sum(array_map(fn ($c) => (float) $c['rate'], $components)), 3);

        $conflict = $this->supplyTotalConflict($request, $totalRate, $rule->exists ? (int) $rule->id : null);
        if ($conflict !== null) {
            return CommonHelper::responseError($conflict);
        }

        DB::transaction(function () use ($request, $rule, $components) {
            $rule->country_id = (int) $request->country_id;
            $rule->region_id = $request->filled('region_id') ? (int) $request->region_id : null;
            $rule->tax_category_id = (int) $request->tax_category_id;
            $rule->place_of_supply = $request->place_of_supply;
            $rule->status = $request->has('status') ? (int) $request->status : ($rule->status ?? 1);
            $rule->save();

            TaxRuleComponent::where('tax_rule_id', $rule->id)->delete();
            foreach (array_values($components) as $i => $component) {
                TaxRuleComponent::create([
                    'tax_rule_id' => $rule->id,
                    'name'        => trim((string) $component['name']),
                    'rate'        => round((float) $component['rate'], 3),
                    'sort_order'  => $i,
                ]);
            }
        });

        return CommonHelper::responseSuccessWithData('tax_rule_saved_successfully', $rule->fresh('components'));
    }

    /**
     * Rules are safe to delete: orders keep their own frozen copy of every rate they
     * were charged, so removing a rule can never rewrite an issued invoice.
     */
    public function delete(Request $request)
    {
        $rule = TaxRule::find((int) $request->input('id'));
        if (!$rule) {
            return CommonHelper::responseError('tax_rule_not_found');
        }
        TaxRuleComponent::where('tax_rule_id', $rule->id)->delete();
        $rule->delete();

        return CommonHelper::responseSuccess('tax_rule_deleted_successfully');
    }

    /** Accepts components as a JSON string (FormData) or a real array. */
    private function components(Request $request): array
    {
        $components = $request->input('components', []);
        if (is_string($components)) {
            $components = json_decode($components, true) ?: [];
        }
        return is_array($components) ? array_values(array_filter($components, 'is_array')) : [];
    }

    /**
     * The intra/inter equality check.
     *
     * Components can't structurally guarantee CGST + SGST == IGST, so it is enforced
     * here instead: saving an `intra` rule whose total differs from the matching
     * `inter` rule (same country, region and category) is refused.
     * `any` rules are exempt — a jurisdiction using `any` has no split to reconcile.
     */
    private function supplyTotalConflict(Request $request, float $totalRate, ?int $ignoreId): ?string
    {
        $placeOfSupply = $request->place_of_supply;
        if ($placeOfSupply === 'any') {
            return null;
        }
        $opposite = $placeOfSupply === 'intra' ? 'inter' : 'intra';

        $siblings = TaxRule::with('components')
            ->where('country_id', (int) $request->country_id)
            ->where('place_of_supply', $opposite)
            ->where('status', 1)
            ->when($ignoreId, fn ($q) => $q->where('id', '!=', $ignoreId))
            ->get()
            ->filter(function ($sibling) use ($request) {
                return (int) $sibling->region_id === (int) $request->input('region_id')
                    && (int) $sibling->tax_category_id === (int) $request->input('tax_category_id');
            });

        foreach ($siblings as $sibling) {
            if (abs($sibling->totalRate() - $totalRate) > 0.0001) {
                return __('tax_rule_supply_totals_must_match', [
                    'other' => $opposite,
                    'rate'  => rtrim(rtrim(number_format($sibling->totalRate(), 3, '.', ''), '0'), '.'),
                ]);
            }
        }

        return null;
    }
}
