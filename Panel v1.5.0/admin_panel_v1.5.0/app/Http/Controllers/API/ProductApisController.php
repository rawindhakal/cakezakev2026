<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Helpers\ProductHelper;
use App\Http\Controllers\Controller;
use App\Models\Branch;
use App\Models\TaxCategory;
use App\Models\Brand;
use App\Models\Category;
use App\Models\Product;
use App\Models\ProductImages;
use App\Models\ProductVariant;
use App\Models\ProductVariantBranchStock;
use App\Models\ProductVariantAttributeValue;
use App\Models\ProductVariantCustomValue;
use App\Models\OrderItem;
use App\Models\Setting;
use App\Services\LanguageService;
use App\Models\Country;
use App\Models\Zone;
use App\Models\Language;
use App\Models\ProductRecommendation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;
class ProductApisController extends Controller
{
    /** Variant "Other Images": what the field takes, and how big one file may be. */
    private const GALLERY_MAX_MB = 5;

    private const GALLERY_MIMES = 'jpeg,jpg,png,gif,webp,svg,mp4';

    private const GALLERY_TYPES_LABEL = 'JPG, PNG, GIF, WEBP, SVG, MP4';

    /**
     * Admin/Branch product listing for the cards UI.
     *
     * Query params:
     *  - search        text to match against product name (current + default translation) and id
     *  - category_id   filter by category
     *  - branch_id     filter by branch (admin only)
     *  - is_draft      1 | 0 (draft vs published listing)
     *  - sort_by       latest | oldest | name_asc | name_desc | price_low | price_high
     *  - page / per_page
     */

    public function variantUsage(Request $request)
    {
        $variantId = (int) $request->input('variant_id', 0);
        if (!$variantId) {
            return CommonHelper::responseWithData(['order_count' => 0]);
        }
        $orderCount = OrderItem::where('product_variant_id', $variantId)->distinct()->count('order_id');

        return CommonHelper::responseWithData(['order_count' => (int) $orderCount]);
    }

    public function checkSku(Request $request)
    {
        $sku = trim((string) $request->input('sku', ''));
        if ($sku === '') {
            return CommonHelper::responseWithData(['available' => true]);
        }
        $productId = (int) $request->input('product_id', 0);

        $query = ProductVariant::where('sku', $sku);
        if ($productId) {
            $query->where('product_id', '!=', $productId);
        }

        return CommonHelper::responseWithData(['available' => !$query->exists()]);
    }

    /**
     * Demand signals for one product: how many distinct customers are holding it in a wishlist / cart right now.
     */
    public function demandStats(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_id' => 'required|integer|exists:products,id',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $productId = (int) $request->product_id;

        return CommonHelper::responseWithData([
            'wishlist_users' => (int) DB::table('favorites')->where('product_id', $productId)->distinct()->count('user_id'),
            'cart_users'     => (int) DB::table('carts')->where('product_id', $productId)->distinct()->count('user_id'),
        ]);
    }

