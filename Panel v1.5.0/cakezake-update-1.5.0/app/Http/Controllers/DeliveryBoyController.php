<?php

namespace App\Http\Controllers;

use App\Helpers\CommonHelper;
use App\Http\Controllers\API\OrdersApiController;
use App\Http\Controllers\API\OrderStatusApiController;
use App\Http\Controllers\API\ReturnRequestsApiController;
use App\Models\Country;
use App\Models\DeliveryBoy;
use App\Models\DeliveryBoySalary;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatus;
use App\Models\ReturnRequest;
use App\Models\ReturnStatusList;
use App\Models\Role;
use Illuminate\Support\Facades\DB;
use App\Models\OrderStatusList;
use App\Models\PanelNotification;
use App\Models\Setting;
use App\Models\DeliveryBoyCashCollection;
use App\Models\DeliveryBoySettlement;
use App\Models\WithdrawalRequest;
use App\Models\LiveTracking;
use App\Models\Zone;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller as BaseController;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Session;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Hash;

class DeliveryBoyController extends BaseController
{
    /**
     * Delivery-boy dashboard. One payload for BOTH the web panel and the mobile app.
     *
     * A boy is bound to one country for life, so everything is implicitly scoped to
     * their own `country_id` — there is no country/zone filter here.
     *
     * Money model:
     *  - every earning (order bonus, item bonus, return commission) is a `credit` wallet transaction
     *  - every payout / manual debit is a `debit` wallet transaction; `delivery_boys.balance` is authoritative
     *  - COD cash collected -> delivery_boy_cash_collections(type=COD), increases `cash_received`
     *  - cash handed back  -> delivery_boy_cash_collections(type=delivery_boy_cash_collection), decreases it
     */
    public function index(Request $request)
    {
        $boy = auth()->user()->deliveryBoy;
        if (!$boy) {
            return CommonHelper::responseError('delivery_boy_not_found');
        }
        $id = $boy->id;
        $today = Carbon::today();

        $country = $boy->country_id ? Country::find($boy->country_id) : null;

        /* ---------- wallet (delivery_boy_settlements is the single earnings ledger) ---------- */
        $credits = DeliveryBoySettlement::where('delivery_boy_id', $id)->where('type', DeliveryBoySettlement::$typeCredit);
        $debits  = DeliveryBoySettlement::where('delivery_boy_id', $id)->where('type', DeliveryBoySettlement::$typeDebit);

        // Salary is a separate ledger (it never touches `balance`), but it IS earnings —
        // so "total earned" = bonus/commission credits + salary paid out.
        $salaryTotal = (float) DeliveryBoySalary::where('delivery_boy_id', $id)->sum('amount');

        $totalEarned    = (float) (clone $credits)->sum('amount') + $salaryTotal;
        $totalDebited   = (float) (clone $debits)->sum('amount');
        $todayEarnings  = (float) (clone $credits)->whereDate('created_at', $today)->sum('amount');

        $pendingWithdraw = (float) WithdrawalRequest::where('type', WithdrawalRequest::$typeDeliveryBoy)
            ->where('type_id', $id)->where('status', WithdrawalRequest::$statusPending)->sum('amount');
        $approvedWithdraw = (float) WithdrawalRequest::where('type', WithdrawalRequest::$typeDeliveryBoy)
            ->where('type_id', $id)->where('status', WithdrawalRequest::$statusApproved)->sum('amount');

        /* ---------- COD cash ---------- */
        $codQ = DeliveryBoyCashCollection::where('delivery_boy_id', $id)->where('type', DeliveryBoyCashCollection::$paymentTypeCod);
        $depositQ = DeliveryBoyCashCollection::where('delivery_boy_id', $id)->where('type', 'delivery_boy_cash_collection');

        $cashCollected = (float) (clone $codQ)->sum('amount');
        $cashDeposited = (float) (clone $depositQ)->sum('amount');
        $todayCash     = (float) (clone $codQ)->whereDate('transaction_date', $today)->sum('amount');

        /* ---------- orders: quick = order level, ecommerce = item level ---------- */
        $quick = Order::where('delivery_boy_id', $id)->where('channel', 'quick');
        $ecom  = OrderItem::from('order_items as oi')->join('orders as o', 'oi.order_id', '=', 'o.id')
            ->where('oi.delivery_boy_id', $id)->where('o.channel', 'ecommerce')->whereNull('oi.deleted_at');

        $activeStatuses = [1, 2, 3, 4, 5, 9, 10, 11];
        $quickDelivered = (int) (clone $quick)->where('active_status', OrderStatusList::$delivered)->count();
        $ecomDelivered  = (int) (clone $ecom)->where('oi.active_status', OrderStatusList::$delivered)->count();

        $todayDelivered = (int) (clone $quick)->where('active_status', OrderStatusList::$delivered)->whereDate('updated_at', $today)->count()
            + (int) (clone $ecom)->where('oi.active_status', OrderStatusList::$delivered)->whereDate('oi.updated_at', $today)->count();

        // Status breakdown across both channels — only the statuses a delivery boy can
        // actually move an order to (the dispatch leg), mirroring OrderStatusApiController.
        $quickByStatus = (clone $quick)->selectRaw('active_status, COUNT(*) c')->groupBy('active_status')->pluck('c', 'active_status');
        $ecomByStatus  = (clone $ecom)->selectRaw('oi.active_status as active_status, COUNT(*) c')->groupBy('oi.active_status')->pluck('c', 'active_status');
        $boyStatusIds = [OrderStatusList::$outForDelivery, OrderStatusList::$delivered, OrderStatusList::$pickedUp];
        $statusBreakdown = [];
        foreach ($boyStatusIds as $sid) {
            $statusBreakdown[] = [
                'status_id' => (int) $sid,
                'name'      => OrderStatusList::getTranslatedName((int) $sid),
                'count'     => (int) ($quickByStatus[$sid] ?? 0) + (int) ($ecomByStatus[$sid] ?? 0),
            ];
        }

        /* ---------- returns assigned ---------- */
        $returns = ReturnRequest::where('delivery_boy_id', $id);
        $returnsDone = (int) (clone $returns)->whereIn('status', [ReturnStatusList::$rReturnToBranch, ReturnStatusList::$rRefundCompleted])->count();

        // Only the return statuses a delivery boy handles (pickup leg).
        $retCounts = (clone $returns)->selectRaw('status, COUNT(*) c')->groupBy('status')->pluck('c', 'status');
        $returnBreakdown = [];
        foreach (array_keys(ReturnStatusList::getDeliveryBoyStatuses()) as $sid) {
            $returnBreakdown[] = [
                'status_id' => (int) $sid,
                'name'      => ReturnStatusList::getTranslatedName((int) $sid),
                'count'     => (int) ($retCounts[$sid] ?? 0),
            ];
        }

        /* ---------- salary ---------- */
        $lastSalary  = DeliveryBoySalary::where('delivery_boy_id', $id)->orderByDesc('paid_on')->first();

        /* ---------- earnings trend (default: last 30 days) ---------- */
        $trend = in_array($request->input('trend'), ['7', '30', '90', '12m'], true) ? $request->input('trend') : '30';
        $labels = [];
        $series = [];

        if ($trend === '12m') {
            // Monthly buckets for the last 12 months.
            $start = $today->copy()->startOfMonth()->subMonths(11);
            $byMonth = DeliveryBoySettlement::where('delivery_boy_id', $id)->where('type', DeliveryBoySettlement::$typeCredit)
                ->where('created_at', '>=', $start)
                ->selectRaw("DATE_FORMAT(created_at, '%Y-%m') k, SUM(amount) a")->groupBy('k')->pluck('a', 'k');
            $salaryByMonth = DeliveryBoySalary::where('delivery_boy_id', $id)
                ->where('paid_on', '>=', $start)
                ->selectRaw("DATE_FORMAT(paid_on, '%Y-%m') k, SUM(amount) a")->groupBy('k')->pluck('a', 'k');
            for ($i = 0; $i < 12; $i++) {
                $m = $start->copy()->addMonths($i);
                $labels[] = $m->format('M y');
                $key = $m->format('Y-m');
                $series[] = round((float) ($byMonth[$key] ?? 0) + (float) ($salaryByMonth[$key] ?? 0), 2);
            }
        } else {
            $days = (int) $trend;
            $start = $today->copy()->subDays($days - 1);
            $byDay = DeliveryBoySettlement::where('delivery_boy_id', $id)->where('type', DeliveryBoySettlement::$typeCredit)
                ->where('created_at', '>=', $start)
                ->selectRaw('DATE(created_at) d, SUM(amount) a')->groupBy('d')->pluck('a', 'd');
            $salaryByDay = DeliveryBoySalary::where('delivery_boy_id', $id)
                ->where('paid_on', '>=', $start->toDateString())
                ->selectRaw('DATE(paid_on) d, SUM(amount) a')->groupBy('d')->pluck('a', 'd');
            for ($i = 0; $i < $days; $i++) {
                $day = $start->copy()->addDays($i);
                $labels[] = $day->format('d M');
                $key = $day->format('Y-m-d');
                $series[] = round((float) ($byDay[$key] ?? 0) + (float) ($salaryByDay[$key] ?? 0), 2);
            }
        }

        $data = [
            'profile' => [
                'id'            => $id,
                'name'          => $boy->getAttributeValue('name'),
                'profile_url'   => $boy->profile_url,
                // 1 = active, 3 = deactivated (toggled from the dashboard).
                'status'        => (int) $boy->status,
                'country'       => $country->name ?? '',
                'currency'      => $country->currency ?? (Setting::get_value('currency') ?: ''),
                'currency_code' => $country->currency_code ?? '',
                'bonus_type'    => (int) $boy->bonus_type,
            ],
            'today' => [
                'earnings'  => round($todayEarnings, 2),
                'delivered' => $todayDelivered,
                'cash'      => round($todayCash, 2),
                'orders'    => (int) (clone $quick)->whereDate('created_at', $today)->count()
                    + (int) (clone $ecom)->whereDate('oi.created_at', $today)->count(),
            ],
            'wallet' => [
                'balance'            => round((float) $boy->balance, 2),
                'total_earned'       => round($totalEarned, 2),
                'total_debited'      => round($totalDebited, 2),
                'pending_withdrawal' => round($pendingWithdraw, 2),
                'total_withdrawn'    => round($approvedWithdraw, 2),
                // What the boy may actually request right now.
                'available'          => round(max(0, (float) $boy->balance - $pendingWithdraw), 2),
            ],
            'cash' => [
                'in_hand'        => round((float) $boy->cash_received, 2),
                'total_collected' => round($cashCollected, 2),
                'total_deposited' => round($cashDeposited, 2),
                // Total settled back to admin across BOTH modes (cash handover + wallet deduction).
                'total_settled'   => round($cashDeposited, 2),
            ],
            'salary' => [
                'total_paid'   => round($salaryTotal, 2),
                'last_paid_on' => $lastSalary ? $lastSalary->getRawOriginal('paid_on') : null,
                'last_amount'  => $lastSalary ? round((float) $lastSalary->amount, 2) : 0,
            ],
            'orders' => [
                'total'     => (int) (clone $quick)->count() + (int) (clone $ecom)->count(),
                'active'    => (int) (clone $quick)->whereIn('active_status', $activeStatuses)->count()
                    + (int) (clone $ecom)->whereIn('oi.active_status', $activeStatuses)->count(),
                'delivered' => $quickDelivered + $ecomDelivered,
                'cancelled' => (int) (clone $quick)->whereIn('active_status', [OrderStatusList::$cancelled, OrderStatusList::$returned])->count()
                    + (int) (clone $ecom)->whereIn('oi.active_status', [OrderStatusList::$cancelled, OrderStatusList::$returned])->count(),
                'quick'     => (int) (clone $quick)->count(),
                'ecommerce' => (int) (clone $ecom)->count(),
            ],
            'status_breakdown' => $statusBreakdown,
            'returns' => [
                'total'     => (int) (clone $returns)->count(),
                'completed' => $returnsDone,
                'pending'   => (int) (clone $returns)->count() - $returnsDone,
                'breakdown' => $returnBreakdown,
            ],
            'earnings_trend' => [
                'labels' => $labels,
                'data'   => $series,
                'trend'  => $trend,
                'total'  => round(array_sum($series), 2),
            ],
            'recent_settlements' => DeliveryBoySettlement::settlementHistory($id)->take(5)->map(fn($r) => [
                'id'         => $r['id'],
                'entry_type' => $r['entry_type'],
                'type'       => $r['type'],
                'amount'     => round((float) $r['amount'], 2),
                'message'    => $r['message'],
                'date'       => $r['created_at'],
            ])->values()->all(),
            // COD collections only — settlements/deposits live in settlement history.
            'recent_cash' => DeliveryBoyCashCollection::where('delivery_boy_cash_collections.delivery_boy_id', $id)
                ->where('delivery_boy_cash_collections.type', DeliveryBoyCashCollection::$paymentTypeCod)
                ->leftJoin('orders', 'delivery_boy_cash_collections.order_id', '=', 'orders.id')
                ->orderByDesc('delivery_boy_cash_collections.id')->limit(5)
                ->get(['delivery_boy_cash_collections.id', 'delivery_boy_cash_collections.order_id', 'orders.order_number', 'delivery_boy_cash_collections.type', 'delivery_boy_cash_collections.amount', 'delivery_boy_cash_collections.transaction_date'])
                ->map(fn($t) => [
                    'id'           => $t->id,
                    'order_id'     => $t->order_id,
                    'order_number' => $t->order_number,
                    'type'         => $t->type,
                    'amount'       => round((float) $t->amount, 2),
                    'date'         => $t->getRawOriginal('transaction_date'),
                ])->all(),
            'recent_withdrawals' => WithdrawalRequest::where('type', WithdrawalRequest::$typeDeliveryBoy)
                ->where('type_id', $id)->orderByDesc('id')->limit(5)
                ->get(['id', 'amount', 'status', 'created_at'])
                ->map(fn($w) => [
                    'id'     => $w->id,
                    'amount' => round((float) $w->amount, 2),
                    'status' => (int) $w->status,
                    'date'   => $w->getRawOriginal('created_at'),
                ])->all(),
        ];

        return CommonHelper::responseWithData($data);
    }
    public function doLanguageChange(Request $request)
    {
        Session::put('lang', $request->language);
        return response()->json(['status' => true]);
    }

