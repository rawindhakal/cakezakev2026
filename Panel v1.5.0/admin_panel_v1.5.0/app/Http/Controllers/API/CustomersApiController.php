<?php

namespace App\Http\Controllers\API;

use App\Helpers\AddonHelper;
use App\Helpers\CommonHelper;
use App\Helpers\HomeLayoutResolver;
use App\Helpers\ProductHelper;
use App\Http\Controllers\Controller;
use App\Models\Cart;
use App\Models\Country;
use App\Models\Favorite;
use App\Models\Order;
use App\Models\OrderStatusList;
use App\Models\ProductStockAlert;
use App\Models\Transaction;
use App\Models\WalletTransaction;
use App\Models\User;
use App\Models\UserAddress;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CustomersApiController extends Controller
{
    public function getCustomers(Request $request)
    {
        $query = User::where('status', '!=', 2);

        // Zone scope — branch users are force-scoped to their zone (and the admin
        // zone header filters too): only customers who ordered in that zone.
        $zoneId = (int) $request->input('zone_id', 0);
        if ($zoneId) {
            $query->whereIn('id', Order::where('zone_id', $zoneId)->distinct()->pluck('user_id'));
        }

        // How the customer signed up: phone | google | apple | email.
        $type = trim((string) $request->input('type', ''));
        if ($type !== '' && in_array($type, ['phone', 'google', 'apple', 'email'], true)) {
            $query->where('type', $type);
        }

        $status = $request->input('status');
        if ($status !== null && $status !== '' && in_array((int) $status, [0, 1], true)) {
            $query->where('status', (int) $status);
        }

        if ($request->has('search')) {
            $searchTerm = $request->input('search');
            $query->where(function ($query) use ($searchTerm) {
                $query->where('name', 'like', '%' . $searchTerm . '%')
                    ->orWhere('email', 'like', '%' . $searchTerm . '%')
                    ->orWhere('mobile', 'like', '%' . $searchTerm . '%')
                    ->orWhere('referral_code', 'like', '%' . $searchTerm . '%')
                    ->orWhere('friends_code', 'like', '%' . $searchTerm . '%')
                    ->orWhere('status', 'like', '%' . $searchTerm . '%');
            });
        }

        // Apply sorting
        if ($request->has('sort_by')) {
            $sortColumn = $request->input('sort_by', 'id');
            $sortDirection = $request->input('sort_dir', 'desc dvfd');
            $query->orderBy($sortColumn, $sortDirection);
        }

        // Get the total count for pagination
        $total = $query->count();
        $customers = $query->get();

        $customersForResponse = $customers->map(function (User $user) {
            $row = $user->toArray();
            $rawCreated = $user->getAttributes()['created_at'] ?? null;
            if ($rawCreated !== null && $rawCreated !== '') {
                $row['created_at'] = $rawCreated;
            }
            return $row;
        });

        return CommonHelper::responseWithData($customersForResponse, $total);
    }
    /** Full customer profile: stats, orders, addresses, transactions. */
    public function getCustomerDetail($id)
    {
        $user = User::find($id);
        if (!$user) {
            return CommonHelper::responseError('customer_record_not_found');
        }

        // Global header country/zone filter — the detail (stats/orders/transactions/wallet)
        // is computed over the customer's activity in the selected country/zone.
        $countryId = (int) request()->input('country_id', 0);
        $zoneId    = (int) request()->input('zone_id', 0);
        $scopeOrders = function ($q) use ($countryId, $zoneId) {
            return $q->when($countryId, fn ($x) => $x->where('country_id', $countryId))
                ->when($zoneId, fn ($x) => $x->where('zone_id', $zoneId));
        };

        $base = $scopeOrders(Order::where('user_id', $id));
        $totalOrders = (clone $base)->count();
        $delivered   = (clone $base)->where('active_status', OrderStatusList::$delivered)->count();
        $lastOrder   = (clone $base)->orderByDesc('id')->first();

        $confirmed = [2, 3, 4, 5, 6, 9, 10, 11];
        $quickSpent = (float) (clone $base)->where('channel', 'quick')
            ->whereIn('active_status', $confirmed)
            ->sum(DB::raw('COALESCE(orders.final_total,0) + COALESCE(orders.wallet_balance,0)'));
        $ecomSpent = (float) DB::table('order_items as oi')
            ->join('orders as o', 'oi.order_id', '=', 'o.id')
            ->whereNull('o.deleted_at')->whereNull('oi.deleted_at')
            ->where('o.user_id', $id)
            ->when($countryId, fn ($x) => $x->where('o.country_id', $countryId))
            ->when($zoneId, fn ($x) => $x->where('o.zone_id', $zoneId))
            ->where('o.channel', 'ecommerce')->whereIn('oi.active_status', $confirmed)
            ->sum(DB::raw('COALESCE(oi.final_total,0) + COALESCE(oi.wallet_balance,0)'));
        $totalSpent = round($quickSpent + $ecomSpent, 2);
        // AOV over the orders that actually contributed revenue.
        $confirmedOrders = (int) (clone $base)->whereIn('active_status', $confirmed)->count();

        $orders = $scopeOrders(Order::select(
            'orders.id',
            'orders.order_number',
            'orders.channel',
            'orders.final_total',
            'orders.currency',
            'orders.payment_method',
            'orders.active_status',
            'orders.created_at',
            DB::raw('(SELECT GROUP_CONCAT(oi.product_name SEPARATOR ", ") FROM order_items oi WHERE oi.order_id = orders.id) as items_preview'),
            DB::raw('(SELECT t.status FROM transactions t WHERE t.order_id = orders.id ORDER BY t.id DESC LIMIT 1) as payment_status')
        )->where('user_id', $id))->orderByDesc('id')->get();

        // --- Analytics ---
        // Status breakdown: every status with this customer's order count.
        $statusCounts = $scopeOrders(Order::where('user_id', $id))
            ->select('active_status', DB::raw('COUNT(*) as c'))
            ->groupBy('active_status')
            ->pluck('c', 'active_status');
        $statusBreakdown = OrderStatusList::orderBy('id')->get()->map(function ($s) use ($statusCounts) {
            $key = OrderStatusList::getTranslationKey($s->id);
            return [
                'id'     => $s->id,
                'name'   => $key !== '' ? __($key) : $s->status,
                'count'  => (int) ($statusCounts[$s->id] ?? 0),
            ];
        })->values();

        // Monthly orders for the current year.
        $year = (int) date('Y');
        $monthly = $scopeOrders(Order::where('user_id', $id)->whereYear('created_at', $year))
            ->select(DB::raw('MONTH(created_at) as m'), DB::raw('COUNT(*) as orders'), DB::raw('SUM(final_total) as revenue'))
            ->groupBy(DB::raw('MONTH(created_at)'))
            ->get()->keyBy('m');
        $months = [];
        $monthlyOrders = [];
        $monthlyRevenue = [];
        $labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        for ($m = 1; $m <= 12; $m++) {
            $months[] = $labels[$m - 1];
            $monthlyOrders[] = (int) ($monthly[$m]->orders ?? 0);
            $monthlyRevenue[] = round((float) ($monthly[$m]->revenue ?? 0), 2);
        }

        // Orders per channel (all-time).
        $channelCounts = $scopeOrders(Order::where('user_id', $id))
            ->select('channel', DB::raw('COUNT(*) as c'))
            ->groupBy('channel')->pluck('c', 'channel');
        $quickCount = (int) ($channelCounts['quick'] ?? 0);
        $ecommerceCount = (int) ($channelCounts['ecommerce'] ?? 0);

        $addresses = UserAddress::where('user_id', $id)->get();

        $transactionRows = Transaction::where('user_id', $id)
            ->when($countryId, fn ($q) => $q->where('country_id', $countryId))
            ->when($zoneId, fn ($q) => $q->where('zone_id', $zoneId))
            ->orderByDesc('id')->get();
        $walletRows = WalletTransaction::where('user_id', $id)
            ->when($countryId, fn ($q) => $q->where('country_id', $countryId))
            ->orderByDesc('id')->get();

        // Map order id -> order_number for both ledgers so the tabs show the number.
        $refOrderIds = $transactionRows->pluck('order_id')
            ->merge($walletRows->pluck('order_id'))
            ->filter()->unique()->all();
        $orderNumbers = !empty($refOrderIds)
            ? Order::whereIn('id', $refOrderIds)->pluck('order_number', 'id')
            : collect();

        $transactions = $transactionRows->map(function ($t) use ($orderNumbers) {
            return [
                'id'           => $t->id,
                'order_id'     => $t->order_id,
                'order_number' => $t->order_id ? ($orderNumbers[$t->order_id] ?? null) : null,
                'type'         => CommonHelper::translateTransactionMessage($t->type),
                'amount'       => $t->amount,
                'status'       => $t->status,
                'message'      => CommonHelper::translateTransactionMessage($t->message),
                'date'         => $t->getAttributes()['created_at'] ?? null,
            ];
        });

        // Wallet ledger (credits/debits) for the wallet-transactions tab.
        $walletTransactions = $walletRows->map(function ($wt) use ($orderNumbers) {
            return [
                'id'           => $wt->id,
                'order_id'     => $wt->order_id,
                'order_number' => $wt->order_id ? ($orderNumbers[$wt->order_id] ?? null) : null,
                'type'         => $wt->type,
                'amount'       => $wt->amount,
                'status'       => $wt->status,
                'message'      => CommonHelper::translateLedgerMessage($wt->message),
                'date'         => $wt->getAttributes()['created_at'] ?? null,
            ];
        });

        // Wallet + currency reflect the selected country (else home country / last order).
        $walletBalance = $countryId
            ? (float) CommonHelper::getUserWalletBalance($id, $countryId)
            : (float) $user->balance;
        $detailCurrency = $countryId
            ? Country::where('id', $countryId)->value('currency')
            : ($lastOrder->currency ?? null);

        $data = [
            'user' => [
                'id'           => $user->id,
                'name'         => $user->name,
                'email'        => $user->email,
                'mobile'       => $user->mobile,
                'country_code' => $user->country_code,
                'balance'      => $walletBalance,
                'status'       => (int) $user->status,
                'created_at'   => $user->getAttributes()['created_at'] ?? null,
                'profile'      => $user->getAttributes()['profile'] ?? '',
                'profile_url'  => $user->profile,
            ],
            'stats' => [
                'total_orders'    => $totalOrders,
                'delivered'       => $delivered,
                'total_spent'     => $totalSpent,
                'avg_order_value' => $confirmedOrders > 0 ? round($totalSpent / $confirmedOrders, 2) : 0,
                'wallet_balance'  => $walletBalance,
                'last_order_date' => $lastOrder ? $lastOrder->getAttributes()['created_at'] ?? null : null,
                'currency'        => $detailCurrency,
            ],
            'orders'       => $orders,
            'addresses'    => $addresses,
            'transactions' => $transactions,
            'wallet_transactions' => $walletTransactions,
            'analytics'    => [
                'status_breakdown' => $statusBreakdown,
                'year'             => $year,
                'months'           => $months,
                'monthly_orders'   => $monthlyOrders,
                'monthly_revenue'  => $monthlyRevenue,
                'quick_orders'     => $quickCount,
                'ecommerce_orders' => $ecommerceCount,
            ],
        ];

        return CommonHelper::responseWithData($data);
    }

    private function applyListFilters($query, Request $request, string $table): void
    {
        if (!empty($request->category_id)) {
            $categoryIds = HomeLayoutResolver::categorySubtreeIds((int) $request->category_id);
            $query->whereIn('products.category_id', $categoryIds);
        }
        if (!empty($request->brand_id)) {
            $query->where('products.brand_id', (int) $request->brand_id);
        }
        if (!empty($request->channel)) {
            $query->where($table . '.channel', $request->channel);
        }
        // Accept both snake_case and camelCase date params from the two frontends.
        $startDate = $request->start_date ?? $request->startDate ?? null;
        $endDate   = $request->end_date ?? $request->endDate ?? null;
        if (!empty($startDate)) {
            $query->whereDate($table . '.created_at', '>=', $startDate);
        }
        if (!empty($endDate)) {
            $query->whereDate($table . '.created_at', '<=', $endDate);
        }
    }

    public function getWishlists(Request $request)
    {
        $query = Favorite::select(
                'users.name as user_name',
                DB::raw('(SELECT pv.name FROM product_variants pv WHERE pv.product_id = products.id ORDER BY pv.sort_order, pv.id LIMIT 1) as product_name'),
                DB::raw('(SELECT s.name FROM product_variants pv2 JOIN product_variant_branch_stocks pvss ON pvss.product_variant_id = pv2.id JOIN branches s ON s.id = pvss.branch_id WHERE pv2.product_id = products.id AND pvss.is_listed = 1 ORDER BY pv2.sort_order, pv2.id LIMIT 1) as branch_name'),
                'favorites.*',
                DB::raw("COUNT(*) as 'total_qty'")
            )
            ->leftJoin('users', 'favorites.user_id', '=', 'users.id')
            ->leftJoin('products', 'favorites.product_id', '=', 'products.id');

        $this->applyListFilters($query, $request, 'favorites');

        $wishlists = $query->groupBy('favorites.product_id')
            ->orderBy('favorites.id', 'DESC')
            ->get();

        return CommonHelper::responseWithData($wishlists);
    }

    /**
     * Customers' "notify me when back in stock" requests.
     *
     * Two questions an admin has: who is waiting on what (the list), and which products
     * are in demand right now (the summary) — the second is what decides a reorder.
     */
    public function getStockAlerts(Request $request)
    {
        $query = ProductStockAlert::from('product_stock_alerts as a')
            ->leftJoin('users as u', 'u.id', '=', 'a.user_id')
            ->leftJoin('products as p', 'p.id', '=', 'a.product_id')
            ->leftJoin('product_variants as v', 'v.id', '=', 'a.product_variant_id')
            ->leftJoin('zones as z', 'z.id', '=', 'a.zone_id');

        if ($request->filled('status') && in_array((int) $request->status, [0, 1, 2], true)) {
            $query->where('a.status', (int) $request->status);
        }
        if ($request->filled('country_id')) {
            $query->where('a.country_id', (int) $request->country_id);
        }
        if ($request->filled('zone_id')) {
            $query->where('a.zone_id', (int) $request->zone_id);
        }
        if ($request->filled('startDate') && $request->filled('endDate')) {
            $query->whereBetween('a.created_at', [$request->startDate . ' 00:00:00', $request->endDate . ' 23:59:59']);
        }
        $search = trim((string) $request->input('search', ''));
        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                $q->where('p.name', 'like', "%{$search}%")
                    ->orWhere('v.name', 'like', "%{$search}%")
                    ->orWhere('u.name', 'like', "%{$search}%")
                    ->orWhere('u.mobile', 'like', "%{$search}%")
                    ->orWhere('u.email', 'like', "%{$search}%");
            });
        }

        $topProducts = (clone $query)
            ->where('a.status', ProductStockAlert::STATUS_WAITING)
            ->selectRaw('a.product_id, p.name as product_name, p.image, COUNT(*) as waiting, MIN(a.created_at) as oldest_request')
            ->groupBy('a.product_id', 'p.name', 'p.image')
            ->orderByDesc('waiting')
            ->limit(10)
            ->get()
            ->map(fn ($r) => [
                'product_id'     => (int) $r->product_id,
                'product_name'   => $r->product_name,
                'image'          => $r->image ? asset('storage/' . $r->image) : '',
                'waiting'        => (int) $r->waiting,
                'oldest_request' => $r->oldest_request,
            ]);

        if ($request->filled('product_id')) {
            $query->where('a.product_id', (int) $request->product_id);
        }
        $total = (clone $query)->count('a.id');

        $counts = (clone $query)
            ->selectRaw('SUM(a.status = 1) as waiting, SUM(a.status = 2) as notified, SUM(a.status = 0) as cancelled, COUNT(DISTINCT a.product_variant_id) as variants, COUNT(DISTINCT a.user_id) as customers')
            ->first();

        $limit = (int) $request->input('per_page', 20) ?: 20;
        $page = max(1, (int) $request->input('page', 1));
        $rows = $query->select(
            'a.*',
            'u.name as user_name',
            'u.mobile as user_mobile',
            'u.email as user_email',
            'p.name as product_name',
            'p.image as product_image',
            'v.name as variant_name',
            'z.name as zone_name',
            DB::raw('(SELECT s.name FROM branches s
                WHERE s.zone_id = a.zone_id
                ORDER BY (EXISTS (SELECT 1 FROM product_variant_branch_stocks pvss
                    WHERE pvss.branch_id = s.id AND pvss.product_variant_id = a.product_variant_id)) DESC, s.id
                LIMIT 1) as branch_name')
        )
            ->orderByDesc('a.id')
            ->skip(($page - 1) * $limit)
            ->take($limit)
            ->get()
            ->map(function ($r) {
                $r->product_image = $r->product_image ? asset('storage/' . $r->product_image) : '';
                $r->status_name = match ((int) $r->status) {
                    ProductStockAlert::STATUS_WAITING  => __('waiting'),
                    ProductStockAlert::STATUS_NOTIFIED => __('notified'),
                    default                            => __('cancelled'),
                };
                return $r;
            });

        return CommonHelper::responseWithData([
            'alerts'  => $rows,
            'summary' => [
                'waiting'   => (int) ($counts->waiting ?? 0),
                'notified'  => (int) ($counts->notified ?? 0),
                'cancelled' => (int) ($counts->cancelled ?? 0),
                'variants'  => (int) ($counts->variants ?? 0),
                'customers' => (int) ($counts->customers ?? 0),
            ],
            'top_products' => $topProducts,
        ], $total);
    }

    /** Admin: cart listing (one row per cart entry) with product/variant/branch labels. */
    public function getCarts(Request $request)
    {
        $query = Cart::select(
                'carts.*',
                'users.name as user_name',
                'products.name as product_name',
                'product_variants.name as variant_name',
                'branches.name as branch_name'
            )
            ->leftJoin('users', 'carts.user_id', '=', 'users.id')
            ->leftJoin('products', 'carts.product_id', '=', 'products.id')
            ->leftJoin('product_variants', 'carts.product_variant_id', '=', 'product_variants.id')
            ->leftJoin('branches', 'carts.branch_id', '=', 'branches.id');

        $this->applyListFilters($query, $request, 'carts');

        $carts = $query->orderBy('carts.id', 'DESC')->get();

        return CommonHelper::responseWithData($carts);
    }

    /** Admin: remove a cart row and release its reserved stock back to available. */
    public function removeCart(Request $request)
    {
        if (empty($request->id)) {
            return CommonHelper::responseError('id_is_required');
        }

        $cart = Cart::find($request->id);
        if (!$cart) {
            return CommonHelper::responseError('cart_item_not_found');
        }

        // Return the reserved qty to available for that variant+branch (reserved-- , available++).
        ProductHelper::releaseStock($cart->product_variant_id, $cart->branch_id, (int) $cart->qty);
        AddonHelper::moveCartStock($cart->addons, $cart->branch_id, (int) $cart->qty, 'release');
        $cart->delete();

        return CommonHelper::responseSuccess('cart_item_removed_successfully');
    }

    /** Set customer status explicitly (1 = active, 0 = inactive). */
    public function setStatus(Request $request)
    {
        $user = isset($request->id) ? User::find($request->id) : null;
        if (!$user) {
            return CommonHelper::responseError('customer_record_not_found');
        }
        $user->status = ((int) $request->status === 1) ? 1 : 0;
        $user->save();
        // Deactivating must log the customer out everywhere: revoke their tokens
        if ($user->status === 0) {
            $user->tokens()->update(['revoked' => true]);
        }
        CommonHelper::sendCustomerStatusNotification($user);
        return CommonHelper::responseSuccess('customers_status_updated_successfully');
    }
}