    public function getProducts(Request $request)
    {
        $perPage = (int) $request->input('per_page', 12);
        if ($perPage <= 0) {
            $perPage = 12;
        }
        $page = max(1, (int) $request->input('page', 1));

        $search       = trim((string) $request->input('search', $request->input('filter', '')));
        $categoryId   = $request->input('category_id', $request->input('category'));
        $brandId      = $request->input('brand_id', $request->input('brand'));
        $taxCategoryId = $request->input('tax_category_id');
        $branchId     = $request->input('branch_id', $request->input('branch'));
        $isDraft      = $request->input('is_draft');
        $status       = $request->input('status');
        $salesChannel = $request->input('sales_channel');
        $isFood       = $request->input('is_food');
        $sortBy       = $request->input('sort_by', 'latest');

        if (auth()->check() && isset(auth()->user()->branch->id)) {
            $branchId = auth()->user()->branch->id;
        }

        // Global header country/zone filter: scope prices + currency to that region's
        // branches so the list shows the selected country's currency and its branch prices.
        $countryId = (int) $request->input('country_id', 0);
        $zoneId    = (int) $request->input('zone_id', 0);
        $allowedBranchIds = null;
        $listCurrency = null;
        if ($countryId || $zoneId) {
            $zoneIds = $zoneId ? [$zoneId] : Zone::where('country_id', $countryId)->pluck('id')->all();
            $allowedBranchIds = Branch::where(function ($q) use ($zoneIds) {
                $q->whereIn('zone_id', $zoneIds);
            })->pluck('id')->all();

            $curCountryId = $countryId ?: (int) Zone::where('id', $zoneId)->value('country_id');
            $listCurrency = $curCountryId ? Country::where('id', $curCountryId)->value('currency') : null;
        }

        $query = Product::query()
            ->with([
                'translations',
                'category:id,name',
                'category.translations',
                'variants' => function ($q) {
                    $q->select('id', 'product_id', 'image', 'sku')
                        ->withSum('branchStocks as stock_sum', 'available')
                        ->orderBy('id');
                },
                // Price is per-branch (PVSS): load listed rows to derive the price range.
                // Scoped to the header country/zone's branches when a filter is active.
                'variants.branchStocks' => function ($q) use ($allowedBranchIds) {
                    $q->select('id', 'product_variant_id', 'branch_id', 'price', 'discounted_price', 'is_listed');
                    if ($allowedBranchIds !== null) {
                        $q->whereIn('branch_id', $allowedBranchIds);
                    }
                },
                'variants.translations',
            ])
            ->withAvg(['ratings as rating_avg' => fn ($q) => $q->where('status', 1)], 'rate');

        if ($isDraft !== null && $isDraft !== '') {
            $query->where('is_draft', (int) $isDraft);
        }

        if (!empty($categoryId)) {
            $query->where('category_id', (int) $categoryId);
        }

        if (!empty($brandId)) {
            $query->where('brand_id', (int) $brandId);
        }

        // 0 = the products no tax category prices — worth being able to find.
        if ($taxCategoryId !== null && $taxCategoryId !== '') {
            (int) $taxCategoryId === 0
                ? $query->whereNull('tax_category_id')
                : $query->where('tax_category_id', (int) $taxCategoryId);
        }

        if ($status !== null && $status !== '') {
            $query->where('status', (int) $status);
        }

        if (!empty($salesChannel) && in_array($salesChannel, ['quick', 'ecommerce', 'both'], true)) {
            $query->where('sales_channel', $salesChannel);
        }

        // Food items are the only ones that carry addons, so the addon tooling filters on it.
        if ($isFood !== null && $isFood !== '') {
            $query->where('is_food', (int) $isFood);
        }

        // Filter by branch via PVSS — a product belongs to the branch if any variant has a
        // listed PVSS row in that branch. A DRAFT counts as the branch's on any PVSS row:
        if (!empty($branchId)) {
            $query->whereExists(function ($q) use ($branchId) {
                $q->select(DB::raw(1))
                    ->from('product_variants as pv')
                    ->join('product_variant_branch_stocks as pvss', 'pvss.product_variant_id', '=', 'pv.id')
                    ->whereColumn('pv.product_id', 'products.id')
                    ->where('pvss.branch_id', (int) $branchId)
                    ->where(function ($w) {
                        $w->where('pvss.is_listed', 1)->orWhere('products.is_draft', 1);
                    });
            });
        }

        // "Listed only" toggle: show only products that have at least one listed
        // branch — scoped to the header country/zone's branches when a filter is active.
        // Off → all products (no listing constraint).
        if ((int) $request->input('listed_only', 0) === 1) {
            $query->where(function ($outer) use ($allowedBranchIds) {
                $outer->where('products.is_draft', 1)
                    ->orWhereExists(function ($q) use ($allowedBranchIds) {
                        $q->select(DB::raw(1))
                            ->from('product_variants as pv')
                            ->join('product_variant_branch_stocks as pvss', 'pvss.product_variant_id', '=', 'pv.id')
                            ->whereColumn('pv.product_id', 'products.id')
                            ->where('pvss.is_listed', 1);
                        if ($allowedBranchIds !== null) {
                            $q->whereIn('pvss.branch_id', $allowedBranchIds);
                        }
                    });
            });
        }

        if ($search !== '') {
            $like = '%' . $search . '%';
            $query->where(function ($q) use ($like, $search) {
                $q->where('id', '=', is_numeric($search) ? (int) $search : 0)
                    ->orWhere('products.name', 'like', $like)
                    ->orWhereHas('translations', function ($qt) use ($like) {
                        $qt->where('name', 'like', $like);
                    })
                    ->orWhereHas('variants', function ($qv) use ($like) {
                        $qv->where('name', 'like', $like)
                            ->orWhere('sku', 'like', $like)
                            ->orWhereHas('translations', function ($qt) use ($like) {
                                $qt->where('name', 'like', $like);
                            });
                    });
            });
        }

        switch ($sortBy) {
            case 'oldest':    $query->orderBy('id', 'asc'); break;
            case 'name_asc':
            case 'name_desc':
                $direction = $sortBy === 'name_asc' ? 'asc' : 'desc';
                $query->orderBy('products.name', $direction);
                break;
            case 'price_low':
                // Price is per-branch (PVSS): sort by the lowest listed branch price.
                $query->orderByRaw('(SELECT MIN(pvss.price) FROM product_variant_branch_stocks pvss JOIN product_variants pv ON pv.id = pvss.product_variant_id WHERE pv.product_id = products.id AND pvss.is_listed = 1) ASC');
                break;
            case 'price_high':
                $query->orderByRaw('(SELECT MAX(pvss.price) FROM product_variant_branch_stocks pvss JOIN product_variants pv ON pv.id = pvss.product_variant_id WHERE pv.product_id = products.id AND pvss.is_listed = 1) DESC');
                break;
            case 'latest':
            default:          $query->orderBy('id', 'desc'); break;
        }

        $total = (clone $query)->count();
        $products = $query->skip(($page - 1) * $perPage)->take($perPage)->get();

        $items = $products->map(function (Product $p) {
            $variants = $p->variants ?? collect();
            // Price is per-branch (PVSS): the admin list shows the effective-price range
            // across listed branch rows (discounted price when set, else selling price).
            $listedStocks = $variants->flatMap(fn ($v) => $v->branchStocks->where('is_listed', 1));
            $prices = $listedStocks
                ->map(fn ($s) => (float) $s->discounted_price > 0 ? (float) $s->discounted_price : (float) $s->price)
                ->filter(fn ($v) => $v > 0);
            $discounted = $listedStocks->pluck('discounted_price')->filter(fn ($v) => $v !== null && $v > 0);
            $stock = (int) $variants->sum('stock_sum');

            $firstVariant = $variants->first();

            $translations = $p->relationLoaded('translations')
                ? $p->getRelation('translations')->map(fn ($t) => [
                    'language_id'       => $t->language_id,
                    'name'              => $t->name,
                    'tags'              => $t->tags,
                    'manufacturer'      => $t->manufacturer,
                    'description'       => $t->description,
                    'short_description' => $t->short_description,
                    'meta_title'        => $t->meta_title,
                    'meta_keywords'     => $t->meta_keywords,
                    'schema_markup'     => $t->schema_markup,
                    'meta_description'  => $t->meta_description,
                ])->values()->toArray()
                : [];

            $categoryPayload = null;
            if ($p->relationLoaded('category') && $p->category) {
                $categoryPayload = [
                    'id'           => $p->category->id,
                    'name'         => $p->category->name,
                    'translations' => $p->category->relationLoaded('translations')
                        ? $p->category->getRelation('translations')->map(fn ($t) => [
                            'language_id' => $t->language_id,
                            'name'        => $t->name,
                        ])->values()->toArray()
                        : [],
                ];
            }

            $firstVariantImage = optional($firstVariant)->image;
            return [
                'id'              => $p->id,
                'name'            => $p->getAttributes()['name'] ?? '',
                'image'           => $firstVariantImage,
                'image_url'       => $firstVariantImage ? asset('storage/' . $firstVariantImage) : '',
                'category'        => $categoryPayload,
                'is_draft'        => (int) $p->is_draft,
                'status'          => (int) $p->status,
                'product_type'    => (int) $p->product_type,
                'is_food'         => (int) ($p->is_food ?? 0),
                'is_addon_only'   => (int) ($p->is_addon_only ?? 0),
                'is_prescription_required' => (int) ($p->is_prescription_required ?? 0),
                'sales_channel'   => (string) ($p->sales_channel ?? 'both'),
                'variants_count'  => $variants->count(),
                'total_stock'     => $stock,
                'min_price'       => $prices->count() ? (float) $prices->min() : 0,
                'max_price'       => $prices->count() ? (float) $prices->max() : 0,
                'min_discounted'  => $discounted->count() ? (float) $discounted->min() : 0,
                'rating_avg'      => round((float) ($p->rating_avg ?? 0), 2),
                'translations'    => $translations,
            ];
        })->values();

        $categories = Category::where('status', 1)
            ->select('id', 'name', 'parent_id')
            ->with(['translations:id,category_id,language_id,name'])
            ->orderBy('name')
            ->get()
            ->map(function (Category $c) {
                return [
                    'id'           => $c->id,
                    'name'         => $c->name,
                    'parent_id'    => (int) ($c->parent_id ?? 0),
                    'translations' => $c->relationLoaded('translations')
                        ? $c->getRelation('translations')->map(fn ($t) => [
                            'language_id' => $t->language_id,
                            'name'        => $t->name,
                        ])->values()->toArray()
                        : [],
                ];
            })->values();

        $branches = [];
        if (!auth()->check() || !isset(auth()->user()->branch->id)) {
            $branches = Branch::where('status', 1)
                ->select('id', 'name')
                ->with(['translations:id,branch_id,language_id,name'])
                ->orderBy('name')
                ->get()
                ->map(function (Branch $s, $i) {
                    return [
                        'id'           => $s->id,
                        'name'         => $s->name,
                        'translations' => $s->relationLoaded('translations')
                            ? $s->getRelation('translations')->map(fn ($t) => [
                                'language_id' => $t->language_id,
                                'name'        => $t->name,
                            ])->values()->toArray()
                            : [],
                    ];
                })->values();
        }

        $brands = Brand::where('status', 1)
            ->select('id', 'name')
            ->with(['translations:id,brand_id,language_id,name'])
            ->orderBy('name')
            ->get()
            ->map(function (Brand $b) {
                return [
                    'id'           => $b->id,
                    'name'         => $b->name,
                    'translations' => $b->relationLoaded('translations')
                        ? $b->getRelation('translations')->map(fn ($t) => [
                            'language_id' => $t->language_id,
                            'name'        => $t->name,
                        ])->values()->toArray()
                        : [],
                ];
            })->values();

        // Tab counts follow the same branch scope as the list — a branch panel counting every
        // branch's products showed a draft total it could not open.
        $tabCount = function (int $draft) use ($branchId) {
            $q = Product::where('is_draft', $draft);
            if (!empty($branchId)) {
                $q->whereExists(function ($sub) use ($branchId, $draft) {
                    $sub->select(DB::raw(1))
                        ->from('product_variants as pv')
                        ->join('product_variant_branch_stocks as pvss', 'pvss.product_variant_id', '=', 'pv.id')
                        ->whereColumn('pv.product_id', 'products.id')
                        ->where('pvss.branch_id', (int) $branchId);
                    // Published: only what the branch actually lists. Draft: any row it owns.
                    if ($draft === 0) {
                        $sub->where('pvss.is_listed', 1);
                    }
                });
            }

            return $q->count();
        };

        $publishedCount = $tabCount(0);
        $draftCount     = $tabCount(1);

        return CommonHelper::responseWithData([
            'products'   => $items,
            'categories' => $categories,
            'brands'     => $brands,
            'tax_categories' => TaxCategory::where('status', 1)
                ->orderBy('name')->get(['id', 'name', 'code']),
            'branches'    => $branches,
            'counts'     => [
                'published' => $publishedCount,
                'draft'     => $draftCount,
            ],
            // Currency of the header-selected country (null when no country/zone filter).
            'currency'   => $listCurrency,
        ], $total);
    }