    public function createSlug($text)
    {
        $slug = CommonHelper::slugify($text);
        return CommonHelper::responseWithData($slug);
    }

    public function getTopNotifications()
    {
        $notifications = PanelNotification::where('notifiable_id', auth()->user()->id);
        $unReadCount = (clone $notifications)->where('read_at', NULL)->get()->count();
        $notifications = $notifications->orderBy('created_at', 'DESC')->get();

        $data = array();
        $data['unread'] = $unReadCount;
        $data['notifications'] = $notifications;
        return CommonHelper::responseWithData($data);
    }

    public function markAsReadNotifications(Request $request)
    {

        auth()->user()
            ->unreadNotifications
            ->when($request->input('id'), function ($query) use ($request) {
                return $query->where('id', $request->input('id'));
            })
            ->markAsRead();
        return CommonHelper::responseWithData("Notification Mark as Read Successfully!");
    }

    public function getOrders(Request $request)
    {

        $delivery_boy_id = auth()->user()->deliveryBoy->id;

        $limit = (int) ($request->limit ?? 12);
        $offset = (int) ($request->offset ?? 0);

        // Parse dates only when provided (avoid errors and overhead). Accept snake_case
        // (start_date/end_date) with legacy camelCase fallback.
        $sd = $request->start_date ?? $request->startDate ?? null;
        $ed = $request->end_date ?? $request->endDate ?? null;
        $startDate = (!empty($sd)) ? Carbon::parse($sd)->startOfDay() : null;
        $endDate = (!empty($ed)) ? Carbon::parse($ed)->endOfDay() : null;

        $branchSubquery = "(SELECT s.name FROM order_items oi JOIN branches s ON oi.branch_id = s.id WHERE oi.order_id = orders.id LIMIT 1)";
        $orders = Order::select(
            'orders.*',
            'orders.id as order_id',
            'delivery_boys.name as delivery_boy_name',
            DB::raw("{$branchSubquery} as branch_name"),
            'users.name as user_name',
            'users.mobile as user_mobile',
            'users.country_code as user_country_code',
            'orders.active_status as order_status'
        )
            ->leftJoin('users', 'orders.user_id', '=', 'users.id')
            ->leftJoin('delivery_boys', 'orders.delivery_boy_id', '=', 'delivery_boys.id')
            ->where('orders.channel', 'quick')
            ->where('orders.delivery_boy_id', $delivery_boy_id);

        if ($startDate && $endDate) {
            $orders = $orders->whereBetween('orders.created_at', [$startDate, $endDate]);
        } elseif ($startDate) {
            $orders = $orders->where('orders.created_at', '>=', $startDate);
        } elseif ($endDate) {
            $orders = $orders->where('orders.created_at', '<=', $endDate);
        }

        if (isset($request->status) && $request->status != "" && $request->status != 0) {
            $orders = $orders->where('orders.active_status', $request->status);
        }

        if (in_array($request->channel, ['quick', 'ecommerce'], true)) {
            $orders = $orders->where('orders.channel', $request->channel);
        }

        if (isset($request->search) && !empty($request->search)) {
            $search = $request->search;
            $orders = $orders->where(function ($query) use ($search, $branchSubquery) {
                $query->where('orders.id', 'LIKE', "%$search%")
                    ->orWhere('users.name', 'LIKE', "%$search%")
                    ->orWhere('users.mobile', 'LIKE', "%$search%")
                    ->orWhere('orders.mobile', 'LIKE', "%$search%")
                    ->orWhere('orders.payment_method', 'LIKE', "%$search%")
                    ->orWhere('orders.delivery_charge', 'LIKE', "%$search%")
                    ->orWhere('orders.wallet_balance', 'LIKE', "%$search%")
                    ->orWhere('orders.final_total', 'LIKE', "%$search%")
                    ->orWhere('orders.remaining_final', 'LIKE', "%$search%")
                    ->orWhere('orders.total', 'LIKE', "%$search%")
                    ->orWhereRaw("({$branchSubquery}) LIKE ?", ["%$search%"])
                    ->orWhere('delivery_boys.name', 'LIKE', "%$search%");
            });
        }

        if (isset($request->type)) {
            $activeTypeStatus = [OrderStatusList::$paymentPending, OrderStatusList::$received, OrderStatusList::$processed, OrderStatusList::$outForDelivery, OrderStatusList::$shipped, OrderStatusList::$preparing, OrderStatusList::$readyForPickup, OrderStatusList::$pickedUp];
            $previousTypeStatus = [OrderStatusList::$delivered, OrderStatusList::$cancelled, OrderStatusList::$returned];
            if ($request->type == Order::$activeType) {
                $orders = $orders->whereIn('orders.active_status', $activeTypeStatus);
            } else {
                $orders = $orders->whereIn('orders.active_status', $previousTypeStatus);
            }
        }

        // Lightweight count (no branch subquery) - run before get()
        $ordersForCount = clone $orders;
        $ordersForCount->getQuery()->select(DB::raw('orders.id'));
        $totalOrder = $ordersForCount->count();

        // Fetch only the limited rows (skip/take applied)
        $orders = $orders->orderBy('orders.updated_at', 'DESC')->skip($offset)->take((int) $limit)->get();

        // Bulk-fetch items for all fetched orders (avoids N+1)
        $orderIds = $orders->pluck('id')->all();
        $allItems = OrderItem::select(
            'order_items.*',
            'v.id as variant_id',
            'v.name as variant_name',
            'v.image as variant_image',
            'p.id as product_id',
            'p.product_type'
        )
            ->from('order_items')
            ->leftJoin('product_variants as v', 'order_items.product_variant_id', '=', 'v.id')
            ->leftJoin('products as p', 'v.product_id', '=', 'p.id')
            ->whereIn('order_items.order_id', $orderIds)
            ->orderBy('order_items.id', 'ASC')
            ->get()
            ->groupBy('order_id');

        // Translate status names
        $langCode = app()->has('lang_code') ? app('lang_code') : 'en';
        app()->setLocale($langCode);

        $generate_otp = Setting::get_value("generate_otp");

        $orderTax = CommonHelper::attachCustomerTaxLines($allItems->flatten(1));

        foreach ($orders as $key => $row) {
            if ($generate_otp == 0) {
                $orders[$key]->otp = 0;
            }
            $orders[$key]->order_status_name = OrderStatusList::getTranslatedName((int) ($row->order_status ?? 0));
            $orders[$key]->date = $row->created_at;
            foreach (['additional_charges', 'surge_charges'] as $jf) {
                $v = $row->{$jf} ?? null;
                $orders[$key]->{$jf} = is_string($v) ? (json_decode($v, true) ?: []) : (is_array($v) ? $v : []);
            }

            $orders[$key]->address = CommonHelper::orderAddressObject($row->address ?? null);

            $tax = $orderTax[$row->id] ?? [];
            $orders[$key]->tax_breakdown = $tax['tax_breakdown'] ?? [];
            $orders[$key]->decimal_point = CommonHelper::countryDecimalPoint($row->country_id ?? null);
            $orders[$key]->delivery_charges = CommonHelper::deliveryChargeObject(
                $row->delivery_charge ?? 0,
                $tax['delivery_charge_tax'] ?? null
            );

            $items = $allItems->get($row->id, collect());
            // Quick orders are single-branch: branch_info sits at order level (like address).
            $orders[$key]->branch_info = CommonHelper::branchInfo(optional($items->first())->branch_id);
            foreach ($items as $item) {
                $item->name          = $item->variant_name;
                $item->image         = CommonHelper::imageUrl($item->variant_image);
                $item->product_type  = (int) ($item->product_type ?? 0);
                $item->date          = $item->created_at;
                // discounted_price: DB value when > 0, else fall back to base price.
                $item->discounted_price = ((float) $item->discounted_price > 0)
                    ? (float) $item->discounted_price
                    : (float) $item->price;

                foreach (['additional_charges', 'surge_charges', 'addons'] as $jf) {
                    $v = $item->{$jf} ?? null;
                    $item->{$jf} = is_string($v) ? (json_decode($v, true) ?: []) : (is_array($v) ? $v : []);
                }
                // This line's own frozen heads — never the order's.
                $item->tax_breakdown = CommonHelper::itemTaxBreakdown($item);
                unset($item->tax_lines);
            }
            $items = $items->makeHidden(['status', 'created_at', 'updated_at', 'deleted_at', 'courier_agency', 'tracking_id', 'tracking_url']);
            $orders[$key]->items = $items->values();
        }

        $orders = $orders->makeHidden(['created_at', 'updated_at', 'deleted_at', 'delivery_charge']);
        return CommonHelper::responseWithData($orders, $totalOrder);
    }

