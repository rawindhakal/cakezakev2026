<?php

namespace App\Http\Controllers\API;

use App\Plugins\Registries\ShippingProviderRegistry;
use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusList;
use App\Services\Shipping\ShipmentService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * The dispatch desk: every ecommerce parcel waiting to go out, across all orders.
 *
 * The order drawer is the right place to decide *how* one order ships. It is the wrong
 * place to work through a morning's dispatch — nobody opens thirty orders to print
 * thirty labels. This list is the other half: one screen, filtered by branch and state,
 * with printing and tracking driven from a selection.
 *
 * It deliberately covers parcels that were never booked with a courier. Plenty of branches
 * hand over to a local rider or a courier they call themselves, and they still need a
 * stack of delivery receipts. So a row here is an order item that is ready to travel,
 * whether or not an plugin is involved.
 */
class ShipmentsApiController extends Controller
{
    /**
     * Rows a dispatch desk works from.
     *
     * The states are the questions someone actually asks in the morning: what is booked
     * but has no waybill, what is printed and waiting for the courier, what is moving,
     * what went wrong, and what has not been handed to anyone yet.
     */
    public const STATES = [
        'to_dispatch'      => 'not handed to anyone yet',
        'awaiting_waybill' => 'booked with the courier, waiting for a waybill',
        'ready_to_ship'    => 'has a waybill, not collected yet',
        'in_transit'       => 'on its way',
        'delivered'        => 'delivered',
        'exception'        => 'a delivery attempt failed',
    ];

    private const COURIER_ONLY_STATES = ['awaiting_waybill', 'exception'];

    public function index(Request $request)
    {
        /* One row per consignment, not per line. A parcel is what the desk handles: the
           items a carrier already holds under one shipment id, the ones sharing a waybill
           typed in by hand, the ones a rider took, and — for anything not yet handed over —
           the dispatchable lines of one order from one branch, which is precisely what would
           go into one box. */
        $groups = $this->groupedQuery($request)
            ->orderByDesc(DB::raw('MAX(order_items.id)'))
            ->skip(max(0, (int) $request->input('offset', 0)))
            ->take($perPage = min(100, max(10, (int) $request->input('per_page', 25))))
            ->get();

        $total = (int) DB::query()->fromSub($this->groupedQuery($request), 'consignments')->count();

        $items = $this->itemsOfGroups($request, $groups);

        $provider = app(ShippingProviderRegistry::class)->default('ecommerce');

        $data = $groups->map(function ($group) use ($items) {
            $lines = $items->get($this->groupKey($group), collect());
            $first = $lines->first() ?: $group;
            $address = CommonHelper::addressObject($first->order_address ?? '');

            /* The least advanced line sets the state: a parcel is only delivered once every
               item in it is, and an exception on any line is the whole parcel's problem. */
            $statuses = $lines->pluck('active_status')->map(fn ($s) => (int) $s);
            $exception = $lines->pluck('courier_exception')->filter()->first();

            return [
                // Identifies the parcel itself, which the panel needs to keep a row's
                // state (expanded, selected) across a refresh.
                'group_key'       => $this->groupKey($group),
                // Every action takes the whole consignment, so it carries every line's id.
                'order_item_ids'  => $lines->pluck('id')->map(fn ($id) => (int) $id)->values()->all(),
                'order_item_id'   => (int) $first->id,
                'order_id'        => (int) $group->order_id,
                'order_number'    => $first->order_number,
                'items'           => $lines->map(fn ($l) => [
                    'id'       => (int) $l->id,
                    'name'     => $l->product_name,
                    'quantity' => (float) $l->quantity,
                ])->values()->all(),
                'item_count'      => $lines->count(),
                'quantity'        => (float) $lines->sum('quantity'),
                'branch_name'      => $first->branch_name,
                'customer_name'   => $address['name'] ?: $first->customer_name,
                'city'            => ($address['city'] ?? '') ?: (string) ($first->address_city ?? ''),
                // The snapshot first, then the order's own copy for anything placed before
                // the snapshot carried postal parts.
                'pincode'         => ($address['pincode'] ?? '') ?: (string) ($first->delivery_pincode ?? ''),
                'payment_method'  => $first->payment_method,
                'currency'        => $first->currency,
                'final_total'     => round((float) $lines->sum('final_total'), 2),
                'status'          => $statuses->min() ?? (int) $first->active_status,
                'status_name'     => OrderStatusList::getTranslatedName((int) ($statuses->min() ?? $first->active_status)),
                'mixed_status'    => $statuses->unique()->count() > 1,
                'state'           => $this->stateOf((object) [
                    'courier_exception'   => $exception,
                    'active_status'       => $statuses->min() ?? (int) $first->active_status,
                    'courier_shipment_id' => $group->courier_shipment_id,
                    'tracking_id'         => $group->tracking_id,
                ]),
                'courier'          => $first->courier_agency,
                'courier_provider' => $first->courier_provider,
                'shipment_id'      => $group->courier_shipment_id,
                'awb'              => $group->tracking_id,
                'tracking_url'     => $first->tracking_url,
                'label_url'        => $first->courier_label_url,
                'exception'        => $exception,
                'delivery_boy'     => $first->delivery_boy_name,
                'estimated_delivery_date' => $first->estimated_delivery_date,
                'created_at'       => optional($first->created_at)->toDateTimeString(),
            ];
        })->values();

        return CommonHelper::responseWithData([
            'rows'      => $data,
            'total'     => $total,
            'per_page'  => $perPage,
            'offset'    => max(0, (int) $request->input('offset', 0)),
            'states'    => $this->visibleStates($request, $counts = $this->counts($request), $provider),
            'counts'    => $counts,
            'provider'  => $provider ? ['key' => $provider->key(), 'label' => $provider->label()] : null,
            'can_print_bulk' => $provider instanceof \App\Services\Shipping\PrintsShippingDocuments,
        ]);
    }