    public function getActiveProducts()
    {
        $query = DB::table('products as p')
            ->select(
                'p.id as id',
                'p.id as product_id',
                'pv.name as name',
                'p.status',
                'p.slug',
                'p.tax_category_id',
                'p.image',
                'p.product_type',
                'p.is_prescription_required',
                'p.manufacturer',
                'p.made_in',
                'p.return_status',
                'p.cancelable_status',
                'p.till_status_quick',
                'p.till_status_ecommerce',
                'pv.id as product_variant_id',
                // Price is per-branch (PVSS): representative = lowest listed branch price.
                DB::raw('(SELECT MIN(pvss.price) FROM product_variant_branch_stocks pvss WHERE pvss.product_variant_id = pv.id AND pvss.is_listed = 1) as price'),
                DB::raw('(SELECT MIN(pvss.discounted_price) FROM product_variant_branch_stocks pvss WHERE pvss.product_variant_id = pv.id AND pvss.is_listed = 1) as discounted_price'),
                DB::raw('(SELECT COALESCE(SUM(available), 0) FROM product_variant_branch_stocks WHERE product_variant_id = pv.id) as stock')
            )
            ->join('product_variants as pv', 'p.id', '=', 'pv.product_id')
            ->where('p.status', 1);

        $products = $query->orderBy('p.id', 'DESC')->get();

        // Load translations for products
        if ($products->isNotEmpty()) {
            $productIds = $products->pluck('product_id')->unique()->toArray();
            $productsWithTranslations = Product::whereIn('id', $productIds)
                ->with('translations')
                ->get()
                ->keyBy('id');

            // Attach translations to each product in the results
            $products = $products->map(function ($product) use ($productsWithTranslations) {
                $productModel = $productsWithTranslations->get($product->product_id);

                if ($productModel && $productModel->relationLoaded('translations')) {
                    $product->translations = $productModel->getRelation('translations')->toArray();
                } else {
                    $product->translations = [];
                }

                return $product;
            });
        }

        return CommonHelper::responseWithData($products);
    }

    public function save(Request $request)
    {
        return $this->stepperSave($request);
    }

    public function update(Request $request)
    {
        return $this->stepperSave($request);
    }