    public function scanDeliveryReceipt(Request $request)
    {
        $code = trim((string) $request->input('code'));
        if ($code === '') {
            return CommonHelper::responseError('code_is_required');
        }

        // SB-244-quick[-1057] | 244
        $orderId = 0;
        $itemId = null;
        if (preg_match('/^SB-(\d+)-([a-z]+)(?:-(\d+))?$/i', $code, $m)) {
            $orderId = (int) $m[1];
            $itemId  = isset($m[3]) ? (int) $m[3] : null;
        } elseif (ctype_digit($code)) {
            $orderId = (int) $code;
        } else {
            return CommonHelper::responseError('invalid_barcode');
        }

        $order = Order::find($orderId);
        if (!$order) {
            return CommonHelper::responseError('order_not_found');
        }

        $dbId = (int) (auth()->user()->deliveryBoy->id ?? 0);
        if (!$dbId) {
            return CommonHelper::responseError('delivery_boy_not_found');
        }
        // Quick orders are assigned on the order, ecommerce ones per item.
        $assigned = (int) $order->delivery_boy_id === $dbId
            || OrderItem::where('order_id', $order->id)->where('delivery_boy_id', $dbId)->exists()
            || ReturnRequest::where('order_id', $order->id)->where('delivery_boy_id', $dbId)->exists();

        if (!$assigned) {
            return CommonHelper::responseError('order_not_assigned_to_you');
        }

        $request->merge(['order_id' => $order->id]);

        if ($order->channel === 'ecommerce') {
            // A parcel coming back is a pickup, not a delivery: when the scanned item
            // (or, on an order-wise label, any item of the order) is under return, open
            // the return request instead of the order.
            if ($return = $this->scannedReturnRequest($order->id, $itemId, $dbId)) {
                $request->merge(['return_request_id' => $return->id]);

                return $this->returnRequests($request);
            }

            if ($itemId) {
                $request->merge(['order_item_id' => $itemId]);
            }

            return $this->getEcomOrders($request);
        }

        return $this->getOrder($request);
    }

