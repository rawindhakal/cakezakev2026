<?php

namespace App\Http\Controllers\API;

use App\Helpers\AddonHelper;
use App\Helpers\CommonHelper;
use App\Helpers\ProductHelper;
use App\Http\Controllers\Controller;
use App\Services\LanguageService;
use App\Services\Shipping\ShipmentService;
use App\Jobs\ProcessReferralBonusAfterReturnPeriod;
use App\Jobs\SendEmailJob;
use App\Models\DeliveryBoy;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatus;
use App\Models\OrderStatusList;
use App\Models\Role;
use App\Models\Branch;
use App\Models\Transaction;
use App\Models\User;
use App\Models\DeliveryBoyCashCollection;
use App\Models\DeliveryBoySettlement;
use App\Models\PromoCode;
use App\Models\ReturnRequest;
use App\Models\Zone;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;

class OrdersApiController extends Controller
{
    public function getOrders(Request $request)
    {
        $limit = $request->input('per_page', 10);
        $offset = (($request->input('page', 0)) - 1) * $limit;
        $search = $request->input('search', '');

        $branches = $this->getBranchesWithTranslations();

        $branchId = (isset($request->branch) && $request->branch != '') ? (int) $request->branch : null;

        $branchNameSubquery = $branchId
            ? DB::raw("(SELECT s.name FROM branches s INNER JOIN order_items oi ON s.id = oi.branch_id WHERE oi.order_id = orders.id AND oi.branch_id = {$branchId} LIMIT 1) as branch_name")
            : DB::raw('(SELECT s.name FROM branches s INNER JOIN order_items oi ON s.id = oi.branch_id WHERE oi.order_id = orders.id LIMIT 1) as branch_name');

        $ordersQuery = Order::select(
            'orders.id',
            'orders.recipient_name',
            'orders.recipient_phone',
            'orders.recipient_relationship',
            'orders.occasion',
            'orders.delivery_slot_id',
            'orders.payment_verification',
            'orders.delivery_starts_at',
            'orders.delivery_ends_at',
            'orders.delivery_date',
            'orders.delivery_slot',
            'orders.gift_delivery_type',
            'orders.gift_message',
            'orders.sender_name',
            'orders.is_surprise',
            'orders.personalization',
            'orders.delivery_type',
            'orders.order_number',
            'orders.invoice_number',
            'orders.mobile',
            'orders.total',
            'orders.delivery_charge',
            'orders.wallet_balance',
            'orders.final_total',
            'orders.remaining_final',
            'orders.payment_method',
            'orders.additional_charges',
            'orders.surge_charges',
            'orders.promo_discount',
            'orders.active_status',
            'orders.channel',
            'orders.address',
            'orders.delivery_boy_id',
            'orders.created_at',
            'orders.user_id',
            'orders.currency',
            'users.name as user_name',
            // Latest transaction status (paid/failed) — null when none recorded.
            DB::raw('(SELECT t.status FROM transactions t WHERE t.order_id = orders.id ORDER BY t.id DESC LIMIT 1) as payment_status'),
            // Comma-joined item names for the list "items" column.
            DB::raw('(SELECT GROUP_CONCAT(oi.product_name SEPARATOR ", ") FROM order_items oi WHERE oi.order_id = orders.id) as items_preview'),
            // Delivery city/state from the order address.
            DB::raw('(SELECT CONCAT_WS(", ", ua.city, ua.state) FROM user_addresses ua WHERE ua.id = orders.address_id LIMIT 1) as customer_city'),
            // Assigned delivery boy name (null = unassigned).
            DB::raw('(SELECT db.name FROM delivery_boys db WHERE db.id = orders.delivery_boy_id LIMIT 1) as delivery_boy_name'),
            $branchNameSubquery
        )
            ->leftJoin('users', 'orders.user_id', '=', 'users.id');

        // Only parse dates when actually provided
        if (isset($request->startDate) && $request->startDate != "" && isset($request->endDate) && $request->endDate != "") {
            $startDate = Carbon::parse($request->startDate)->startOfDay();
            $endDate = Carbon::parse($request->endDate)->endOfDay();

            // Use whereExists for better performance than join
            $ordersQuery = $ordersQuery->whereExists(function ($query) use ($startDate, $endDate) {
                $query->select(DB::raw(1))
                    ->from('order_items')
                    ->whereColumn('order_items.order_id', 'orders.id')
                    ->whereBetween('order_items.created_at', [$startDate, $endDate]);
            });
        }

        if (isset($request->branch) && $request->branch != "") {
            // Use whereExists for branch filter to avoid join issues
            $ordersQuery = $ordersQuery->whereExists(function ($query) use ($request) {
                $query->select(DB::raw(1))
                    ->from('order_items')
                    ->whereColumn('order_items.order_id', 'orders.id')
                    ->where('order_items.branch_id', $request->branch);
            });
        }

        // Mode / channel filter (quick | ecommerce).
        if (isset($request->channel) && $request->channel != "" && in_array($request->channel, ['quick', 'ecommerce'], true)) {
            $ordersQuery = $ordersQuery->where('orders.channel', $request->channel);
        }
        // Delivery type filter (delivery | pickup) — the "Self Pickup" page pins it.
        if ($request->filled('delivery_type') && in_array($request->delivery_type, ['delivery', 'pickup'], true)) {
            $ordersQuery = $ordersQuery->where('orders.delivery_type', $request->delivery_type);
        }

        // Country / zone filters (admin panel dropdowns).
        if (!empty($request->country_id)) {
            $ordersQuery = $ordersQuery->where('orders.country_id', $request->country_id);
        }
        if (!empty($request->zone_id)) {
            $ordersQuery = $ordersQuery->where('orders.zone_id', $request->zone_id);
        }

        // Payment method filter.
        if (isset($request->payment_method) && $request->payment_method != "") {
            $ordersQuery = $ordersQuery->where('orders.payment_method', $request->payment_method);
        }

        // Payment status filter (latest transaction status, or 'pending' when none/unpaid).
        if (isset($request->payment_status) && $request->payment_status != "") {
            $ps = $request->payment_status;
            $ordersQuery = $ordersQuery->where(function ($q) use ($ps) {
                $latest = '(SELECT t.status FROM transactions t WHERE t.order_id = orders.id ORDER BY t.id DESC LIMIT 1)';
                if ($ps === 'pending') {
                    $q->whereRaw("COALESCE($latest, 'pending') = 'pending'");
                } else {
                    $q->whereRaw("$latest = ?", [$ps]);
                }
            });
        }

        // Amount range (payable total).
        if (isset($request->amount_min) && $request->amount_min !== "" && is_numeric($request->amount_min)) {
            $ordersQuery = $ordersQuery->where('orders.final_total', '>=', (float) $request->amount_min);
        }
        if (isset($request->amount_max) && $request->amount_max !== "" && is_numeric($request->amount_max)) {
            $ordersQuery = $ordersQuery->where('orders.final_total', '<=', (float) $request->amount_max);
        }

        // ── Delivery date planning ───────────────────────────────────────────────
        $sched = app(\App\Services\DeliverySchedulingService::class);
        $today = $sched->now()->toDateString();
        $tomorrow = $sched->now()->addDay()->toDateString();
        $open = [1, 2, 3, 4, 5, 9, 10, 11]; // not delivered / cancelled / returned
        $dc = (clone $ordersQuery);
        $deliveryCounts = [
            'today'       => (clone $dc)->where('orders.delivery_date', $today)->count(),
            'tomorrow'    => (clone $dc)->where('orders.delivery_date', $tomorrow)->count(),
            'upcoming'    => (clone $dc)->where('orders.delivery_date', '>', $today)->whereNotIn('orders.active_status', [6, 7, 8])->count(),
            'overdue'     => (clone $dc)->where('orders.delivery_date', '<', $today)->whereIn('orders.active_status', $open)->count(),
            'unscheduled' => (clone $dc)->whereNull('orders.delivery_date')->count(),
        ];
        if ($request->filled('delivery_date')) {
            $ordersQuery = $ordersQuery->where('orders.delivery_date', $request->delivery_date);
        }
        if ($request->filled('delivery_from')) {
            $ordersQuery = $ordersQuery->where('orders.delivery_date', '>=', $request->delivery_from);
        }
        if ($request->filled('delivery_to')) {
            $ordersQuery = $ordersQuery->where('orders.delivery_date', '<=', $request->delivery_to);
        }
        if ($request->filled('delivery_slot_id')) {
            $ordersQuery = $ordersQuery->where('orders.delivery_slot_id', (int) $request->delivery_slot_id);
        }
        switch ((string) $request->input('delivery_when', '')) {
            case 'today':       $ordersQuery = $ordersQuery->where('orders.delivery_date', $today); break;
            case 'tomorrow':    $ordersQuery = $ordersQuery->where('orders.delivery_date', $tomorrow); break;
            case 'week':        $ordersQuery = $ordersQuery->whereBetween('orders.delivery_date', [$today, $sched->now()->addDays(6)->toDateString()]); break;
            case 'upcoming':    $ordersQuery = $ordersQuery->where('orders.delivery_date', '>', $today)->whereNotIn('orders.active_status', [6, 7, 8]); break;
            case 'overdue':     $ordersQuery = $ordersQuery->where('orders.delivery_date', '<', $today)->whereIn('orders.active_status', $open); break;
            case 'unscheduled': $ordersQuery = $ordersQuery->whereNull('orders.delivery_date'); break;
        }

        // Product name filter.
        if (isset($request->product_name) && $request->product_name != "") {
            $pname = $request->product_name;
            $ordersQuery = $ordersQuery->whereExists(function ($query) use ($pname) {
                $query->select(DB::raw(1))
                    ->from('order_items')
                    ->whereColumn('order_items.order_id', 'orders.id')
                    ->where('order_items.product_name', 'like', "%{$pname}%");
            });
        }

        if ($search) {
            // Optimize search with better query structure
            $ordersQuery = $ordersQuery->where(function ($query) use ($search) {
                $query->where('orders.payment_method', 'like', "%{$search}%")
                    ->orWhere('orders.id', 'like', "%{$search}%")
                    ->orWhere('orders.order_number', 'like', "%{$search}%")
                    ->orWhere('orders.invoice_number', 'like', "%{$search}%")
                    ->orWhere('orders.mobile', 'like', "%{$search}%")
                    ->orWhere('orders.delivery_charge', 'like', "%{$search}%")
                    ->orWhere('orders.wallet_balance', 'like', "%{$search}%")
                    ->orWhere('orders.remaining_final', 'like', "%{$search}%")
                    ->orWhere('orders.total', 'like', "%{$search}%")
                    ->orWhereExists(function ($subQuery) use ($search) {
                        $subQuery->select(DB::raw(1))
                            ->from('users')
                            ->whereColumn('users.id', 'orders.user_id')
                            ->where('users.name', 'like', "%{$search}%");
                    })
                    ->orWhereExists(function ($subQuery) use ($search) {
                        $subQuery->select(DB::raw(1))
                            ->from('order_items')
                            ->leftJoin('branches', 'order_items.branch_id', '=', 'branches.id')
                            ->whereColumn('order_items.order_id', 'orders.id')
                            ->where('branches.name', 'like', "%{$search}%");
                    })
                    ->orWhereExists(function ($subQuery) use ($search) {
                        $subQuery->select(DB::raw(1))
                            ->from('order_items')
                            ->whereColumn('order_items.order_id', 'orders.id')
                            ->where('order_items.active_status', 'like', "%{$search}%");
                    });
            });
        }

        // Stat-card counts — computed over all current filters EXCEPT status, so
        // the cards reflect the filtered context but still show each bucket.
        $countsRaw = (clone $ordersQuery)
            ->select('orders.active_status', DB::raw('COUNT(*) as c'))
            ->groupBy('orders.active_status')
            ->pluck('c', 'orders.active_status');
        $bucket = fn(array $ids) => (int) collect($ids)->sum(fn($id) => (int) ($countsRaw[$id] ?? 0));
        $counts = [
            'total'      => (int) $countsRaw->sum(),
            'pending'    => $bucket([1, 2]),          // payment pending + received
            'processing' => $bucket([3, 4, 5, 9, 10, 11]), // processed/shipped/out-for-delivery + preparing/ready-for-pickup/picked-up
            'delivered'  => $bucket([6]),
            'cancelled'  => $bucket([7, 8]),          // cancelled + returned
        ];

        // Status filter (applied after counts so cards stay representative).
        if (isset($request->status) && $request->status != "") {
            $ordersQuery = $ordersQuery->where('orders.active_status', $request->status);
        }

        // Get total count using a separate optimized query (without groupBy)
        $orders_total = (clone $ordersQuery)->count();

        // Apply ordering and pagination (sort: newest|oldest|amount_high|amount_low).
        $sort = strtolower((string) $request->input('sort', 'newest'));
        switch ($sort) {
            case 'oldest':
                $ordersQuery->orderBy('orders.id', 'ASC');
                break;
            case 'amount_high':
                $ordersQuery->orderBy('orders.final_total', 'DESC');
                break;
            case 'amount_low':
                $ordersQuery->orderBy('orders.final_total', 'ASC');
                break;
            case 'delivery_asc':   // soonest delivery first, unscheduled last
                $ordersQuery->orderByRaw('orders.delivery_starts_at IS NULL')->orderBy('orders.delivery_starts_at', 'ASC')->orderBy('orders.id', 'ASC');
                break;
            case 'delivery_desc':
                $ordersQuery->orderByRaw('orders.delivery_starts_at IS NULL')->orderBy('orders.delivery_starts_at', 'DESC')->orderBy('orders.id', 'DESC');
                break;
            default: // newest
                $ordersQuery->orderBy('orders.id', 'DESC');
                break;
        }
        $orders = $ordersQuery->skip($offset)->take($limit)->get();

        // Normalize additional_charges to an array. It is array-cast on the Order
        // model now, but tolerate legacy JSON strings too.
        $orders->transform(function ($order) {
            $ac = $order->additional_charges;
            if (is_string($ac)) {
                $decoded = json_decode($ac, true);
                $order->additional_charges = is_array($decoded) ? $decoded : [];
            } elseif (!is_array($ac)) {
                $order->additional_charges = [];
            }
            $order->date = $order->created_at;
            return $order;
        });
        $orders = $orders->makeHidden(['created_at']);

        $item_limit = $request->input('item_per_page', 10);
        $item_offset = (($request->input('item_page', 0)) - 1) * $item_limit;
        $data = array(
            "branches" => $branches,
            "orders" => $orders,
            "orders_total" => $orders_total,
            "counts" => $counts,
            "delivery_counts" => $deliveryCounts,
        );
        return CommonHelper::responseWithData($data);
    }