    /**
     * Unified create/update for stepper form.
     * Multipart payload:
     *  id?                            for update
     *  category_id                    leaf category id
     *  brand_id, tax_category_id?     ids
     *  branch_id                      required
     *  product_type?                  0|1|2 (none/veg/non_veg)
     *  made_in?                       country_id
     *  return_status?, cancelable_status?, till_status?, cod_allowed?
     *  return_days?
     *  total_allowed_quantity?
     *  status?
     *  translations[lang_id][name|description|meta_title|meta_keywords|meta_description|schema_markup|tags|manufacturer]
     *  attribute_value_ids            JSON [{attribute_id, value_id}]
     *  variants                       JSON [variant object]
     *  variant_images[idx][main]      file
     *  variant_images[idx][gallery][] files  stills or one short mp4 clip each
     */
    protected function stepperSave(Request $request)
    {
        $isDraft = (int) $request->input('is_draft', 0) === 1;

        $rules = ['category_id' => 'required|integer|exists:categories,id'];
        if (!$isDraft) {
            $rules['variants'] = 'required';
        }

        $rules['variant_images.*.gallery.*'] = 'file|mimes:' . self::GALLERY_MIMES
            . '|max:' . (self::GALLERY_MAX_MB * 1024);
        // Stated in MB, not Laravel's kilobyte wording, so the admin reads the real limit.
        $size = self::GALLERY_MAX_MB . ' MB';
        $validator = Validator::make($request->all(), $rules, [
            'variant_images.*.gallery.*.max'   => str_replace('{size}', $size, __('file_size_exceeds_limit_x')),
            'variant_images.*.gallery.*.mimes' => str_replace(
                ['{types}', '{size}'],
                [self::GALLERY_TYPES_LABEL, $size],
                __('allowed_types_and_max_size')
            ),
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        if (Category::where('parent_id', (int) $request->input('category_id'))->exists()) {
            return CommonHelper::responseError(__('category_must_be_leaf'));
        }

        $translations = $this->parseJsonInput($request->input('translations', []));
        $defaultLang = Language::where('is_default', 1)->first();
        $defaultLangId = $defaultLang ? $defaultLang->id : null;

        $variants = $this->parseJsonInput($request->input('variants', []));
        if (!$isDraft && (!is_array($variants) || count($variants) === 0)) {
            return CommonHelper::responseError('at_least_one_variant_required');
        }
        if (!is_array($variants)) {
            $variants = [];
        }

        // Variant name now drives the product identity (no products.name column).
        $defaultName = '';
        foreach ($variants as $vRow) {
            if (!is_array($vRow)) continue;
            $vTrans = $vRow['translations'] ?? [];
            $candidate = '';
            if ($defaultLangId !== null && is_array($vTrans)) {
                $candidate = (string) ($vTrans[$defaultLangId]['name'] ?? ($vTrans[(string) $defaultLangId]['name'] ?? ''));
            }
            if (trim($candidate) === '') {
                $candidate = (string) ($vRow['name'] ?? '');
            }
            if (trim($candidate) !== '') {
                $defaultName = trim($candidate);
                break;
            }
        }
        if (!$isDraft && $defaultName === '') {
            return CommonHelper::responseError('variant_name_required_in_default_language');
        }
        if ($defaultName === '') {
            $defaultName = 'Draft Product ' . time();
        }

        // Validate SKU uniqueness (within payload + across other products) to avoid raw DB errors.
        $skuSeen = [];
        $skuList = [];
        foreach ($variants as $row) {
            if (!is_array($row)) {
                continue;
            }
            $sku = trim((string) ($row['sku'] ?? ''));
            if ($sku === '') {
                continue;
            }
            $key = mb_strtolower($sku);
            if (isset($skuSeen[$key])) {
                return CommonHelper::responseError(__('duplicate_sku', ['sku' => $sku]));
            }
            $skuSeen[$key] = true;
            $skuList[] = $sku;
        }
        if (!empty($skuList)) {
            $conflictQuery = ProductVariant::whereIn('sku', $skuList);
            if ($request->input('id')) {
                $conflictQuery->where('product_id', '!=', $request->input('id'));
            }
            $conflict = $conflictQuery->first();
            if ($conflict) {
                return CommonHelper::responseError(__('sku_already_used', ['sku' => $conflict->sku]));
            }
        }

        try {
            $product = DB::transaction(function () use ($request, $translations, $defaultLangId, $defaultName, $variants) {
                $id = $request->input('id');
                $product = $id ? Product::findOrFail($id) : new Product();

                $product->category_id = $request->input('category_id');
                $salesChannel = $request->input('sales_channel', 'both');
                $product->sales_channel = in_array($salesChannel, ['quick', 'ecommerce', 'both'], true) ? $salesChannel : 'both';
                $product->brand_id = $request->input('brand_id') ?: 0;
                $product->tax_category_id = $request->input('tax_category_id') ?: null;
                $product->product_type = $request->input('product_type');
                $product->is_food = (int) ($request->input('is_food') ?? 0) === 1 ? 1 : 0;
                $product->is_addon_only = (int) ($request->input('is_addon_only') ?? 0) === 1 ? 1 : 0;
                // Gifting
                $product->is_personalizable = (int) ($request->input('is_personalizable') ?? 0) === 1 ? 1 : 0;
                $product->is_featured = (int) ($request->input('is_featured') ?? 0) === 1 ? 1 : 0;
                foreach (['occasions', 'relationships', 'delivery_types'] as $giftKey) {
                    $slugs = array_values(array_filter(array_map('trim', explode(',', (string) $request->input($giftKey, '')))));
                    $product->{$giftKey} = json_encode($slugs);
                }
                // Only medical products can demand a prescription; clear the flag otherwise
                // so a type change doesn't leave a stale requirement blocking checkout.
                $product->is_prescription_required = ((int) $request->input('product_type') === 5)
                    ? (int) ($request->input('is_prescription_required') ?? 0)
                    : 0;
                // Base columns mirror the default language (same rule as manufacturer below).
                $product->name = $defaultLangId && isset($translations[$defaultLangId]['name'])
                    ? $translations[$defaultLangId]['name'] : $request->input('name');
                $product->manufacturer = $defaultLangId && isset($translations[$defaultLangId]['manufacturer'])
                    ? $translations[$defaultLangId]['manufacturer'] : $request->input('manufacturer');
                $product->made_in = $defaultLangId && isset($translations[$defaultLangId]['made_in'])
                    ? $translations[$defaultLangId]['made_in'] : $request->input('made_in');
                $product->return_status = $request->input('return_status');
                $product->cancelable_status = $request->input('cancelable_status');
                // Channel-wise cancellable-till (quick / ecommerce).
                $product->till_status_quick = $request->input('till_status_quick');
                $product->till_status_ecommerce = $request->input('till_status_ecommerce');
                $product->return_days = (int) $request->input('return_days', 0);
                $product->cod_allowed = (int) $request->input('cod_allowed', 0);
                $product->total_allowed_quantity = (int) $request->input('total_allowed_quantity', 0);
                $product->status = (int) $request->input('status', 1);
                $product->is_draft = (int) $request->input('is_draft', 0);
                $product->description = $defaultLangId && isset($translations[$defaultLangId]['description'])
                    ? $translations[$defaultLangId]['description'] : ($request->input('description') ?? '');
                $product->short_description = $defaultLangId && isset($translations[$defaultLangId]['short_description'])
                    ? $translations[$defaultLangId]['short_description'] : ($request->input('short_description') ?? '');
                $product->meta_title = $translations[$defaultLangId]['meta_title'] ?? $request->input('meta_title') ?? '';
                $product->meta_keywords = $translations[$defaultLangId]['meta_keywords'] ?? $request->input('meta_keywords') ?? '';
                $product->meta_description = $translations[$defaultLangId]['meta_description'] ?? $request->input('meta_description') ?? '';
                $product->schema_markup = $translations[$defaultLangId]['schema_markup'] ?? $request->input('schema_markup') ?? '';
                $product->tags = $translations[$defaultLangId]['tags'] ?? $request->input('tags') ?? '';

                $product->slug = $this->makeProductSlug($defaultName, $product->id);

                $product->save();

                $this->syncProductTranslations($product, $translations);
                $this->syncProductVariants($product, $variants, $request);

                $firstVariant = ProductVariant::where('product_id', $product->id)->orderBy('id')->first();
                if ($firstVariant && $firstVariant->image) {
                    $product->image = $firstVariant->image;
                    $product->saveQuietly();
                }

                return $product;
            });

            // The saved variants (id + image identity). The add form auto-saves as a draft
            // while the user is still typing, and without this it keeps sending id-less
            // variants and re-uploading the same files on every save.
            $savedVariants = ProductVariant::with('images')
                ->where('product_id', $product->id)
                ->orderBy('sort_order')->orderBy('id')
                ->get()
                ->map(fn (ProductVariant $v) => [
                    'id'         => (int) $v->id,
                    'sort_order' => (int) $v->sort_order,
                    'sku'        => $v->sku,
                    'image'      => $v->image ? asset('storage/' . $v->image) : null,
                    'image_path' => $v->image,
                    'gallery'    => $v->images->map(fn ($img) => [
                        'id'   => (int) $img->id,
                        'url'  => asset('storage/' . $img->image),
                        'path' => $img->image,
                    ])->values(),
                ])->values();

            return CommonHelper::responseSuccessWithData(
                $request->input('id') ? 'product_updated_successfully' : 'product_saved_successfully',
                ['id' => $product->id, 'variants' => $savedVariants]
            );
        } catch (\Illuminate\Database\QueryException $e) {
            Log::info('Stepper save error: ' . $e->getMessage());
            if ((int) ($e->errorInfo[1] ?? 0) === 1062) {
                if (stripos($e->getMessage(), 'sku') !== false) {
                    return CommonHelper::responseError('sku_must_be_unique');
                }
                return CommonHelper::responseError('duplicate_unique_value');
            }
            return CommonHelper::responseError('could_not_save_product');
        } catch (\Throwable $e) {
            Log::info('Stepper save error: ' . $e->getMessage());
            return CommonHelper::responseError($e->getMessage());
        }
    }

    protected function syncProductTranslations(Product $product, array $translations): void
    {
        foreach ($translations as $langId => $payload) {
            if (!is_array($payload)) {
                continue;
            }
            $product->saveTranslation((int) $langId, [
                'name' => $payload['name'] ?? null,
                'tags' => $payload['tags'] ?? null,
                'manufacturer' => $payload['manufacturer'] ?? null,
                'made_in' => $payload['made_in'] ?? null,
                'description' => $payload['description'] ?? null,
                'short_description' => $payload['short_description'] ?? null,
                'meta_title' => $payload['meta_title'] ?? null,
                'meta_keywords' => $payload['meta_keywords'] ?? null,
                'schema_markup' => $payload['schema_markup'] ?? null,
                'meta_description' => $payload['meta_description'] ?? null,
            ]);
        }
    }

    protected function syncProductVariants(Product $product, array $variants, Request $request): void
    {
        $keepIds = [];
        foreach ($variants as $idx => $row) {
            if (!is_array($row)) {
                continue;
            }
            $variantId = $row['id'] ?? null;
            $variant = $variantId
                ? ProductVariant::where('product_id', $product->id)->find($variantId)
                : null;
                
            $rowSku = trim((string) ($row['sku'] ?? ''));
            if (!$variant && $rowSku !== '') {
                $variant = ProductVariant::where('product_id', $product->id)->where('sku', $rowSku)->first();
            }
            if (!$variant) {
                $variant = new ProductVariant(['product_id' => $product->id]);
            }

            $variant->product_id = $product->id;
            $variant->name = $row['name'] ?? null;
            $variant->sku = $row['sku'] ?? null;
            $variant->hsn_code = $row['hsn_code'] ?? null;
            // Courier shipping data. Blank stays null so a shipping plugin can fall back
            // to its own default box rather than quoting on a zero-weight parcel.
            foreach (['weight', 'length', 'breadth', 'height'] as $dim) {
                $value = $row[$dim] ?? null;
                $variant->{$dim} = ($value === null || $value === '') ? null : (float) $value;
            }
            // Price / discounted / slabs / purchase are per-branch now (PVSS), written
            // in syncVariantBranchStocks — nothing price-related stays on the variant.
            $variant->sort_order = $idx;

            if ($request->hasFile("variant_images.$idx.main")) {
                $variant->image = CommonHelper::uploadFile($request->file("variant_images.$idx.main"), null, 'products/variants', $variant->image);
            } elseif (!empty($row['image_path'])) {
                $variant->image = $row['image_path'];
            }

            $variant->save();
            $keepIds[] = $variant->id;

            $this->syncVariantTranslations($variant, $row['translations'] ?? []);
            $this->syncVariantAttributeValues($variant, $row['attribute_values'] ?? []);
            $this->syncVariantCustomValues($variant, $row['custom_values'] ?? []);
            $this->syncVariantGallery($variant, $request, $idx, $row['gallery_delete_ids'] ?? [], $row['gallery_paths'] ?? []);
            $this->syncVariantBranchStocks($variant, $row['branch_stocks'] ?? [], (bool) $product->tax_category_id);
        }

        if (!empty($keepIds)) {
            ProductVariant::where('product_id', $product->id)
                ->whereNotIn('id', $keepIds)
                ->delete();
        }
    }

    protected function syncVariantBranchStocks(ProductVariant $variant, $rows, bool $hasTaxCategory = false): void
    {
        if (!is_array($rows)) {
            $rows = [];
        }

        $keepBranchIds = [];
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }
            $branchId = (int) ($row['branch_id'] ?? 0);
            if ($branchId <= 0) {
                continue;
            }
            // Unlimited stock is per-branch now. The admin UI hides available /
            // min_alert when a branch is unlimited, but we still persist whatever
            // was submitted so switching back to Limited preserves the numbers.
            $isUnlimited = (int) ($row['is_unlimited_stock'] ?? 0);
            $available = (int) ($row['available'] ?? 0);
            $minAlert  = (int) ($row['min_alert'] ?? 0);

            // Branch-wise pricing. price + discounted_price are required when the branch
            // is listed; pricing_slabs is optional. purchase_price is the branch's cost
            // (differs by branch country). null-safe: unlisted rows may omit price.
            $isListed = (int) ($row['is_listed'] ?? 1);
            $price = is_numeric($row['price'] ?? null) ? (float) $row['price'] : null;
            $discounted = is_numeric($row['discounted_price'] ?? null) ? (float) $row['discounted_price'] : null;
            $purchase = is_numeric($row['purchase_price'] ?? null) ? (float) $row['purchase_price'] : null;
            $slabs = ProductHelper::normalizeSlabs($row['pricing_slabs'] ?? []);

            // price + discounted are required for a listed branch; discounted ≤ price.
            if ($isListed === 1) {
                if ($price === null || $discounted === null) {
                    throw new \RuntimeException(__('price_and_discounted_price_are_required_for_a_listed_branch'));
                }
                if ($discounted > $price) {
                    throw new \RuntimeException(__('discounted_price_cannot_be_greater_than_price'));
                }
            }

            // 'reserved' is intentionally NOT written here — it is system-managed
            // (cart reserve/release/commit). Admin edits only available/min_alert.
            // New rows fall back to the column default (0).
            ProductVariantBranchStock::updateOrCreate(
                ['product_variant_id' => $variant->id, 'branch_id' => $branchId],
                [
                    'is_listed'        => $isListed,
                    'stock_status'     => (int) ($row['stock_status'] ?? 1),
                    'available'        => $available,
                    'min_alert'        => $minAlert,
                    'is_unlimited_stock' => $isUnlimited,
                    'price'            => $price,
                    'discounted_price' => $discounted,
                    'pricing_slabs'    => !empty($slabs) ? $slabs : null,
                    'purchase_price'   => $purchase,
                    'is_tax_inclusive' => (int) ($hasTaxCategory && !empty($row['is_tax_inclusive'])),
                ]
            );
            $keepBranchIds[] = $branchId;
            ProductHelper::notifyBackInStock($variant->id, $branchId);
        }

        $q = ProductVariantBranchStock::where('product_variant_id', $variant->id);
        if (!empty($keepBranchIds)) {
            $q->whereNotIn('branch_id', $keepBranchIds);
        }
        $q->delete();
    }