    private function scannedReturnRequest(int $orderId, ?int $itemId, int $dbId): ?ReturnRequest
    {
        $returns = ReturnRequest::where('order_id', $orderId)
            ->where('delivery_boy_id', $dbId)
            ->when($itemId, fn ($q) => $q->where('order_item_id', $itemId))
            ->orderBy('id')
            ->get();

        if ($returns->isEmpty()) {
            return null;
        }

        $done = [ReturnStatusList::$rRejected, ReturnStatusList::$rRefundCompleted];

        return $returns->first(fn ($r) => !in_array((int) $r->status, $done, true))
            ?: $returns->first();
    }

    public function getOrder(Request $request)
    {
        $response = app(OrdersApiController::class)->view($request->order_id);
        $payload  = json_decode($response->getContent(), true);
        if (!empty($payload['data']['order_items'])) {
            foreach ($payload['data']['order_items'] as &$oi) {
                unset($oi['courier_agency'], $oi['tracking_id'], $oi['tracking_url']);
            }
        }
        return response()->json($payload, $response->getStatusCode());
    }

    /**
     * Ecommerce: order items assigned to this delivery boy, item-wise. Each entry =
     * one item + its order context + sibling items of the same order also assigned
     * to this boy.
     */
    public function getEcomOrders(Request $request)
    {
        $dbId = auth()->user()->deliveryBoy->id;
        $limit  = (int) ($request->limit ?? 12);
        $offset = (int) ($request->offset ?? 0);

        $base = OrderItem::from('order_items as oi')
            ->join('orders as o', 'oi.order_id', '=', 'o.id')
            ->where('oi.delivery_boy_id', $dbId)
            ->where('o.channel', 'ecommerce');

        if (!empty($request->order_id)) {
            $base->where('oi.order_id', $request->order_id);
        }
        if (!empty($request->order_item_id)) {
            $base->where('oi.id', $request->order_item_id);
        }
        if (isset($request->status) && $request->status != "" && $request->status != 0) {
            $base->where('oi.active_status', $request->status);
        }
        // Optional date range (inclusive), on the order date. Accept snake_case with legacy fallback.
        $sd = $request->start_date ?? $request->startDate ?? null;
        $ed = $request->end_date ?? $request->endDate ?? null;
        if (!empty($sd) && !empty($ed)) {
            $base->whereBetween('o.created_at', [
                Carbon::parse($sd)->startOfDay(),
                Carbon::parse($ed)->endOfDay(),
            ]);
        }
        if (isset($request->type)) {
            $active = [OrderStatusList::$paymentPending, OrderStatusList::$received, OrderStatusList::$processed, OrderStatusList::$outForDelivery, OrderStatusList::$shipped, OrderStatusList::$preparing, OrderStatusList::$readyForPickup, OrderStatusList::$pickedUp];
            $previous = [OrderStatusList::$delivered, OrderStatusList::$cancelled, OrderStatusList::$returned];
            $base->whereIn('oi.active_status', $request->type == Order::$activeType ? $active : $previous);
        }
        if (isset($request->search) && $request->search != "") {
            $s = $request->search;
            $base->where(function ($q) use ($s) {
                $q->where('oi.id', 'like', "%$s%")
                    ->orWhere('oi.order_id', 'like', "%$s%")
                    ->orWhere('oi.product_name', 'like', "%$s%");
            });
        }

        $total = (clone $base)->count('oi.id');

        $items = (clone $base)->select(
            'oi.*',
            'o.id as order_id',
            'o.order_number',
            'o.payment_method',
            'o.address as order_address',
            'o.country_id as order_country_id',
            'o.delivery_charge as order_delivery_charge',
            'o.currency',
            'u.name as user_name',
            'u.mobile as user_mobile',
            'u.country_code as user_country_code',
            'v.name',
            'p.image',
            'p.product_type'
        )
            ->leftJoin('users as u', 'o.user_id', '=', 'u.id')
            ->leftJoin('product_variants as v', 'oi.product_variant_id', '=', 'v.id')
            ->leftJoin('products as p', 'v.product_id', '=', 'p.id')
            ->orderBy('oi.id', 'DESC')
            ->skip($offset)->take($limit)->get();

        if ($items->isEmpty()) {
            return CommonHelper::responseWithData([], $total);
        }

        $orderIds = $items->pluck('order_id')->unique()->values()->all();
        // Siblings of the same order assigned to THIS delivery boy.
        $siblingsByOrder = OrderItem::from('order_items as oi')
            ->leftJoin('product_variants as v', 'oi.product_variant_id', '=', 'v.id')
            ->leftJoin('products as p', 'v.product_id', '=', 'p.id')
            ->whereIn('oi.order_id', $orderIds)
            ->where('oi.delivery_boy_id', $dbId)
            ->orderBy('oi.id', 'ASC')
            ->get(['oi.id', 'oi.order_id', 'oi.product_name', 'oi.quantity', 'oi.active_status',
                'oi.final_total', 'oi.wallet_balance', 'p.image', 'p.product_type'])
            ->groupBy('order_id');

        // Return-request status per item (main + siblings) for order_item_status.
        $returnItemIds = collect($items->pluck('id'))
            ->merge($siblingsByOrder->flatten(1)->pluck('id'))
            ->map(fn($id) => (int) $id)->unique()->all();
        $returnStatusByItem = ReturnRequest::whereIn('order_item_id', $returnItemIds)->pluck('status', 'order_item_id');

        $ecomOrderTax = CommonHelper::attachCustomerTaxLines($items);

        foreach ($items as $item) {
            $item->image = CommonHelper::imageUrl($item->image);
            $item->product_type = (int) ($item->product_type ?? 0);
            $item->otp = (int) $item->otp; // 0 = OTP disabled at placement; > 0 = customer's item OTP
            $item->branch_info = CommonHelper::branchInfo($item->branch_id);
            $item->order_status_name = OrderStatusList::getTranslatedName((int) $item->active_status);
            // Item status name: the return status once a return exists, else the active status.
            $item->order_item_status = $returnStatusByItem->has((int) $item->id)
                ? ReturnStatusList::getTranslatedName((int) $returnStatusByItem[(int) $item->id])
                : OrderStatusList::getTranslatedName((int) $item->active_status);
            $item->date = $item->created_at;
            $item->address = CommonHelper::orderAddressObject($item->order_address);
            unset($item->order_address);
            foreach (['additional_charges', 'surge_charges', 'addons'] as $jf) {
                $v = $item->{$jf} ?? null;
                $item->{$jf} = is_string($v) ? (json_decode($v, true) ?: []) : (is_array($v) ? $v : []);
            }

            $item->tax_breakdown = CommonHelper::itemTaxBreakdown($item);
            unset($item->tax_lines);
            $item->decimal_point = CommonHelper::countryDecimalPoint($item->order_country_id ?? null);

            $deliveryTax = $ecomOrderTax[$item->order_id]['delivery_charge_tax'] ?? null;
            $itemDelivery = round((float) ($item->delivery_charge ?? 0), 2);
            $orderDelivery = (float) ($item->order_delivery_charge ?? 0);
            $share = $orderDelivery > 0 ? $itemDelivery / $orderDelivery : 0;
            $item->delivery_charges = CommonHelper::deliveryChargeObject($itemDelivery, [
                'tax_amount' => (float) ($deliveryTax['tax_amount'] ?? 0) * $share,
                'tax_name'   => $deliveryTax['tax_name'] ?? null,
                'tax_rate'   => $deliveryTax['tax_rate'] ?? 0,
            ]);
            unset($item->order_delivery_charge, $item->order_country_id);
            $item->timeline = CommonHelper::orderProgressTimeline(
                OrderStatus::where('order_id', $item->order_id)
                    ->where('order_item_id', $item->id)->orderBy('id', 'ASC')->get(),
                'ecommerce',
                fn ($sid) => OrderStatusList::getTranslatedName($sid)
            );
            $item->other_items = collect($siblingsByOrder->get($item->order_id, collect()))
                ->reject(fn($x) => (int) $x->id === (int) $item->id)
                ->map(fn($x) => [
                    'order_item_id' => (int) $x->id,
                    'product_name'  => $x->product_name,
                    'product_type'  => (int) ($x->product_type ?? 0),
                    'quantity'      => $x->quantity,
                    'final_total'   => round((float) $x->final_total + (float) $x->wallet_balance, 2),
                    'image'         => CommonHelper::imageUrl($x->image),
                    'status'        => (int) $x->active_status,
                    'status_name'   => OrderStatusList::getTranslatedName((int) $x->active_status),
                    'order_item_status' => $returnStatusByItem->has((int) $x->id)
                        ? ReturnStatusList::getTranslatedName((int) $returnStatusByItem[(int) $x->id])
                        : OrderStatusList::getTranslatedName((int) $x->active_status),
                ])->values();
        }

        foreach ($items as $item) {
            $item->refund_amount = (float) ($item->refund_amount ?? 0);
            $item->discounted_price = ((float) ($item->discounted_price ?? 0) > 0)
                ? (float) $item->discounted_price
                : (float) ($item->price ?? 0);
            // Customer chat visibility (forward delivery while live, or return pickup in progress).
            $item->is_delivery_boy_chat_visible = CommonHelper::isDeliveryBoyChatVisibleForOrderItem(
                (int) $item->id,
                $item->delivery_boy_id ? (int) $item->delivery_boy_id : null,
                (int) $item->active_status
            );
        }
        $items = $items->makeHidden(['created_at', 'updated_at', 'deleted_at', 'status', 'image_url', 'courier_agency', 'tracking_id', 'tracking_url']);
        return CommonHelper::responseWithData($items, $total);
    }

