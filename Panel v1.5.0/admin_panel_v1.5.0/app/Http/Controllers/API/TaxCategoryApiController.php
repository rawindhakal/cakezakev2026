<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\TaxCategory;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * Tax categories: WHAT a product is ("Food", "Standard rate", "Exempt").
 *
 * Deliberately rate-free. A category is 5% in one country and 0% in another, and the
 * rate can change on a date — all of that lives in tax rules. Products point here.
 *
 * Also deliberately single-language: this name never reaches a customer. What they
 * read on a cart or invoice is the tax COMPONENT ("CGST", "VAT"), a legal identifier
 * that must not be translated.
 */
class TaxCategoryApiController extends Controller
{
    public function index(Request $request)
    {
        if ($request->filled('id')) {
            return CommonHelper::responseWithData(TaxCategory::where('id', (int) $request->id)->first());
        }

        $query = TaxCategory::query();

        if ($request->filled('status')) {
            $query->where('status', (int) $request->input('status'));
        }
        if ($request->filled('search')) {
            $search = trim((string) $request->input('search'));
            $query->where(fn ($q) => $q->where('name', 'like', "%{$search}%")->orWhere('code', 'like', "%{$search}%"));
        }

        $total = (clone $query)->count();

        $limit = (int) $request->get('limit', 0);
        if ($limit > 0) {
            $query->skip((int) $request->get('offset', 0))->take($limit);
        }

        $categories = $query->orderBy('id', 'ASC')->get();

        // How many jurisdictions actually price this category — an unruled category
        // silently taxes nothing, which is worth surfacing in the list.
        $ruleCounts = DB::table('tax_rules')->where('status', 1)
            ->selectRaw('tax_category_id, COUNT(*) as n')->groupBy('tax_category_id')
            ->pluck('n', 'tax_category_id');
        $productCounts = DB::table('products')->whereNull('deleted_at')
            ->selectRaw('tax_category_id, COUNT(*) as n')->groupBy('tax_category_id')
            ->pluck('n', 'tax_category_id');

        foreach ($categories as $category) {
            $category->rule_count = (int) ($ruleCounts[$category->id] ?? 0);
            $category->product_count = (int) ($productCounts[$category->id] ?? 0);
        }

        return CommonHelper::responseWithData($categories, $total);
    }

    public function save(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name'        => 'required|string|max:191',
            'code'        => 'required|string|max:32',
            'description' => 'nullable|string|max:191',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $category = $request->filled('id') ? TaxCategory::find((int) $request->id) : new TaxCategory();
        if ($request->filled('id') && !$category) {
            return CommonHelper::responseError('tax_category_not_found');
        }

        $code = strtoupper(preg_replace('/[^A-Za-z0-9]+/', '_', trim((string) $request->code)));
        $code = trim($code, '_');
        $clash = TaxCategory::where('code', $code)
            ->when($category->exists, fn ($q) => $q->where('id', '!=', $category->id))->exists();
        if ($clash) {
            return CommonHelper::responseError('tax_category_code_already_exists');
        }

        /* Deactivating is how a category is retired, and a retired category stops
           taxing — so refuse while anything still points at it, rather than silently
           dropping tax on those products. */
        $newStatus = $request->has('status') ? (int) $request->status : ($category->status ?? 1);
        if ($category->exists && $newStatus === 0 && (int) $category->status === 1 && $this->inUse($category->id)) {
            return CommonHelper::responseError('tax_category_in_use_cannot_deactivate');
        }

        $category->name = $request->name;
        $category->code = $code;
        $category->description = $request->input('description');
        $category->status = $newStatus;
        $category->save();

        return CommonHelper::responseSuccessWithData('tax_category_saved_successfully', $category->fresh());
    }

    /** Anything still pointing at this category — products, rules or a zone charge. */
    private function inUse(int $categoryId): bool
    {
        return DB::table('products')->where('tax_category_id', $categoryId)->whereNull('deleted_at')->exists()
            || DB::table('tax_rules')->where('tax_category_id', $categoryId)->exists()
            || DB::table('zones')->where('delivery_charge_tax_category_id', $categoryId)->exists();
    }

    /**
     * Blocked while products, rules or zone charges still reference it. Deleting a
     * category out from under a product would silently make that product untaxed.
     */
    public function delete(Request $request)
    {
        $category = TaxCategory::find((int) $request->input('id'));
        if (!$category) {
            return CommonHelper::responseError('tax_category_not_found');
        }

        if ($this->inUse($category->id)) {
            return CommonHelper::responseError('tax_category_in_use_deactivate_instead');
        }

        $category->delete();

        return CommonHelper::responseSuccess('tax_category_deleted_successfully');
    }
}