    protected function syncVariantTranslations(ProductVariant $variant, array $translations): void
    {
        foreach ($translations as $langId => $payload) {
            if (!is_array($payload)) {
                continue;
            }
            $variant->saveTranslation((int) $langId, [
                'name' => $payload['name'] ?? null,
            ]);
        }
    }

    protected function syncVariantAttributeValues(ProductVariant $variant, array $rows): void
    {
        ProductVariantAttributeValue::where('product_variant_id', $variant->id)->delete();
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }
            $attributeId = (int) ($row['attribute_id'] ?? 0);
            $valueId = (int) ($row['value_id'] ?? 0);
            if ($attributeId <= 0 || $valueId <= 0) {
                continue;
            }
            ProductVariantAttributeValue::create([
                'product_variant_id' => $variant->id,
                'attribute_id' => $attributeId,
                'attribute_value_id' => $valueId,
            ]);
        }
    }

    protected function syncVariantCustomValues(ProductVariant $variant, array $rows): void
    {
        $keep = [];
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }
            $fieldId = (int) ($row['field_id'] ?? 0);
            if ($fieldId <= 0) {
                continue;
            }
            $cv = ProductVariantCustomValue::firstOrNew([
                'product_variant_id' => $variant->id,
                'category_custom_field_id' => $fieldId,
            ]);
            $cv->value_text = $row['value_text'] ?? null;
            $cv->value_number = isset($row['value_number']) && $row['value_number'] !== '' ? $row['value_number'] : null;
            $cv->value_date = !empty($row['value_date']) ? $row['value_date'] : null;
            $cv->value_json = isset($row['value_json']) ? $row['value_json'] : null;
            $cv->save();
            $keep[] = $cv->id;

            foreach (($row['translations'] ?? []) as $langId => $payload) {
                if (!is_array($payload)) {
                    continue;
                }
                $cv->saveTranslation((int) $langId, [
                    'value_text' => $payload['value_text'] ?? null,
                    'value_json' => $payload['value_json'] ?? null,
                ]);
            }
        }
        ProductVariantCustomValue::where('product_variant_id', $variant->id)
            ->whereNotIn('id', $keep)
            ->delete();
    }

    protected function syncVariantGallery(ProductVariant $variant, Request $request, int $idx, array $deleteIds, array $galleryPaths = []): void
    {
        if (!empty($deleteIds)) {
            $rows = ProductImages::where('product_variant_id', $variant->id)
                ->whereIn('id', $deleteIds)->get();
            foreach ($rows as $row) {
                CommonHelper::deleteFile($row->image);
                $row->delete();
            }
        }
        $files = $request->file("variant_images.$idx.gallery", []);
        if (is_array($files)) {
            foreach ($files as $file) {
                if (!$file) {
                    continue;
                }

                $path = CommonHelper::uploadFile($file, null, 'products/variants');
                if (!$path) {
                    continue;
                }
                ProductImages::create([
                    'product_id' => $variant->product_id,
                    'product_variant_id' => $variant->id,
                    'image' => $path,
                ]);
            }
        }

        foreach ($galleryPaths as $path) {
            $path = trim((string) $path);
            if ($path === '' || !Storage::disk('public')->exists($path)) {
                continue;
            }
            $exists = ProductImages::where('product_variant_id', $variant->id)
                ->where('image', $path)->exists();
            if (!$exists) {
                ProductImages::create([
                    'product_id' => $variant->product_id,
                    'product_variant_id' => $variant->id,
                    'image' => $path,
                ]);
            }
        }
    }

    protected function parseJsonInput($value): array
    {
        if (is_array($value)) {
            return $value;
        }
        if (is_string($value)) {
            $decoded = json_decode($value, true);
            return is_array($decoded) ? $decoded : [];
        }
        return [];
    }

    protected function makeProductSlug(string $name, $excludeId = null): string
    {
        $base = strtolower(preg_replace('/[^a-z0-9]+/i', '-', $name));
        $base = trim($base, '-');
        if ($base === '') {
            $base = 'product';
        }
        $slug = $base;
        $i = 1;
        while (Product::where('slug', $slug)->when($excludeId, fn ($q) => $q->where('id', '!=', $excludeId))->exists()) {
            $i++;
            $slug = $base . '-' . $i;
        }
        return $slug;
    }

    /**
     * Edit prefill — returns product with translations, variants, attrs, custom values, images.
     */
    public function edit($id)
    {
        $product = Product::with([
            'category',
            'brand',
            'taxCategory',
            'images',
            'translations',
            'variants' => function ($q) {
                $q->with(['images', 'translations', 'attributeValues', 'customValues.translations', 'branchStocks'])
                  ->orderBy('sort_order');
            },
        ])->where('id', $id)->first();

        if (!$product) {
            return CommonHelper::responseError('product_not_found');
        }

        if ($product->relationLoaded('category') && $product->category) {
            $product->category->makeHidden(['catActiveChilds', 'cat_active_childs']);
        }

        $defaultLang = app(LanguageService::class)->getDefaultLanguage();
        $defaultLangId = $defaultLang ? $defaultLang->id : null;

        $translationsArr = [];
        foreach ($product->getRelation('translations') as $trans) {
            $translationsArr[] = [
                'language_id' => $trans->language_id,
                'name' => $trans->name ?? '',
                'tags' => $trans->tags ?? '',
                'manufacturer' => $trans->manufacturer ?? '',
                'made_in' => $trans->made_in ?? '',
                'description' => $trans->description ?? '',
                'short_description' => $trans->short_description ?? '',
                'meta_title' => $trans->meta_title ?? '',
                'meta_keywords' => $trans->meta_keywords ?? '',
                'schema_markup' => $trans->schema_markup ?? '',
                'meta_description' => $trans->meta_description ?? '',
            ];
        }
        $hasDefault = collect($translationsArr)->contains('language_id', $defaultLangId);
        if ($defaultLangId && !$hasDefault) {
            array_unshift($translationsArr, [
                'language_id' => $defaultLangId,
                'name' => $product->getAttributes()['name'] ?? '',
                'tags' => $product->tags ?? '',
                'manufacturer' => $product->manufacturer ?? '',
                'made_in' => $product->made_in ?? '',
                'description' => $product->description ?? '',
                'short_description' => $product->short_description ?? '',
                'meta_title' => $product->meta_title ?? '',
                'meta_keywords' => $product->meta_keywords ?? '',
                'schema_markup' => $product->schema_markup ?? '',
                'meta_description' => $product->meta_description ?? '',
            ]);
        }

        $variantsOut = $product->variants->map(function (ProductVariant $v) {
            return [
                'id' => $v->id,
                'name' => $v->name,
                'sku' => $v->sku,
                'hsn_code' => $v->hsn_code,
                'weight' => $v->weight,
                'length' => $v->length,
                'breadth' => $v->breadth,
                'height' => $v->height,
                'sort_order' => $v->sort_order,
                'image' => $v->image ? asset('storage/' . $v->image) : null,
                'image_path' => $v->image,
                'gallery' => $v->images->map(fn ($img) => [
                    'id' => $img->id,
                    'url' => asset('storage/' . $img->image),
                    'path' => $img->image,
                ]),
                'attribute_values' => $v->attributeValues->map(fn ($av) => [
                    'attribute_id' => $av->attribute_id,
                    'value_id' => $av->attribute_value_id,
                ]),
                'custom_values' => $v->customValues->map(function ($cv) {
                    // HasTranslations fallback returns base attribute as raw JSON string
                    // (skips cast). Decode explicitly so frontend gets array.
                    $rawJson = $cv->getRawOriginal('value_json');
                    return [
                        'field_id' => $cv->category_custom_field_id,
                        'value_text' => $cv->value_text,
                        'value_number' => $cv->value_number,
                        'value_date' => $cv->value_date,
                        'value_json' => $rawJson ? json_decode($rawJson, true) : null,
                        'translations' => $cv->translations,
                    ];
                }),
                'branch_stocks' => $v->branchStocks->map(fn ($s) => [
                    'branch_id' => $s->branch_id,
                    'is_listed' => (int) $s->is_listed,
                    'stock_status' => (int) $s->stock_status,
                    'available' => (int) $s->available,
                    'reserved' => (int) $s->reserved,
                    'min_alert' => (int) $s->min_alert,
                    // Unlimited stock is per-branch (PVSS) now, not product-level.
                    'is_unlimited_stock' => (int) $s->is_unlimited_stock,
                    // Branch-wise pricing (null until set for that branch).
                    'price' => $s->price !== null ? (float) $s->price : null,
                    'discounted_price' => $s->discounted_price !== null ? (float) $s->discounted_price : null,
                    'pricing_slabs' => ProductHelper::normalizeSlabs($s->pricing_slabs),
                    'purchase_price' => $s->purchase_price !== null ? (float) $s->purchase_price : null,
                    'is_tax_inclusive' => (bool) $s->is_tax_inclusive,
                ]),
                'translations' => $v->translations,
            ];
        });

        $payload = $product->toArray();
        $payload['translations'] = $translationsArr;
        $payload['attribute_value_ids'] = $product->variants
            ->flatMap(fn (ProductVariant $v) => $v->attributeValues->map(fn ($av) => [
                'attribute_id' => $av->attribute_id,
                'value_id' => $av->attribute_value_id,
            ]))
            ->unique(fn ($row) => $row['attribute_id'] . '-' . $row['value_id'])
            ->values();
        $payload['variants'] = $variantsOut;
        $payload['image_url'] = $product->image ? asset('storage/' . $product->image) : null;

        return CommonHelper::responseWithData($payload);
    }

    public function delete(Request $request)
    {
        if ($request->filled('product_id')) {
            $product = Product::find((int) $request->input('product_id'));
            if (!$product) {
                return CommonHelper::responseError('product_already_deleted');
            }
            $variantIds = ProductVariant::where('product_id', $product->id)->pluck('id');
            if ($variantIds->count() && OrderItem::whereIn('product_variant_id', $variantIds)->exists()) {
                return CommonHelper::responseError('this_product_variant_cannot_be_deleted_as_it_exists_in_orders');
            }
            ProductVariant::whereIn('id', $variantIds)->delete();
            $product->delete();
            return CommonHelper::responseSuccess('product_deleted_successfully');
        }

        if (isset($request->id)) {
            $productVariant = ProductVariant::find($request->id);

            if ($productVariant) {
                // Check if the product variant exists in order_items
                $orderItemExists = OrderItem::where('product_variant_id', $productVariant->id)->exists();

                if ($orderItemExists) {
                    return CommonHelper::responseError('this_product_variant_cannot_be_deleted_as_it_exists_in_orders');
                }

                $product_id = $productVariant->product_id;

                $variantDeleteStatus = $productVariant->delete();
                $variants = ProductVariant::where('product_id', $product_id)->get();

                if ($variantDeleteStatus == true && $variants->count() == 0) {
                    $product = Product::find($product_id);
                    if ($product) {
                        $product->delete();
                    }
                }

                return CommonHelper::responseSuccess('product_deleted_successfully');
            } else {
                return CommonHelper::responseError('product_already_deleted');
            }
        }

        return CommonHelper::responseError('invalid_request');
    }

    public function changeStatus(Request $request)
    {
        if (isset($request->id)) {
            $product = Product::find($request->id);
            if ($product) {
                $product->status = ($product->status == 1) ? 0 : 1;
                $product->save();
                return CommonHelper::responseSuccess('products_status_updated_successfully');
            } else {
                return CommonHelper::responseSuccess('products_record_not_found');
            }
        }
    }

    public function getProduct(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_id' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $product_id = $request->product_id;

        $product = Product::withAllTranslations()
            ->with('images', 'variants.images', 'variants.unit', 'category', 'brand')
            ->where('id', $product_id)
            ->first();

        if (!$product) {
            return CommonHelper::responseError('product_not_found');
        }

        $productArray = $product->toArray();
        $productArray['translations'] = collect($product->getAllActiveLanguageTranslations())
            ->keyBy('language_code')
            ->toArray();

        return CommonHelper::responseWithData($productArray);
    }

    /**
     * Shared Gemini call. Returns ['data' => array] on success or ['error' => string].
     */
    private function callGeminiJson(string $prompt): array
    {
        $apiKey = Setting::get_value('text_gen_key');
        if (empty($apiKey)) {
            return ['error' => 'Google Gemini API key not configured'];
        }

        $url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=' . $apiKey;
        $payload = [
            'contents' => [
                ['parts' => [['text' => $prompt]]],
            ],
            'generationConfig' => [
                'response_mime_type' => 'application/json',
            ],
        ];

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode($payload),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_TIMEOUT => 60,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Accept: application/json',
            ],
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        unset($ch);

        if ($curlError) {
            return ['error' => 'Network error: ' . $curlError];
        }
        if ($httpCode !== 200 || empty($response)) {
            return ['error' => 'Failed to generate content from Gemini'];
        }

        $data = json_decode($response, true);
        $text = $data['candidates'][0]['content']['parts'][0]['text'] ?? '';
        if (empty($text)) {
            return ['error' => 'Empty AI response'];
        }

        $parsed = json_decode($text, true);
        if (!$parsed) {
            return ['error' => 'Invalid AI JSON format'];
        }

        return ['data' => $parsed];
    }

    /**
     * Generate product description + short description from the product name using Gemini AI.
     */
    public function generateProductDescription(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_name' => 'required|string|max:255',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        try {
            $name = trim($request->input('product_name'));
            $category = trim((string) $request->input('category', ''));

            $prompt = "
            You are an expert e-commerce copywriter.

            Product Name: \"{$name}\"
            " . ($category !== '' ? "Category: \"{$category}\"" : '') . "

            Instructions:
            1. Generate a concise short_description strictly under 160 characters (including spaces), plain text, no HTML.
            2. Write a high-quality, original product description as valid, well-structured HTML only (no markdown).
            3. Use tags such as <p>, <ul>, <li>, <strong> where appropriate. Do NOT include <h1>.
            4. Highlight key features, benefits and usage. Keep it factual and persuasive without keyword stuffing.
            5. Description word count between 80 and 300 words.
            6. No inline styles, scripts, comments, emojis, external links, or AI disclaimers.
            7. Return ONLY a valid JSON object — no extra text before or after.

            Required JSON Format:
            {
              \"short_description\": \"\",
              \"description\": \"<p>...</p>\"
            }
            ";

            $res = $this->callGeminiJson($prompt);
            if (isset($res['error'])) {
                return CommonHelper::responseError($res['error']);
            }

            $out = $res['data'];
            if (!empty($out['short_description']) && mb_strlen($out['short_description']) > 160) {
                $out['short_description'] = mb_substr($out['short_description'], 0, 157) . '...';
            }

            return CommonHelper::responseWithData($out);
        } catch (\Exception $e) {
            Log::error('Gemini Product Desc Error: ' . $e->getMessage());
            return CommonHelper::responseError('AI generation failed');
        }
    }

    /**
     * Generate SEO fields (meta title/description/keywords) from product name + description using Gemini AI.
     */
    public function generateProductSeo(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_name' => 'required|string|max:255',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        try {
            $name = trim($request->input('product_name'));
            $description = trim(strip_tags((string) $request->input('description', '')));
            if (mb_strlen($description) > 1500) {
                $description = mb_substr($description, 0, 1500);
            }

            $prompt = "
            You are an SEO specialist for an e-commerce branch.

            Product Name: \"{$name}\"
            " . ($description !== '' ? "Product Description: \"{$description}\"" : '') . "

            Instructions:
            1. meta_title: compelling, at most 60 characters, must include the product name.
            2. meta_description: persuasive summary, between 120 and 160 characters.
            3. meta_keywords: 6 to 12 comma-separated relevant keywords (no '#').
            4. Plain text only. No HTML, no markdown, no emojis, no AI disclaimers.
            5. Return ONLY a valid JSON object — no extra text before or after.

            Required JSON Format:
            {
              \"meta_title\": \"\",
              \"meta_description\": \"\",
              \"meta_keywords\": \"\"
            }
            ";

            $res = $this->callGeminiJson($prompt);
            if (isset($res['error'])) {
                return CommonHelper::responseError($res['error']);
            }

            $out = $res['data'];
            if (!empty($out['meta_title']) && mb_strlen($out['meta_title']) > 70) {
                $out['meta_title'] = mb_substr($out['meta_title'], 0, 67) . '...';
            }
            if (!empty($out['meta_description']) && mb_strlen($out['meta_description']) > 170) {
                $out['meta_description'] = mb_substr($out['meta_description'], 0, 167) . '...';
            }

            return CommonHelper::responseWithData($out);
        } catch (\Exception $e) {
            Log::error('Gemini Product SEO Error: ' . $e->getMessage());
            return CommonHelper::responseError('AI generation failed');
        }
    }

    public function generateSeo(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        try {
            $name = trim($request->input('name'));
            $context = trim((string) $request->input('context', ''));
            $description = trim(strip_tags((string) $request->input('description', '')));
            if (mb_strlen($description) > 1500) {
                $description = mb_substr($description, 0, 1500);
            }

            $prompt = "
            You are an SEO specialist for an e-commerce website.

            " . ($context !== '' ? "Page/Content Type: \"{$context}\"\n" : '') . "
            Title: \"{$name}\"
            " . ($description !== '' ? "Content: \"{$description}\"" : '') . "

            Instructions:
            1. meta_title: compelling, at most 60 characters, must include the title.
            2. meta_description: persuasive summary, between 120 and 160 characters.
            3. meta_keywords: 6 to 12 comma-separated relevant keywords (no '#').
            4. Plain text only. No HTML, no markdown, no emojis, no AI disclaimers.
            5. Return ONLY a valid JSON object — no extra text before or after.

            Required JSON Format:
            {
              \"meta_title\": \"\",
              \"meta_description\": \"\",
              \"meta_keywords\": \"\"
            }
            ";

            $res = $this->callGeminiJson($prompt);
            if (isset($res['error'])) {
                return CommonHelper::responseError($res['error']);
            }

            $out = $res['data'];
            if (!empty($out['meta_title']) && mb_strlen($out['meta_title']) > 70) {
                $out['meta_title'] = mb_substr($out['meta_title'], 0, 67) . '...';
            }
            if (!empty($out['meta_description']) && mb_strlen($out['meta_description']) > 170) {
                $out['meta_description'] = mb_substr($out['meta_description'], 0, 167) . '...';
            }

            return CommonHelper::responseWithData($out);
        } catch (\Exception $e) {
            Log::error('Gemini SEO Error: ' . $e->getMessage());
            return CommonHelper::responseError('AI generation failed');
        }
    }

    /**
     * Variants of one product, shaped for the listing's quick-look modal: what the
     * variant is, what it costs and whether it can be sold. Price and stock are
     * per-branch (PVSS), so each variant carries its listed branch rows.
     */
    public function getProductVariants(Request $request)
    {
        $product = Product::with([
            'variants' => fn ($q) => $q->orderBy('sort_order')->orderBy('id'),
            'variants.translations',
            'variants.branchStocks.branch:id,name',
            'variants.attributeValues.attribute.translations',
            'variants.attributeValues.attributeValue.translations',
        ])->find($request->input('product_id'));

        if (!$product) {
            return CommonHelper::responseError('product_not_found');
        }

        $variants = $product->variants->map(function (ProductVariant $v) {
            $listed = $v->branchStocks->where('is_listed', 1);
            // Effective price = the discounted one when set, else the selling price.
            $prices = $listed->map(fn ($s) => (float) $s->discounted_price > 0
                ? (float) $s->discounted_price
                : (float) $s->price)->filter(fn ($n) => $n > 0);

            return [
                'id'         => $v->id,
                'name'       => $v->name,
                'sku'        => $v->sku,
                'image'      => $v->image ? asset('storage/' . $v->image) : '',
                'attributes' => $v->attributeValues->map(fn ($av) => [
                    'name'  => optional($av->attribute)->name,
                    'value' => optional($av->attributeValue)->value,
                ])->filter(fn ($a) => $a['name'] && $a['value'])->values(),
                'min_price'  => $prices->count() ? (float) $prices->min() : 0,
                'max_price'  => $prices->count() ? (float) $prices->max() : 0,
                'available'  => (int) $listed->sum(fn ($s) => (int) $s->available),
                'unlimited'  => (bool) $listed->contains(fn ($s) => (int) $s->is_unlimited_stock === 1),
                'branches'     => $listed->map(fn ($s) => [
                    'branch_id'   => (int) $s->branch_id,
                    'branch_name' => optional($s->branch)->name,
                    'price'      => $s->price !== null ? (float) $s->price : null,
                    'discounted_price' => $s->discounted_price !== null ? (float) $s->discounted_price : null,
                    'available'  => (int) $s->available,
                    'is_unlimited_stock' => (int) $s->is_unlimited_stock,
                    'stock_status' => (int) $s->stock_status,
                ])->values(),
            ];
        })->values();

        return CommonHelper::responseWithData([
            'product_id' => (int) $product->id,
            'name'       => $product->name,
            'variants'   => $variants,
        ]);
    }

    /* =====================================================================
     * Recommendations (cross-sell / up-sell) — admin management.
     * ===================================================================== */

    /** Cross-sell + up-sell products currently set on a product. */
    public function getRecommendations(Request $request)
    {
        $validator = Validator::make($request->all(), ['product_id' => 'required'], []);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $productId = (int) $request->product_id;
        $rows = ProductRecommendation::where('product_id', $productId)
            ->orderBy('row_order')->orderBy('id')
            ->get(['related_product_id', 'type']);

        $relatedIds = $rows->pluck('related_product_id')->unique()->all();
        $cards = $this->recommendationCards($relatedIds);

        $out = ['cross_sell' => [], 'upsell' => []];
        foreach ($rows as $r) {
            if (isset($cards[$r->related_product_id])) {
                $out[$r->type][] = $cards[$r->related_product_id];
            }
        }
        return CommonHelper::responseWithData($out);
    }

    /** Search products to add as recommendations (excludes the owner product). */
    public function searchRecommendationProducts(Request $request)
    {
        $productId = (int) $request->input('product_id', 0);
        $search    = trim((string) $request->input('search', ''));
        $limit     = (int) ($request->input('limit', 20));
        $limit     = $limit > 0 ? min($limit, 50) : 20;
        $categoryId = (int) $request->input('category_id', 0);

        $query = Product::query()->where('status', 1)->where('is_draft', 0);
        if ($productId) {
            $query->where('id', '!=', $productId);
        }
        if ($categoryId) {
            $query->where('category_id', $categoryId);
        }
        if ($search !== '') {
            $like = '%' . $search . '%';
            $query->where(function ($q) use ($like) {
                $q->where('slug', 'like', $like)
                    ->orWhereHas('variants', function ($qv) use ($like) {
                        $qv->where('name', 'like', $like)->orWhere('sku', 'like', $like);
                    });
            });
        }
        $ids = $query->orderByDesc('id')->limit($limit)->pluck('id')->all();

        return CommonHelper::responseWithData(array_values($this->recommendationCards($ids)));
    }

    /** Replace a product's recommendation set for one type (cross_sell | upsell). */
    public function saveRecommendations(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_id' => 'required',
            'type'       => 'required|in:cross_sell,upsell',
        ], []);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $productId = (int) $request->product_id;
        $type      = $request->type;
        $relatedIds = $request->input('related_product_ids', []);
        if (is_string($relatedIds)) {
            $relatedIds = array_filter(array_map('intval', explode(',', $relatedIds)));
        }
        $relatedIds = array_values(array_unique(array_filter(array_map('intval', (array) $relatedIds), fn($id) => $id > 0 && $id !== $productId)));

        // 3 attempts: a concurrent save for the same product can briefly deadlock on
        // the unique index; Laravel re-runs the closure on a deadlock.
        DB::transaction(function () use ($productId, $type, $relatedIds) {
            ProductRecommendation::where('product_id', $productId)->where('type', $type)->delete();
            $order = 0;
            foreach ($relatedIds as $rid) {
                ProductRecommendation::create([
                    'product_id'         => $productId,
                    'related_product_id' => $rid,
                    'type'               => $type,
                    'row_order'          => $order++,
                ]);
            }
        }, 3);

        return CommonHelper::responseSuccess('recommendations_saved_successfully');
    }

    /**
     * Minimal product cards for the recommendations UI, keyed by product id:
     * { id, name, sku, image_url, price }. Cheapest listed variant drives name/price.
     */
    private function recommendationCards(array $productIds): array
    {
        if (empty($productIds)) {
            return [];
        }
        $products = Product::with(['variants.branchStocks'])->whereIn('id', $productIds)->get();
        $cards = [];
        foreach ($products as $p) {
            // Price is per-branch (PVSS): representative = cheapest listed branch price.
            foreach ($p->variants as $v) {
                ProductHelper::applyBranchPrice($v);
            }
            $variant = $p->variants
                ->sortBy(fn($v) => (float) $v->discounted_price > 0 ? (float) $v->discounted_price : (float) $v->price)
                ->first();
            $price = $variant
                ? ((float) $variant->discounted_price > 0 ? (float) $variant->discounted_price : (float) $variant->price)
                : 0;
            $image = $p->image_url ?? null;
            if (empty($image) && $variant && !empty($variant->image)) {
                $image = asset('storage/' . $variant->image);
            }
            $cards[$p->id] = [
                'id'        => (int) $p->id,
                'name'      => $variant ? (string) $variant->name : (string) ($p->name ?? ''),
                'sku'       => $variant ? $variant->sku : null,
                'image_url' => $image,
                'price'     => $price,
            ];
        }
        return $cards;
    }
}