    /**
     * Courier labels for a selection that may span several orders.
     *
     * Grouped per order because a shipment belongs to one, and the carrier is asked once
     * per order — the URLs come back together so the desk opens one tab per sheet rather
     * than one per parcel.
     */
    public function labels(Request $request)
    {
        return $this->documents($request, 'labels');
    }

    public function manifest(Request $request)
    {
        return $this->documents($request, 'manifest');
    }

    /**
     * Delivery receipts for anything selected, courier or not.
     *
     * This is the part that serves a branch shipping without any plugin: one PDF, one
     * receipt per page, printed in the order the desk selected them.
     */
    public function receipts(Request $request)
    {
        $itemIds = $this->selection($request);
        if (empty($itemIds)) {
            return CommonHelper::responseError('please_select_at_least_one_item');
        }

        $items = $this->scopedItems($request, $itemIds);
        if ($items->isEmpty()) {
            return CommonHelper::responseError('please_select_at_least_one_item');
        }

        /* One receipt per parcel, matching what the list shows: the lines that travel
           together are printed together, so the rider signs once for the box rather than
           once per line inside it. */
        $receipts = [];
        foreach ($items->groupBy(fn ($item) => $this->groupKey($item)) as $parcel) {
            $data = CommonHelper::deliveryReceiptDataForItems($parcel);
            if ($data) {
                $receipts[] = $data;
            }
        }

        if (empty($receipts)) {
            return CommonHelper::responseError('nothing_to_print');
        }

        return CommonHelper::deliveryReceiptsPdf(
            $receipts,
            'batch-' . now()->format('Ymd-His'),
            $request->filled('size') ? (string) $request->input('size') : null
        );
    }