    /** Delivery boy updates one of THEIR assigned order item's status (ecommerce). */
    public function updateItemStatus(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_item_id' => 'required|integer',
            'status_id'     => 'required|integer',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $dbId = auth()->user()->deliveryBoy->id;
        $item = OrderItem::find($request->order_item_id);
        if (!$item || (int) $item->delivery_boy_id !== (int) $dbId) {
            return CommonHelper::responseError('order_item_not_assigned_to_you');
        }
        if (in_array((int) $item->active_status, [OrderStatusList::$cancelled, OrderStatusList::$returned], true)) {
            return CommonHelper::responseError('could_not_update_order_status_cancelled_or_returned');
        }

        // OTP check on delivery — only enforced for delivery boys. Validated against the
        // item's stored otp (> 0 means OTP was enabled at placement).
        if (
            (int) $request->status_id === OrderStatusList::$delivered && (int) $item->otp > 0
            && (int) auth()->user()->role_id === Role::$roleDeliveryBoy
        ) {
            if (empty($request->otp) || (int) $request->otp !== (int) $item->otp) {
                return CommonHelper::responseError('invalid_otp');
            }
        }

        $item->active_status = $request->status_id;
        $item->save();

        if (in_array((int) $request->status_id, [OrderStatusList::$cancelled, OrderStatusList::$returned], true)) {
            CommonHelper::reverseOrderItemTax($item);
        }

        CommonHelper::setOrderStatus([
            'order_id'      => $item->order_id,
            'order_item_id' => $item->id,
            'status'        => $request->status_id,
            'created_by'    => auth()->user()->id,
            'user_type'     => OrderStatus::$userTypeAdmin,
        ]);

        if ((int) $request->status_id === OrderStatusList::$delivered) {
            CommonHelper::creditOrderItemDelivery($item->fresh());
        }
        CommonHelper::syncEcommerceOrderStatus($item->order_id);

        try {
            CommonHelper::sendOrderItemStatusMailNotification($item, 'order_item_status_update');
        } catch (\Exception $e) {
            Log::error('delivery_boy_update_item_status_notification_error: ' . $e->getMessage());
        }
        try {
            dispatch(function () use ($item) {
                CommonHelper::sendSmsOrderStatus($item, $item->active_status);
            })->afterResponse();
        } catch (\Exception $e) {
            Log::error('delivery_boy_update_item_status_sms_error: ' . $e->getMessage());
        }

        return CommonHelper::responseSuccess('order_status_updated_successfully');
    }

    public function getOrderStatus(Request $request)
    {
        return app(OrderStatusApiController::class)->getOrderStatus($request);
    }

