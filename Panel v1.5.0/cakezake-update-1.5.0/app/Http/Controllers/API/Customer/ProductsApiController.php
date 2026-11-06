<?php

namespace App\Http\Controllers\API\Customer;

use App\Helpers\AddonHelper;
use App\Helpers\CommonHelper;
use App\Helpers\CustomerProductShaper;
use App\Helpers\HomeLayoutResolver;
use App\Helpers\ProductHelper;
use App\Services\TaxService;
use App\Http\Controllers\Controller;
use App\Models\Attribute;
use App\Models\AttributeValue;
use App\Models\Brand;
use App\Models\Cart;
use App\Models\Favorite;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\Branch;
use App\Models\Setting;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use App\Models\ProductRating;
use App\Models\ProductStockAlert;
use App\Models\ProductVariantBranchStock;
use App\Models\RatingImages;
use App\Models\RecentlyVisitedProduct;
use Illuminate\Validation\Rule;

class ProductsApiController extends Controller
{
    /**
     * Customer product listing (card view).
     *
     * Required: latitude, longitude.
     * Optional:
     *   - sales_channel (quick|ecommerce)
     *   - category_id   (CSV)
     *   - brand_ids      (CSV)
     *   - branch_id, country_id, slug
     *   - search         (matches name / slug / tags)
     *   - tag_names      (CSV)
     *   - min_price, max_price (variant final-price bounds, ex-tax)
     *   - min_discount_percent, max_discount_percent (% off; either bound implies
     *                     a real discount, so full-price products drop out)
     *   - attribute_value_ids (CSV, from the filters API)
     *   - data_source    (manual | new_arrivals | top_selling | trending |
     *                     best_rated | discounted | recently_visited | buy_again |
     *                     most_favorited | category | brand)
     *   - manual_product_ids (CSV; required when data_source=manual)
     *   - sort           (price_low | price_high | new | popular | discount)
     *   - limit, offset
     *
     * Response is fully language-flat: every translatable string is already
     * resolved to the current request language (HasTranslations trait sees
     * LanguageService::getCurrentId()). No nested `translations` object.
     */
    public function getProducts(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude'  => 'required',
            'longitude' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $channel = strtolower(trim((string) $request->header('channel')));
        if (!in_array($channel, ['quick', 'ecommerce'], true)) {
            return CommonHelper::responseError(__('invalid_channel_header'));
        }

        $lat  = (float) $request->latitude;
        $lng  = (float) $request->longitude;
        $zone = CommonHelper::getDeliverableCity($lat, $lng, $channel);
        if (!$zone) {
            return CommonHelper::responseWithData([], 0);
        }

        $branchIds = Branch::where('status', 1)
            ->where('zone_id', $zone->id)
            ->get()
            ->pluck('id')
            ->all();
        if (empty($branchIds)) {
            return CommonHelper::responseWithData([], 0);
        }
        $branchIdsSql = implode(',', array_map('intval', $branchIds));

        $userId = $request->user('api-customers') ? $request->user('api-customers')->id : null;
        $limit  = (int) ($request->limit ?? 10);
        $offset = (int) ($request->offset ?? 0);
        $limit  = $limit > 0 ? min($limit, 100) : 10;

        $query = Product::query()
            ->where('status', 1)
            ->where('is_draft', 0)
            ->taxonomyActive()
            ->notAddonOnly()
            ->whereIn('sales_channel', [$channel, 'both'])
            // Visibility: product shown if at least one variant has a listed
            // PVSS row in a zone branch. Stock-status/available drive in_stock,
            // not visibility.
            ->whereExists(function ($q) use ($branchIds) {
                $q->select(DB::raw(1))
                    ->from('product_variants as pv')
                    ->join('product_variant_branch_stocks as pvss', 'pvss.product_variant_id', '=', 'pv.id')
                    ->whereColumn('pv.product_id', 'products.id')
                    ->whereIn('pvss.branch_id', $branchIds)
                    ->where('pvss.is_listed', 1);
            });

        $filterMode = self::filterMode($request);
        if ($request->filled('category_id')) {
            $ids = array_values(array_unique(array_filter(
                array_map('intval', explode(',', (string) $request->category_id))
            )));

            if (empty($ids) && $filterMode !== 'exclude') {
                return CommonHelper::responseWithData([], 0);
            }

            if (strtolower((string) $request->input('data_source', '')) === 'category') {
                $expanded = [];
                foreach ($ids as $rid) {
                    foreach (HomeLayoutResolver::categorySubtreeIds((int) $rid) as $sid) {
                        $expanded[$sid] = true;
                    }
                }
                $ids = array_keys($expanded);
            }
            self::applyIdFilter($query, 'category_id', $ids, $filterMode);
        }
        if ($request->filled('brand_ids')) {
            $ids = array_values(array_filter(array_map('intval', explode(',', $request->brand_ids))));
            self::applyIdFilter($query, 'brand_id', $ids, $filterMode);
        }
        // made_in is free text now (not a country id) — no country-id filter.
        if ($request->filled('slug')) {
            $query->where('slug', $request->slug);
        }
        // Ids of a fuzzy (misspelled-search) fallback, best match first — used further down
        // to keep that ranking when the caller did not ask for a specific sort.
        $fuzzyOrderIds = [];
        if ($request->filled('search')) {
            $term = trim((string) $request->search);
            if ($term !== '') {
                $words = preg_split('/\s+/u', $term, -1, PREG_SPLIT_NO_EMPTY) ?: [$term];
                // Bound the join count on a pathological query.
                $words = array_slice($words, 0, 8);

                // Every word must match somewhere on the product (name, variant, attribute...).
                $exact = function ($q) use ($words) {
                    foreach ($words as $word) {
                        $like = '%' . $word . '%';
                        // A category name matches its whole subtree: products hang off leaf
                        // categories, so searching a parent ("Beverages") must still return them.
                        $categoryIds = $this->categoryIdsMatching($word);
                        $q->where(function ($qq) use ($like, $categoryIds) {
                            $qq->where('products.name', 'like', $like)
                                ->orWhere('slug', 'like', $like)
                                ->orWhere('tags', 'like', $like)
                                // Translated product name.
                                ->orWhereHas('translations', fn($t) => $t->where('name', 'like', $like))
                                // Variant name.
                                ->orWhereHas('variants', fn($qv) => $qv->where('name', 'like', $like))
                                // Attributes: attribute name + value (base + translated).
                                ->orWhereHas('variants.attributeValues.attribute', fn($qa) => $qa
                                    ->where('name', 'like', $like)
                                    ->orWhereHas('translations', fn($tt) => $tt->where('name', 'like', $like)))
                                ->orWhereHas('variants.attributeValues.attributeValue', fn($qav) => $qav
                                    ->where('value', 'like', $like)
                                    ->orWhereHas('translations', fn($tt) => $tt->where('value', 'like', $like)))
                                // Custom section field values (text).
                                ->orWhereHas('variants.customValues', fn($qc) => $qc->where('value_text', 'like', $like))
                                // Brand name (base + translated) — searching a brand lists its products.
                                ->orWhereHas('brand', fn($qb) => $qb
                                    ->where('name', 'like', $like)
                                    ->orWhereHas('translations', fn($tt) => $tt->where('name', 'like', $like)));

                            if (!empty($categoryIds)) {
                                $qq->orWhereIn('products.category_id', $categoryIds);
                            }
                        });
                    }
                };

                // Spelling fallback: "pigen" / "biscut" should still find Pigeon / Biscuit.
                // Only runs when the literal search found nothing, so a normal search costs
                // exactly what it did before.
                $hasExact = (clone $query)->where($exact)->exists();
                $fuzzyIds = $hasExact ? [] : $this->fuzzyProductIds($query, $words);

                if (!empty($fuzzyIds)) {
                    $fuzzyOrderIds = $fuzzyIds;
                    $query->whereIn('products.id', $fuzzyIds);
                } else {
                    $query->where($exact);
                }
            }
        }

        // Sort key — also drives which variant is shown outside `variants` so the
        // representative reflects the sort (e.g. price_high pins the dearest variant).
        $sort = strtolower((string) $request->input('sort', 'new'));

        // Price range (ex-tax final price). Captured for representative-variant
        // selection during shaping too, so the card reflects a variant in range.
        $priceMin = null;
        $priceMax = null;
        if ($request->filled('min_price') || $request->filled('max_price')) {
            $priceMin = (float) ($request->min_price ?? 0);
            $priceMax = $request->filled('max_price') ? (float) $request->max_price : null;
            $query->whereHas('variants.branchStocks', function ($q) use ($priceMin, $priceMax, $branchIds) {
                $q->whereIn('branch_id', $branchIds)->where('is_listed', 1)
                    ->whereRaw('IF(discounted_price > 0, discounted_price, price) >= ?', [$priceMin]);
                if ($priceMax !== null) {
                    $q->whereRaw('IF(discounted_price > 0, discounted_price, price) <= ?', [$priceMax]);
                }
            });
        }

        // Discount range, as a percentage off the variant's own price. A home-builder
        // banner reading "40% off and above" sends min_discount_percent=40; one reading
        // "Up to 50% off" sends max_discount_percent=50.
        //
        // Any discount bound implies a real discount: a product at full price is not
        // "up to 50% off", so undiscounted variants are excluded whichever bound is set.
        [$discMin, $discMax] = self::discountBounds($request);
        if ($discMin !== null || $discMax !== null) {
            $query->whereHas('variants.branchStocks', function ($q) use ($discMin, $discMax, $branchIds) {
                $q->whereIn('branch_id', $branchIds)->where('is_listed', 1)
                    ->where('price', '>', 0)
                    ->where('discounted_price', '>', 0)
                    ->whereColumn('discounted_price', '<', 'price');
                if ($discMin !== null) {
                    $q->whereRaw('((price - discounted_price) / price) * 100 >= ?', [$discMin]);
                }
                if ($discMax !== null) {
                    $q->whereRaw('((price - discounted_price) / price) * 100 <= ?', [$discMax]);
                }
            });
        }

        // Attribute facet filter: CSV of attribute_value_ids (from the filters API).
        // Values are grouped by their attribute — OR within the same attribute,
        // AND across attributes (a product matches if it has a variant carrying
        // one of the selected values for every selected attribute).
        // $attrGroups (attribute_id => [value_ids]) is reused during shaping to
        // explode a product into one card per matching variant.
        $attrGroups = [];
        if ($request->filled('attribute_value_ids')) {
            $valueIds = array_values(array_filter(array_map('intval', explode(',', $request->attribute_value_ids))));
            if (!empty($valueIds)) {
                foreach (AttributeValue::whereIn('id', $valueIds)->pluck('attribute_id', 'id') as $vid => $aid) {
                    $attrGroups[(int) $aid][] = (int) $vid;
                }
                foreach ($attrGroups as $vids) {
                    $query->whereHas('variants.attributeValues', function ($q) use ($vids) {
                        $q->whereIn('attribute_value_id', $vids);
                    });
                }
            }
        }

        // Similar products: given a source product id, return products that share at
        // least one of its (comma-separated) tags OR sit in the same category, minus
        // the source itself. Tag matches rank first, same-category after.
        $isSimilar = false;
        $similarProductId = (int) $request->input('is_similar_product_id', 0);
        if ($similarProductId > 0) {
            $source = Product::find($similarProductId);
            if (!$source) {
                return CommonHelper::responseWithData([], 0);
            }
            $tags  = array_values(array_filter(array_map('trim', explode(',', (string) $source->tags))));
            $catId = (int) $source->category_id;

            // Nothing to match on -> no similar products.
            if (empty($tags) && !$catId) {
                return CommonHelper::responseWithData([], 0);
            }

            $query->where('id', '!=', $similarProductId)
                ->where(function ($q) use ($tags, $catId) {
                    foreach ($tags as $t) {
                        $q->orWhere('tags', 'like', '%' . $t . '%');
                    }
                    if ($catId) {
                        $q->orWhere('category_id', $catId);
                    }
                });

            // Order: tag-related first, then category-related, newest within each group.
            if (!empty($tags)) {
                $conds = [];
                $binds = [];
                foreach ($tags as $t) {
                    $conds[] = 'tags LIKE ?';
                    $binds[] = '%' . $t . '%';
                }
                $query->orderByRaw('(CASE WHEN ' . implode(' OR ', $conds) . ' THEN 1 ELSE 0 END) DESC', $binds);
            }
            if ($catId) {
                $query->orderByRaw('(CASE WHEN category_id = ? THEN 1 ELSE 0 END) DESC', [$catId]);
            }
            $query->orderByDesc('id');
            $isSimilar = true;
        }

        // data_source preset ordering / filtering (mirrors Home Builder product_slider sources).
        $dataSource = $isSimilar ? '' : strtolower((string) $request->input('data_source', ''));
        $orderApplied = $isSimilar;
        switch ($dataSource) {
            case 'manual':
                $ids = array_values(array_filter(array_map('intval', explode(',', (string) $request->manual_product_ids))));
                if (empty($ids)) {
                    return CommonHelper::responseWithData([], 0);
                }
                $query->whereIn('id', $ids)
                    ->orderByRaw('FIELD(id,' . implode(',', $ids) . ')');
                $orderApplied = true;
                break;

            case 'category':
                $query->orderByDesc('id');
                $orderApplied = true;
                break;

            case 'new_arrivals':
                $query->orderByDesc('id');
                $orderApplied = true;
                break;

            case 'top_selling':
                $query->orderByDesc(DB::raw('(
                    SELECT COUNT(*)
                    FROM order_items oi
                    JOIN product_variants pv ON oi.product_variant_id = pv.id
                    WHERE pv.product_id = products.id
                )'));
                $orderApplied = true;
                break;

            case 'best_rated':
                $query->orderByDesc(DB::raw('(SELECT AVG(rate) FROM product_ratings WHERE product_id = products.id)'));
                $orderApplied = true;
                break;

            case 'discounted':
                $query->whereHas('variants.branchStocks', function ($q) use ($branchIds) {
                    $q->whereIn('branch_id', $branchIds)->where('is_listed', 1)
                        ->whereColumn('discounted_price', '<', 'price')
                        ->where('discounted_price', '>', 0);
                })->orderByDesc('id');
                $orderApplied = true;
                break;

            case 'recently_visited':
                if (!$userId) {
                    return CommonHelper::responseWithData([], 0);
                }
                $ids = RecentlyVisitedProduct::where('user_id', $userId)
                    ->orderByDesc('visited_at')
                    ->limit(50)
                    ->pluck('product_id')
                    ->all();
                if (empty($ids)) {
                    return CommonHelper::responseWithData([], 0);
                }
                $query->whereIn('id', $ids)
                    ->orderByRaw('FIELD(id,' . implode(',', $ids) . ')');
                $orderApplied = true;
                break;

            case 'trending':
                // Most ordered in the last 30 days (windowed top_selling).
                $query->orderByDesc(DB::raw('(
                    SELECT COUNT(*)
                    FROM order_items oi
                    JOIN product_variants pv ON oi.product_variant_id = pv.id
                    WHERE pv.product_id = products.id
                      AND oi.created_at >= (NOW() - INTERVAL 30 DAY)
                )'));
                $orderApplied = true;
                break;

            case 'buy_again':
                // Products this customer has ordered before, most recent first.
                if (!$userId) {
                    return CommonHelper::responseWithData([], 0);
                }
                $ids = DB::table('order_items as oi')
                    ->join('product_variants as pv', 'oi.product_variant_id', '=', 'pv.id')
                    ->where('oi.user_id', $userId)
                    ->orderByDesc('oi.created_at')
                    ->pluck('pv.product_id')
                    ->unique()
                    ->values()
                    ->all();
                if (empty($ids)) {
                    return CommonHelper::responseWithData([], 0);
                }
                $query->whereIn('id', $ids)
                    ->orderByRaw('FIELD(id,' . implode(',', $ids) . ')');
                $orderApplied = true;
                break;

            case 'most_favorited':
                // Wishlisted by the most customers (social proof).
                $query->orderByDesc(DB::raw('(
                    SELECT COUNT(*) FROM favorites WHERE favorites.product_id = products.id
                )'));
                $orderApplied = true;
                break;
        }

        if (!$orderApplied) {
            // Price is per-branch (PVSS): sort by the effective price in the zone's branches.
            $pvssJoin = "FROM product_variant_branch_stocks pvss
                JOIN product_variants pv ON pv.id = pvss.product_variant_id
                WHERE pv.product_id = products.id AND pvss.is_listed = 1
                  AND pvss.branch_id IN ($branchIdsSql)";
            if ($sort === 'price_low') {
                $query->orderByRaw("(SELECT MIN(IF(pvss.discounted_price > 0, pvss.discounted_price, pvss.price)) $pvssJoin) ASC");
            } elseif ($sort === 'price_high') {
                $query->orderByRaw("(SELECT MAX(IF(pvss.discounted_price > 0, pvss.discounted_price, pvss.price)) $pvssJoin) DESC");
            }  elseif ($sort === 'discount') {
                $query->orderByDesc(DB::raw("(SELECT MAX(IF(pvss.discounted_price > 0 AND pvss.price > 0, (pvss.price - pvss.discounted_price) / pvss.price, 0)) $pvssJoin)"));
            } elseif ($sort === 'popular') {
                $query->orderByDesc(DB::raw('(
                    SELECT COUNT(*)
                    FROM order_items oi
                    JOIN product_variants pv ON oi.product_variant_id = pv.id
                    WHERE pv.product_id = products.id
                )'));
            } elseif (!empty($fuzzyOrderIds)) {
                // Closest spelling match first — plain "newest" would bury it.
                $query->orderByRaw('FIELD(products.id,' . implode(',', $fuzzyOrderIds) . ')');
            } else {
                $query->orderByDesc('id');
            }
        }

        $total = (clone $query)->count();

        $products = $query->with([
            'variants',
            'variants.images',
            'variants.branchStocks' => fn($q) => $q->whereIn('branch_id', $branchIds),
            'variants.attributeValues.attribute.translations',
            'variants.attributeValues.attributeValue.translations',
            'brand.translations',
            'category.translations',
            'ratings',
            'translations',
        ])
            ->skip($offset)
            ->take($limit)
            ->get();

        // Price is per-branch (PVSS): copy the zone branch's pricing onto each variant so
        // representative-variant selection + price-range helpers read the branch price.
        foreach ($products as $p) {
            foreach ($p->variants as $v) {
                ProductHelper::applyBranchPrice($v);
            }
        }

        $favoriteIds = [];
        if ($userId && $products->isNotEmpty()) {
            CustomerProductShaper::setNotifyRequestedVariantIds(
                ProductStockAlert::waiting()->where('user_id', $userId)
                    ->whereIn('product_id', $products->pluck('id'))
                    ->pluck('product_variant_id')->all()
            );
            $favoriteIds = Favorite::where('user_id', $userId)
                ->whereIn('product_id', $products->pluck('id')->all())
                ->pluck('product_id')
                ->all();
        }

        // One zone == one branch, so branch + delivery time are the same for every
        // product in the zone — resolve once. Delivery time is quick commerce only.
        $delivery      = CustomerProductShaper::zoneDelivery($zone, $lat, $lng);
        $branchName     = $delivery['branch_name'];
        $timeToDeliver = $channel === 'quick' ? $delivery['time_to_deliver'] : 0;

        $currency = CommonHelper::countryCurrency($zone?->country);
        // Card shaping. Without an attribute filter the representative variant
        // (the data shown outside `variants`) stays the cheapest listed one.
        // With an attribute filter, a product is expanded into one card per
        // matching listed variant — so e.g. selecting Red + Blue returns the
        // same product twice, each pinned to its colour variant.
        $cards = [];
        foreach ($products as $p) {
            if (!empty($attrGroups)) {
                $matched = $this->matchingCardVariantIds($p, $attrGroups, $priceMin, $priceMax, $discMin, $discMax);
                foreach ($matched as $vid) {
                    $cards[] = CustomerProductShaper::shapeCard($p, $favoriteIds, $timeToDeliver, $branchName, $currency, $vid);
                }
            } else {
                // Representative variant follows the sort (and price range), so
                // price_high shows the dearest variant etc. Defaults to the cheapest in range.
                $repId = $this->sortRepresentativeVariantId($p, $sort, $priceMin, $priceMax, $discMin, $discMax);
                $cards[] = CustomerProductShaper::shapeCard($p, $favoriteIds, $timeToDeliver, $branchName, $currency, $repId);
            }
        }

        return CommonHelper::responseWithData($cards, $total);
    }

    /**
     * Products whose text is a near-miss for the search words (typos, dropped or swapped
     * letters). Only used when the literal search matched nothing.
     *
     * SQL cannot do this on its own — MySQL has no similarity function — so it narrows the
     * field with a cheap prefix/phonetic filter, then scores the candidates in PHP with
     * levenshtein. Every search word must find a near match on the product, mirroring the
     * AND semantics of the literal search.
     */
    private function fuzzyProductIds($base, array $words, int $maxCandidates = 400, int $maxResults = 60): array
    {
        $words = array_values(array_filter(array_map(
            fn ($w) => mb_strtolower(trim((string) $w)),
            $words
        ), fn ($w) => mb_strlen($w) >= 3));
        if (empty($words)) {
            return []; // 1-2 letter terms are all "near" everything; not worth guessing.
        }

        // Narrow the field with the word's 3-letter runs: a single typo can only damage the
        // runs that cover it, so at least one survives and still matches the real product
        // ("kasar" keeps "sar" of "kesar", "mengo" keeps "ngo" of "mango"). SOUNDEX picks up
        // the phonetic misses on top ("fone" -> "phone").
        $fragments = [];
        foreach ($words as $word) {
            $len = mb_strlen($word);
            for ($i = 0; $i + 3 <= $len; $i++) {
                $fragments[mb_substr($word, $i, 3)] = true;
            }
        }
        // Bound the OR count on a long multi-word query.
        $fragments = array_slice(array_keys($fragments), 0, 16);

        $candidates = (clone $base)
            ->where(function ($q) use ($words, $fragments) {
                foreach ($fragments as $fragment) {
                    $like = '%' . $fragment . '%';
                    $q->orWhere('products.name', 'like', $like)
                        ->orWhereHas('translations', fn ($t) => $t->where('name', 'like', $like))
                        ->orWhereHas('variants', fn ($v) => $v->where('name', 'like', $like))
                        ->orWhereHas('brand', fn ($b) => $b->where('name', 'like', $like)
                            ->orWhereHas('translations', fn ($tt) => $tt->where('name', 'like', $like)))
                        ->orWhereHas('category', fn ($cq) => $cq->where('name', 'like', $like)
                            ->orWhereHas('translations', fn ($tt) => $tt->where('name', 'like', $like)));
                }
                foreach ($words as $word) {
                    $q->orWhereRaw('SOUNDEX(products.name) = SOUNDEX(?)', [$word]);
                }
            })
            ->limit($maxCandidates)
            ->pluck('products.name', 'products.id');

        if ($candidates->isEmpty()) {
            return [];
        }

        $ids = $candidates->keys()->all();
        // Variant, translated, brand and category names all count as the product's text.
        $extra = [];
        foreach (DB::table('product_variants')->whereIn('product_id', $ids)->get(['product_id', 'name']) as $row) {
            $extra[(int) $row->product_id][] = (string) $row->name;
        }
        foreach (DB::table('product_translations')->whereIn('product_id', $ids)->get(['product_id', 'name']) as $row) {
            $extra[(int) $row->product_id][] = (string) $row->name;
        }
        foreach ($this->relatedNamesByProduct($ids) as $productId => $names) {
            $extra[$productId] = array_merge($extra[$productId] ?? [], $names);
        }

        $scored = [];
        foreach ($candidates as $id => $name) {
            $tokens = $this->searchTokens(array_merge([(string) $name], $extra[(int) $id] ?? []));
            if (empty($tokens)) {
                continue;
            }

            $score = 0.0;
            foreach ($words as $word) {
                $best = $this->bestTokenScore($word, $tokens);
                if ($best === null) {
                    $score = 0.0;
                    break; // one unmatched word is enough to drop the product
                }
                $score += $best;
            }
            if ($score > 0) {
                $scored[(int) $id] = $score;
            }
        }

        arsort($scored);

        return array_slice(array_keys($scored), 0, $maxResults);
    }

    /**
     * Category ids whose name (base or translated) contains $word, plus their whole
     * subtree — products sit on leaf categories, so a parent name has to pull the
     * descendants' products in with it.
     *
     * @return array<int>
     */
    private function categoryIdsMatching(string $word): array
    {
        $like = '%' . $word . '%';
        $matched = DB::table('categories')->where('status', 1)->where('name', 'like', $like)->pluck('id')
            ->merge(
                DB::table('category_translations')->where('name', 'like', $like)->pluck('category_id')
            )
            ->map(fn ($id) => (int) $id)->unique();

        if ($matched->isEmpty()) {
            return [];
        }

        $ids = [];
        foreach ($matched as $rootId) {
            foreach (HomeLayoutResolver::categorySubtreeIds($rootId) as $sid) {
                $ids[(int) $sid] = true;
            }
        }

        return array_keys($ids);
    }

    /**
     * Brand + category names (base and translated) of the given products, keyed by product
     * id — the fuzzy scorer treats them as part of the product's searchable text.
     *
     * @return array<int, array<string>>
     */
    private function relatedNamesByProduct(array $productIds): array
    {
        $rows = DB::table('products')->whereIn('id', $productIds)->get(['id', 'brand_id', 'category_id']);
        $brandIds = $rows->pluck('brand_id')->filter()->map(fn ($id) => (int) $id)->unique()->all();
        $categoryIds = $rows->pluck('category_id')->filter()->map(fn ($id) => (int) $id)->unique()->all();

        $namesFor = function (string $table, string $translationTable, string $foreignKey, array $ids): array {
            if (empty($ids)) {
                return [];
            }
            $names = [];
            foreach (DB::table($table)->whereIn('id', $ids)->get(['id', 'name']) as $row) {
                $names[(int) $row->id][] = (string) $row->name;
            }
            foreach (DB::table($translationTable)->whereIn($foreignKey, $ids)->get([$foreignKey, 'name']) as $row) {
                $names[(int) $row->{$foreignKey}][] = (string) $row->name;
            }

            return $names;
        };

        $brandNames = $namesFor('brands', 'brand_translations', 'brand_id', $brandIds);
        $categoryNames = $namesFor('categories', 'category_translations', 'category_id', $categoryIds);

        $out = [];
        foreach ($rows as $row) {
            $merged = array_merge(
                $brandNames[(int) $row->brand_id] ?? [],
                $categoryNames[(int) $row->category_id] ?? []
            );
            if (!empty($merged)) {
                $out[(int) $row->id] = $merged;
            }
        }

        return $out;
    }

    /** Lower-cased word list of some product texts, long enough to be worth comparing. */
    private function searchTokens(array $texts): array
    {
        $tokens = [];
        foreach ($texts as $text) {
            foreach (preg_split('/[^\p{L}\p{N}]+/u', mb_strtolower($text), -1, PREG_SPLIT_NO_EMPTY) ?: [] as $token) {
                if (mb_strlen($token) >= 3) {
                    $tokens[$token] = true;
                }
            }
        }

        return array_keys($tokens);
    }

    /**
     * How well $word matches the closest of $tokens: 1.0 for a prefix/substring hit, less
     * as the edit distance grows, null when nothing is close enough. The allowance scales
     * with length — one typo in a short word, more in a long one.
     */
    private function bestTokenScore(string $word, array $tokens): ?float
    {
        $len = mb_strlen($word);
        $allowed = $len <= 4 ? 1 : (int) floor($len / 4) + 1;
        $best = null;

        foreach ($tokens as $token) {
            // The word sits inside the token ("pige" in "pigeon") — a clean hit.
            if (str_contains($token, $word)) {
                return 1.0;
            }
            // The token sits inside the word: only counts when the token is nearly the whole
            // word, otherwise every product with a token like "on" would score perfectly.
            if (mb_strlen($token) >= 4 && mb_strlen($token) >= $len - 2 && str_contains($word, $token)) {
                return 1.0;
            }
            // Length gap alone already exceeds the allowance — skip the distance call.
            if (abs(mb_strlen($token) - $len) > $allowed) {
                continue;
            }
            $distance = levenshtein($word, $token);
            if ($distance <= $allowed) {
                $score = 1 - ($distance / max($len, 1));
                $best = $best === null ? $score : max($best, $score);
            }
        }

        return $best;
    }

    /** Listed variants of $p that have a listed PVSS row in the zone. */
    private function listedVariants(Product $p)
    {
        return $p->variants->filter(fn($v) => $v->branchStocks->where('is_listed', 1)->count() > 0);
    }

    /**
     * min/max discount percent off the request, clamped to 0..100.
     * Both null when the caller asked for no discount bound.
     *
     * @return array{0: ?float, 1: ?float}
     */
    private static function discountBounds(Request $request): array
    {
        $read = function (string $key) use ($request): ?float {
            $raw = $request->input($key);
            // Non-numeric text is treated as "not asked for": casting it to 0 would
            // silently turn a typo into a discounted-products-only listing.
            if (!$request->filled($key) || !is_numeric($raw)) {
                return null;
            }
            return max(0.0, min(100.0, (float) $raw));
        };

        return [$read('min_discount_percent'), $read('max_discount_percent')];
    }

    /** Ex-tax final price used by the price filter (discounted if set, else price). */
    private function variantFinalPrice($v): float
    {
        return (float) $v->discounted_price > 0 ? (float) $v->discounted_price : (float) $v->price;
    }

    private function variantInPriceRange($v, ?float $min, ?float $max): bool
    {
        $final = $this->variantFinalPrice($v);
        if ($min !== null && $final < $min) {
            return false;
        }
        if ($max !== null && $final > $max) {
            return false;
        }
        return true;
    }

    /**
     * Same discount test the SQL filter applies, variant by variant, so the card
     * shown for a "50% off" banner is pinned to a variant that really is 50% off.
     */
    private function variantInDiscountRange($v, ?float $min, ?float $max): bool
    {
        if ($min === null && $max === null) {
            return true;
        }
        $pct = $this->variantDiscountFraction($v) * 100;
        if ($pct <= 0) {
            return false; // A full-price variant satisfies no discount bound.
        }
        if ($min !== null && $pct < $min) {
            return false;
        }
        if ($max !== null && $pct > $max) {
            return false;
        }
        return true;
    }

    /**
     * Listed variant ids of $p that match every selected attribute group (one
     * of the group's values present on the variant) and the price range.
     */
    private function matchingCardVariantIds(
        Product $p,
        array $attrGroups,
        ?float $priceMin,
        ?float $priceMax,
        ?float $discMin = null,
        ?float $discMax = null
    ): array {
        $ids = [];
        foreach ($this->listedVariants($p) as $v) {
            if (!$this->variantInPriceRange($v, $priceMin, $priceMax)
                || !$this->variantInDiscountRange($v, $discMin, $discMax)) {
                continue;
            }
            $vIds = $v->attributeValues->pluck('attribute_value_id')->map(fn($x) => (int) $x)->all();
            $matchesAll = true;
            foreach ($attrGroups as $groupValues) {
                if (empty(array_intersect($vIds, $groupValues))) {
                    $matchesAll = false;
                    break;
                }
            }
            if ($matchesAll) {
                $ids[] = (int) $v->id;
            }
        }
        return $ids;
    }

    /** Variant-level discount fraction (0..1); 0 when not discounted. */
    private function variantDiscountFraction($v): float
    {
        $price = (float) $v->price;
        $disc  = (float) $v->discounted_price;
        return ($disc > 0 && $price > 0) ? ($price - $disc) / $price : 0;
    }

    /**
     * Representative variant id matching the active sort (within price range):
     * price_high => dearest, discount =>
     * biggest discount; everything else => cheapest.
     */
    private function sortRepresentativeVariantId(
        Product $p,
        string $sort,
        ?float $min,
        ?float $max,
        ?float $discMin = null,
        ?float $discMax = null
    ): ?int {
        $variants = $this->listedVariants($p)
            ->filter(fn($v) => $this->variantInPriceRange($v, $min, $max)
                && $this->variantInDiscountRange($v, $discMin, $discMax));
        if ($variants->isEmpty()) {
            return null;
        }
        switch ($sort) {
            case 'price_high':
                $v = $variants->sortByDesc(fn($v) => $this->variantFinalPrice($v))->first();
                break;
            case 'discount':
                $v = $variants->sortByDesc(fn($v) => $this->variantDiscountFraction($v))->first();
                break;
            default: // price_low, popular, new, etc. => cheapest in range
                $v = $variants->sortBy(fn($v) => $this->variantFinalPrice($v))->first();
                break;
        }
        return $v ? (int) $v->id : null;
    }

    /**
     * Filter options for a category's products — drives the listing filter UI.
     *
     * Pass one category_id. Products attach to leaf categories, so when the id
     * is a parent the options aggregate over its whole descendant subtree and
     * its direct children are returned for drill-down. Omit category_id to get
     * options for the entire zone/channel catalog.
     *
     * Returns brands actually used, the attribute values actually used (not the
     * category's full assigned attribute set), and the price range — all scoped
     * to products visible in the caller's zone. Output is language-flat.
     *
     * Required: latitude, longitude + channel header.
     */
    public function getProductFilters(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude'  => 'required',
            'longitude' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $channel = strtolower(trim((string) $request->header('channel')));
        if (!in_array($channel, ['quick', 'ecommerce'], true)) {
            return CommonHelper::responseError(__('invalid_channel_header'));
        }

        $lat  = (float) $request->latitude;
        $lng  = (float) $request->longitude;
        $zone = CommonHelper::getDeliverableCity($lat, $lng, $channel);
        if (!$zone) {
            return CommonHelper::responseWithData($this->emptyFilters(), false);
        }

        $branchIds = Branch::where('status', 1)
            ->where('zone_id', $zone->id)
            ->get()
            ->pluck('id')
            ->all();
        if (empty($branchIds)) {
            return CommonHelper::responseWithData($this->emptyFilters(), false);
        }

        $categoryIds = [];
        if ($request->filled('category_id')) {
            $categoryIds = array_values(array_unique(array_filter(
                array_map('intval', explode(',', (string) $request->category_id))
            )));

            if (empty($categoryIds) && self::filterMode($request) !== 'exclude') {
                return CommonHelper::responseWithData($this->emptyFilters(), false);
            }
        }

        // Visible products in this zone + (optional) category subtree.
        $productQuery = Product::query()
            ->where('status', 1)
            ->where('is_draft', 0)
            // A switched-off brand or category takes its products with it.
            ->taxonomyActive()
            ->notAddonOnly()
            ->whereIn('sales_channel', [$channel, 'both'])
            ->whereExists(function ($q) use ($branchIds) {
                $q->select(DB::raw(1))
                    ->from('product_variants as pv')
                    ->join('product_variant_branch_stocks as pvss', 'pvss.product_variant_id', '=', 'pv.id')
                    ->whereColumn('pv.product_id', 'products.id')
                    ->whereIn('pvss.branch_id', $branchIds)
                    ->where('pvss.is_listed', 1);
            });
        self::applyIdFilter($productQuery, 'category_id', $categoryIds, self::filterMode($request));

        // Optional: scope the filter set to a product-slider data_source, so a
        // slider's "see more" derives filters (brands/attributes/price) only from
        // that source's products. Membership-affecting sources narrow the set;
        // pure-ordering sources (top_selling/trending/new_arrivals/best_rated/
        // most_favorited) and `category` (handled via category_id) add no filter.
        $userId = $request->user('api-customers') ? $request->user('api-customers')->id : null;
        $dataSource = strtolower((string) $request->input('data_source', ''));
        $emptySource = false;
        switch ($dataSource) {
            case 'manual':
                $ids = array_values(array_filter(array_map('intval', explode(',', (string) $request->manual_product_ids))));
                if (empty($ids)) {
                    $emptySource = true;
                    break;
                }
                $productQuery->whereIn('id', $ids);
                break;
            case 'discounted':
                $productQuery->whereHas('variants.branchStocks', function ($q) use ($branchIds) {
                    $q->whereIn('branch_id', $branchIds)->where('is_listed', 1)
                        ->whereColumn('discounted_price', '<', 'price')->where('discounted_price', '>', 0);
                });
                break;
            case 'recently_visited':
                $ids = $userId
                    ? RecentlyVisitedProduct::where('user_id', $userId)->orderByDesc('visited_at')->limit(50)->pluck('product_id')->all()
                    : [];
                if (empty($ids)) {
                    $emptySource = true;
                    break;
                }
                $productQuery->whereIn('id', $ids);
                break;
            case 'buy_again':
                $ids = $userId
                    ? DB::table('order_items as oi')->join('product_variants as pv', 'oi.product_variant_id', '=', 'pv.id')
                        ->where('oi.user_id', $userId)->pluck('pv.product_id')->unique()->values()->all()
                    : [];
                if (empty($ids)) {
                    $emptySource = true;
                    break;
                }
                $productQuery->whereIn('id', $ids);
                break;
        }

        // brand_ids narrows the set to specific brands regardless of data_source
        // (so filters reflect only those brands' products: their categories +
        // attributes + price). Also covers data_source=brand.
        if ($request->filled('brand_ids')) {
            $bids = array_values(array_filter(array_map('intval', explode(',', (string) $request->brand_ids))));
            self::applyIdFilter($productQuery, 'brand_id', $bids, self::filterMode($request));
        }

        // A discount-scoped landing (a "50% off" banner) derives its facets from the
        // discounted products only, so the price slider and attribute list match the
        // listing the customer is looking at.
        [$discMin, $discMax] = self::discountBounds($request);
        if ($discMin !== null || $discMax !== null) {
            $productQuery->whereHas('variants.branchStocks', function ($q) use ($discMin, $discMax, $branchIds) {
                $q->whereIn('branch_id', $branchIds)->where('is_listed', 1)
                    ->where('price', '>', 0)
                    ->where('discounted_price', '>', 0)
                    ->whereColumn('discounted_price', '<', 'price');
                if ($discMin !== null) {
                    $q->whereRaw('((price - discounted_price) / price) * 100 >= ?', [$discMin]);
                }
                if ($discMax !== null) {
                    $q->whereRaw('((price - discounted_price) / price) * 100 <= ?', [$discMax]);
                }
            });
        }
        $productIds = $emptySource ? [] : $productQuery->pluck('id')->all();

        $data = $this->emptyFilters();
        if (empty($productIds)) {
            return CommonHelper::responseWithData($data, false);
        }

        // Brands actually used by those products.
        $brandIds = Product::whereIn('id', $productIds)
            ->whereNotNull('brand_id')
            ->distinct()
            ->pluck('brand_id')
            ->filter()
            ->all();
        if (!empty($brandIds)) {
            $data['brands'] = Brand::whereIn('id', $brandIds)
                ->where('status', 1)
                ->orderBy('name', 'ASC')
                ->get(['id', 'name', 'image'])
                ->map(fn($b) => ['id' => $b->id, 'name' => $b->name, 'image_url' => $b->image_url])
                ->all();
        }

        // Price bounds over listed variants in the zone (final price, ex-tax).
        $priceRow = DB::table('product_variants as pv')
            ->join('product_variant_branch_stocks as pvss', 'pvss.product_variant_id', '=', 'pv.id')
            ->whereIn('pv.product_id', $productIds)
            ->whereIn('pvss.branch_id', $branchIds)
            ->where('pvss.is_listed', 1)
            ->selectRaw('MIN(IF(pvss.discounted_price > 0, pvss.discounted_price, pvss.price)) as min_price, MAX(IF(pvss.discounted_price > 0, pvss.discounted_price, pvss.price)) as max_price')
            ->first();
        $data['min_price'] = $priceRow && $priceRow->min_price !== null ? (float) $priceRow->min_price : 0;
        $data['max_price'] = $priceRow && $priceRow->max_price !== null ? (float) $priceRow->max_price : 0;

        // Attributes + the values actually used by those products' variants
        // (NOT the category's assigned attribute set).
        $usedPairs = DB::table('product_variant_attribute_values as pva')
            ->join('product_variants as pv', 'pv.id', '=', 'pva.product_variant_id')
            ->whereIn('pv.product_id', $productIds)
            ->select('pva.attribute_id', 'pva.attribute_value_id')
            ->distinct()
            ->get();

        $valueIdsByAttr = [];
        foreach ($usedPairs as $row) {
            $valueIdsByAttr[(int) $row->attribute_id][] = (int) $row->attribute_value_id;
        }
        if (!empty($valueIdsByAttr)) {
            $allValueIds = array_merge(...array_values($valueIdsByAttr));
            $attrModels = Attribute::whereIn('id', array_keys($valueIdsByAttr))
                ->where('status', 1)
                ->orderBy('id')
                ->get()->keyBy('id');
            $valueModels = AttributeValue::whereIn('id', $allValueIds)
                ->orderBy('id')
                ->get()->groupBy('attribute_id');
            foreach ($attrModels as $aid => $attr) {
                $vals = ($valueModels[$aid] ?? collect())
                    ->map(fn($v) => ['id' => $v->id, 'value' => $v->value])
                    ->values()->all();
                if (empty($vals)) {
                    continue;
                }
                $data['attributes'][] = [
                    'id'     => $attr->id,
                    'name'   => $attr->name,
                    'values' => $vals,
                ];
            }
        }

        return CommonHelper::responseWithData($data, false);
    }

    /**
     * A home-builder section can scope an ordering-only data_source to a set of
     * categories or brands, either keeping only those or keeping everything but
     * those. The slider echoes `filter_mode=exclude` for the second case; anything
     * else means the ids are an include list, which is how this endpoint has
     * always read them.
     */
    private static function filterMode(Request $request): string
    {
        return strtolower((string) $request->input('filter_mode', '')) === 'exclude' ? 'exclude' : 'include';
    }

    /**
     * Apply an id list to a column in whichever direction the mode asks for.
     * `brand_id` is nullable with a 0 default, so excluding brands must keep the
     * products that have no brand at all.
     */
    private static function applyIdFilter($query, string $column, array $ids, string $mode): void
    {
        if (empty($ids)) {
            return;
        }

        if ($mode === 'exclude') {
            $query->where(function ($q) use ($column, $ids) {
                $q->whereNotIn($column, $ids)->orWhereNull($column);
            });

            return;
        }

        $query->whereIn($column, $ids);
    }

    private function emptyFilters(): array
    {
        return [
            'brands'           => [],
            'attributes'       => [],
            'min_price'        => 0,
            'max_price'        => 0,
        ];
    }

    /**
     * Customer product detail — full product with variants, attributes,
     * custom-section values, images, category, brand, tax, etc.
     * Language-flat output: no nested translations objects.
     *
     * Required: latitude + longitude (zone gate) and one of id|slug|barcode.
     */
    public function getProduct(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'id'        => 'required_without_all:slug,barcode',
            'slug'      => 'required_without_all:id,barcode',
            'barcode'   => 'required_without_all:id,slug',
            'latitude'  => 'required',
            'longitude' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $channel = strtolower(trim((string) $request->header('channel')));
        if (!in_array($channel, ['quick', 'ecommerce'], true)) {
            return CommonHelper::responseError(__('invalid_channel_header'));
        }

        $lat  = (float) $request->latitude;
        $lng  = (float) $request->longitude;
        $zone = CommonHelper::getDeliverableCity($lat, $lng, $channel);
        if (!$zone) {
            return CommonHelper::responseError(__('not_deliverable_to_this_location'));
        }
        $branchIds = Branch::where('status', 1)
            ->where('zone_id', $zone->id)
            ->get()
            ->pluck('id')
            ->all();
        if (empty($branchIds)) {
            return CommonHelper::responseError(__('no_items_found'));
        }

        $q = Product::query()
            ->where('status', 1)
            ->where('is_draft', 0)
            // A switched-off brand or category takes its products with it.
            ->taxonomyActive()
            ->notAddonOnly()
            ->whereIn('sales_channel', [$channel, 'both'])
            ->whereExists(function ($sub) use ($branchIds) {
                $sub->select(DB::raw(1))
                    ->from('product_variants as pv')
                    ->join('product_variant_branch_stocks as pvss', 'pvss.product_variant_id', '=', 'pv.id')
                    ->whereColumn('pv.product_id', 'products.id')
                    ->whereIn('pvss.branch_id', $branchIds)
                    ->where('pvss.is_listed', 1);
            });

        if ($request->filled('id')) {
            $q->where('id', (int) $request->id);
        } elseif ($request->filled('slug')) {
            $q->where('slug', $request->slug);
        } elseif ($request->filled('barcode')) {
            $q->where('barcode', $request->barcode);
        }

        $product = $q->with([
            'variants.attributeValues.attribute.translations',
            'variants.attributeValues.attributeValue.translations',
            'variants.customValues.field.translations',
            'variants.customValues.field.section.translations',
            'variants.images',
            'variants.translations',
            'variants.branchStocks' => fn($qq) => $qq->whereIn('branch_id', $branchIds),
            'images',
            'brand.translations',
            'category.translations',
            'ratings',
            'translations',
            'addonGroups' => fn ($qq) => $qq->where('status', 1),
            'addonGroups.translations',
            'addonGroups.activeOptions.translations',
            'addonGroups.activeOptions.branchPrices',
            'addonGroups.activeOptions.linkedVariant',
            // A linked option shows its product's picture, so that product comes along.
            'addonGroups.activeOptions.linkedVariant.product:id,image,product_type',
        ])->first();

        if (!$product) {
            return CommonHelper::responseError(__('no_items_found'));
        }

        $hasListedVariant = $product->variants->contains(function ($v) {
            return $v->branchStocks->where('is_listed', 1)->count() > 0;
        });
        if (!$hasListedVariant) {
            return CommonHelper::responseError(__('no_items_found'));
        }

        $userId = $request->user('api-customers') ? $request->user('api-customers')->id : null;

        $detail = $this->shapeProductDetail($product, $userId);

        // Zone branch name + delivery time (quick commerce only).
        $delivery = CustomerProductShaper::zoneDelivery($zone, $lat, $lng);
        $detail['branch_name']      = $delivery['branch_name'];
        $detail['time_to_deliver'] = $channel === 'quick'
            ? CustomerProductShaper::formatDeliveryTime((int) $delivery['time_to_deliver'])
            : '';

        $detail['estimated_delivery_date'] = $channel === 'ecommerce'
            ? CommonHelper::zoneDeliveryDate($zone)
            : null;

        $detail['pincode_check_available'] = ($channel === 'ecommerce'
            && CommonHelper::pincodeCheckAvailable($zone)) ? 1 : 0;

        $currency = CommonHelper::countryCurrency($zone?->country);
        $detail['currency']       = $currency['currency'];
        $detail['currency_code']  = $currency['currency_code'];
        $detail['decimal_point']  = $currency['decimal_point'];

        return CommonHelper::responseWithData($detail);
    }

    public function notifyMeSave(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_variant_id' => 'required|integer',
            'latitude'           => 'required',
            'longitude'          => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user = $request->user('api-customers');
        $channel = strtolower(trim((string) $request->header('channel')));
        $zone = CommonHelper::getDeliverableCity((float) $request->latitude, (float) $request->longitude, $channel ?: null);
        if (!$zone) {
            return CommonHelper::responseError('not_deliverable_to_this_location');
        }

        $variant = ProductVariant::with('product')->find((int) $request->product_variant_id);
        if (!$variant || !$variant->product || (int) $variant->product->status !== 1) {
            return CommonHelper::responseError('product_not_found');
        }

        if ($this->variantInStockForZone($variant->id, (int) $zone->id)) {
            return CommonHelper::responseError('product_already_in_stock');
        }

        $alert = ProductStockAlert::updateOrCreate(
            ['user_id' => $user->id, 'product_variant_id' => $variant->id],
            [
                'product_id'  => $variant->product_id,
                'country_id'  => $zone->country_id,
                'zone_id'     => $zone->id,
                'status'      => ProductStockAlert::STATUS_WAITING,
                'notified_at' => null,
            ]
        );

        return CommonHelper::responseSuccessWithData('notify_me_saved', [
            'id'                  => $alert->id,
            'product_variant_id'  => (int) $variant->id,
            'is_notify_requested' => 1,
        ]);
    }

    public function notifyMeRemove(Request $request)
    {
        $validator = Validator::make($request->all(), ['product_variant_id' => 'required|integer']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user = $request->user('api-customers');
        ProductStockAlert::where('user_id', $user->id)
            ->where('product_variant_id', (int) $request->product_variant_id)
            ->waiting()
            ->update(['status' => ProductStockAlert::STATUS_CANCELLED]);

        return CommonHelper::responseSuccessWithData('notify_me_removed', [
            'product_variant_id'  => (int) $request->product_variant_id,
            'is_notify_requested' => 0,
        ]);
    }

    /** Same rule the product APIs use: listed at a zone branch, and unlimited or available > 0. */
    private function variantInStockForZone(int $variantId, int $zoneId): bool
    {
        $branchIds = Branch::where('status', 1)->where('zone_id', $zoneId)->pluck('id');
        if ($branchIds->isEmpty()) {
            return false;
        }

        return ProductVariantBranchStock::where('product_variant_id', $variantId)
            ->whereIn('branch_id', $branchIds)
            ->where('is_listed', 1)
            ->where(function ($q) {
                $q->where('is_unlimited_stock', 1)
                    ->orWhere(fn ($w) => $w->where('stock_status', 1)->where('available', '>', 0));
            })
            ->exists();
    }

    /**
     * Build the full product detail payload. Every translatable string is
     * already resolved to the current language via HasTranslations.
     */
    /**
     * The questions this dish asks, with the options the customer may pick.
     *
     * Priced at $branchId — the same branch the rest of the response is priced at. An option
     * that branch cannot serve is left out entirely: its price elsewhere is another
     * country's currency, so there is nothing to fall back to, and a linked product that
     * is out of stock here cannot be made. A group left with no options disappears with
     * them, because a question with no answers cannot be put to the customer and a
     * required one would otherwise block the dish outright.
     *
     * `input_type` is stated outright so the client renders a radio or a checkbox without
     * inferring it, and `max_qty_per_option` above 1 is the cue to render a stepper.
     */
    private static function shapeAddonGroups($p, ?int $branchId = null): array
    {
        if (!$p->relationLoaded('addonGroups')) {
            return [];
        }

        return $p->addonGroups->map(fn ($g) => [
            'id'                 => (int) $g->id,
            'name'               => (string) $g->name,
            'selection_text'     => $g->selectionText(),
            'input_type'         => (string) $g->input_type,
            'is_required'        => (int) ($g->is_required ? 1 : 0),
            'min_select'         => (int) ($g->min_select ?? 0),
            'max_select'         => (int) ($g->max_select ?? 0),
            'max_qty_per_option' => max(1, (int) ($g->max_qty_per_option ?? 1)),
            'options'            => self::shapeAddonOptions($g, $branchId),
        ])
            ->filter(fn ($g) => !empty($g['options']))
            ->values()->all();
    }

    /** One group's options, priced at $branchId; the ones it cannot serve are dropped. */
    private static function shapeAddonOptions($g, ?int $branchId): array
    {
        $groupCap = max(1, (int) ($g->max_qty_per_option ?? 1));

        return $g->activeOptions->map(function ($o) use ($branchId, $groupCap) {
            $priced = AddonHelper::describe([['id' => $o->id, 'qty' => 1]], $branchId);
            $line = $priced['lines'][0] ?? null;
            if (!$line || !$line['available']) {
                return null;   // not served at this branch
            }

            $charge = (float) $line['unit_price'];
            $list   = AddonHelper::listPrice($o, $branchId);
            $image  = $o->imageUrl();

            $row = [
                'id'                => (int) $o->id,
                'name'              => (string) $o->name,
                'price'             => $charge,
                'original_price'    => $list > $charge ? $list : $charge,
                // An option that cannot be served is dropped above, so anything the
                // client receives is in stock; the field keeps the contract explicit.
                'in_stock'          => 1,
                // Diet mark on products.product_type's scale: 0 none, 1 veg, 2 non-veg,
                // 4 eggetarian. A linked option reports its own product's.
                'product_type'      => $o->productType(),
                // Stepper cap for ONE unit of the dish — the group's rule, lowered to
                // what the shelf holds when this option is a real product. The order of
                // several dishes is still checked server-side at add-to-cart.
                'max_qty'           => AddonHelper::maxSelectableQty($o, $branchId, $groupCap),
                'is_linked'         => $o->linked_variant_id ? 1 : 0,
                'linked_variant_id' => $o->linked_variant_id ? (int) $o->linked_variant_id : null,
            ];

            /* Optional, so the key is absent rather than empty when there is no
               picture — a client checking for it never has to tell '' from a URL. A
               linked option carries its product's image here without the operator
               uploading anything. */
            if ($image !== '') {
                $row['image'] = $image;
            }

            return $row;
        })->filter()->values()->all();
    }

    private function shapeProductDetail(Product $p, ?int $userId): array
    {
        $isFav = $userId
            ? Favorite::where('user_id', $userId)->where('product_id', $p->id)->exists()
            : false;

        $notifyRequestedIds = $userId
            ? ProductStockAlert::waiting()->where('user_id', $userId)->where('product_id', $p->id)
                ->pluck('product_variant_id')->map(fn ($id) => (int) $id)->all()
            : [];

        $cartByVariant = [];
        if ($userId) {
            $cartByVariant = Cart::where('user_id', $userId)
                ->whereIn('product_variant_id', $p->variants->pluck('id')->all())
                ->groupBy('product_variant_id')
                ->selectRaw('product_variant_id, SUM(qty) as qty')
                ->pluck('qty', 'product_variant_id')
                ->all();
        }

        $images = $p->images->map(fn($im) => [
            'id'        => (int) $im->id,
            'image_url' => $im->image_url,
        ])->values()->all();

        $listedVariants = $p->variants->filter(function ($v) {
            return $v->branchStocks->where('is_listed', 1)->count() > 0;
        })->values();

        $unlimitedForVariant = fn(ProductVariant $v): int => $v->branchStocks
            ->where('is_listed', 1)->where('is_unlimited_stock', 1)->count() > 0 ? 1 : 0;
        $productUnlimited = (int) $listedVariants->contains(fn($v) => $unlimitedForVariant($v) === 1);

        // The branch whose prices this response quotes. Everything priced below must come
        // from this one branch, or the response mixes two branches' money, in two currencies.
        $priceBranchId = ProductHelper::priceBranchId($listedVariants->first());

        // Branch-resolved rate: the branch decides the tax, not the catalogue.
        $taxPct = TaxService::rateForProduct((int) $p->id, $priceBranchId);
        $taxInclusive = false;
        $variants = $listedVariants->map(function (ProductVariant $variant) use ($p, $cartByVariant, $notifyRequestedIds, $unlimitedForVariant, $taxPct, &$taxInclusive) {
            ProductHelper::applyBranchPrice($variant);
            $variantInclusive = (bool) ($variant->is_tax_inclusive ?? false);
            $taxInclusive = $taxInclusive || $variantInclusive;
            $priceWithTax = (float) CommonHelper::doubleNumber(TaxService::applyTax((float) $variant->price, $taxPct, $variantInclusive));
            $discWithTax  = (float) $variant->discounted_price > 0
                ? (float) CommonHelper::doubleNumber(TaxService::applyTax((float) $variant->discounted_price, $taxPct, $variantInclusive))
                : 0;
            $finalPrice   = $discWithTax > 0 ? $discWithTax : $priceWithTax;
            $discountPct  = $priceWithTax > 0 && $discWithTax > 0
                ? round((($priceWithTax - $discWithTax) / $priceWithTax) * 100, 2)
                : 0;

            $variantUnlimited = $unlimitedForVariant($variant);

            // Stock visibility per zone:
            //   - variant must be listed in at least one zone branch
            //   - unlimited → in_stock if any listed PVSS row
            //   - limited   → in_stock only when listed PVSS row has
            //                 stock_status=1 AND available>0
            $listedStocks = $variant->branchStocks->where('is_listed', 1);
            $hasListedBranch = $listedStocks->count() > 0;
            $stock = (int) $listedStocks->where('stock_status', 1)->sum('available');
            $inStock = $hasListedBranch && ($variantUnlimited === 1 || $stock > 0);
            $minAlertSum = (int) $listedStocks->sum('min_alert');
            $isMinAlert = $variantUnlimited === 0
                && $hasListedBranch
                && $stock > 0
                && $stock <= $minAlertSum;
            $images = CustomerProductShaper::buildVariantImages($variant);

            $attributes = $variant->attributeValues->map(function ($av) {
                return [
                    'attribute_id'       => (int) $av->attribute_id,
                    'attribute_name'     => $av->attribute ? (string) $av->attribute->name : null,
                    'attribute_value_id' => (int) $av->attribute_value_id,
                    'attribute_value'    => $av->attributeValue ? (string) $av->attributeValue->value : null,
                ];
            })->values()->all();

            $sectionsBucket = [];
            foreach ($variant->customValues as $cv) {
                $field = $cv->field;
                if (!$field) continue;
                $type  = $field->field_type ?: 'text';
                $value = null;
                switch ($type) {
                    case 'number':
                        $value = $cv->value_number;
                        break;
                    case 'date':
                        $value = $cv->value_date ?: null;
                        break;
                    case 'multiselect':
                    case 'checkbox':
                    case 'json':
                        $value = $cv->value_json;
                        break;
                    case 'boolean':
                        $raw = $cv->value_text;
                        if ($raw === null || $raw === '') {
                            $value = null;
                        } else {
                            $value = ((int) $raw === 1 || $raw === true || $raw === 'true') ? 'yes' : 'no';
                        }
                        break;
                    default:
                        $value = $cv->value_text;
                }
                if ($value === null) continue;
                if (is_string($value) && trim($value) === '') continue;
                if (is_array($value) && empty($value)) continue;

                $section = $field->section;
                $sectionId = $section ? (int) $section->id : 0;
                $sectionName = $section ? (string) $section->name : '';

                if (!isset($sectionsBucket[$sectionId])) {
                    $sectionsBucket[$sectionId] = [
                        'section_id'   => $sectionId,
                        'section_name' => $sectionName,
                        'fields'       => [],
                    ];
                }
                $sectionsBucket[$sectionId]['fields'][] = [
                    'field_label' => (string) $field->field_label,
                    'field_type'  => $type,
                    'value'       => $value,
                ];
            }
            $customSections = array_values(array_filter(
                $sectionsBucket,
                fn($s) => !empty($s['fields'])
            ));

            return [
                'id'                => (int) $variant->id,
                'name'              => (string) $variant->name,
                'sku'               => $variant->sku,
                'price'             => $priceWithTax,
                'discounted_price'  => (float) CommonHelper::doubleNumber($finalPrice),
                'discount_percent'  => (float) $discountPct,
                'stock'             => $stock,
                'in_stock'          => $inStock,
                'is_notify_requested' => in_array((int) $variant->id, $notifyRequestedIds, true) ? 1 : 0,
                'is_min_alert'      => $isMinAlert,
                'is_unlimited_stock' => $variantUnlimited,
                'cart_count'        => (int) ($cartByVariant[$variant->id] ?? 0),
                'images'            => $images,
                'attributes'        => $attributes,
                'custom_sections'   => $customSections,
            ];
        })->values()->all();

        $axisBucket = [];
        foreach ($listedVariants as $v) {
            foreach ($v->attributeValues as $av) {
                $attrId = (int) $av->attribute_id;
                $valId  = (int) $av->attribute_value_id;
                if (!isset($axisBucket[$attrId])) {
                    $axisBucket[$attrId] = [
                        'attribute_id'   => $attrId,
                        'attribute_name' => $av->attribute ? (string) $av->attribute->name : null,
                        'values'         => [],
                        '_seen'          => [],
                    ];
                }
                if (!isset($axisBucket[$attrId]['_seen'][$valId])) {
                    $axisBucket[$attrId]['_seen'][$valId] = true;
                    $axisBucket[$attrId]['values'][] = [
                        'attribute_value_id' => $valId,
                        'attribute_value'    => $av->attributeValue ? (string) $av->attributeValue->value : null,
                    ];
                }
            }
        }
        $variantAxes = array_values(array_map(function ($a) {
            unset($a['_seen']);
            return $a;
        }, $axisBucket));

        $ratings = CommonHelper::productAverageRating($p->id);
        $productRatingEnabled = (int) (Setting::get_value('product_rating') ?? 0) === 1;

        return [
            'id'                 => (int) $p->id,
            'name'               => $listedVariants->isNotEmpty() ? (string) $listedVariants->first()->name : '',
            'slug'               => (string) $p->slug,
            'image_url'          => $p->image_url,
            'images'             => $images,
            'short_description'  => (string) ($p->short_description ?? ''),
            'description'        => (string) ($p->description ?? ''),
            'manufacturer'       => (string) ($p->manufacturer ?? ''),
            'product_type'       => (int) ($p->product_type ?? 0),
            'is_food'            => (int) ($p->is_food ?? 0),
            'addon_groups'       => self::shapeAddonGroups($p, $priceBranchId),
            'is_prescription_required' => (int) ($p->is_prescription_required ?? 0),
            'sales_channel'      => $p->sales_channel,
            'is_unlimited_stock' => $productUnlimited,
            'total_allowed_quantity' => (int) ($p->total_allowed_quantity ?? 0),
            'return_status'      => (int) ($p->return_status ?? 0),
            'return_days'        => (int) ($p->return_days ?? 0),
            'cancelable_status'  => (int) ($p->cancelable_status ?? 0),
            // Channel-wise cancellable-till: quick products get the quick value, ecommerce
            // get the ecommerce value, "both" get both.
            'till_status_quick'       => in_array($p->sales_channel, ['quick', 'both'], true) ? (string) ($p->till_status_quick ?? '') : '',
            'till_status_ecommerce'   => in_array($p->sales_channel, ['ecommerce', 'both'], true) ? (string) ($p->till_status_ecommerce ?? '') : '',
            'cod_allowed'        => (int) ($p->cod_allowed ?? 0),
            'tax_included_in_price' => $taxInclusive ? 1 : 0,
            'meta_title'         => (string) ($p->meta_title ?? ''),
            'meta_description'   => (string) ($p->meta_description ?? ''),
            'meta_keywords'      => (string) ($p->meta_keywords ?? ''),
            'schema_markup'      => (string) ($p->schema_markup ?? ''),
            'category_id'        => (int) $p->category_id,
            'category_name'      => $p->category ? (string) $p->category->name : null,
            'brand_id'           => $p->brand_id ? (int) $p->brand_id : null,
            'brand_name'         => $p->brand ? (string) $p->brand->name : null,
            'brand_image'        => $p->brand ? ($p->brand->image_url ?? null) : null,
            'tax_category_id'    => (int) ($p->tax_category_id ?? 0),
            'tax_percentage'     => (float) $taxPct,
            'made_in'            => (string) ($p->made_in ?? ''),
            'is_favorite'        => $isFav,
            'is_deliverable'     => true,
            'product_rating'     => $productRatingEnabled,
            'rating'             => round((float) $ratings['average_rating'], 1),
            'rating_count'       => (int) $ratings['rating_count'],
            'star_breakdown'     => [
                '1' => (int) $ratings['one_star_rating'],
                '2' => (int) $ratings['two_star_rating'],
                '3' => (int) $ratings['three_star_rating'],
                '4' => (int) $ratings['four_star_rating'],
                '5' => (int) $ratings['five_star_rating'],
            ],
            'variant_axes'       => $variantAxes,
            'variants'           => $variants,
        ];
    }

    public function productRatingSave(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'rate' => 'required',
            'product_id' => ['required', Rule::unique('product_ratings')->where(function ($query) {
                return $query->where('user_id', auth()->user()->id);
            })],
            'image.*' => 'image|mimes:jpeg,png,jpg,gif,svg|max:2048'
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $product_rating = new ProductRating();
        $product_rating->product_id = $request->product_id;
        $product_rating->user_id = auth()->user()->id;
        $product_rating->rate = $request->rate;
        $product_rating->review = $request->review ?? '';
        $product_rating->status = 1;
        $product_rating->save();
        if ($request->hasFile('image')) {
            CommonHelper::uploadRatingImages($request->file('image'), $product_rating->id);
        }
        $data = ProductRating::with('user', 'images')->where('id', $product_rating->id)->get();
        return CommonHelper::responseSuccessWithData("Product Rating Saved Successfully!", $data);
    }

    public function productRatingEdit(Request $request)
    {
        $id = $request->id;
        $product_rating = ProductRating::with('images')->where('id', $id)->first();

        if (!$product_rating) {
            return CommonHelper::responseError("Product Rating Not found!");
        }
        return CommonHelper::responseWithData($product_rating);
    }

    public function productRatingUpdate(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'rate' => 'required',
            'image.*' => 'image|mimes:jpeg,png,jpg,gif,svg|max:2048'
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $product_image_ids = json_decode($request->deleteImageIds);
        // Check if $product_image_ids is not null and is an array or countable
        if (!is_null($product_image_ids) && (is_array($product_image_ids) || $product_image_ids instanceof Countable)) {
            // Check if $product_image_ids is not empty
            if (count($product_image_ids) !== 0) {
                foreach ($product_image_ids as $product_image_id) {
                    $image = RatingImages::find($product_image_id);
                    if ($image) {
                        $image->delete();
                    }
                }
            }
        }
        $product_rating = ProductRating::find($request->id);
        $product_rating->rate = $request->rate;
        $product_rating->review = $request->review ?? '';
        $product_rating->status = 1;
        $product_rating->save();
        if ($request->hasFile('image')) {
            CommonHelper::uploadRatingImages($request->file('image'), $product_rating->id);
        }
        $data = ProductRating::with('user', 'images')->where('id', $request->id)->get();
        return CommonHelper::responseSuccessWithData("Product Updated Successfully!", $data);
    }

    public function productRatingsList(Request $request)
    {
        $sort = $request->input('sort', 'id');
        $order = $request->input('order', 'DESC');

        $product_id  = $request->product_id;
        $category_id = $request->category_id;
        $brand_id    = $request->brand_id;

        $productsQuery = Product::where('status', 1)->with('translations');
        if ($category_id) {
            $productsQuery->where('category_id', (int) $category_id);
        }
        if ($brand_id) {
            $productsQuery->where('brand_id', (int) $brand_id);
        }

        $products = (clone $productsQuery)
            ->orderBy('id', 'DESC')
            ->get(['id', 'name'])
            ->map(fn ($p) => [
                'id'           => $p->id,
                'name'         => $p->name,
                'translations' => $p->translations,
            ])
            ->values();

        if ($product_id != null) {
            $productIds = [(int) $product_id];
        } elseif ($category_id || $brand_id) {
            // Filtered "all products": every product the filters allow.
            $productIds = (clone $productsQuery)->pluck('id')->all();
        } else {
            $productIds = ProductRating::selectRaw('product_id, AVG(rate) as avg_rate, COUNT(*) as cnt')
                ->groupBy('product_id')
                ->orderByDesc('avg_rate')
                ->orderByDesc('cnt')
                ->limit(10)
                ->pluck('product_id')
                ->all();
        }

        $productRatingsData = ['products' => $products];

        if (empty($productIds)) {
            $productRatingsData['rating_list'] = [];
            return CommonHelper::responseWithData($productRatingsData, 0);
        }

        // Star breakdown only makes sense for a single selected product.
        if ($product_id != null) {
            $avg = CommonHelper::productAverageRating($product_id);
            $productRatingsData['average_rating'] = $avg['average_rating'];
            $productRatingsData['one_star_rating'] = $avg['one_star_rating'];
            $productRatingsData['two_star_rating'] = $avg['two_star_rating'];
            $productRatingsData['three_star_rating'] = $avg['three_star_rating'];
            $productRatingsData['four_star_rating'] = $avg['four_star_rating'];
            $productRatingsData['five_star_rating'] = $avg['five_star_rating'];
        }

        // Product name + image for labelling each rating row.
        $productMeta = Product::whereIn('id', $productIds)->get(['id', 'name', 'image'])->keyBy('id');

        $query = ProductRating::with([
            'user:id,name,email,mobile,country_code,profile',
            'images',
        ])
            ->whereIn('product_id', $productIds)
            ->orderBy($sort, $order);
        $total = $query->count();

        if ($request->filled('limit')) {
            $query->skip((int) $request->get('offset', 0))->take((int) $request->get('limit'));
        }
        $ratingList = $query->get();
        $ratingList->each(function ($r) use ($productMeta) {
            $p = $productMeta[$r->product_id] ?? null;
            $r->product_name = $p->name ?? '';
            $r->product_image_url = $p ? $p->image_url : '';
        });

        $productRatingsData['rating_list'] = $ratingList;
        return CommonHelper::responseWithData($productRatingsData, $total);
    }
    public function productRatingImageList(Request $request)
    {
        $limit = $request->input('limit', 10);
        $offset = $request->input('offset', 0);

        $product_id = $request->product_id;
        if ($product_id != null) {
            $productRatingImages = ProductRating::with('images')->where('product_id', $product_id)->get();
            if ($productRatingImages->isNotEmpty()) {
                $images = $productRatingImages->pluck('images')->flatten();
                $total = $images->count();
                $images = $productRatingImages->pluck('images')->flatten()->skip($offset)->take($limit);
                $RatingImages = [];
                foreach ($images as $image) {
                    $RatingImages[] = $image->image_url;
                }
                return CommonHelper::responseWithData($RatingImages, $total);
            }
            return CommonHelper::responseError("Product not available");
        } else {
            return CommonHelper::responseError("Please select product first");
        }
    }

    public function getSeoThings(Request $request)
    {
        $slug = $request->input('slug');

        $product = Product::withTranslation()
            ->select('id', 'meta_title', 'meta_keywords', 'meta_description', 'schema_markup', 'image')
            ->where('slug', $slug)
            ->first();

        if (!$product) {
            return CommonHelper::responseError("Product not available");
        }
        $seoThings = [];
        $seoThings['meta_title'] = $product->meta_title;
        $seoThings['meta_keywords'] = $product->meta_keywords;
        $seoThings['meta_description'] = $product->meta_description;
        $seoThings['schema_markup'] = $product->schema_markup;
        $seoThings['og_image'] = $product->image_url;
        $seoThings['favicon'] = Setting::get_value('favicon') ? asset('storage/' . Setting::get_value('favicon')) : '';

        return CommonHelper::responseWithData($seoThings);
    }

    public function getRecentlyVisitedProducts(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude'  => 'required',
            'longitude' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user = $request->user('api-customers');
        if (!$user) {
            return CommonHelper::responseError('User authentication required.');
        }
        $user_id = $user->id;

        $channel = strtolower(trim((string) $request->header('channel')));
        if (!in_array($channel, ['quick', 'ecommerce'], true)) {
            return CommonHelper::responseError(__('invalid_channel_header'));
        }

        $lat  = (float) $request->latitude;
        $lng  = (float) $request->longitude;
        $zone = CommonHelper::getDeliverableCity($lat, $lng, $channel);
        if (!$zone) {
            return CommonHelper::responseWithData([], 0);
        }

        // Quick commerce respects branch hours; ecommerce ignores them.
        $branchIds = Branch::where('status', 1)
            ->where('zone_id', $zone->id)
            ->get()
            ->pluck('id')
            ->all();
        if (empty($branchIds)) {
            return CommonHelper::responseWithData([], 0);
        }

        // Recently visited product ids for this user, most recent first.
        $recentQuery = RecentlyVisitedProduct::where('user_id', $user_id)
            ->orderByDesc('visited_at')
            ->orderByDesc('created_at')
            ->limit(10);
        if ($request->filled('product_id')) {
            $recentQuery->where('product_id', '!=', (int) $request->product_id);
        }
        $recentIds = $recentQuery->pluck('product_id')->unique()->values()->all();
        if (empty($recentIds)) {
            return CommonHelper::responseWithData([], 0);
        }

        // Same visibility gate as the product listing: channel match + at least one
        // listed PVSS row in a zone branch. Preserve recently-visited order.
        $query = Product::query()
            ->where('status', 1)
            ->where('is_draft', 0)
            // A switched-off brand or category takes its products with it.
            ->taxonomyActive()
            ->notAddonOnly()
            ->whereIn('sales_channel', [$channel, 'both'])
            ->whereIn('id', $recentIds)
            ->whereExists(function ($q) use ($branchIds) {
                $q->select(DB::raw(1))
                    ->from('product_variants as pv')
                    ->join('product_variant_branch_stocks as pvss', 'pvss.product_variant_id', '=', 'pv.id')
                    ->whereColumn('pv.product_id', 'products.id')
                    ->whereIn('pvss.branch_id', $branchIds)
                    ->where('pvss.is_listed', 1);
            })
            ->orderByRaw('FIELD(id,' . implode(',', $recentIds) . ')');

        $total = (clone $query)->count();

        $products = $query->with([
            'variants',
            'variants.images',
            'variants.branchStocks' => fn($q) => $q->whereIn('branch_id', $branchIds),
            'variants.attributeValues.attribute.translations',
            'variants.attributeValues.attributeValue.translations',
            'brand.translations',
            'category.translations',
            'ratings',
            'translations',
        ])->get();

        if ($products->isEmpty()) {
            return CommonHelper::responseWithData([], 0);
        }

        $favoriteIds = Favorite::where('user_id', $user_id)
            ->whereIn('product_id', $products->pluck('id')->all())
            ->pluck('product_id')
            ->all();
        CustomerProductShaper::setNotifyRequestedVariantIds(
            ProductStockAlert::waiting()->where('user_id', $user_id)
                ->whereIn('product_id', $products->pluck('id')->all())
                ->pluck('product_variant_id')->all()
        );

        // One zone == one branch, so branch + delivery time are shared across the zone.
        $delivery      = CustomerProductShaper::zoneDelivery($zone, $lat, $lng);
        $branchName     = $delivery['branch_name'];
        $timeToDeliver = $channel === 'quick' ? $delivery['time_to_deliver'] : 0;
        $currency      = CommonHelper::countryCurrency($zone?->country);

        $cards = $products->map(fn($p) => CustomerProductShaper::shapeCard($p, $favoriteIds, $timeToDeliver, $branchName, $currency))->values()->all();

        return CommonHelper::responseWithData($cards, $total);
    }

    public function addRecentlyVisitedProduct(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_id' => 'required|exists:products,id',
        ], [
            'product_id.required' => 'The product_id field is required.',
            'product_id.exists' => 'The selected product does not exist.',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user = $request->user('api-customers');
        if (!$user) {
            return CommonHelper::responseError('User authentication required.');
        }

        $user_id = $user->id;
        $product_id = $request->product_id;

        try {
            RecentlyVisitedProduct::updateOrCreate(
                [
                    'user_id' => $user_id,
                    'product_id' => $product_id
                ],
                [
                    'visited_at' => now()
                ]
            );

            // Keep only the 10 most recent entries, delete older ones
            $idsToKeep = RecentlyVisitedProduct::where('user_id', $user_id)
                ->orderBy('visited_at', 'desc')
                ->orderBy('created_at', 'desc')
                ->limit(10)
                ->pluck('id');

            // Delete all entries for this user that are NOT in the top 10
            if ($idsToKeep->count() > 0) {
                RecentlyVisitedProduct::where('user_id', $user_id)
                    ->whereNotIn('id', $idsToKeep)
                    ->delete();
            }

            return CommonHelper::responseSuccess("Recently visited product tracked successfully!");
        } catch (\Exception $e) {
            return CommonHelper::responseError("Failed to track recently visited product: " . $e->getMessage());
        }
    }
}