    /** Pull fresh tracking for a selection, for when a webhook was missed. */
    public function track(Request $request)
    {
        $itemIds = $this->selection($request);
        $items = $this->scopedItems($request, $itemIds)->filter(fn ($i) => $i->courier_shipment_id);
        if ($items->isEmpty()) {
            return CommonHelper::responseError('this_item_has_no_shipment_yet');
        }

        $service = app(ShipmentService::class);
        $updated = 0;

        // One call per parcel, not per line: items sharing an AWB share a journey.
        foreach ($items->groupBy('order_id') as $orderId => $group) {
            $order = Order::find($orderId);
            if (!$order) {
                continue;
            }
            foreach ($group->groupBy('courier_shipment_id') as $parcel) {
                $result = $service->track($order, $parcel->pluck('id')->map(fn ($i) => (int) $i)->all());
                $updated += !empty($result['ok']) ? 1 : 0;
            }
        }

        return CommonHelper::responseSuccessWithData('tracking_refreshed', ['parcels' => $updated]);
    }

    /** Ask the carrier to collect the selected parcels. */
    public function schedulePickup(Request $request)
    {
        if (shouldDemoMask()) {
            return CommonHelper::responseError('this_action_is_disabled_in_demo_mode');
        }

        $items = $this->scopedItems($request, $this->selection($request))
            ->filter(fn ($i) => $i->courier_shipment_id);
        if ($items->isEmpty()) {
            return CommonHelper::responseError('this_item_has_no_shipment_yet');
        }

        $service = app(ShipmentService::class);
        $booked = 0;

        foreach ($items->groupBy('order_id') as $orderId => $group) {
            $order = Order::find($orderId);
            if (!$order) {
                continue;
            }
            foreach ($group->groupBy('courier_shipment_id') as $parcel) {
                $result = $service->schedulePickup($order, $parcel->pluck('id')->map(fn ($i) => (int) $i)->all());
                $booked += !empty($result['ok']) ? 1 : 0;
            }
        }

        return $booked > 0
            ? CommonHelper::responseSuccessWithData('pickup_scheduled_successfully', ['parcels' => $booked])
            : CommonHelper::responseError('could_not_schedule_the_pickup');
    }

    /* ---------------------------------------------------------------- internals */

    /**
     * Ecommerce delivery lines only, scoped to the caller's branch.
     *
     * Self-pickup is excluded because nothing travels, and quick orders because they are
     * ridden out within the hour rather than dispatched.
     */
    private function baseQuery(Request $request)
    {
        $query = OrderItem::query()
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->leftJoin('branches', 'branches.id', '=', 'order_items.branch_id')
            ->leftJoin('users', 'users.id', '=', 'orders.user_id')
            ->leftJoin('delivery_boys', 'delivery_boys.id', '=', 'order_items.delivery_boy_id')
            // Only for the city of an older order, whose snapshot kept just a formatted line.
            ->leftJoin('user_addresses', 'user_addresses.id', '=', 'orders.address_id')
            ->where('orders.channel', 'ecommerce')
            ->where('orders.delivery_type', 'delivery')
            ->whereNull('order_items.deleted_at')
            // Cancelled and unpaid lines are not going anywhere.
            ->whereNotIn('order_items.active_status', [OrderStatusList::$paymentPending, OrderStatusList::$cancelled]);

        // EnsureBranchScope has already forced branch_id for a branch user.
        if ($request->filled('branch_id')) {
            $query->where('order_items.branch_id', (int) $request->input('branch_id'));
        }
        if ($request->filled('country_id')) {
            $query->where('orders.country_id', (int) $request->input('country_id'));
        }
        if ($request->filled('zone_id')) {
            $query->where('orders.zone_id', (int) $request->input('zone_id'));
        }

        if ($request->filled('search')) {
            $search = trim((string) $request->input('search'));
            $query->where(function ($q) use ($search) {
                $q->where('orders.order_number', 'like' , "%{$search}%")
                    ->orWhere('orders.delivery_pincode', 'like', "%{$search}%")
                    ->orWhere('order_items.tracking_id', 'like', "%{$search}%")
                    ->orWhere('order_items.product_name', 'like', "%{$search}%")
                    ->orWhere('users.name', 'like', "%{$search}%");
            });
        }

        if ($request->filled('from')) {
            $query->whereDate('orders.created_at', '>=', $request->input('from'));
        }
        if ($request->filled('to')) {
            $query->whereDate('orders.created_at', '<=', $request->input('to'));
        }

        $this->applyState($query, (string) $request->input('state', ''));

        return $query;
    }

