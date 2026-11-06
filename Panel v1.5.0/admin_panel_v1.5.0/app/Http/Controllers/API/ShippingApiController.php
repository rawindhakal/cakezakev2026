<?php

namespace App\Http\Controllers\API;

use App\Services\Shipping\AssignsWaybillOnBooking;
use App\Services\Shipping\ReportsAccountBalance;
use App\Plugins\Registries\ShippingProviderRegistry;
use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Services\Shipping\ShipmentService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;

/**
 * Courier shipping for the order drawer.
 *
 * Core endpoints, not an plugin's: the panel talks to these whichever courier is
 * installed, and with none installed every call answers "no provider" so the drawer
 * simply hides the option.
 *
 * Permission-wise this is part of updating an order, so it follows
 * `update_order_status` rather than inventing a permission of its own.
 */
class ShippingApiController extends Controller
{
    public function __construct(private ShipmentService $shipments) {}

    /** Which couriers this install has, if any. */
    public function providers(Request $request)
    {
        $registry = app(ShippingProviderRegistry::class);

        $providers = array_map(function (array $provider) use ($registry) {
            $instance = $registry->provider($provider['key']);

            $provider += [
                'assigns_waybill_on_booking' => !$instance instanceof AssignsWaybillOnBooking
                    || $instance->assignsWaybillOnBooking(),
            ];

            if (!$instance instanceof ReportsAccountBalance || !$provider['configured']) {
                return $provider + ['balance' => null, 'balance_currency' => null];
            }

            $balance = Cache::remember(
                'shipping:balance:' . $provider['key'],
                600,
                function () use ($instance) {
                    try {
                        return $instance->accountBalance();
                    } catch (\Throwable $e) {
                        // A balance nobody can read must never stop a booking.
                        Log::warning('[Shipping] account balance unavailable: ' . $e->getMessage());

                        return ['ok' => false, 'balance' => null, 'currency' => null, 'message' => null];
                    }
                }
            );

            return $provider + [
                'balance'          => $balance['ok'] ? $balance['balance'] : null,
                'balance_currency' => $balance['ok'] ? ($balance['currency'] ?? null) : null,
            ];
        }, $registry->describe());

        return CommonHelper::responseWithData(['providers' => $providers]);
    }

    /** What the ship dialog needs before it can ask for rates. */
    public function context(Request $request)
    {
        [$order, $itemIds, $error] = $this->target($request);
        if ($error) {
            return CommonHelper::responseError($error);
        }

        $result = $this->shipments->context($order, $itemIds, $this->overrides($request));

        // A blocking reason is still useful data — the dialog shows what to fix.
        return CommonHelper::responseWithData($result['data'] ?? []);
    }

    public function quote(Request $request)
    {
        [$order, $itemIds, $error] = $this->target($request);
        if ($error) {
            return CommonHelper::responseError($error);
        }

        $result = $this->shipments->quote($order, $itemIds, $request->input('provider'), $this->overrides($request));

        return $result['ok']
            ? CommonHelper::responseWithData($result['data'])
            : CommonHelper::responseError((string) $result['message']);
    }

    public function create(Request $request)
    {
        if (shouldDemoMask()) {
            return CommonHelper::responseError('this_action_is_disabled_in_demo_mode');
        }

        [$order, $itemIds, $error] = $this->target($request);
        if ($error) {
            return CommonHelper::responseError($error);
        }

        $result = $this->shipments->createShipment(
            $order,
            $itemIds,
            $request->input('courier_id'),
            $request->input('provider'),
            optional($request->user())->id,
            $this->overrides($request)
        );

        return $result['ok']
            ? CommonHelper::responseSuccessWithData($result['message'], $result['data'] ?? [])
            : CommonHelper::responseError($result['message']);
    }

    public function schedulePickup(Request $request)
    {
        return $this->simple($request, fn (Order $o, array $ids) => $this->shipments->schedulePickup($o, $ids));
    }

    public function label(Request $request)
    {
        return $this->simple($request, fn (Order $o, array $ids) => $this->shipments->label($o, $ids));
    }

    public function cancel(Request $request)
    {
        if (shouldDemoMask()) {
            return CommonHelper::responseError('this_action_is_disabled_in_demo_mode');
        }

        return $this->simple($request, fn (Order $o, array $ids) => $this->shipments->cancelShipment($o, $ids));
    }