    public function getCashCollection(Request $request)
    {
        $delivery_boy_id = auth()->user()->deliveryBoy->id;

        $transactions = DeliveryBoyCashCollection::where('delivery_boy_id', $delivery_boy_id)
            ->where('type', DeliveryBoyCashCollection::$paymentTypeCod);

        if (isset($request->startDate) && $request->startDate != "" && isset($request->endDate) && $request->endDate != "") {
            $startDate = Carbon::parse($request->input('startDate'))->startOfDay();
            $endDate = Carbon::parse($request->input('endDate'))->endOfDay();
            $transactions = $transactions->whereBetween('created_at', [$startDate, $endDate]);
        }
        if (isset($request->search) && !empty($request->search)) {
            $searchTerm = $request->search;
            $transactions = $transactions->where(function ($q) use ($searchTerm) {
                $q->where('id', 'LIKE', '%' . $searchTerm . '%')
                    ->orWhere('order_id', 'LIKE', '%' . $searchTerm . '%')
                    ->orWhere('amount', 'LIKE', '%' . $searchTerm . '%')
                    ->orWhere('message', 'LIKE', '%' . $searchTerm . '%');
            });
        }
        $transactions = $transactions->orderBy('id', 'DESC')
            ->get(['id', 'order_id', 'currency', 'amount', 'status', 'message', 'transaction_date']);

        // order id -> order_number for display.
        $orderNumbers = Order::whereIn('id', $transactions->pluck('order_id')->filter()->unique())
            ->pluck('order_number', 'id');

        $data = [];
        $data['cash_in_hand'] = DeliveryBoy::where('id', $delivery_boy_id)->value('cash_received');
        // The boy's own country currency for the stat cards / totals.
        $data['currency'] = optional(auth()->user()->deliveryBoy->country)->currency;
        $data['cash_collected'] = DeliveryBoyCashCollection::where(['type' => 'delivery_boy_cash_collection', 'delivery_boy_id' => $delivery_boy_id])->sum('amount');
        $data['transactions'] = $transactions->map(function (DeliveryBoyCashCollection $dt) use ($orderNumbers) {
            return [
                'id'               => $dt->id,
                'order_id'         => $dt->order_id,
                'order_number'     => $dt->order_id ? ($orderNumbers[$dt->order_id] ?? null) : null,
                'currency'         => $dt->currency,
                'amount'           => $dt->amount,
                'status'           => $dt->status,
                'message'          => CommonHelper::translateLedgerMessage($dt->message),
                'transaction_date' => $dt->getRawOriginal('transaction_date'),
            ];
        });
        $total = $transactions->count();
        return CommonHelper::responseWithData($data, $total);
    }

    /** Settlement history for the logged-in boy: commissions, withdrawals, cash deposits. */
    public function getSettlementHistory(Request $request)
    {
        $delivery_boy_id = auth()->user()->deliveryBoy->id;
        $rows = DeliveryBoySettlement::settlementHistory($delivery_boy_id);

        if (isset($request->startDate) && $request->startDate != "" && isset($request->endDate) && $request->endDate != "") {
            $start = Carbon::parse($request->startDate)->startOfDay();
            $end = Carbon::parse($request->endDate)->endOfDay();
            $rows = $rows->filter(fn($r) => $r['created_at'] && Carbon::parse($r['created_at'])->between($start, $end))->values();
        }
        // Entry-type filter: delivery_commission | return_commission | withdrawal |
        // cash_deposit_cash | cash_deposit_wallet (empty/absent = all).
        if (isset($request->entry_type) && $request->entry_type !== '') {
            $rows = $rows->filter(fn($r) => $r['entry_type'] === $request->entry_type)->values();
        }
        if (isset($request->search) && $request->search !== '') {
            $needle = mb_strtolower($request->search);
            $rows = $rows->filter(fn($r) => str_contains(mb_strtolower(implode(' ', [
                $r['id'],
                $r['entry_type'],
                $r['type'],
                $r['amount'],
                $r['message'] ?? '',
            ])), $needle))->values();
        }

        return CommonHelper::responseWithData($rows, $rows->count());
    }

    public function addWithdrawalRequest(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'amount' => 'required|numeric|min:0.01|not_in:0',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $amount = round($request->amount, 2);

        $deliveryBoy = auth()->user()->deliveryBoy;
        if (empty($deliveryBoy)) {
            return CommonHelper::responseError('delivery_boy_not_found');
        }
        if ($deliveryBoy->balance < $amount) {
            return CommonHelper::responseError('the_amount_is_greater_than_your_balance');
        }

        // Currency snapshot: a boy is bound to one country for life, so it's simply theirs.
        $country = $deliveryBoy->country_id ? Country::find($deliveryBoy->country_id) : null;

        DB::beginTransaction();
        try {
            $withdrawalRequest = new WithdrawalRequest();
            $withdrawalRequest->type = WithdrawalRequest::$typeDeliveryBoy;
            $withdrawalRequest->type_id = $deliveryBoy->id;
            $withdrawalRequest->amount = $amount;
            $withdrawalRequest->country_id = $deliveryBoy->country_id;
            $withdrawalRequest->currency = $country->currency ?? (Setting::get_value('currency') ?: null);
            $withdrawalRequest->currency_code = $country->currency_code ?? null;
            $withdrawalRequest->message = $request->message;
            $withdrawalRequest->status = WithdrawalRequest::$statusPending;
            $withdrawalRequest->save();

            DB::commit();

            CommonHelper::sendWithdrawalRequestAdminNotification($withdrawalRequest);
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Delivery boy withdrawal request error: ' . $e->getMessage());
            return CommonHelper::responseError('something_went_wrong');
        }

        return CommonHelper::responseSuccess('withdrawal_request_submitted_successfully');
    }

    /** Salary transactions of the authenticated delivery boy (self-service list). */
    public function getSalaryTransactions(Request $request)
    {
        $deliveryBoy = auth()->user()->deliveryBoy;
        $delivery_boy_id = $deliveryBoy->id;

        // Currency of the boy's country (fixed at registration).
        $country = $deliveryBoy->country_id ? Country::find($deliveryBoy->country_id) : null;
        $currency = $country->currency ?? null;

        $limit  = (int) ($request->limit ?? 10);
        $offset = (int) ($request->offset ?? 0);
        $search = trim((string) ($request->search ?? ''));
        $sd = $request->start_date ?? $request->startDate ?? null;
        $ed = $request->end_date ?? $request->endDate ?? null;

        $query = DeliveryBoySalary::where('delivery_boy_id', $delivery_boy_id)
            ->when($search !== '', function ($q) use ($search) {
                $like = '%' . $search . '%';
                $q->where(function ($w) use ($like) {
                    $w->where('note', 'LIKE', $like)->orWhere('amount', 'LIKE', $like);
                });
            })
            ->when(!empty($sd), fn($q) => $q->whereDate('paid_on', '>=', Carbon::parse($sd)->toDateString()))
            ->when(!empty($ed), fn($q) => $q->whereDate('paid_on', '<=', Carbon::parse($ed)->toDateString()));

        $total = (clone $query)->count();

        $rows = $query->orderByDesc('id')->offset($offset)->limit($limit > 0 ? $limit : 10)->get();

        $salaries = $rows->map(function (DeliveryBoySalary $s) use ($currency) {
            return [
                'id'         => (int) $s->id,
                'amount'     => (float) $s->amount,
                'currency'   => $currency,
                'paid_on'    => $s->getRawOriginal('paid_on'),
                'note'       => $s->note,
                'created_at' => $s->getRawOriginal('created_at'),
            ];
        });

        return CommonHelper::responseWithData($salaries, $total);
    }