    /**
     * The consignments themselves: one row per parcel, with the columns that define it.
     *
     * Items land in the same group when they belong to one order, leave one branch, and
     * share whatever already binds them — a carrier's shipment id, a hand-typed waybill,
     * or the rider carrying them. Lines with none of those are still one group per order
     * and branch, because that is the box they would go into.
     */
    private function groupedQuery(Request $request)
    {
        return $this->baseQuery($request)
            ->select([
                'order_items.order_id',
                'order_items.branch_id',
                'order_items.courier_shipment_id',
                'order_items.tracking_id',
                'order_items.delivery_boy_id',
                DB::raw('MAX(order_items.id) as newest_item_id'),
            ])
            ->groupBy(
                'order_items.order_id',
                'order_items.branch_id',
                'order_items.courier_shipment_id',
                'order_items.tracking_id',
                'order_items.delivery_boy_id',
            );
    }

    /** The key that decides which consignment a line belongs to. */
    private function groupKey($row): string
    {
        return implode('|', [
            (int) ($row->order_id ?? 0),
            (int) ($row->branch_id ?? 0),
            (string) ($row->courier_shipment_id ?? ''),
            (string) ($row->tracking_id ?? ''),
            (int) ($row->delivery_boy_id ?? 0),
        ]);
    }

    /**
     * Every line of the consignments on this page, in one query, keyed by group.
     *
     * The same filters run again so a line the desk filtered out cannot reappear inside a
     * group — a delivered item never joins a parcel still waiting to ship.
     */
    private function itemsOfGroups(Request $request, $groups)
    {
        if ($groups->isEmpty()) {
            return collect();
        }

        $lines = $this->baseQuery($request)
            ->whereIn('order_items.order_id', $groups->pluck('order_id')->unique()->all())
            ->orderBy('order_items.id')
            ->get([
                'order_items.id', 'order_items.order_id', 'order_items.product_name', 'order_items.quantity',
                'order_items.active_status', 'order_items.branch_id', 'order_items.delivery_boy_id',
                'order_items.courier_provider', 'order_items.courier_shipment_id', 'order_items.courier_label_url',
                'order_items.courier_exception', 'order_items.tracking_id', 'order_items.tracking_url',
                'order_items.courier_agency', 'order_items.final_total', 'order_items.estimated_delivery_date',
                'order_items.created_at',
                'orders.order_number', 'orders.payment_method', 'orders.address as order_address',
                'orders.delivery_pincode', 'orders.currency', 'orders.user_id',
                'branches.name as branch_name',
                'users.name as customer_name',
                'user_addresses.city as address_city',
                'delivery_boys.name as delivery_boy_name',
            ]);

        return $lines->groupBy(fn ($line) => $this->groupKey($line));
    }

    /** The state filters, expressed once so the list and the counts agree. */
    private function applyState($query, string $state): void
    {
        switch ($state) {
            case 'to_dispatch':
                // Nothing booked, nobody assigned: this is the pile to work through.
                $query->whereNull('order_items.courier_shipment_id')
                    ->whereNull('order_items.tracking_id')
                    ->where('order_items.delivery_boy_id', 0)
                    ->whereIn('order_items.active_status', [OrderStatusList::$received, OrderStatusList::$processed]);
                break;
            case 'awaiting_waybill':
                $query->whereNotNull('order_items.courier_shipment_id')->whereNull('order_items.tracking_id');
                break;
            case 'ready_to_ship':
                $query->whereNotNull('order_items.tracking_id')
                    ->whereIn('order_items.active_status', [OrderStatusList::$received, OrderStatusList::$processed]);
                break;
            case 'in_transit':
                $query->whereIn('order_items.active_status', [OrderStatusList::$shipped, OrderStatusList::$outForDelivery]);
                break;
            case 'delivered':
                $query->where('order_items.active_status', OrderStatusList::$delivered);
                break;
            case 'exception':
                $query->whereNotNull('order_items.courier_exception');
                break;
        }
    }

