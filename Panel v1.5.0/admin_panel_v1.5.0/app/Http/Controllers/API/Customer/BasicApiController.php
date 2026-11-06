<?php

namespace App\Http\Controllers\API\Customer;

use App\Helpers\CommonHelper;
use App\Helpers\CustomerProductShaper;
use App\Http\Controllers\Controller;
use App\Models\Admin;
use App\Models\Blog;
use App\Models\BlogCategory;
use App\Models\BlogTag;
use App\Models\Brand;
use App\Models\Category;
use App\Models\Country;
use App\Models\Zone;
use App\Models\DeliveryBoy;
use App\Models\Faq;
use App\Models\Favorite;
use App\Models\Notification;
use App\Models\Order;
use App\Models\OrderStatusList;
use App\Models\PromoCode;
use App\Models\Branch;
use App\Models\Product;
use App\Models\ProductStockAlert;
use App\Models\Setting;
use App\Models\SocialMedia;
use App\Models\Transaction;
use App\Models\WalletTransaction;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;

class BasicApiController extends Controller
{
    public function getCategories(Request $request)
    {
        $limit = ($request->limit);
        $offset = ($request->offset);

        $category_id = $request->input('category_id', 0);

        $category_slug = $request->input('slug');

        $is_own_data = (int) $request->input('is_own_data', 0); // used in website for breadcrum translate

        if ($is_own_data === 1) {
            if (empty($category_slug)) {
                return CommonHelper::responseError(__('no_category_found'));
            }
            $category = Category::where('status', 1)->where('slug', $category_slug)->first();
            if (!$category) {
                return CommonHelper::responseError(__('no_category_found'));
            }
            $category->setRelation('catActiveChilds', collect());
            $category->makeHidden(['image']);
            return CommonHelper::responseWithData(collect([$category]), 1);
        }

        $validator = Validator::make($request->all(), [
            'latitude'  => 'required',
            'longitude' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        if (isset($category_slug) && !empty($category_slug)) {
            $category = Category::where('status', 1)->where('slug', $category_slug)->first();

            $categories = Category::where('status', 1)->where('parent_id', $category->id);
        } else {
            $categories = Category::where('status', 1)->where('parent_id', $category_id);
        }
        
        $channel = strtolower(trim((string) $request->header('channel')));
        $channel = in_array($channel, ['quick', 'ecommerce'], true) ? $channel : null;

        $zone = CommonHelper::getDeliverableCity((float) $request->latitude, (float) $request->longitude, $channel);
        $branchIds = $zone
            ? Branch::where('status', 1)
                ->where('zone_id', $zone->id)
                ->get()
                ->pluck('id')->map('intval')->all()
            : [];

        $productCatIds = CommonHelper::categoryIdsWithProducts($branchIds, $channel);
        $categories->whereIn('id', $productCatIds);

        $total = $categories->count();

        if (isset($limit) && $limit > 0) {
            $categories = $categories->orderBy('row_order', 'ASC')->offset($offset)->limit($limit)->get(['id', 'name', 'slug', 'image']);
        } else {
            $categories = $categories->orderBy('row_order', 'ASC')->get(['id', 'name', 'slug', 'image']);
        }

        $categories->load('translations');
        $tree = Category::with('translations')->orderBy('row_order')->orderBy('id')->get()->groupBy('parent_id');

        $productCatSet = array_flip($productCatIds);
        $pruneChildren = function ($cat) use (&$pruneChildren, $productCatSet, $tree) {
            $children = $tree->get($cat->id, collect());
            $cat->setRelation('catChilds', $children);
            $kids = $children
                ->filter(fn ($c) => (int) $c->status === 1 && isset($productCatSet[$c->id]))
                ->values();
            foreach ($kids as $c) {
                $pruneChildren($c);
            }
            $cat->setRelation('catActiveChilds', $kids);
        };
        foreach ($categories as $cat) {
            $pruneChildren($cat);
        }

        $categories = $categories->makeHidden(['image']);


        if (count($categories) > 0) {
            return CommonHelper::responseWithData($categories, $total);
        } else {
            return CommonHelper::responseError(__('no_category_found'));
        }
    }

    public function getUserTransactions(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'type' => 'required',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user_id = auth()->user()->id;
        $type = $request->type;

        $limit = $request->get('limit', 10);
        $offset = $request->get('offset', 0);
        $total = Transaction::where('user_id', $user_id)->get();

        if ($type == "transactions") {
            $transactions = Transaction::where('user_id', $user_id)
                ->where('type', '!=', 'delivery_boy_cash_collection')
                ->orderBy('created_at', 'DESC');
            $total = $transactions->count();
            $transactions = $transactions->offset($offset)->limit($limit)->get();
            $transactions = $transactions->makeHidden(['user_id', 'order_id', 'payu_txn_id', 'updated_at', 'transaction_date']);
            foreach ($transactions as $t) {
                $t->message = CommonHelper::translateTransactionMessage($t->message);
                $t->type = CommonHelper::translateTransactionMessage($t->type);
            }
            $transactions = $transactions->map(function (Transaction $t) {
                $row = $t->toArray();
                $rawCreatedAt = $t->getAttributes()['created_at'] ?? null;
                if ($rawCreatedAt !== null && $rawCreatedAt !== '') {
                    $row['created_at'] = $rawCreatedAt;
                }
                return $row;
            });
            return CommonHelper::responseWithData($transactions, $total);
        } elseif ($type == "wallet") {
            $wallet_transactions = WalletTransaction::where('user_id', $user_id)
                ->orderBy('created_at', 'DESC');
            $total = $wallet_transactions->count();
            $wallet_transactions = $wallet_transactions->offset($offset)->limit($limit)->get();
            for ($i = 0; $i < count($wallet_transactions); $i++) {
                $wallet_transactions[$i]['last_updated'] = (isset($wallet_transactions[$i]['last_updated']) == null) ? "" : $wallet_transactions[$i]['last_updated'];
                $wallet_transactions[$i]['status'] = $wallet_transactions[$i]['type'];
                $wallet_transactions[$i]['message'] = CommonHelper::translateTransactionMessage($wallet_transactions[$i]['message']);
            }
            $wallet_transactions = $wallet_transactions->map(function (WalletTransaction $wt) {
                $row = $wt->toArray();
                $rawCreatedAt = $wt->getAttributes()['created_at'] ?? null;
                if ($rawCreatedAt !== null && $rawCreatedAt !== '') {
                    $row['created_at'] = $rawCreatedAt;
                }
                return $row;
            });
            return CommonHelper::responseWithData($wallet_transactions, $total);
        }
    }

    // Favorites
    public function getFavorites(Request $request)
    {

        $validator = Validator::make($request->all(), [
            'latitude' => 'required',
            'longitude' => 'required',
        ], [
            'latitude.required' => 'The latitude field is required.',
            'longitude.required' => 'The longitude field is required.'
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $channel = strtolower(trim((string) $request->header('channel')));
        if (!in_array($channel, ['quick', 'ecommerce'], true)) {
            return CommonHelper::responseError(__('invalid_channel_header'));
        }

        $user_id = auth()->user()->id;
        $lat     = (float) $request->latitude;
        $lng     = (float) $request->longitude;
        $limit   = (int) ($request->limit ?? 10);
        $offset  = (int) ($request->offset ?? 0);
        $limit   = $limit > 0 ? min($limit, 100) : 10;

        // Channel-scoped favorites; legacy (null channel) rows match either channel.
        $favRows = Favorite::where('user_id', $user_id)
            ->where(function ($q) use ($channel) {
                $q->where('channel', $channel)->orWhereNull('channel');
            })
            ->orderByDesc('created_at')
            ->get(['product_id']);

        $allIds = $favRows->pluck('product_id')->map(fn ($id) => (int) $id)->unique()->values()->all();
        $total  = count($allIds);
        $pageIds = array_slice($allIds, $offset, $limit);

        [$branchIds, $zone] = $this->favoriteBranchContext($channel, $lat, $lng);
        $cards = $this->loadFavoriteCards($pageIds, $branchIds, $zone, $channel, $lat, $lng);

        return CommonHelper::responseWithData($cards ?: [], $total);
    }

    public function addToFavorite(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_id' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $channel = strtolower(trim((string) $request->header('channel')));
        if (!in_array($channel, ['quick', 'ecommerce'], true)) {
            return CommonHelper::responseError(__('invalid_channel_header'));
        }

        $user_id = auth()->user()->id;
        $favorite = Favorite::where('user_id', $user_id)->where('product_id', $request->product_id)->first();
        if ($favorite) {
            return CommonHelper::responseError('product_already_added_as_favorite');
        }

        $product = Product::where('id', $request->product_id)->first();
        if (empty($product)) {
            return CommonHelper::responseError('no_products_found');
        }

        $favorite = new Favorite();
        $favorite->user_id = $user_id;
        $favorite->product_id = $request->product_id;
        $favorite->channel = $channel;
        $favorite->save();

        // Return the added product as a shaped card (same schema as listings).
        $lat = $request->filled('latitude') ? (float) $request->latitude : null;
        $lng = $request->filled('longitude') ? (float) $request->longitude : null;
        [$branchIds, $zone] = $this->favoriteBranchContext($channel, $lat, $lng);
        $cards = $this->loadFavoriteCards([(int) $request->product_id], $branchIds, $zone, $channel, $lat, $lng);

        return CommonHelper::responseSuccessWithData('item_added_in_users_favorite_list_successfully', $cards[0] ?? null);
    }

    private function favoriteBranchContext(string $channel, $lat, $lng): array
    {
        $zone = null;
        $branchIds = [];
        if ($lat !== null && $lng !== null) {
            $zone = CommonHelper::getDeliverableCity((float) $lat, (float) $lng, $channel);
            if ($zone) {
                $branchIds = Branch::where('status', 1)
                    ->where('zone_id', $zone->id)
                    ->get()
                    ->pluck('id')
                    ->all();
            }
        }
        if (empty($branchIds)) {
            $branchIds = Branch::where('status', 1)
                ->whereNotNull('zone_id')
                ->pluck('id')
                ->all();
        }
        return [$branchIds, $zone];
    }

    private function loadFavoriteCards(array $productIds, array $branchIds, $zone, string $channel, $lat, $lng): array
    {
        if (empty($productIds)) {
            return [];
        }

        $products = Product::query()
            ->whereIn('id', $productIds)
            ->with([
                'variants',
                'variants.images',
                'variants.branchStocks' => fn ($q) => $q->whereIn('branch_id', $branchIds),
                'variants.attributeValues.attribute.translations',
                'variants.attributeValues.attributeValue.translations',
                'brand.translations',
                'category.translations',
                'ratings',
                'translations',
            ])
            ->get()
            ->keyBy('id');

        $delivery      = CustomerProductShaper::zoneDelivery($zone, $lat, $lng);
        $branchName     = $delivery['branch_name'];
        $timeToDeliver = $channel === 'quick' ? $delivery['time_to_deliver'] : 0;
        $currency      = CommonHelper::countryCurrency($zone?->country);

        $favoriteIds = $productIds; // every product here is favorited
        CustomerProductShaper::setNotifyRequestedVariantIds(
            ProductStockAlert::waiting()->where('user_id', auth()->user()->id)
                ->whereIn('product_id', $productIds)
                ->pluck('product_variant_id')->all()
        );
        $cards = [];
        foreach ($productIds as $pid) {
            if (!isset($products[$pid])) {
                continue;
            }
            $cards[] = CustomerProductShaper::shapeCard($products[$pid], $favoriteIds, $timeToDeliver, $branchName, $currency);
        }
        return $cards;
    }
    
    public function removeFromFavorite(Request $request)
    {
        $favorite = Favorite::where('user_id', auth()->user()->id);
        if (isset($request->product_id)) {
            $favorite->where('product_id', $request->product_id)->first();
            if ($favorite) {
                $favorite->delete();
                return CommonHelper::responseSuccess('item_removed_from_users_favorite_list_successfully');
            } else {
                return CommonHelper::responseError('no_product_found');
            }
        } else {
            $favorite->get();
            if (count($favorite) > 0) {
                $favorite->delete();
                return CommonHelper::responseSuccess('all_items_removed_from_users_favorite_list_successfully');
            } else {
                return CommonHelper::responseError('no_product_found');
            }
        }
    }

    // Faqs
    public function getFaqs(Request $request)
    {
        $limit = ($request->limit) ?? 10;
        $offset = ($request->offset) ?? 0;
        $total = Faq::count();
        $faqs = Faq::orderBy('sort_order')->orderBy('id')->offset($offset)->limit($limit)->get();
        return CommonHelper::responseWithData($faqs, $total);
    }

    // Promo Code
    public function validatePromoCode(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'promo_code' => 'required',
            'total' => 'required'
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user_id = auth()->user()->id;
        $promo_code = $request->promo_code;
        $total = $request->total;
        $deliveryType = strtolower(trim((string) $request->input('delivery_type', 'delivery')));
        $context = [
            'latitude'      => $request->latitude ?? null,
            'longitude'     => $request->longitude ?? null,
            'channel'       => strtolower(trim((string) $request->header('channel'))) ?: null,
            'platform'      => strtolower(trim((string) $request->input('platform'))) ?: null,
            'delivery_type' => in_array($deliveryType, ['delivery', 'pickup'], true) ? $deliveryType : 'delivery',
        ];
        $zone = (!empty($context['latitude']) && !empty($context['longitude']))
            ? CommonHelper::getDeliverableCity($context['latitude'], $context['longitude'], $context['channel'])
            : null;

        $response = CommonHelper::validatePromoCode($user_id, $promo_code, $total, $context);
        if ($response['is_applicable'] == 0) {
            return CommonHelper::responseError($response['message']);
        } else {
            $currency = CommonHelper::countryCurrency($zone?->country);
            $response['currency']      = $currency['currency'];
            $response['currency_code'] = $currency['currency_code'];
            $response['decimal_point'] = $currency['decimal_point'];
            return CommonHelper::responseWithData($response);
        }
    }
    public function getPromoCode(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude'  => 'required',
            'longitude' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user_id = auth()->user()->id;
        $limit = ($request->limit) ?? 10;
        $offset = ($request->offset) ?? 0;
        $sort = ($request->sort) ?? 'id';
        $order = ($request->order) ?? 'DESC';
        if (!isset($request->amount) || empty($request->amount)) {
            return CommonHelper::responseError("Please Pass amount");
        }
        $amount = $request->amount;

        $deliveryType = strtolower(trim((string) $request->input('delivery_type', 'delivery')));
        $deliveryType = in_array($deliveryType, ['delivery', 'pickup'], true) ? $deliveryType : 'delivery';

        $context = [
            'latitude'      => $request->latitude ?? null,
            'longitude'     => $request->longitude ?? null,
            'channel'       => strtolower(trim((string) $request->header('channel'))) ?: null,
            'platform'      => strtolower(trim((string) $request->input('platform'))) ?: null,
            'delivery_type' => $deliveryType,
        ];

        // Scheduling + audience are evaluated in the customer's country timezone
        // (resolved from the delivery location's zone; UTC when unknown).
        $contextZone = (!empty($context['latitude']) && !empty($context['longitude']))
            ? CommonHelper::getDeliverableCity($context['latitude'], $context['longitude'], $context['channel'])
            : null;
        $nowTz   = Carbon::now(CommonHelper::zoneTimezone($contextZone));
        $curDate = $nowTz->format('Y-m-d');
        $curTime = $nowTz->format('H:i:s');
        $curDow  = (int) $nowTz->dayOfWeek; // 0 = Sunday .. 6 = Saturday
        $isNewUser = Order::where('user_id', $user_id)->count() === 0;

        // Only publicly-visible coupons are listed; hidden ones are apply-only.
        $query = PromoCode::select('id', 'title', 'description', 'promo_code', 'image')
            ->where('status', '=', 1)
            ->where('visibility', 'public')
            ->where('source', '!=', 'spin_wheel')
            ->when($deliveryType === 'pickup', fn ($q) => $q->where('discount_type', '!=', 'free_delivery'));

        // ---- Scheduling: date range (permanent skips it), time-of-day window, weekday ----
        $query->where(function ($q) use ($curDate) {
            $q->where('is_permanent', 1)
                ->orWhere(function ($w) use ($curDate) {
                    $w->where(function ($s) use ($curDate) {
                        $s->whereNull('start_date')->orWhere('start_date', '<=', $curDate);
                    })->where(function ($e) use ($curDate) {
                        $e->whereNull('end_date')->orWhere('end_date', '>=', $curDate);
                    });
                });
        });
        $query->where(function ($q) use ($curTime) {
            $q->where('full_day_promotion', 1)
                ->orWhereNull('start_time')->orWhereNull('end_time')
                ->orWhere(function ($w) use ($curTime) {
                    $w->where('start_time', '<=', $curTime)->where('end_time', '>=', $curTime);
                });
        });
        $query->where(function ($q) use ($curDow) {
            $q->whereNull('weekday_recurrence')
                ->orWhere('weekday_recurrence', '[]')
                ->orWhereRaw('JSON_CONTAINS(weekday_recurrence, ?)', [(string) $curDow]);
        });

        // ---- Audience: all / new (no prior orders) / specific (user in the list) ----
        $query->where(function ($q) use ($isNewUser, $user_id) {
            $q->where('audience_type', 'all');
            if ($isNewUser) {
                $q->orWhere('audience_type', 'new');
            }
            $q->orWhere(function ($w) use ($user_id) {
                $w->where('audience_type', 'specific')
                    ->whereRaw('JSON_CONTAINS(audience_ids, ?)', [(string) $user_id]);
            });
        });

        // ---- Platform: app / web coupons listed only on their platform ----
        if (in_array($context['platform'], ['app', 'web'], true)) {
            $query->whereIn('platform', ['all', $context['platform']]);
        }

        // ---- Zone: zone-restricted coupons are listed only inside their zone ----
        // Global coupons (no zone_ids) always show; zone-bound ones only when the
        // customer's resolved zone is in the list.
        $zone = null;
        $userZoneId = 0;
        if (!empty($context['latitude']) && !empty($context['longitude'])) {
            $zone = CommonHelper::getDeliverableCity($context['latitude'], $context['longitude'], $context['channel']);
            $userZoneId = $zone ? (int) $zone->id : 0;
        }
        $query->where(function ($q) use ($userZoneId) {
            $q->whereNull('zone_ids')->orWhereRaw('JSON_LENGTH(zone_ids) = 0');
            if ($userZoneId > 0) {
                $q->orWhereRaw('JSON_CONTAINS(zone_ids, ?)', [(string) $userZoneId]);
            }
        });

        $total = $query->count();
        $codeModels = $query->orderBy($sort, $order)->skip($offset)->take($limit)->get();

        if ($codeModels->isNotEmpty()) {
            $decimalPoint = (int) (Setting::get_value('decimal_point') ?? 2);
            if ($decimalPoint < 0) {
                $decimalPoint = 2;
            }

            $currency = CommonHelper::countryCurrency($zone?->country);

            $codes = [];
            foreach ($codeModels as $key => $model) {
                $result = CommonHelper::validatePromoCode($user_id, $model->promo_code, $amount, $context);

                $codes[$key] = [
                    'id'                   => $model->id,
                    'promo_code_id'        => $model->id,
                    'is_applicable'        => (int) ($result['is_applicable'] ?? 0),
                    'message'              => $result['message'] ?? '',
                    'unlock_message'       => $result['unlock_message'] ?? '',
                    'promo_code'           => $model->promo_code,
                    'title'                => $model->title ?? '',
                    'description'          => $model->description ?? '',
                    'image_url'            => $model->image_url ?? '',
                    'total'                => round((float) ($result['total'] ?? 0), $decimalPoint),
                    'discount'             => round((float) ($result['discount'] ?? 0), $decimalPoint),
                    'discounted_amount'    => round((float) ($result['discounted_amount'] ?? 0), $decimalPoint),
                    'discount_type'        => $result['discount_type'] ?? $model->discount_type,
                    'discount_apply_type'  => $result['discount_apply_type'] ?? $model->discount_apply_type,
                    'max_discount_amount'  => (float) ($result['max_discount_amount'] ?? $model->max_discount_amount),
                    'minimum_order_amount' => (float) ($result['minimum_order_amount'] ?? $model->minimum_order_amount),
                    'min_product_quantity' => (int) ($result['min_product_quantity'] ?? $model->min_product_quantity),
                    'free_delivery'        => (int) ($result['free_delivery'] ?? ($model->discount_type === 'free_delivery' ? 1 : 0)),
                    'currency'             => $currency['currency'],
                    'currency_code'        => $currency['currency_code'],
                    'decimal_point'        => $currency['decimal_point'],
                ];
            }

            // Applicable coupons first, then highest discount first.
            usort($codes, function ($a, $b) {
                if ($a['is_applicable'] !== $b['is_applicable']) {
                    return $b['is_applicable'] <=> $a['is_applicable'];
                }
                return $b['discount'] <=> $a['discount'];
            });

            return CommonHelper::responseWithData($codes, $total);
        } else {
            return CommonHelper::responseError("Data not Found!");
        }
    }

    public function getSocialMedia()
    {
        $socialMedia = SocialMedia::orderBy('id', 'DESC')->get();
        if (count($socialMedia)) {
            return CommonHelper::responseWithData($socialMedia);
        } else {
            return CommonHelper::responseError("No Offer Found!");
        }
    }

    public function getZone(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude' => 'required',
            'longitude' => 'required',
        ], [
            'required' => 'The city :attribute field is required.'
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $channel = strtolower(trim((string) $request->header('channel'))) ?: null;
        $city = CommonHelper::getDeliverableCity($request->latitude, $request->longitude, $channel);

        $channels = CommonHelper::deliverableChannels($request->latitude, $request->longitude);

        if (empty($city)) {
            return response()->json([
                'error'              => true,
                'status'             => 0,
                'message'            => __('we_doesnt_delivery_at_selected_city'),
                'channels_available' => $channels,
            ]);
        }

        // Delivery / self-pickup availability is reported by the cart API, not here.
        $data = $city->toArray();
        $data['channels_available'] = $channels;

        return CommonHelper::responseWithData($data);
    }

    public function getZones(Request $request)
    {
        $countryId = (int) $request->input('country_id', 0);
        if ($countryId <= 0) {
            $countryId = (int) (Country::where('is_default', 1)->value('id')
                ?: Country::where('status', 1)->orderBy('id')->value('id'));
        }
        if ($countryId <= 0) {
            return CommonHelper::responseError('no_country_found');
        }

        $zones = Zone::where('country_id', $countryId)
            ->where('status', 1)
            ->whereHas('branches', fn ($q) => $q->where('status', 1))
            ->orderBy('name')
            ->get(['id', 'name', 'slug', 'polygon_boundary_quick', 'polygon_boundary_ecommerce', 'sales_channel'])
            ->map(function (Zone $z) {
                $quick = is_array($z->polygon_boundary_quick) ? $z->polygon_boundary_quick : [];
                $ecom  = is_array($z->polygon_boundary_ecommerce) ? $z->polygon_boundary_ecommerce : [];

                if ($z->sales_channel === 'quick') {
                    $boundary = $quick ?: $ecom;
                } elseif ($z->sales_channel === 'ecommerce') {
                    $boundary = $ecom ?: $quick;
                } else {
                    $boundary = self::mergeBoundaries($quick, $ecom);
                }

                return [
                    'id'               => (int) $z->id,
                    'name'             => $z->getAttributeValue('name'),
                    'slug'             => $z->slug,
                    'channel'          => $z->sales_channel,
                    'polygon_boundary'            => $boundary
                ];
            });

        return CommonHelper::responseWithData($zones, $zones->count());
    }

    private static function mergeBoundaries(array $quick, array $ecom): array
    {
        if (empty($quick)) {
            return $ecom;
        }
        if (empty($ecom)) {
            return $quick;
        }

        // Remember the input point shape so we return the same one.
        $sample = $quick[0] ?? $ecom[0] ?? [];
        $assoc  = is_array($sample) && array_key_exists('lat', $sample);

        $wktQuick = self::pointsToWkt($quick);
        $wktEcom  = self::pointsToWkt($ecom);
        if ($wktQuick === null || $wktEcom === null) {
            return array_merge($quick, $ecom);
        }

        try {
            $row = DB::selectOne(
                'SELECT ST_AsGeoJSON(ST_Union(ST_GeomFromText(?), ST_GeomFromText(?))) AS g',
                [$wktQuick, $wktEcom]
            );
            $geo = json_decode($row->g ?? '', true);
            $points = self::geoJsonOuterPoints($geo, $assoc);
            return $points ?: array_merge($quick, $ecom);
        } catch (\Throwable $e) {
            return array_merge($quick, $ecom);
        }
    }

    /** Build a closed POLYGON WKT ("lng lat" order) from a point list, or null. */
    private static function pointsToWkt(array $points): ?string
    {
        $coords = [];
        foreach ($points as $p) {
            if (!is_array($p)) {
                return null;
            }
            $lat = $p['lat'] ?? $p[0] ?? null;
            $lng = $p['lng'] ?? $p['lon'] ?? $p[1] ?? null;
            if ($lat === null || $lng === null) {
                return null;
            }
            $coords[] = ((float) $lng) . ' ' . ((float) $lat);
        }
        if (count($coords) < 3) {
            return null;
        }
        // A WKT ring must be closed (first point repeated at the end).
        if ($coords[0] !== end($coords)) {
            $coords[] = $coords[0];
        }
        return 'POLYGON((' . implode(',', $coords) . '))';
    }

    /**
     * Flatten a GeoJSON Polygon/MultiPolygon into outer-ring points, converting
     * [lng, lat] back to the caller's point shape ({lat,lng} or [lat,lng]).
     */
    private static function geoJsonOuterPoints($geo, bool $assoc): array
    {
        if (!is_array($geo) || empty($geo['type']) || empty($geo['coordinates'])) {
            return [];
        }

        // Collect the outer ring of each polygon (index 0 = exterior, rest = holes).
        $rings = [];
        if ($geo['type'] === 'Polygon') {
            $rings[] = $geo['coordinates'][0] ?? [];
        } elseif ($geo['type'] === 'MultiPolygon') {
            foreach ($geo['coordinates'] as $poly) {
                $rings[] = $poly[0] ?? [];
            }
        } else {
            return [];
        }

        $out = [];
        foreach ($rings as $ring) {
            foreach ($ring as $c) {
                $lng = (float) ($c[0] ?? 0);
                $lat = (float) ($c[1] ?? 0);
                $out[] = $assoc ? ['lat' => $lat, 'lng' => $lng] : [$lat, $lng];
            }
        }
        return $out;
    }

    public function getNotifications(Request $request)
    {
        $limit = ($request->limit) ?? 10;
        $offset = ($request->offset) ?? 0;
        $sort = ($request->sort) ?? 'id';
        $order = ($request->sort) ?? 'DESC';
        $where = '';
        if (isset($request->search) && $request->search != '') {
            $search = $request->search;
            $where = " `id` like '%" . $search . "%' OR `title` like '%" . $search . "%' OR `message` like '%" . $search . "%' OR `image` like '%" . $search . "%' OR `date_sent` like '%" . $search . "%' ";
        }

        $authUser = $request->user('api-customers');
        $user_id = $authUser ? $authUser->id : '';
        if ($user_id) {
            $sql = Notification::where(function ($q) use ($user_id) {
                $q->where(function ($inner) use ($user_id) {
                    $inner->where('type', 'user')->where('type_id', $user_id);
                })->orWhereNotIn('type', ['user', 'delivery_boy']);
            });
            if ($authUser->created_at) {
                $sql = $sql->where('date_sent', '>=', $authUser->created_at);
            }
        } else {
            $sql = Notification::whereNotIn('type', ['user', 'delivery_boy']);
        }
        if ($where != "") {
            $sql = $sql->whereRaw($where);
        }
        $total = $sql->count();
        $notifications = $sql->orderBy($sort, $order)->skip($offset)->take($limit)->get();

        if (!empty($notifications)) {
            $categoryIds = $notifications->where('type', 'category')->pluck('type_id')->filter()->unique()->all();
            $categoryNames = !empty($categoryIds)
                ? Category::whereIn('id', $categoryIds)->pluck('name', 'id')
                : collect();

            $rows = array();
            foreach ($notifications as $row) {
                $tempRow = array();
                $tempRow['id'] = $row->id;
                $tempRow['title'] = $row->title;
                $tempRow['message'] = $row->message;
                $tempRow['type'] = $row->type;
                $tempRow['type_id'] = $row->type_id;
                $tempRow['category_name'] = $row->type === 'category'
                    ? (string) ($categoryNames[$row->type_id] ?? '')
                    : '';
                $tempRow['image_url'] = CommonHelper::getImage($row->image);
                $tempRow['link_url'] = $row->type_link;
                $tempRow['date_sent'] = $row->date_sent;
                $rows[] = $tempRow;
            }
            return CommonHelper::responseWithData($rows, $total);
        } else {
            return CommonHelper::responseError('no_notification_found');
        }
    }

    public function getBrands(Request $request)
    {
        $offset = $request->input('offset', 0);
        $limit = $request->input('limit', 10);
        $latitude = $request->input('latitude');
        $longitude = $request->input('longitude');

        // Validate if latitude & longitude are provided
        if (!$latitude || !$longitude) {
            return CommonHelper::responseError('Latitude and longitude are required.');
        }

        // Get branch IDs based on location
        $branch_ids = CommonHelper::getBranchIds($latitude, $longitude);

        // If no branches found in the area, return error
        if (empty($branch_ids)) {
            return CommonHelper::responseError('No branches found in this area.');
        }

        // Fetch brands with products sold by branches in the area
        $brands = Brand::where('status', 1)
            ->whereHas('products', function ($query) use ($branch_ids) {
                $query->where('products.status', 1)
                    ->whereExists(function ($pvssQuery) use ($branch_ids) {
                        $pvssQuery->select(DB::raw(1))
                            ->from('product_variants as pv')
                            ->join('product_variant_branch_stocks as pvss', 'pvss.product_variant_id', '=', 'pv.id')
                            ->whereColumn('pv.product_id', 'products.id')
                            ->whereIn('pvss.branch_id', $branch_ids)
                            ->where('pvss.is_listed', 1);
                    })
                    ->whereExists(function ($categoryQuery) {
                        $categoryQuery->select(DB::raw(1))
                            ->from('categories')
                            ->whereColumn('categories.id', 'products.category_id')
                            ->where('categories.status', 1);
                    });
            })
            ->orderBy('id', 'ASC');

        // Get total count before applying pagination
        $total = $brands->count();

        // Apply pagination
        $brands = $brands->offset($offset)->limit($limit)->get();
        $brands = $brands->makeHidden(['created_at', 'updated_at', 'image', 'status']);

        if ($brands->isNotEmpty()) {
            return CommonHelper::responseWithData($brands, $total);
        } else {
            return CommonHelper::responseError('No brands found in this area.');
        }
    }

    public function getOrderStatusLists(Request $request)
    {
        // Optionally narrowed to one kind of order (channel + delivery type), in flow
        // order, with "Collected" for a pickup order's final stage.
        $channel = strtolower(trim((string) $request->input('channel', '')));
        $deliveryType = strtolower(trim((string) $request->input('delivery_type', '')));
        if ($channel !== '' || $deliveryType === 'pickup') {
            $flow = OrderStatusList::flowFor($channel ?: null, $deliveryType ?: null);
            $statuses = OrderStatusList::whereIn('id', $flow)->get()
                ->sortBy(fn ($s) => array_search($s->id, $flow, true))
                ->values()
                ->map(function ($s) use ($deliveryType) {
                    $s->status_name = OrderStatusList::getCustomerTranslatedName((int) $s->id, $deliveryType ?: null);
                    return $s;
                });
        } else {
            $statuses = OrderStatusList::orderBy('id', 'ASC')->get();
        }
        $total = $statuses->count();
        if (!empty($statuses)) {
            return CommonHelper::responseWithData($statuses, $total);
        } else {
            return CommonHelper::responseError('status_not_found');
        }
    }

    public function deleteDeliveryBoyAccount()
    {
        try {
            $delivery_boy_admin_id = auth()->user()->id;
            $delivery_boy = DeliveryBoy::where('admin_id', $delivery_boy_admin_id)->first();

            if ($delivery_boy->email == 'alex@gmail.com' && isDemoMode()) {
                return CommonHelper::responseError("This function is not available in demo mode!");
            }
            if (floatval($delivery_boy->balance ?? 0) > 0) {
                return CommonHelper::responseError('cannot_delete_account_with_balance');
            }
            $admin = Admin::where('id', $delivery_boy_admin_id)->first();
            $admin->delete();
            $delivery_boy->delete();
            return CommonHelper::responseSuccess('your_delivery_boy_account_deleted_successfully');
        } catch (\Exception $e) {
            Log::error('Login : ' . $e->getMessage());
            return CommonHelper::responseError($e->getMessage());
        }
    }

    public function getSeoThings(Request $request)
    {
        $slug = $request->input('slug');

        $category = Category::where('slug', $slug)
            ->with('translations')
            ->first();

        if (!$category) {
            return CommonHelper::responseError('category_not_available');
        }
        $seoThings = [];
        $seoThings['meta_title'] = $category->meta_title;
        $seoThings['meta_keywords'] = $category->meta_keywords;
        $seoThings['meta_description'] = $category->meta_description;
        $seoThings['schema_markup'] = $category->schema_markup;
        $seoThings['og_image'] = $category->image_url;
        $seoThings['favicon'] = Setting::get_value('favicon') ? asset('storage/' . Setting::get_value('favicon')) : '';

        $seoThings['translations'] = $category->translations;

        return CommonHelper::responseWithData($seoThings);
    }

    public function getBlogCategories(Request $request)
    {
        try {
            $limit = (int) $request->input('limit', 50);
            $offset = (int) $request->input('offset', 0);
            $search = $request->input('search');

            $query = BlogCategory::with('translations')
                ->where('status', 1)
                ->withCount(['activeBlogs'])
                ->orderByDesc('id');

            if ($search && trim($search) !== '') {
                $query->where('name', 'like', '%' . trim($search) . '%');
            }

            $total = (clone $query)->count();
            $categories = $query->offset($offset)->limit($limit)->get();

            return CommonHelper::responseWithData($categories, $total);
        } catch (\Throwable $e) {
            return CommonHelper::responseError('something_went_wrong');
        }
    }

    public function getBlogs(Request $request)
    {
        try {
            $limit = (int) $request->input('limit', 10);
            $page = (int) $request->input('page', 1);
            $offset = ($page - 1) * $limit;
            $search = $request->input('search');
            $categoryId = $request->input('category_id');
            $slug = $request->input('slug');
            $tagId = $request->input('tag_id');

            $query = Blog::with(['category', 'translations', 'category.translations'])
                ->where('status', 1)
                ->whereHas('category', fn($q) => $q->where('status', 1));

            if ($search && trim($search) !== '') {
                $query->search($search);
            }
            if ($slug && trim($slug) !== '') {
                $query->where('slug', $slug);
            }
            if ($categoryId && (int) $categoryId > 0) {
                $query->where('category_id', (int) $categoryId);
            }
            if ($tagId && (int) $tagId > 0) {
                $query->whereRaw('FIND_IN_SET(?, COALESCE(tags, ""))', [(int) $tagId]);
            }

            $total = (clone $query)->count();
            $blogs = $query->orderByDesc('id')->offset($offset)->limit($limit)->get();
            $blogs = $this->appendTagsMetadata($blogs);
            $blogs = $blogs->map(function ($blog) {
                $raw = $blog->getAttributes()['created_at'] ?? null;
                $row = $blog->toArray();
                if ($raw !== null && $raw !== '') {
                    $row['created_at'] = $raw;
                }
                return $row;
            });

            return CommonHelper::responseWithData($blogs, $total);
        } catch (\Throwable $e) {
            return CommonHelper::responseError('something_went_wrong');
        }
    }

    private function appendTagsMetadata($blogs)
    {
        $tagIds = $blogs->pluck('tags')
            ->filter()
            ->flatMap(fn($v) => explode(',', $v))
            ->unique()
            ->values();

        $langId = app()->has('lang_id') ? app('lang_id') : null;
        $query = BlogTag::whereIn('id', $tagIds);
        if ($langId) {
            $query->where('language_id', $langId);
        }
        $tagMap = $query->pluck('name', 'id')->toArray();

        foreach ($blogs as $blog) {
            $blog->tag_names = collect(explode(',', $blog->tags ?? ''))
                ->map(fn($id) => $tagMap[$id] ?? null)
                ->filter()
                ->values()
                ->all();
        }

        return $blogs;
    }

}