    public function getSettings()
    {

        $variables = array(
            "app_name",
            "support_number",
            "support_email",
            "is_version_system_on_delivery_boy",
            "required_force_update_delivery_boy",
            "current_version_delivery_boy",
            "ios_is_version_system_on_delivery_boy",
            "ios_required_force_update_delivery_boy",
            "ios_current_version_delivery_boy",
            "app_mode_delivery_boy",
            "app_mode_delivery_boy_remark",
            "app_mode_delivery_boy_start",
            "app_mode_delivery_boy_end",
            "enable_road_path_tracking",
            "delivery_boy_light_mode_color",
            "delivery_boy_dark_mode_color",
            "map_provider",
            "delivery_boy_playstore_url",
            "delivery_boy_appstore_url",
            "clarity_project_id_delivery_boy",
            "clarity_status_delivery_boy",
            "password_min_length",
            "password_max_length",
            "password_require_uppercase",
            "password_require_lowercase",
            "password_require_number",
            "password_require_special"
        );

        $settings = CommonHelper::getSettings($variables);
        $settings = CommonHelper::resolveTranslatedSettings($settings);

        foreach ($variables as $key) {
            if (!array_key_exists($key, $settings)) {
                $settings[$key] = "";
            }
        }

        $settings['broadcast_driver'] = CommonHelper::getBroadcastDriver();
        $settings['broadcast_config'] = CommonHelper::getBroadcastClientConfig();

        return CommonHelper::responseWithData($settings);
    }

    /**
     * Country-scoped settings for the delivery boy app: delivery-boy policies
     * (translated via Content-Language) + regional date/time formats.
     * Guest (no token): first active country's policies, EMPTY formats.
     * Authenticated: the delivery boy's own country (fixed at registration).
     */
    public function getCountrySetting(Request $request)
    {
        $deliveryBoy = $request->user('api')?->deliveryBoy;
        $isAuth = (bool) $deliveryBoy;

        $countryId = ($isAuth ? $deliveryBoy->country_id : null)
            ?: Country::where('status', 1)->orderBy('id')->value('id');
        $country = $countryId ? Country::find($countryId) : null;
        if (!$country) {
            return CommonHelper::responseError('no_country_found');
        }

        $policies = CommonHelper::countryPolicies($country->id, [
            'privacy_policy_delivery_boy',
            'terms_conditions_delivery_boy',
        ]);

        $data = array_merge([
            'country_id'  => (int) $country->id,
            'date_format' => $isAuth ? ($country->date_format ?: 'd-m-Y') : '',
            'time_format' => $isAuth ? ($country->time_format ?: 'h:i A') : '',
            'timezone'    => $isAuth ? ($country->timezone ?: 'UTC') : '',
            'currency'    => $country->currency ?? '',
        ], $policies);

        return CommonHelper::responseSuccessWithData('success', $data);
    }

    private function trackAllActiveDeliveries(Request $request, $latitude, $longitude)
    {
        $ids = $this->writeActiveDeliveryPositions($request, $latitude, $longitude);

        if ($ids === null) {
            return CommonHelper::responseError('delivery_boy_not_found');
        }

        // The count is the whole point of the reply: 0 means stop asking the device.
        return CommonHelper::responseWithData(['tracked' => $ids->count()]);
    }

    private function writeActiveDeliveryPositions(Request $request, $latitude, $longitude)
    {
        $boy = $request->user()?->deliveryBoy;
        if (!$boy) {
            return null;
        }

        $outForDelivery = OrderStatusList::$outForDelivery;

        $ids = Order::where('delivery_boy_id', $boy->id)
            ->where('active_status', $outForDelivery)
            ->pluck('id')
            ->merge(
                OrderItem::where('delivery_boy_id', $boy->id)
                    ->where('active_status', $outForDelivery)
                    ->distinct()
                    ->pluck('order_id')
            )
            ->unique()
            ->values();

        foreach ($ids as $orderId) {
            LiveTracking::updateOrCreate(
                ['order_id' => (int) $orderId],
                [
                    'order_id'  => (int) $orderId,
                    'latitude'  => $latitude,
                    'longitude' => $longitude,
                ]
            );
        }

        return $ids;
    }

    public function manageLiveTracking(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_id' => 'nullable|numeric|exists:orders,id',
            'order_status' => 'nullable|numeric|in:5,6',
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $latitude = $request->input('latitude');
        $longitude = $request->input('longitude');

        if (!$request->filled('order_id')) {
            return $this->trackAllActiveDeliveries($request, $latitude, $longitude);
        }

        $orderId = $request->order_id;
        $orderStatus = $request->input('order_status', OrderStatusList::$outForDelivery);

        // Check if the order exists and if it's valid for tracking
        $order = Order::find($orderId);
        if (!$order) {
            return response()->json([
                'error' => true,
                'message' => 'Order does not exist.'
            ]);
        }

        if (in_array($order->active_status, [
            1,
            2,
            3,
            4,
            7,
            8,
            9,
            10
        ])) {
            return response()->json([
                'error' => true,
                'message' => "Order is {$order->active_status}. You cannot track this order."
            ]);
        }

        // Prepare the data for live tracking
        $trackingData = [
            'order_id' => $orderId,
            'order_status' => $orderStatus,
            'latitude' => $latitude,
            'longitude' => $longitude,
        ];

        // Update or insert live tracking data
        $liveTracking = LiveTracking::updateOrCreate(
            ['order_id' => $orderId],
            $trackingData
        );

        if ((int) $orderStatus === OrderStatusList::$outForDelivery) {
            $this->writeActiveDeliveryPositions($request, $latitude, $longitude);
        }

        $message = $liveTracking->wasRecentlyCreated ? 'Live Tracking Details Inserted Successfully.' : 'Live Tracking Details Updated Successfully.';
        return  CommonHelper::responseSuccess($message);
    }