    /**
     * A failed delivery: try again, or send it back.
     *
     * Both are outward instructions to a carrier, so demo mode blocks them like every
     * other write.
     */
    public function resolveException(Request $request)
    {
        if (shouldDemoMask()) {
            return CommonHelper::responseError('this_action_is_disabled_in_demo_mode');
        }

        $validator = Validator::make($request->all(), [
            'action'  => 'required|in:reattempt,return',
            'comment' => 'nullable|string|max:191',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        return $this->simple($request, fn (Order $o, array $ids) => $this->shipments->resolveException(
            $o,
            $ids,
            (string) $request->input('action'),
            $request->input('comment')
        ));
    }

    /** One label sheet for everything selected. */
    public function labels(Request $request)
    {
        return $this->simple($request, fn (Order $o, array $ids) => $this->shipments->documents($o, $ids, 'labels'));
    }

    /** The handover manifest for everything selected. */
    public function manifest(Request $request)
    {
        return $this->simple($request, fn (Order $o, array $ids) => $this->shipments->documents($o, $ids, 'manifest'));
    }

    public function track(Request $request)
    {
        return $this->simple($request, fn (Order $o, array $ids) => $this->shipments->track($o, $ids, optional($request->user())->id));
    }

    /**
     * The parcel the admin actually packed, when they corrected it.
     *
     * Bounded on both sides: a typo of 500 instead of 0.5 would be quoted, booked and
     * billed, and a zero would be rejected by the carrier with a message nobody can
     * read. Anything outside the range is ignored rather than clamped, so the computed
     * value is used and the field visibly did not take.
     */
    private function overrides(Request $request): array
    {
        $parcel = (array) $request->input('parcel', []);
        $out = [];

        $weight = (float) ($parcel['weight'] ?? 0);
        if ($weight > 0 && $weight <= 300) {
            $out['weight'] = $weight;
        }

        foreach (['length', 'breadth', 'height'] as $side) {
            $value = (float) ($parcel[$side] ?? 0);
            if ($value > 0 && $value <= 300) {
                $out[$side] = $value;
            }
        }

        return $out;
    }

    /* ---------------------------------------------------------------- helpers */

    private function simple(Request $request, callable $action)
    {
        [$order, $itemIds, $error] = $this->target($request);
        if ($error) {
            return CommonHelper::responseError($error);
        }

        $result = $action($order, $itemIds);

        if (!$result['ok']) {
            return CommonHelper::responseError((string) $result['message']);
        }

        return isset($result['data'])
            ? CommonHelper::responseSuccessWithData((string) $result['message'], $result['data'])
            : CommonHelper::responseSuccess((string) $result['message']);
    }

    /**
     * Resolve the order and the selected items, scoped to the caller's branch — a branch
     * user must not be able to ship another branch's parcel by guessing an id.
     *
     * @return array{0:?Order, 1:array<int,int>, 2:?string}
     */
    private function target(Request $request): array
    {
        $validator = Validator::make($request->all(), [
            'order_id'       => 'required|integer|exists:orders,id',
            'order_item_ids' => 'required',
        ]);
        if ($validator->fails()) {
            return [null, [], $validator->errors()->first()];
        }

        $order = Order::find($request->order_id);
        if (!$order) {
            return [null, [], 'order_not_found'];
        }

        $ids = $request->input('order_item_ids');
        $ids = is_array($ids) ? $ids : explode(',', (string) $ids);
        $ids = array_values(array_filter(array_map('intval', $ids)));

        if (empty($ids)) {
            return [null, [], 'please_select_at_least_one_item'];
        }

        // Branch scope: EnsureBranchScope has already forced branch_id onto the request for
        // a branch user, so honouring it here is enough.
        if ($request->filled('branch_id') && optional($request->user())->isBranchUser()) {
            $branchId = (int) $request->input('branch_id');
            $foreign = \App\Models\OrderItem::whereIn('id', $ids)->where('branch_id', '!=', $branchId)->exists();
            if ($foreign) {
                return [null, [], 'you_do_not_have_access_to_this_section'];
            }
        }

        return [$order, $ids, null];
    }
}