    /** What each state holds right now, for the tabs. */
    private function counts(Request $request): array
    {
        $counts = [];
        foreach (array_keys(self::STATES) as $state) {
            $scoped = $request->duplicate();
            $scoped->merge(['state' => $state]);
            $counts[$state] = (int) DB::query()->fromSub($this->groupedQuery($scoped), 'consignments')->count();
        }

        return $counts;
    }

    private function visibleStates(Request $request, array $counts, $provider): array
    {
        return array_values(array_filter(array_keys(self::STATES), function ($state) use ($counts, $provider) {
            if (!in_array($state, self::COURIER_ONLY_STATES, true)) {
                return true;
            }

            return $provider !== null || ($counts[$state] ?? 0) > 0;
        }));
    }

    /** Which state a row belongs to — the same rules as the filters, per row. */
    private function stateOf($row): string
    {
        if ($row->courier_exception) {
            return 'exception';
        }
        if ((int) $row->active_status === OrderStatusList::$delivered) {
            return 'delivered';
        }
        if (in_array((int) $row->active_status, [OrderStatusList::$shipped, OrderStatusList::$outForDelivery], true)) {
            return 'in_transit';
        }
        if ($row->courier_shipment_id && !$row->tracking_id) {
            return 'awaiting_waybill';
        }
        if ($row->tracking_id) {
            return 'ready_to_ship';
        }

        return 'to_dispatch';
    }

    private function selection(Request $request): array
    {
        $ids = $request->input('order_item_ids');
        $ids = is_array($ids) ? $ids : explode(',', (string) $ids);

        return array_values(array_unique(array_filter(array_map('intval', $ids))));
    }

    /**
     * The selected items, re-checked against the same scope the list uses.
     *
     * A branch user must not reach another branch's parcel by posting its id, and a
     * cancelled line must not print a receipt saying it is on its way.
     */
    private function scopedItems(Request $request, array $itemIds)
    {
        if (empty($itemIds)) {
            return collect();
        }

        $query = OrderItem::query()
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->whereIn('order_items.id', $itemIds)
            ->where('orders.channel', 'ecommerce')
            ->whereNotIn('order_items.active_status', [OrderStatusList::$paymentPending, OrderStatusList::$cancelled]);

        if ($request->filled('branch_id') && optional($request->user())->isBranchUser()) {
            $query->where('order_items.branch_id', (int) $request->input('branch_id'));
        }

        return $query->select('order_items.*')->get();
    }

    /** Labels and manifests, asked per order because a shipment belongs to one. */
    private function documents(Request $request, string $document)
    {
        $validator = Validator::make($request->all(), ['order_item_ids' => 'required']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $items = $this->scopedItems($request, $this->selection($request))
            ->filter(fn ($i) => $i->courier_shipment_id);

        if ($items->isEmpty()) {
            return CommonHelper::responseError('this_item_has_no_shipment_yet');
        }

        $service = app(ShipmentService::class);
        $urls = [];
        $failures = [];

        foreach ($items->groupBy('order_id') as $orderId => $group) {
            $order = Order::find($orderId);
            if (!$order) {
                continue;
            }

            $result = $service->documents($order, $group->pluck('id')->map(fn ($i) => (int) $i)->all(), $document);
            if (!empty($result['ok'])) {
                $urls[] = ['order_number' => $order->order_number, 'url' => $result['data']['url']];
            } else {
                $failures[] = $order->order_number . ': ' . __((string) $result['message']);
            }
        }

        if (empty($urls)) {
            return CommonHelper::responseError($failures ? implode(' ', array_slice($failures, 0, 3)) : 'label_is_not_available_yet');
        }

        return CommonHelper::responseSuccessWithData('success', [
            'documents' => $urls,
            // Partial success is normal — one carrier can refuse one order's label while
            // the rest print, and hiding that would send someone to a printer short.
            'failures'  => $failures,
        ]);
    }
}