    /** Delivery planner: orders per delivery date x time slot, with slot capacity. */
    public function deliverySchedule(Request $request)
    {
        $sched = app(\App\Services\DeliverySchedulingService::class);
        $from = $request->input('from', $sched->now()->toDateString());
        $to = $request->input('to', $sched->now()->addDays(13)->toDateString());
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', (string) $from) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', (string) $to)) {
            return CommonHelper::responseError('Invalid date range.');
        }
        $slots = DB::table('delivery_slots')->orderBy('sort_order')->orderBy('start_time')->get(['id', 'label', 'capacity', 'status']);
        $rows = DB::table('orders')->whereBetween('delivery_date', [$from, $to])->whereNotIn('active_status', \App\Services\DeliverySchedulingService::RELEASED_STATUSES)
            ->select('delivery_date', 'delivery_slot_id', 'delivery_slot', 'active_status', DB::raw('COUNT(*) as c'), DB::raw('SUM(final_total) as amount'))
            ->groupBy('delivery_date', 'delivery_slot_id', 'delivery_slot', 'active_status')->get();
        $closed = DB::table('delivery_blackout_dates')->whereBetween('date', [$from, $to])->get(['date', 'slot_id', 'reason']);
        $days = [];
        for ($d = \Carbon\Carbon::parse($from); $d->lte(\Carbon\Carbon::parse($to)); $d->addDay()) {
            $days[$d->toDateString()] = ['date' => $d->toDateString(), 'weekday' => $d->format('D'), 'total' => 0, 'amount' => 0.0, 'pending' => 0, 'delivered' => 0, 'slots' => [], 'closed' => false, 'closed_reason' => null];
        }
        foreach ($closed as $c) {
            $k = \Carbon\Carbon::parse($c->date)->toDateString();
            if (isset($days[$k]) && $c->slot_id === null) { $days[$k]['closed'] = true; $days[$k]['closed_reason'] = $c->reason; }
        }
        foreach ($rows as $r) {
            $k = \Carbon\Carbon::parse($r->delivery_date)->toDateString();
            if (!isset($days[$k])) continue;
            $key = $r->delivery_slot_id ?: ('label:' . $r->delivery_slot);
            $days[$k]['slots'][$key] = ($days[$k]['slots'][$key] ?? 0) + (int) $r->c;
            $days[$k]['total'] += (int) $r->c;
            $days[$k]['amount'] += (float) $r->amount;
            if ((int) $r->active_status === 6) $days[$k]['delivered'] += (int) $r->c; else $days[$k]['pending'] += (int) $r->c;
        }
        return CommonHelper::responseWithData(['from' => $from, 'to' => $to, 'slots' => $slots, 'days' => array_values($days),
            'unscheduled' => DB::table('orders')->whereNull('delivery_date')->whereNotIn('active_status', [6, 7, 8])->count()]);
    }

    public function view($id)
    {
        $data = CommonHelper::getOrderDetails($id);
        if (!$data["order"]) {
            return CommonHelper::responseError("Order Not found!");
        }

        // Only delivery boys in the order's country can be assigned.
        $data["deliveryBoys"] = $this->getDeliveryBoysWithTranslations(
            $data["order"]->country_id ?? null,
            $data["order"]->zone_id ?? null
        );

        unset($data['order']->charge_tax_lines, $data['order']->hsn_summary, $data['order']->tax_component_totals);
        foreach ($data['order_items'] as $oi) {
            unset($oi->tax_lines);
        }

        // Branch details (translated name + location/contact) — order level and per item.
        $data['order']->branch_info = CommonHelper::branchInfo($data['order']->branch_id ?? null);
        foreach ($data['order_items'] as $oi) {
            $oi->branch_info = CommonHelper::branchInfo($oi->branch_id ?? null);
        }

        /* Which fulfilment doors the drawer may offer for this order — its zone's choice,
           minus a courier with no working plugin behind it. */
        $data['order']->delivery_methods = CommonHelper::deliveryMethodsForZone(
            Zone::find($data['order']->zone_id ?? 0)
        );

        $data['order']->decimal_point = CommonHelper::countryDecimalPoint($data['order']->country_id ?? null);
        foreach ($data['order_items'] as $oi) {
            $oi->decimal_point = $data['order']->decimal_point;
        }

        // Delivery-boy ↔ customer chat visibility. Quick = order-level (forward only, never
        // returnable); ecommerce = per item (forward delivery, or an active return pickup).
        $isPickup = ($data['order']->delivery_type ?? 'delivery') === 'pickup';
        $data['order']->is_delivery_boy_chat_visible = !$isPickup && CommonHelper::isDeliveryBoyChatVisibleForward(
            $data['order']->delivery_boy_id ? (int) $data['order']->delivery_boy_id : null,
            (int) ($data['order']->active_status ?? 0)
        );
        if (($data['order']->channel ?? '') === 'ecommerce' && !$isPickup) {
            foreach ($data['order_items'] as $oi) {
                $oi->is_delivery_boy_chat_visible = CommonHelper::isDeliveryBoyChatVisibleForOrderItem(
                    (int) $oi->id,
                    $oi->delivery_boy_id ? (int) $oi->delivery_boy_id : null,
                    (int) ($oi->active_status ?? 0)
                );
            }
        }

        $deliveryType = $data['order']->delivery_type ?? 'delivery';
        $progressTimeline = fn ($rows, string $channel) => CommonHelper::orderProgressTimeline(
            $rows,
            $channel,
            function ($sid) use ($deliveryType) {
                if ($deliveryType === 'pickup' && (int) $sid === OrderStatusList::$delivered) {
                    return __('collected');
                }
                $key = OrderStatusList::getTranslationKey((int) $sid);
                return $key !== '' ? __($key) : (string) $sid;
            },
            fn ($row) => [
                'created_by' => $row->createdByName ?? '',
                'user_type'  => $row->user_type ?? null,
            ],
            fn ($row) => $row->displayDateTime,
            $deliveryType
        );

        // Single `timeline` param: order-wise for quick and for every pickup order
        // (order_item_id = 0); for ecommerce delivery it is embedded per item instead.
        if (($data['order']->channel ?? '') === 'ecommerce' && !$isPickup) {
            $data["timeline"] = [];
            $perItem = OrderStatus::where('order_id', $id)
                ->where('order_item_id', '!=', 0)
                ->orderBy('id', 'ASC')->get()
                ->groupBy('order_item_id')
                ->map(fn ($rows) => collect($progressTimeline($rows, 'ecommerce')));
            foreach ($data['order_items'] as $oi) {
                $timeline = $perItem->get($oi->id, collect())->values();
                // If the item was returned, continue the timeline with the return flow
                // (after the "returned" entry).
                $returnRequestId = ReturnRequest::where('order_item_id', $oi->id)->value('id');
                if ($returnRequestId) {
                    $returnTimeline = collect(CommonHelper::getReturnRequestTimeline($returnRequestId))
                        ->map(fn ($t) => [
                            'status'      => $t['status'],
                            'status_name' => $t['status_name'],
                            'created_by'  => $t['updated_by'] ?? '',
                            'user_type'   => null,
                            'datetime'    => $t['datetime'],
                            'is_return'   => true,
                        ]);
                    $timeline = $timeline->concat($returnTimeline)->values();
                }
                $oi->timeline = $timeline;
            }
        } else {
            $data["timeline"] = $progressTimeline(
                OrderStatus::where('order_id', $id)->where('order_item_id', 0)->orderBy('id', 'ASC')->get(),
                (string) ($data['order']->channel ?? 'quick')
            );
        }

        return CommonHelper::responseWithData($data);
    }

    public function downloadOrderInvoice(Request $request)
    {
        $data = CommonHelper::getOrderDetails($request->order_id, true);
        if (!$data["order"]) {
            return CommonHelper::responseError("Order Not found!");
        }
        CommonHelper::AdditionalChargesArray($data['order']);

        return CommonHelper::downloadOrderInvoice(
            $request->order_id,
            $request->filled('size') ? (string) $request->input('size') : null
        );
    }

    public function downloadDeliveryReceipt(Request $request)
    {
        // null lets the configured default size win; the print menu still overrides.
        $size = $request->filled('size') ? (string) $request->input('size') : null;
        $itemId = $request->input('order_item_id');

        if ($itemId) {
            $item = OrderItem::find($itemId);
            if (!$item) {
                return CommonHelper::responseError('order_item_not_found');
            }

            $data = CommonHelper::deliveryReceiptDataForItem($item);
            if (!$data) {
                return CommonHelper::responseError('Order Not found!');
            }

            return CommonHelper::deliveryReceiptPdf($data, $item->order_id . '-' . $item->id, $size);
        }

        // Whole order: cancelled and returned items are not in the parcel.
        $data = CommonHelper::getOrderDetails($request->order_id, true);
        if (!$data['order']) {
            return CommonHelper::responseError('Order Not found!');
        }

        return CommonHelper::deliveryReceiptPdf($data, $request->order_id, $size);
    }

    /** Download a single order item's invoice (ecommerce, item-wise). */
    public function downloadOrderItemInvoice(Request $request)
    {
        $item = OrderItem::find($request->order_item_id);
        if (!$item) {
            return CommonHelper::responseError('order_item_not_found');
        }
        $data = CommonHelper::getOrderDetails($item->order_id);
        if (!$data["order"]) {
            return CommonHelper::responseError("Order Not found!");
        }

        // Keep only this item, and present its amounts as the invoice totals.
        $allItems = collect($data['order_items']);
        $data['order_items'] = $allItems->where('id', $item->id)->values();
        $orderSubTotal = (float) $allItems->sum('sub_total');
        $chargeShare = $orderSubTotal > 0 ? ((float) $item->sub_total / $orderSubTotal) : 0.0;
        CommonHelper::attachOrderTaxSummary(
            $data['order'],
            $data['order_items'],
            DB::table('order_item_taxes')->where('order_id', $item->order_id)->where('is_reversal', 0)
                ->where(fn ($q) => $q->where('order_item_id', $item->id)->orWhereNull('order_item_id'))
                ->get(),
            $chargeShare
        );
        $order = $data['order'];
        $order->delivery_charge   = $item->delivery_charge;
        $order->additional_charges = $item->additional_charges;
        $order->surge_charges     = $item->surge_charges;
        $order->promo_discount    = $item->promo_discount;
        $order->wallet_balance    = $item->wallet_balance;
        $order->remaining_total   = $item->sub_total;
        $order->final_total       = $item->final_total;
        $order->remaining_final   = max(0, (float) $item->final_total - (float) $item->wallet_balance);
        // Item refunded (cancelled/returned): nothing left payable, surface its refund.
        if (in_array((int) $item->active_status, [7, 8], true)) {
            $order->remaining_final = 0;
            $order->refund_amount   = (float) $item->refund_amount;
        }
        $order->active_status = $item->active_status;
        // This invoice is for the single item — show the item's own invoice number.
        $order->invoice_number = $item->invoice_number ?: ($order->invoice_number . '-' . $item->id);
        $data['order'] = $order;

        return CommonHelper::invoicePdfFromData(
            $data,
            $item->invoice_number ?: ($item->order_id . '-' . $item->id),
            $request->filled('size') ? (string) $request->input('size') : null
        );
    }

    public function delete(Request $request)
    {
        if (isset($request->id)) {
            $order = Order::find($request->id);
            if ($order) {
                $order->delete();
                return CommonHelper::responseSuccess('order_deleted_successfully');
            } else {
                return CommonHelper::responseSuccess("Order Already Deleted!");
            }
        }
    }

    public function deleteItem(Request $request)
    {
        if (isset($request->id)) {
            $orderItem = OrderItem::find($request->id);
            if ($orderItem) {
                $orderItem->delete();
                return CommonHelper::responseSuccess('order_item_deleted_successfully');
            } else {
                return CommonHelper::responseSuccess("Order Item Already Deleted!");
            }
        }
    }


    public function updateStatus(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_id' => 'required',
            'status_id' => 'required',
        ], [
            'order_id.required' => 'The Order id field is required.',
            'status_id.required' => 'The status field is required.',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $order = Order::find($request->order_id);
        if (empty($order)) {
            return CommonHelper::responseError("Order Not found!");
        }
        $selectedStatus = OrderStatusList::where('id', $request->status_id)->value('status');

        if ($order->active_status == $request->status_id) {
            return CommonHelper::responseError("This Order is already " . $selectedStatus . "!");
        }

        if ($order->active_status == 6 && $request->status_id < 6) {
            return CommonHelper::responseError("This Order is Delivered");
        }

        if ($order->active_status == OrderStatusList::$paymentPending) {
            return CommonHelper::responseError("cannot_assign_delivery_boy_while_payment_pending");
        }

        if ($order->active_status == OrderStatusList::$returned || $order->active_status == OrderStatusList::$cancelled) {
            return CommonHelper::responseError("Order is Cancelled OR Returned.");
        }

        // A status outside this order's flow (a rider step on a self-pickup order, say)
        // is not a step at all.
        if (!in_array((int) $request->status_id, OrderStatusList::flowFor($order->channel, $order->delivery_type), true)) {
            return CommonHelper::responseError('status_not_allowed_for_this_order_type');
        }

        // Ready-for-pickup / picked-up / out-for-delivery require an assigned delivery boy —
        // on a delivery. A pickup order is collected by the customer; nobody is assigned.
        $needsDeliveryBoy = [OrderStatusList::$readyForPickup, OrderStatusList::$pickedUp, OrderStatusList::$outForDelivery];
        if (!$order->isPickup() && in_array((int) $request->status_id, $needsDeliveryBoy, true)) {
            $assignedBoy = $request->delivery_boy_id ?? $order->delivery_boy_id;
            if (empty($assignedBoy) || (int) $assignedBoy === 0) {
                return CommonHelper::responseError('please_assign_a_delivery_boy_first');
            }
        }

        // OTP check on delivery for quick orders — only enforced when a delivery boy marks
        // delivered (admins/other roles bypass it). Validated against orders.otp (> 0 = OTP enabled).
        if ((int) $request->status_id === OrderStatusList::$delivered && $order->channel === 'quick' && (int) $order->otp > 0
            && (int) auth()->user()->role_id === Role::$roleDeliveryBoy) {
            if (empty($request->otp) || (int) $request->otp !== (int) $order->otp) {
                return CommonHelper::responseError('invalid_otp');
            }
        }

        DB::beginTransaction();
        try {

            if ($order->active_status != $request->status_id) {
                $effectiveDeliveryBoyId = $order->isPickup() ? 0 : ((isset($request->delivery_boy_id) && $request->delivery_boy_id != "" && $request->delivery_boy_id != 0)
                    ? (int) $request->delivery_boy_id
                    : (int) ($order->delivery_boy_id ?? 0));

                if ($effectiveDeliveryBoyId) {

                    // Delivery Boy cash collection add and cash_received update with update balance of delivery boy start
                    if ($request->status_id == OrderStatusList::$delivered && ($deliveryBoy = DeliveryBoy::find($effectiveDeliveryBoyId))) {

                        CommonHelper::addDeliveryBoySettlement($deliveryBoy->id, $order->delivery_boy_bonus_amount, DeliveryBoySettlement::$typeCredit);
                        $deliveryBoy->refresh();

                        if ($order->payment_method == DeliveryBoyCashCollection::$paymentTypeCod) {

                            $transactionData = [
                                'user_id' => $order->user_id,
                                'order_id' => $order->id,
                                'delivery_boy_id' => $deliveryBoy->id,
                                'type' => $order->payment_method,
                                'amount' => $order->remaining_final,
                                'status' => Transaction::$statusSuccess,
                                'message' => 'cod_collected_on_delivery',
                                'transaction_date' => now(), // Cleaner than date('Y-m-d H:i:s')
                            ];

                            $transaction = DeliveryBoyCashCollection::create($transactionData);

                            $order->transaction_id = $transaction->id ?? 0;

                            $deliveryBoy->cash_received = floatval($deliveryBoy->cash_received) + floatval($order->remaining_final);
                        }

                        $deliveryBoy->save();
                    }

                    $order->delivery_boy_id = $effectiveDeliveryBoyId;
                }

                $order->active_status = $request->status_id;
                $order->save();

                if (in_array((int) $request->status_id, [OrderStatusList::$cancelled, OrderStatusList::$returned], true)) {
                    CommonHelper::reverseOrderTax($order);
                }

                if ($request->status_id == OrderStatusList::$delivered) {
                    $order = Order::with('user', 'items.productVariant.product')->find($request->order_id);
                    $user = $order->user;

                    if ($order->isPickup()) {
                        CommonHelper::recordPickupCodCollection($order);
                    }

                    // Credit wallet-type promo cashback now that the order is delivered.
                    CommonHelper::creditOrderCashback($order);

                    // Refer-&-earn is country-wise, from the ORDER's country: qualify by that
                    // country's threshold, credit in that country's currency into the
                    // referrer's wallet FOR THAT COUNTRY.
                    $orderCountry = CommonHelper::resolveOrderCountry($order);
                    $referralCountryId = $order->country_id ?: ($orderCountry->id ?? null);
                    $referralMinOrderAmount = (float) ($orderCountry->referral_min_order_amount ?? 0);
                    $referralCredit = (float) ($orderCountry->referral_credit_first_order ?? 0);
                    $referredCredit = (float) ($orderCountry->referral_credit_referred ?? 0);

                    if ($user && $user->friends_code && $order->final_total >= $referralMinOrderAmount) {
                        // Check if this is the user's FIRST delivered order
                        $deliveredOrdersCount = Order::where('user_id', $user->id)
                            ->where('active_status', OrderStatusList::$delivered)
                            ->where('id', '!=', $order->id)  // Exclude current order
                            ->count();

                        if ($deliveredOrdersCount === 0) {  // This means it's the first order

                            $now = Carbon::now();

                            $canCreditReferral = true;

                            foreach ($order->items as $item) {
                                // Frozen policy snapshot on the order item.
                                if ($item->return_status == 1 && $item->return_days > 0) {
                                    $canCreditReferral = false;
                                }
                            }

                            if ($canCreditReferral) {
                                // Credit referral bonus immediately
                                $referrer = User::where('referral_code', $user->friends_code)->first();

                                if ($referrer && !CommonHelper::referralLimitReached($referrer->id, $orderCountry)) {
                                    // Referrer bonus → referrer's wallet for the ORDER's country.
                                    if ($referralCredit > 0) {
                                        $current = (float) CommonHelper::getUserWalletBalance($referrer->id, $referralCountryId);
                                        CommonHelper::updateUserWalletBalance($current + $referralCredit, $referrer->id, $referralCountryId);
                                        CommonHelper::addWalletTransaction($order->id, 0, $referrer->id, 'credit', $referralCredit, 'wallet_refer_earn_first_order_bonus');
                                        CommonHelper::sendWalletNotification($referrer, $referralCredit, 'wallet_referral_bonus_customer', 'customer_wallet_referral_bonus', [], $referralCountryId);
                                    }
                                    // Referred-user bonus → the new user's wallet for the same country.
                                    if ($referredCredit > 0) {
                                        $currentReferred = (float) CommonHelper::getUserWalletBalance($user->id, $referralCountryId);
                                        CommonHelper::updateUserWalletBalance($currentReferred + $referredCredit, $user->id, $referralCountryId);
                                        CommonHelper::addWalletTransaction($order->id, 0, $user->id, 'credit', $referredCredit, 'wallet_refer_earn_referred_user_bonus');
                                        CommonHelper::sendWalletNotification($user, $referredCredit, 'wallet_referral_bonus_customer', 'customer_wallet_referral_bonus', [], $referralCountryId);
                                    }
                                }
                            } else {
                                // Queue a job to check again after max return days
                                $maxReturnDays = $order->items->filter(function ($item) {
                                    return $item->return_status == 1 && $item->return_days > 0;
                                })->max(function ($item) {
                                    return $item->return_days;
                                }) ?? 0;

                                $deliveredStatus = OrderStatus::where('order_id', $order->id)
                                    ->where('status', OrderStatusList::$delivered)
                                    ->orderBy('created_at', 'desc')
                                    ->first();

                                $deliveredAt = $deliveredStatus ? Carbon::parse($deliveredStatus->created_at) : Carbon::parse($order->updated_at);
                                $now = Carbon::now();

                                if ($maxReturnDays > 0) {

                                    $returnPeriodEnd = $deliveredAt->copy()->addDays($maxReturnDays);
                                    $delay = $now->diffInSeconds($returnPeriodEnd, false); // false: signed diff

                                    if ($delay > 0) {
                                        ProcessReferralBonusAfterReturnPeriod::dispatch($order->id)->delay(Carbon::now()->addSeconds($delay));
                                    }
                                }
                            }
                        }
                    }
                }

                $excludedStatuses = [OrderStatusList::$cancelled, OrderStatusList::$returned];

                $query = OrderItem::where("order_id", $request->order_id)
                    ->whereNotIn("active_status", $excludedStatuses)
                    ->whereNull('courier_shipment_id')
                    ->update(['active_status' => $request->status_id]);

                $orderStatus = array();
                $orderStatus["order_id"] = $request->order_id;
                $orderStatus['order_item_id'] = 0;
                $orderStatus["status"] = $request->status_id;
                $orderStatus["created_by"] = auth()->user()->id;
                $orderStatus["user_type"] = OrderStatus::$userTypeAdmin;
                CommonHelper::setOrderStatus($orderStatus);
            } else {
                $status = OrderStatusList::find($request->status_id);
                return CommonHelper::responseError('status_is_already' . " " . $status->status);
            }
            DB::commit();
        } catch (\Exception $e) {
            Log::info("Error : " . $e->getMessage());
            DB::rollBack();
            throw $e;
            return CommonHelper::responseError('something_went_wrong');
        }

        $order = Order::with('items')->where("id", $request->order_id)->first();

        if (!empty($order)) {
            try {
                dispatch(function () use ($order) {
                    CommonHelper::sendNotificationOrderStatus($order, 'order_item_status_update');
                    CommonHelper::sendOrderNotificationsToAdmins($order, 'order_status_update', $order->delivery_boy_id ?? null);
                })->afterResponse();
            } catch (\Exception $e) {
                Log::error("Order status notification error: " . $e->getMessage());
            }

            try {
                dispatch(new SendEmailJob($order))->afterResponse();
            } catch (\Exception $e) {
                Log::error('update_order_status_by_delivery_boy_send_mail_error' . ":", [$e->getMessage()]);
            }

            try {
                dispatch(function () use ($order) {
                    CommonHelper::sendSmsOrderStatus($order, $order->active_status);
                })->afterResponse();
            } catch (\Exception $e) {
                Log::error('update_order_status_by_delivery_boy_send_sms_error' . ":", [$e->getMessage()]);
            }
        }

        return CommonHelper::responseSuccess('order_updated_successfully');
    }

    /**
     * Admin cancel — full refund. Unlike a customer cancel (which withholds delivery /
     * non-refundable charges), an admin cancel is not the customer's fault (out of
     * stock etc), so the customer is refunded everything they paid:
     *   - prepaid: the item's full final_total (or the whole order's, for quick)
     *   - COD: only the wallet amount applied at checkout (cash was never collected)
     * Quick orders cancel order-wise (order_id); ecommerce cancels item-wise (order_item_id).
     */
    public function adminCancel(Request $request)
    {
        // order_item_ids (array or csv) cancels several ecommerce items in one go; the
        // same reason is stored on each of them.
        $itemIds = $request->order_item_ids ?? $request->order_item_id;
        $itemIds = is_array($itemIds) ? $itemIds : ($itemIds === null || $itemIds === '' ? [] : explode(',', (string) $itemIds));
        $itemIds = array_values(array_unique(array_filter(array_map('intval', $itemIds))));

        if (empty($request->order_id) && empty($itemIds)) {
            return CommonHelper::responseError('order_item_id_or_order_id_is_required');
        }
        if (trim((string) $request->cancellation_reason) === '') {
            return CommonHelper::responseError('cancellation_reason_is_required');
        }

        $cancelledItems = []; // non-empty on the item branch; drives which notifications fire

        DB::beginTransaction();
        try {
            if (!empty($itemIds)) {
                // Ecommerce — one or more items, all with the same reason.
                $order = null;
                foreach ($itemIds as $itemId) {
                    $orderItem = OrderItem::find($itemId);
                    if (!$orderItem) {
                        DB::rollBack();
                        return CommonHelper::responseError('Order Item Not found.');
                    }
                    if ($order === null || (int) $order->id !== (int) $orderItem->order_id) {
                        $order = Order::find($orderItem->order_id);
                    }
                    if (in_array((int) $orderItem->active_status, [OrderStatusList::$cancelled, OrderStatusList::$returned], true)) {
                        DB::rollBack();
                        return CommonHelper::responseError('order_item_is_already_cancelled');
                    }
                    if ((int) $orderItem->active_status === OrderStatusList::$delivered) {
                        DB::rollBack();
                        return CommonHelper::responseError('delivered_item_cannot_be_cancelled');
                    }
                    $this->adminCancelItem($order, $orderItem, $request->cancellation_reason ?? null);
                    $cancelledItems[] = $orderItem->id;
                }
                CommonHelper::syncEcommerceOrderStatus($order);
            } else {
                // Quick — whole order.
                $order = Order::find($request->order_id);
                if (!$order) {
                    return CommonHelper::responseError('Order Not found.');
                }
                if (in_array((int) $order->active_status, [OrderStatusList::$cancelled, OrderStatusList::$returned], true)) {
                    return CommonHelper::responseError('order_is_already_cancelled_or_returned');
                }
                if ((int) $order->active_status === OrderStatusList::$delivered) {
                    return CommonHelper::responseError('delivered_order_cannot_be_cancelled');
                }
                $items = OrderItem::where('order_id', $order->id)
                    ->where('active_status', '!=', OrderStatusList::$cancelled)
                    ->get();
                foreach ($items as $it) {
                    $this->adminCancelItem($order, $it, $request->cancellation_reason ?? null);
                }

                $isCod = $order->payment_method === Transaction::$paymentTypeCod;
                $orderRefund = $isCod
                    ? floatval($order->wallet_balance)
                    : floatval($order->final_total) + floatval($order->wallet_balance);
                if ($orderRefund > 0) {
                    CommonHelper::addUserWalletBalance($orderRefund, $order->user_id, $order->country_id);
                    CommonHelper::addWalletTransaction($order->id, 0, $order->user_id, 'credit', $orderRefund, 'wallet_order_item_cancelled');
                    CommonHelper::notifyWalletRefundCancelled($order, $items->first(), $orderRefund);
                    $order->refund_amount = floatval($order->refund_amount) + $orderRefund;
                }

                $order->active_status = OrderStatusList::$cancelled;
                $order->remaining_total = 0;
                $order->remaining_final = 0;
                $order->wallet_balance = 0;
                $order->promo_code_id = 0;
                $order->save();

                CommonHelper::reverseOrderChargeTax($order->id);

                CommonHelper::setOrderStatus([
                    'order_id'      => $order->id,
                    'order_item_id' => 0,
                    'status'        => OrderStatusList::$cancelled,
                    'created_by'    => auth()->user()->id,
                    'user_type'     => OrderStatus::$userTypeAdmin,
                ]);
            }

            DB::commit();
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('admin_cancel_error: ' . $e->getMessage());
            return CommonHelper::responseError('something_went_wrong');
        }

        $order = Order::with('items')->find($order->id);
        try {
            dispatch(function () use ($order, $cancelledItems) {
                if (!empty($cancelledItems)) {
                    // One message for the whole action, however many items it covered.
                    foreach (CommonHelper::groupItemsForNotify($cancelledItems) as $group) {
                        $proxy = CommonHelper::notifyGroupItem($group);
                        if (!$proxy) {
                            continue;
                        }
                        CommonHelper::sendMailOrderStatus($proxy, false, 'order_item_status_update');
                        CommonHelper::sendSmsOrderStatus($proxy, OrderStatusList::$cancelled);
                        CommonHelper::sendNotificationOrderStatus($proxy, 'order_item_status_update');
                    }
                } else {
                    // Whole (quick) order.
                    CommonHelper::sendNotificationOrderStatus($order);
                    CommonHelper::sendMailOrderStatus($order, false, 'order_status_update');
                    CommonHelper::sendSmsOrderStatus($order, OrderStatusList::$cancelled);
                    CommonHelper::sendOrderNotificationsToAdmins($order, 'order_status_update', $order->delivery_boy_id ?? null);
                }
            })->afterResponse();
        } catch (\Exception $e) {
            Log::error('admin_cancel_notification_error: ' . $e->getMessage());
        }

        return CommonHelper::responseSuccessWithData('order_cancelled_successfully', $order);
    }

    /** Full-refund + cancel a single order item (admin). */
    private function adminCancelItem($order, $orderItem, $reason = null): void
    {
        $isCod = $order->payment_method === Transaction::$paymentTypeCod;

        $refund = $isCod
            ? floatval($orderItem->wallet_balance)
            : floatval($orderItem->final_total) + floatval($orderItem->wallet_balance);

        if ($refund > 0) {
            CommonHelper::addUserWalletBalance($refund, $order->user_id, $order->country_id);
            CommonHelper::addWalletTransaction($order->id, $orderItem->id, $order->user_id, 'credit', $refund, 'wallet_order_item_cancelled');
            CommonHelper::notifyWalletRefundCancelled($order, $orderItem, $refund);
        }

        $orderItem->refund_amount = $refund;
        $orderItem->active_status = OrderStatusList::$cancelled;
        $orderItem->cancellation_reason = $reason;
        $orderItem->canceled_at = now();
        $orderItem->save();

        CommonHelper::reverseOrderItemTax($orderItem);

        // Restock per-branch (PVSS).
        ProductHelper::restockStock($orderItem->product_variant_id, $orderItem->branch_id, (int) $orderItem->quantity);
        AddonHelper::moveOrderItemStock($orderItem, 'restock');

        // Reduce the order's outstanding totals by this item.
        $order->refund_amount = floatval($order->refund_amount) + $refund;
        $order->remaining_total = max(0, floatval($order->remaining_total) - floatval($orderItem->sub_total));
        $order->remaining_final = max(0, floatval($order->remaining_final) - $refund);
        if (floatval($order->wallet_balance) > 0) {
            $order->wallet_balance = max(0, floatval($order->wallet_balance) - floatval($orderItem->wallet_balance));
        }
        $order->save();
    }

    public function assignDeliveryBoy(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_id' => 'required',
            'delivery_boy_id' => 'required',
        ], [
            'order_id.required' => 'The Order id field is required.',
            'delivery_boy_id.required' => 'The delivery boy field is required.',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // delivery_boy_id = 0 unassigns the order.
        if ((int) $request->delivery_boy_id === 0) {
            $order = Order::find($request->order_id);
            if (!$order) {
                return CommonHelper::responseError('Order Not found!');
            }
            if ($order->isPickup()) {
                return CommonHelper::responseError('delivery_boy_cannot_be_assigned_to_pickup_orders');
            }
            if (in_array((int) $order->active_status, [OrderStatusList::$cancelled, OrderStatusList::$returned, OrderStatusList::$delivered], true)) {
                return CommonHelper::responseError('delivery_boy_cannot_be_changed_for_this_order');
            }
            $order->delivery_boy_id = 0;
            $order->save();
            return CommonHelper::responseSuccess('updated_successfully');
        }

        $deliveryBoy = DeliveryBoy::find($request->delivery_boy_id);
        if (empty($deliveryBoy)) {
            return CommonHelper::responseSuccess('delivery_boy_not_found');
        }
        $order = Order::find($request->order_id);

        // A delivery boy may only serve orders in their own country.
        if ($order && (int) $order->country_id !== (int) $deliveryBoy->country_id) {
            return CommonHelper::responseError('delivery_boy_country_mismatch');
        }
        if ($order && $order->isPickup()) {
            return CommonHelper::responseError('delivery_boy_cannot_be_assigned_to_pickup_orders');
        }

        if ($order) {
            // Delivery boy can't be changed once the order is delivered / cancelled / returned.
            if (in_array((int) $order->active_status, [OrderStatusList::$cancelled, OrderStatusList::$returned, OrderStatusList::$delivered], true)) {
                return CommonHelper::responseError('delivery_boy_cannot_be_changed_for_this_order');
            }
            if ($order->delivery_boy_id == $request->delivery_boy_id) {
                return CommonHelper::responseError('this_delivery_boy_already_assign');
            }
            if ($order->active_status == OrderStatusList::$paymentPending) {
                return CommonHelper::responseError('cannot_assign_delivery_boy_while_payment_pending');
            }

            $final_total = floatval($order->total);

            $bonus_type = $deliveryBoy->bonus_type;
            $bonus_details['final_total'] = $final_total;
            $bonus_details['bonus_type'] = $bonus_type;
            $bonus_amount = 0;
            if ($bonus_type == DeliveryBoy::$bonusCommission) {

                $bonus_percentage = floatval($deliveryBoy->bonus_percentage);
                $bonus_min_amount = floatval($deliveryBoy->bonus_min_amount);
                $bonus_max_amount = floatval($deliveryBoy->bonus_max_amount);

                $bonus_amount = floatval(($final_total * $bonus_percentage) / 100);

                if ($bonus_amount < $bonus_min_amount && $bonus_min_amount != 0) {
                    $bonus_amount = $bonus_min_amount;
                }

                if ($bonus_amount > $bonus_max_amount && $bonus_max_amount != 0) {
                    $bonus_amount = $bonus_max_amount;
                }

                $bonus_details['bonus_type_name'] = DeliveryBoy::$commission;
                $bonus_details['bonus_percentage'] = $bonus_percentage;
                $bonus_details['bonus_min_amount'] = $bonus_min_amount;
                $bonus_details['bonus_max_amount'] = $bonus_max_amount;
                $bonus_details['bonus_amount'] = $bonus_amount;
            } else {
                $bonus_details['bonus_type_name'] = DeliveryBoy::$fixed;
            }
            $bonus_details['bonus_amount'] = $bonus_amount;

            $order->delivery_boy_bonus_details = $bonus_details;
            $order->delivery_boy_bonus_amount = $bonus_amount;

            $order->delivery_boy_id = $request->delivery_boy_id;
            $order->save();

            try {
                dispatch(function () use ($order) {
                    CommonHelper::sendNotificationOrderAssignDeliveryBoy($order);
                    CommonHelper::sendMailOrderStatus($order, true);
                })->afterResponse();
            } catch (\Exception $e) {
                Log::error("Delivery boy assigned on order Send mail error :", [$e->getMessage()]);
            }

            return CommonHelper::responseSuccess('delivery_boy_assigned_successfully_for_this_order');
        } else {
            return CommonHelper::responseError('order_not_found');
        }
    }

    /** Bonus details + amount for a delivery boy over a base total (commission/fixed). */
    private function deliveryBoyBonus(DeliveryBoy $deliveryBoy, float $baseTotal): array
    {
        $bonus_type = $deliveryBoy->bonus_type;
        $bonus_details = ['final_total' => $baseTotal, 'bonus_type' => $bonus_type];
        $bonus_amount = 0;
        if ($bonus_type == DeliveryBoy::$bonusCommission) {
            $bonus_percentage = floatval($deliveryBoy->bonus_percentage);
            $bonus_min_amount = floatval($deliveryBoy->bonus_min_amount);
            $bonus_max_amount = floatval($deliveryBoy->bonus_max_amount);
            $bonus_amount = floatval(($baseTotal * $bonus_percentage) / 100);
            if ($bonus_amount < $bonus_min_amount && $bonus_min_amount != 0) {
                $bonus_amount = $bonus_min_amount;
            }
            if ($bonus_amount > $bonus_max_amount && $bonus_max_amount != 0) {
                $bonus_amount = $bonus_max_amount;
            }
            $bonus_details['bonus_type_name'] = DeliveryBoy::$commission;
            $bonus_details['bonus_percentage'] = $bonus_percentage;
            $bonus_details['bonus_min_amount'] = $bonus_min_amount;
            $bonus_details['bonus_max_amount'] = $bonus_max_amount;
        } else {
            $bonus_details['bonus_type_name'] = DeliveryBoy::$fixed;
        }
        $bonus_details['bonus_amount'] = $bonus_amount;
        return [$bonus_details, $bonus_amount];
    }

    /** Assign (or unassign with 0) a delivery boy to a single ecommerce order item. */
    public function assignDeliveryBoyToItem(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_item_id'   => 'required|integer',
            'delivery_boy_id' => 'required|integer',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $result = $this->assignDeliveryBoyToSingleItem((int) $request->order_item_id, (int) $request->delivery_boy_id);

        return $result === true
            ? CommonHelper::responseSuccess('delivery_boy_assigned_successfully_for_this_order')
            : CommonHelper::responseError($result);
    }

    /** Assign one delivery boy to several ecommerce items at once. No notification is sent on assignment. */
    public function assignDeliveryBoyToItems(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_item_ids'  => 'required',
            'delivery_boy_id' => 'required|integer',
        ], ['order_item_ids.required' => 'The Item id field is required.']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $ids = is_array($request->order_item_ids)
            ? $request->order_item_ids
            : explode(',', (string) $request->order_item_ids);
        $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));
        if (empty($ids)) {
            return CommonHelper::responseError('order_item_not_found');
        }

        foreach ($ids as $id) {
            $result = $this->assignDeliveryBoyToSingleItem($id, (int) $request->delivery_boy_id);
            if ($result !== true) {
                // Items assigned before this point keep their rider — the assignment is
                // saved per item. Report the one that stopped the run.
                return CommonHelper::responseError($result);
            }
        }

        return CommonHelper::responseSuccess('delivery_boy_assigned_successfully_for_this_order');
    }

    private function deliveryMethodNotAllowed($order, string $method, $item = null): ?string
    {
        $methods = CommonHelper::deliveryMethodsForZone(Zone::find($order->zone_id ?? 0));
        if (in_array($method, $methods, true)) {
            return null;
        }

        // Already fulfilled this way: the door was open when it was used, and it stays so.
        $alreadyUsed = $item && match ($method) {
            Zone::DELIVERY_BOY             => (int) $item->delivery_boy_id > 0,
            Zone::DELIVERY_MANUAL_TRACKING => !empty($item->tracking_id),
            default                        => false,
        };
        if ($alreadyUsed) {
            return null;
        }

        return $method === Zone::DELIVERY_BOY
            ? 'this_zone_does_not_deliver_with_a_delivery_boy'
            : 'this_zone_does_not_use_manual_tracking';
    }

    /**
     * @return true|string  true, or the error message key
     */
    private function assignDeliveryBoyToSingleItem(int $orderItemId, int $deliveryBoyId)
    {
        $request = new Request(['order_item_id' => $orderItemId, 'delivery_boy_id' => $deliveryBoyId]);
        $item = OrderItem::find($orderItemId);
        if (!$item) {
            return 'order_item_not_found';
        }
        $order = Order::find($item->order_id);
        if (!$order || $order->channel !== 'ecommerce') {
            return 'item_assignment_only_for_ecommerce_orders';
        }

        if ($blocked = $this->deliveryMethodNotAllowed($order, Zone::DELIVERY_BOY, $item)) {
            return $blocked;
        }
        if ($order->isPickup()) {
            return 'delivery_boy_cannot_be_assigned_to_pickup_orders';
        }
        // No fulfillment before payment: an unpaid order/item can't get a delivery boy.
        if ((int) $item->active_status === OrderStatusList::$paymentPending
            || (int) $order->active_status === OrderStatusList::$paymentPending) {
            return 'cannot_assign_delivery_boy_while_payment_pending';
        }
        if (in_array((int) $item->active_status, [OrderStatusList::$cancelled, OrderStatusList::$returned, OrderStatusList::$delivered], true)) {
            return 'delivery_boy_cannot_be_changed_for_this_item';
        }

        // Block if delivery boy already assigned — locked once set.
        if ((int) $item->delivery_boy_id > 0) {
            return 'fulfillment_already_set_with_delivery_boy';
        }

        // Block if courier tracking is already set (locked once set).
        if (!empty($item->tracking_id)) {
            return 'fulfillment_already_set_with_courier_tracking';
        }

        // A delivery boy may only serve items in their own country.
        $assignBoy = DeliveryBoy::find($request->delivery_boy_id);
        if (!$assignBoy || (int) $order->country_id !== (int) $assignBoy->country_id) {
            return 'delivery_boy_country_mismatch';
        }

        $deliveryBoy = DeliveryBoy::find($request->delivery_boy_id);
        if (!$deliveryBoy) {
            return 'delivery_boy_not_found';
        }
        if ((int) $item->delivery_boy_id === (int) $request->delivery_boy_id) {
            return 'this_delivery_boy_already_assign';
        }

        // Bonus is computed on the item's own payable total.
        [$bonus_details, $bonus_amount] = $this->deliveryBoyBonus($deliveryBoy, floatval($item->final_total));
        $item->delivery_boy_bonus_details = $bonus_details;
        $item->delivery_boy_bonus_amount = $bonus_amount;
        $item->delivery_boy_id = $request->delivery_boy_id;
        // Assigning a delivery boy clears any courier tracking.
        $item->courier_agency = null;
        $item->tracking_id    = null;
        $item->tracking_url   = null;
        $item->save();

        return true;
    }

    public function updateItemDeliveryEstimate(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_item_id'           => 'required|integer',
            'estimated_delivery_date' => 'required|date',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $orderItem = OrderItem::find($request->order_item_id);
        if (!$orderItem) {
            return CommonHelper::responseError('Order Item Not found.');
        }

        $order = Order::find($orderItem->order_id);
        if (!$order || $order->channel !== 'ecommerce') {
            return CommonHelper::responseError('delivery_estimate_is_for_ecommerce_orders_only');
        }
        if ($order->isPickup()) {
            return CommonHelper::responseError('delivery_estimate_not_applicable_for_pickup_orders');
        }
        if (in_array((int) $orderItem->active_status, [OrderStatusList::$delivered, OrderStatusList::$cancelled, OrderStatusList::$returned], true)) {
            return CommonHelper::responseError('delivery_estimate_cannot_be_changed_now');
        }

        $previous = $orderItem->estimated_delivery_date
            ? Carbon::parse($orderItem->estimated_delivery_date)->toDateString()
            : null;
        $next = Carbon::parse($request->estimated_delivery_date)->toDateString();

        $orderItem->estimated_delivery_date = $next;
        $orderItem->save();

        // Silence is the right answer when nothing actually moved.
        if ($previous !== $next) {
            CommonHelper::notifyOrderItemDeliveryEstimate($orderItem, $previous);
        }

        return CommonHelper::responseSuccess('delivery_estimate_updated_successfully');
    }

    public function updateItemsStatus(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'ids' => 'required',
            'status_id' => 'required',
        ], [
            'ids.required' => 'The Item id field is required.',
            'status_id.required' => 'The status field is required.',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $ids = explode(",", $request->ids);

        // Quick orders carry one status for the whole order — block per-item updates;
        // admin must use the order-level status update instead.
        $quickOrderItem = OrderItem::join('orders', 'order_items.order_id', '=', 'orders.id')
            ->whereIn('order_items.id', $ids)
            ->where('orders.channel', 'quick')
            ->exists();
        if ($quickOrderItem) {
            return CommonHelper::responseError(__('quick_order_status_managed_at_order_level'));
        }
        // So does a self-pickup order, whatever its channel: one branch, one status.
        $pickupOrderItem = OrderItem::join('orders', 'order_items.order_id', '=', 'orders.id')
            ->whereIn('order_items.id', $ids)
            ->where('orders.delivery_type', 'pickup')
            ->exists();
        if ($pickupOrderItem) {
            return CommonHelper::responseError(__('pickup_orders_are_updated_order_wise'));
        }

        // No status change while payment is still pending (item- or order-level).
        $paymentPending = OrderItem::join('orders', 'order_items.order_id', '=', 'orders.id')
            ->whereIn('order_items.id', $ids)
            ->where(function ($q) {
                $q->where('order_items.active_status', OrderStatusList::$paymentPending)
                    ->orWhere('orders.active_status', OrderStatusList::$paymentPending);
            })
            ->exists();
        if ($paymentPending) {
            return CommonHelper::responseError('cannot_update_status_while_payment_pending');
        }

        $override = $request->boolean('override_courier');
        $courierOwned = OrderItem::whereIn('id', $ids)
            ->whereNotNull('courier_shipment_id')
            ->where('active_status', '!=', OrderStatusList::$cancelled)
            ->pluck('id');
        if ($courierOwned->isNotEmpty() && !$override && (int) $request->status_id !== OrderStatusList::$cancelled) {
            return CommonHelper::responseError('courier_updates_this_item_status');
        }

        /* Out-for-delivery means somebody is carrying it: a rider, a typed-in waybill, or
           a courier that already holds the parcel under a booking. */
        if ((int) $request->status_id === OrderStatusList::$outForDelivery) {
            foreach ($ids as $id) {
                $oi = OrderItem::find($id);
                if ($oi && (int) $oi->delivery_boy_id === 0 && empty($oi->tracking_id) && empty($oi->courier_shipment_id)) {
                    return CommonHelper::responseError('please_assign_a_delivery_boy_or_set_courier_tracking_first');
                }
            }
        }

        if ($override && $courierOwned->isNotEmpty()) {
            Log::info('[Shipping] admin ' . (auth()->id() ?: '-') . ' set status ' . (int) $request->status_id
                . ' by hand on courier-held items: ' . $courierOwned->implode(','));
        }

        $affectedOrderIds = [];
        $updatedItemIds = [];
        foreach ($ids as $key => $id) {
            $orderItem = OrderItem::find($id);
            $orderItem->active_status = $request->status_id;
            $orderItem->save();

            if (in_array((int) $request->status_id, [OrderStatusList::$cancelled, OrderStatusList::$returned], true)) {
                CommonHelper::reverseOrderItemTax($orderItem);
            }
            $affectedOrderIds[$orderItem->order_id] = true;
            $updatedItemIds[] = (int) $id;

            $orderStatus = array();
            $orderStatus["order_id"] = $orderItem->order_id;
            $orderStatus["order_item_id"] = $id;
            $orderStatus["status"] = $request->status_id;
            $orderStatus["created_by"] = auth()->user()->id;
            $orderStatus["user_type"] = OrderStatus::$userTypeAdmin;
            CommonHelper::setOrderStatus($orderStatus);

            // Delivered → credit the assigned delivery boy's bonus + COD cash (once).
            if ((int) $request->status_id === OrderStatusList::$delivered) {
                CommonHelper::creditOrderItemDelivery($orderItem->fresh());
            }
        }
        // Ecommerce order status follows its items (all delivered → delivered, etc).
        foreach (array_keys($affectedOrderIds) as $oid) {
            CommonHelper::syncEcommerceOrderStatus($oid);

            // Panel + FCM notification to admins/boy for each affected order.
            $notifyOrder = Order::with('items')->find($oid);
            if ($notifyOrder) {
                try {
                    dispatch(function () use ($notifyOrder) {
                        CommonHelper::sendOrderNotificationsToAdmins($notifyOrder, 'order_status_update', $notifyOrder->delivery_boy_id ?? null);
                    })->afterResponse();
                } catch (\Exception $e) {
                    Log::error("updateItemsStatus admin notification error: " . $e->getMessage());
                }
            }
        }

        // Customer push + SMS + mail — ONE message per order per action, not one per
        // item: a bulk update of five items must not fire five pushes. The group's items
        // travel as a single stand-in carrying "First item +4 more" (see notifyGroupItem).
        try {
            dispatch(function () use ($updatedItemIds) {
                foreach (CommonHelper::groupItemsForNotify($updatedItemIds) as $group) {
                    $proxy = CommonHelper::notifyGroupItem($group);
                    if (!$proxy) {
                        continue;
                    }
                    CommonHelper::sendNotificationOrderStatus($proxy, 'order_item_status_update');
                    CommonHelper::sendSmsOrderStatus($proxy, $proxy->active_status);
                    // Not SendEmailJob: it re-fetches the model by id, which would drop
                    // the group's rewritten name and totals.
                    CommonHelper::sendMailOrderStatus($proxy, false, 'order_item_status_update');
                }
            })->afterResponse();
        } catch (\Exception $e) {
            Log::error("updateItemsStatus customer notification error: " . $e->getMessage());
        }

        return CommonHelper::responseSuccess('order_updated_successfully');
    }

    /**
     * Cancel one item, or several at once with the same reason.
     *
     * Bulk is a loop over the single-item path — each item's refund, restock and tax
     * reversal are proportional to what is still live at that moment, so they have to
     * settle one after another. Only the customer notification is grouped: one message
     * for the whole action instead of one per item.
     */
    public function cancelOrderItems(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_item_ids' => 'required',
            'cancellation_reason' => 'required|string',
        ], ['order_item_ids.required' => 'The Item id field is required.']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $ids = is_array($request->order_item_ids)
            ? $request->order_item_ids
            : explode(',', (string) $request->order_item_ids);
        $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));
        if (empty($ids)) {
            return CommonHelper::responseError('order_item_not_found');
        }

        // Quick orders cancel order-wise: the first item takes its siblings with it, so
        // a later id in the same run is legitimately already cancelled — not an error.
        $cascaded = OrderItem::whereIn('id', $ids)->pluck('order_id', 'id')->all();
        $touchedOrders = [];

        $cancelled = [];
        foreach ($ids as $id) {
            $result = $this->cancelSingleOrderItem($id, (string) $request->cancellation_reason);
            if ($result === 'order_item_is_already_cancelled'
                && in_array((int) ($cascaded[$id] ?? 0), $touchedOrders, true)) {
                $cancelled[] = $id;
                continue;
            }
            if ($result !== true) {
                // Items cancelled before this point stay cancelled — their refunds have
                // already settled. Report which one stopped the run.
                if (!empty($cancelled)) {
                    $this->notifyItemsCancelled($cancelled);
                }
                return CommonHelper::responseError($result);
            }
            $touchedOrders[] = (int) ($cascaded[$id] ?? 0);
            $cancelled[] = $id;
        }

        $this->notifyItemsCancelled($cancelled);

        return CommonHelper::responseSuccess('order_cancelled_successfully');
    }

    /** Back-compat: the old single-item endpoint. */
    public function cancelOrderItem(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_item_id' => 'required|integer',
            'cancellation_reason' => 'required|string',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $result = $this->cancelSingleOrderItem((int) $request->order_item_id, (string) $request->cancellation_reason);
        if ($result !== true) {
            return CommonHelper::responseError($result);
        }
        $this->notifyItemsCancelled([(int) $request->order_item_id]);

        return CommonHelper::responseSuccess('order_cancelled_successfully');
    }

    /** One customer message for the whole cancel action (grouped per order). */
    private function notifyItemsCancelled(array $itemIds): void
    {
        if (empty($itemIds)) {
            return;
        }
        try {
            dispatch(function () use ($itemIds) {
                foreach (CommonHelper::groupItemsForNotify($itemIds) as $group) {
                    $proxy = CommonHelper::notifyGroupItem($group);
                    if (!$proxy) {
                        continue;
                    }
                    try {
                        CommonHelper::sendNotificationOrderStatus($proxy, 'order_item_status_update');
                    } catch (\Exception $e) {
                        Log::error('Cancel order item notification error: ' . $e->getMessage());
                    }
                    try {
                        CommonHelper::sendMailOrderStatus($proxy, false, 'order_item_status_update');
                    } catch (\Exception $e) {
                        Log::error('Cancel order item mail notification error: ' . $e->getMessage());
                    }
                    try {
                        CommonHelper::sendSmsOrderStatus($proxy, OrderStatusList::$cancelled);
                    } catch (\Exception $e) {
                        Log::error('Cancel order item SMS error: ' . $e->getMessage());
                    }
                }
            })->afterResponse();
        } catch (\Exception $e) {
            Log::error('Cancel order item notification dispatch error: ' . $e->getMessage());
        }
    }

    /**
     * Cancel a single item: refund, restock, tax reversal, order status.
     *
     * @return true|string  true, or the error message key
     */
    public function cancelItemReturnedToOrigin(int $orderItemId, string $reason)
    {
        return $this->cancelSingleOrderItem($orderItemId, $reason, true);
    }

    private function cancelSingleOrderItem(int $orderItemId, string $reason, bool $shipmentAlreadyClosed = false)
    {
        $request = new Request(['order_item_id' => $orderItemId, 'cancellation_reason' => $reason]);
        $order_item = OrderItem::find($orderItemId);

        if (empty($order_item)) {
            return 'order_item_not_found';
        }

        $order = Order::find($order_item->order_id);
        if (empty($order)) {
            return 'order_not_found';
        }

        if ($order->active_status == OrderStatusList::$cancelled || $order->active_status == OrderStatusList::$returned) {
            return 'order_is_already_cancelled_or_returned';
        }

        if ($order->active_status == OrderStatusList::$delivered) {
            return 'order_is_already_delivered';
        }

        if ($order_item->active_status == OrderStatusList::$cancelled) {
            return 'order_item_is_already_cancelled';
        }

        if ($order_item->active_status == OrderStatusList::$delivered || $order_item->active_status == OrderStatusList::$returned) {
            return 'order_item_cannot_be_cancelled';
        }

        if (!empty($order_item->courier_shipment_id) && !$shipmentAlreadyClosed) {
            $released = app(ShipmentService::class)->cancelShipment($order, [(int) $order_item->id]);
            if (empty($released['ok'])) {
                Log::warning("cancelSingleOrderItem: shipment still live for item {$order_item->id}: " . ($released['message'] ?? ''));

                return 'cancel_the_courier_shipment_first';
            }
        }

        $postStatus = OrderStatusList::$cancelled;

        DB::beginTransaction();
        try {
            if ($order->channel === 'quick') {
                // Quick = single-branch, one status. Cancelling any item cancels the
                // whole order: pre-cancel + restock siblings so the current item is the
                // "last item" and the full-order refund path settles everything once.
                $siblings = OrderItem::where('order_id', $order->id)
                    ->where('id', '!=', $order_item->id)
                    ->where('active_status', '!=', OrderStatusList::$cancelled)
                    ->get();
                foreach ($siblings as $sib) {
                    // Restock per-branch (PVSS); product_variants.stock removed.
                    ProductHelper::restockStock($sib->product_variant_id, $sib->branch_id, (int) $sib->quantity);
                    AddonHelper::moveOrderItemStock($sib, 'restock');
                    $sib->active_status = OrderStatusList::$cancelled;
                    $sib->cancellation_reason = $request->cancellation_reason;
                    $sib->canceled_at = now();
                    $sib->save();
                    CommonHelper::reverseOrderItemTax($sib);
                }
            }

            $itemNum = OrderItem::where("order_id", $order->id)->count();
            $lastItemNum = OrderItem::where("order_id", $order->id)
                ->where('active_status', '!=', OrderStatusList::$cancelled)
                ->count();

            if ($itemNum == 1 || $lastItemNum == 1) {
                $order_status = array();
                $order_status['order_id'] = $order->id;
                $order_status['order_item_id'] = $order_item->id;
                $order_status['status'] = $postStatus;
                $order_status['created_by'] = auth()->id() ?? 0;
                $order_status['user_type'] = OrderStatus::$userTypeAdmin;
                CommonHelper::setOrderStatus($order_status);
                $order->active_status = OrderStatusList::$cancelled;
                $order->promo_code_id = 0;
                $order->save();
                CommonHelper::reverseOrderChargeTax($order->id);
            }

            $user = User::find($order->user_id);
            $currentBalance = floatval($user->balance);

            // Only charges flagged is_refundable are refunded on cancel. Legacy charges
            // without the flag default to refundable (preserves old behaviour).
            $additional_charges = CommonHelper::refundableCharges($order->additional_charges);
            $additional_charges_total = array_sum(array_column($additional_charges, 'amount'));

            // Surge charges — same handling as additional charges.
            $surge_charges = CommonHelper::refundableCharges($order->surge_charges);
            $surge_charges_total = array_sum(array_column($surge_charges, 'charge'));

            $isLastItem = ($itemNum == 1 || $lastItemNum == 1);

            $isCod = ($order->payment_method === Transaction::$paymentTypeCod);
            $isPaymentPending = ($order->active_status == OrderStatusList::$paymentPending);

            $allItemsSubTotal = floatval(OrderItem::where('order_id', $order->id)->sum('sub_total'));
            $itemSubTotal = floatval($order_item->sub_total);
            $itemShare = ($allItemsSubTotal > 0) ? ($itemSubTotal / $allItemsSubTotal) : 0;

            $refundable = 0;
            $walletRefund = 0;

            if (!$isCod && !$isPaymentPending) {
                // Non-COD: customer already paid, refund item amount proportionally
                $refundable = $itemSubTotal;

                if (floatval($order->promo_discount ?? 0) > 0) {
                    $refundable -= floatval($order->promo_discount) * $itemShare;
                }

                if (floatval($order->delivery_charge ?? 0) > 0) {
                    $refundable += floatval($order->delivery_charge) * $itemShare;
                }

                if ($additional_charges_total > 0) {
                    $refundable += $additional_charges_total * $itemShare;
                }

                if ($surge_charges_total > 0) {
                    $refundable += $surge_charges_total * $itemShare;
                }
            }

            // Wallet refund: applies to COD and non-COD but not payment pending (wallet was deducted at order time)
            if (!$isPaymentPending && floatval($order->wallet_balance ?? 0) > 0) {
                if ($isLastItem) {
                    $walletRefund = floatval($order->wallet_balance);
                } else {
                    $activeSubTotal = floatval(OrderItem::where('order_id', $order->id)
                        ->where('active_status', '!=', OrderStatusList::$cancelled)
                        ->sum('sub_total'));
                    $walletShare = ($activeSubTotal > 0) ? ($itemSubTotal / $activeSubTotal) : 0;
                    $walletRefund = floatval($order->wallet_balance) * $walletShare;
                }
                $refundable += $walletRefund;
                $order->wallet_balance = floatval($order->wallet_balance) - $walletRefund;
            }

            $refundable = max(0, round($refundable, 2));

            // Update order totals
            if ($isLastItem) {
                $order->remaining_total = 0;
                $order->remaining_final = $isCod ? 0 : 0;
                $order->wallet_balance = 0;
            } else {
                $order->remaining_total = max(0, floatval($order->remaining_total) - $itemSubTotal);
                $nonWalletRefund = $refundable - $walletRefund;
                $order->remaining_final = max(0, floatval($order->remaining_final) - $nonWalletRefund);
            }

            // Process refund to wallet
            if ($refundable > 0) {
                $new_balance = $currentBalance + $refundable;
                CommonHelper::updateUserWalletBalance($new_balance, $order->user_id);
                CommonHelper::addWalletTransaction($order->id, $order_item->id, $order->user_id, 'credit', $refundable, 'wallet_order_item_cancelled');
                CommonHelper::notifyWalletRefundCancelled($order, $order_item, $refundable);
            }

            $order->save();

            $order_item->active_status = $postStatus;
            $order_item->cancellation_reason = $request->cancellation_reason;
            $order_item->canceled_at = now();
            $order_item->save();

            // Restock the cancelled item per-branch (PVSS).
            ProductHelper::restockStock($order_item->product_variant_id, $order_item->branch_id, (int) $order_item->quantity);
            AddonHelper::moveOrderItemStock($order_item, 'restock');

            // Ecommerce: order status follows its remaining items.
            CommonHelper::syncEcommerceOrderStatus($order);

            if (isset($order->promo_code) && $order->promo_code != null && isset($order->promo_discount) && $order->promo_discount != null) {
                $promo_code = explode("(", $order->promo_code);
                $promoCodeModel = PromoCode::where('promo_code', $promo_code[0])->first();
                if ($promoCodeModel && isset($promoCodeModel->minimum_order_amount) && $order->total < $promoCodeModel->minimum_order_amount) {
                    CommonHelper::updateOrderPromoCode($order->id, $order->promo_discount);
                }
            }

            DB::commit();

            // The caller notifies — one message per order for the whole cancel action.
            return true;
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error("Cancel order item error: " . $e->getMessage());
            return 'something_went_wrong';
        }
    }

    private function getBranchesWithTranslations(): array
    {
        $languageService = app(LanguageService::class);
        $defaultLang = $languageService->getDefaultLanguage();
        $defaultCode = $defaultLang ? $languageService->getLanguageCode($defaultLang->id) : 'en';
        $activeLangCodes = collect($languageService->getActiveLanguages())->pluck('code')->filter()->values()->all();

        $branches = Branch::select('id', 'name')
            ->where('status', 1)
            ->with('translations')
            ->orderBy('id', 'DESC')
            ->get();

        $result = [];
        foreach ($branches as $branch) {
            $nameByCode = [];
            $all = $branch->getAllActiveLanguageTranslations();
            foreach ($all as $t) {
                $code = $t['language_code'] ?? '';
                if ($code !== '') {
                    $nameByCode[$code] = trim((string) ($t['name'] ?? ''));
                }
            }
            $defaultName = $nameByCode[$defaultCode] ?? $branch->getAttributeValue('name') ?? '';
            $nameObj = (object) [];
            foreach ($activeLangCodes as $code) {
                $nameObj->{$code} = ($nameByCode[$code] ?? '') !== '' ? $nameByCode[$code] : $defaultName;
            }
            if ((array) $nameObj === []) {
                $nameObj = (object) ['en' => $branch->getAttributeValue('name') ?? ''];
            }
            $result[] = [
                'id' => $branch->id,
                'name' => $nameObj,
            ];
        }
        return $result;
    }

    private function getDeliveryBoysWithTranslations($countryId = null, $zoneId = null): array
    {
        $languageService = app(LanguageService::class);
        $defaultLang = $languageService->getDefaultLanguage();
        $defaultCode = $defaultLang ? $languageService->getLanguageCode($defaultLang->id) : 'en';
        $activeLangCodes = collect($languageService->getActiveLanguages())->pluck('code')->filter()->values()->all();

        // Active riders serving this order's zone. Zone is the tighter constraint;
        // country is kept for older rows whose zone hasn't been set yet.
        $deliveryBoys = DeliveryBoy::where('status', 1)
            ->when($countryId, fn ($q) => $q->where('country_id', $countryId))
            ->when($zoneId, fn ($q) => $q->where('zone_id', $zoneId))
            ->with('translations')->orderBy('id', 'DESC')->get();

        $result = [];
        foreach ($deliveryBoys as $db) {
            $nameByCode = [];
            $all = $db->getAllActiveLanguageTranslations();
            foreach ($all as $t) {
                $code = $t['language_code'] ?? '';
                if ($code !== '') {
                    $nameByCode[$code] = trim((string) ($t['name'] ?? ''));
                }
            }
            $defaultName = $nameByCode[$defaultCode] ?? $db->getAttributeValue('name') ?? '';
            $nameObj = (object) [];
            foreach ($activeLangCodes as $code) {
                $nameObj->{$code} = ($nameByCode[$code] ?? '') !== '' ? $nameByCode[$code] : $defaultName;
            }
            if ((array) $nameObj === []) {
                $nameObj = (object) ['en' => $db->getAttributeValue('name') ?? ''];
            }
            $result[] = [
                'id' => $db->id,
                'name' => $nameObj,
                'pending_order_count' => $db->pending_order_count ?? 0,
                'driving_license_url' => $db->driving_license_url ?? null,
                'national_identity_card_url' => $db->national_identity_card_url ?? null,
            ];
        }
        return $result;
    }

    /** Save (or clear) courier tracking details on an ecommerce order item. Clears delivery boy. */
    public function saveOrderTracking(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_item_id' => 'required|integer',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $result = $this->saveTrackingForSingleItem((int) $request->order_item_id, $request->all());

        return $result === true
            ? CommonHelper::responseSuccess('updated_successfully')
            : CommonHelper::responseError($result);
    }

    /**
     * One consignment covering several items: the same agency / tracking id / URL goes
     * on every selected item. No notification — tracking is not a status move.
     */
    public function saveOrderTrackingItems(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_item_ids' => 'required',
        ], ['order_item_ids.required' => 'The Item id field is required.']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $ids = is_array($request->order_item_ids)
            ? $request->order_item_ids
            : explode(',', (string) $request->order_item_ids);
        $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));
        if (empty($ids)) {
            return CommonHelper::responseError('order_item_not_found');
        }

        foreach ($ids as $id) {
            $result = $this->saveTrackingForSingleItem($id, $request->all());
            if ($result !== true) {
                // Items saved before this point keep their tracking. Report the blocker.
                return CommonHelper::responseError($result);
            }
        }

        return CommonHelper::responseSuccess('updated_successfully');
    }

    /**
     * @param  array  $data  courier_agency, tracking_id, tracking_url
     * @return true|string   true, or the error message key
     */
    private function saveTrackingForSingleItem(int $orderItemId, array $data)
    {
        $item = OrderItem::find($orderItemId);
        if (!$item) {
            return 'order_item_not_found';
        }
        $order = Order::find($item->order_id);
        if (!$order || $order->channel !== 'ecommerce') {
            return 'item_assignment_only_for_ecommerce_orders';
        }
        if ($blocked = $this->deliveryMethodNotAllowed($order, Zone::DELIVERY_MANUAL_TRACKING, $item)) {
            return $blocked;
        }
        if ($order->isPickup()) {
            return 'courier_tracking_not_applicable_for_pickup_orders';
        }
        if (in_array((int) $item->active_status, [OrderStatusList::$cancelled, OrderStatusList::$returned, OrderStatusList::$delivered], true)) {
            return 'cannot_update_tracking_for_this_item';
        }

        $tid = trim((string) ($data['tracking_id'] ?? ''));

        // Block if delivery boy is already assigned (locked once set).
        if ($tid !== '' && (int) $item->delivery_boy_id > 0) {
            return 'fulfillment_already_set_with_delivery_boy';
        }

        $item->courier_agency = trim((string) ($data['courier_agency'] ?? '')) ?: null;
        $item->tracking_id    = $tid ?: null;
        $item->tracking_url   = trim((string) ($data['tracking_url'] ?? '')) ?: null;

        $item->save();

        return true;
    }
}