    /**
     * Returns assigned to this delivery boy. Without return_request_id, lists all of
     * them (paginated/searchable); with return_request_id, returns that one request
     * plus its order item details.
     */
    public function returnRequests(Request $request)
    {
        $user = auth()->user();
        if ($user->role_id != Role::$roleDeliveryBoy) {
            return CommonHelper::responseError('unauthorized_access_delivery_boy_role_required');
        }

        // Base query (same joined fields as the single-request response) scoped to
        // this delivery boy.
        $query = ReturnRequest::select(
            'return_requests.*',
            'users.name as customer_name',
            'users.mobile as customer_mobile',
            'users.email as customer_email',
            'order_items.product_variant_id',
            'order_items.branch_id',
            'order_items.quantity',
            'order_items.price',
            'order_items.sub_total',
            'order_items.discounted_price',
            'order_items.product_name',
            'orders.payment_method',
            'orders.final_total',
            'orders.currency',
            'orders.country_id as order_country_id',
            'orders.order_number as order_number',
            'zones.id as zone_id',
            'zones.name as city_name',
            'delivery_boys.name as delivery_boy_name',
            'delivery_boys.mobile as delivery_boy_mobile',
            'products.id as product_id',
            'products.product_type',
        )
            ->leftJoin('users', 'return_requests.user_id', '=', 'users.id')
            ->leftJoin('order_items', 'return_requests.order_item_id', '=', 'order_items.id')
            ->leftJoin('orders', 'return_requests.order_id', '=', 'orders.id')
            ->leftJoin('user_addresses', 'orders.address_id', '=', 'user_addresses.id')
            ->leftJoin('zones', 'user_addresses.zone_id', '=', 'zones.id')
            ->leftJoin('product_variants', 'return_requests.product_variant_id', '=', 'product_variants.id')
            ->leftJoin('products', 'product_variants.product_id', '=', 'products.id')
            ->leftJoin('delivery_boys', 'return_requests.delivery_boy_id', '=', 'delivery_boys.id')
            ->where('return_requests.delivery_boy_id', $user->deliveryBoy->id);

        // Locale for translated status names.
        $useContentLanguage = $request->header('Content-Language') !== null
            && trim((string) $request->header('Content-Language')) !== '';
        $previousLocale = app()->getLocale();
        if ($useContentLanguage) {
            $langCode = app()->has('lang_code') ? app('lang_code') : 'en';
            app()->setLocale($langCode);
        }

        // With id -> that single request only (same shape as a list element).
        if (!empty($request->return_request_id)) {
            $returnRequest = (clone $query)->where('return_requests.id', $request->return_request_id)->first();
            if (!$returnRequest) {
                app()->setLocale($previousLocale);
                return CommonHelper::responseError('return_request_not_found_or_you_dont_have_permission_to_view_this_request');
            }
            $data = $this->buildReturnDetail($returnRequest);
            app()->setLocale($previousLocale);
            return CommonHelper::responseWithData($data);
        }

        if ($request->filled('status')) {
            $status = (int) $request->input('status');
            if (!array_key_exists($status, ReturnStatusList::getAllStatuses())) {
                app()->setLocale($previousLocale);
                return CommonHelper::responseError('invalid_status');
            }
            $query->where('return_requests.status', $status);
        }

        // Completed filter = rejected / refund completed.
        if ($request->has('is_completed') && $request->is_completed != "") {
            $completedStatuses = [ReturnStatusList::$rRejected, ReturnStatusList::$rRefundCompleted];
            if ($request->is_completed == 1) {
                $query->whereIn('return_requests.status', $completedStatuses);
            } elseif ($request->is_completed == 0) {
                $query->whereNotIn('return_requests.status', $completedStatuses);
            }
        }

        $search = trim((string) $request->input('search', ''));
        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                if (is_numeric($search)) {
                    $q->where('return_requests.id', $search)
                        ->orWhere('return_requests.user_id', $search)
                        ->orWhere('order_items.quantity', $search)
                        ->orWhere('order_items.sub_total', $search);
                    return;
                }
                $timestamp = strtotime($search);
                if ($timestamp !== false && (preg_match('/[\/\-\.\s]/', $search) || preg_match('/(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/i', $search))) {
                    $q->whereDate('return_requests.created_at', date('Y-m-d', $timestamp));
                    return;
                }

                $statusValue = null;
                $searchLower = strtolower($search);
                if ($searchLower == 'pending')
                    $statusValue = ReturnStatusList::$rPending;
                elseif ($searchLower == 'accepted' || $searchLower == 'approved')
                    $statusValue = ReturnStatusList::$rAccepted;
                elseif (str_contains($searchLower, 'refund') || str_contains($searchLower, 'completed'))
                    $statusValue = ReturnStatusList::$rRefundCompleted;
                elseif ($searchLower == 'rejected')
                    $statusValue = ReturnStatusList::$rRejected;
                elseif (str_contains($searchLower, 'delivery boy'))
                    $statusValue = ReturnStatusList::$rDeliveryBoyAssigned;
                elseif (str_contains($searchLower, 'pickup'))
                    $statusValue = ReturnStatusList::$rOutForPickup;
                elseif (str_contains($searchLower, 'received'))
                    $statusValue = ReturnStatusList::$rReceivedFromCustomer;
                elseif (str_contains($searchLower, 'to branch'))
                    $statusValue = ReturnStatusList::$rReturnToBranch;

                $q->where('return_requests.id', 'LIKE', "%{$search}%")
                    ->orWhere('return_requests.return_number', 'LIKE', "%{$search}%")
                    ->orWhere('orders.order_number', 'LIKE', "%{$search}%")
                    ->orWhere('users.name', 'LIKE', "%{$search}%")
                    ->orWhere('users.mobile', 'LIKE', "%{$search}%")
                    ->orWhere('order_items.product_name', 'LIKE', "%{$search}%")
                    ->orWhere('return_requests.return_reason', 'LIKE', "%{$search}%")
                    ->orWhere('orders.payment_method', 'LIKE', "%{$search}%");
                if ($statusValue !== null) {
                    $q->orWhere('return_requests.status', $statusValue);
                }
            });
        }

        $offset = (int) $request->input('offset', 0);
        $limit = (int) $request->input('limit', 10);
        if ($offset < 0) $offset = 0;
        if ($limit < 1 || $limit > 100) $limit = 10;

        $total = (clone $query)->count();
        $rows = $query->orderBy('return_requests.id', 'DESC')->offset($offset)->limit($limit)->get();
        $list = $rows->map(fn($rr) => $this->buildReturnDetail($rr))->values();

        app()->setLocale($previousLocale);
        return CommonHelper::responseWithData($list, $total);
    }

    /**
     * Build a single return-request detail payload: the joined return_request row
     * (with translated status) + a nested return_item with its order item details.
     */
    private function buildReturnDetail($returnRequest): array
    {
        $returnRequest->order_status_name = ReturnStatusList::getTranslatedName((int) ($returnRequest->status ?? 0));
        foreach (['price', 'sub_total', 'discounted_price', 'final_total'] as $f) {
            $returnRequest->{$f} = (float) ($returnRequest->{$f} ?? 0);
        }
        // discounted_price: DB value when > 0, else fall back to the selling price.
        if ($returnRequest->discounted_price <= 0) {
            $returnRequest->discounted_price = $returnRequest->price;
        }
        $returnRequest->date = $returnRequest->created_at;
        // Selected from products, so it arrives as a string from PDO.
        $returnRequest->product_type = (int) ($returnRequest->product_type ?? 0);
        $returnRequest->makeHidden(['created_at', 'updated_at']);

        $data = $returnRequest->toArray();
        $data['decimal_point'] = CommonHelper::countryDecimalPoint($returnRequest->order_country_id ?? null);
        unset($data['order_country_id']);
        $data['branch_info'] = CommonHelper::branchInfo($returnRequest->branch_id);
        $returnItem = CommonHelper::buildReturnItem($returnRequest->order_id, $returnRequest->order_item_id);
        if ($returnItem) {
            unset($returnItem->courier_agency, $returnItem->tracking_id, $returnItem->tracking_url);
        }
        $data['return_item'] = $returnItem;
        $data['pickup_address'] = CommonHelper::addressObject($returnRequest->address);
        $data['timeline'] = CommonHelper::getReturnRequestTimeline($returnRequest->id);
        // Customer chat visible while the return pickup is active (delivery boy assigned and
        // not rejected / refund-completed).
        $data['is_delivery_boy_chat_visible'] = CommonHelper::isDeliveryBoyChatVisibleForReturn(
            $returnRequest->delivery_boy_id ? (int) $returnRequest->delivery_boy_id : null,
            (int) ($returnRequest->status ?? 0)
        );
        return $data;
    }

    public function zones(Request $request)
    {
        $zones = Zone::where('status', 1)
            ->when($request->filled('country_id'), fn($q) => $q->where('country_id', (int) $request->input('country_id')))
            ->orderBy('name')
            ->get(['id', 'name'])
            ->map(fn(Zone $z) => [
                'id'   => (int) $z->id,
                'name' => $z->name,
            ])
            ->values();

        // Flat list in `data` — no wrapper object, the client just renders options.
        return CommonHelper::responseWithData($zones);
    }

    /** Delivery boy updates the status of a return assigned to them. */
    public function deliveryBoyUpdate(Request $request)
    {
        return app(ReturnRequestsApiController::class)->update($request);
    }

    public function resetPassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'old_password'     => 'required',
            'new_password'     => 'required|required_with:confirm_password|same:confirm_password',
            'confirm_password' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        if (($pwErr = CommonHelper::validatePasswordPolicy($request->new_password)) !== null) {
            return CommonHelper::responseError($pwErr);
        }

        // The delivery boy authenticates via the linked admin record.
        $user = $request->user();
        if (!$user) {
            return CommonHelper::responseError('unauthenticated');
        }

        if (!Hash::check($request->old_password, $user->password)) {
            return CommonHelper::responseError('incorrect_current_password');
        }

        $user->password = bcrypt($request->new_password);
        $user->save();

        return CommonHelper::responseSuccess('password_updated_successfully');
    }
}
