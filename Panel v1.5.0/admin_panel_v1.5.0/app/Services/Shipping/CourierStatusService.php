<?php

namespace App\Services\Shipping;

use App\Plugins\Dto\TrackingUpdate;
use App\Helpers\CommonHelper;
use App\Http\Controllers\API\OrdersApiController;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatus;
use App\Models\OrderStatusList;
use App\Models\Setting;
use App\Models\Transaction;
use Illuminate\Support\Facades\Log;

/**
 * Applies a courier's tracking update to the order items it covers.
 *
 * Core owns order status, so a provider never writes one: it returns a TrackingUpdate in
 * our own vocabulary and this service decides what that means for the items.
 *
 * Two rules keep an automated feed from doing damage:
 *
 *  - **forward only** — a carrier that re-sends "in transit" after "out for delivery"
 *    cannot pull an item backwards, and an item that is cancelled, returned or still
 *    payment-pending is never touched;
 *  - **cancellations and RTOs are recorded, not acted on** — refunds, restocking and tax
 *    reversal belong to the admin's cancel/return flow, which asks for a reason and moves
 *    money. A webhook only writes the carrier's own label into the history.
 */
final class CourierStatusService
{
    /** Where the "who tells the customer" choice is stored. */
    public const NOTIFICATION_SETTING = 'courier_customer_notifications';

    /**
     * A courier sends its own SMS on pickup, transit and delivery. Notifying again from
     * here tells the customer the same thing twice, so by default we stay quiet until
     * the parcel is delivered — the one event that closes the order and settles COD.
     */
    public const NOTIFICATION_MODES = [
        'delivered_only' => 'notify_customer_on_delivery_only',
        'every_stage'    => 'notify_customer_on_every_courier_update',
        'never'          => 'never_notify_customer_about_courier_updates',
    ];

    public static function customerNotificationMode(): string
    {
        $mode = (string) Setting::get_value(self::NOTIFICATION_SETTING);

        return array_key_exists($mode, self::NOTIFICATION_MODES) ? $mode : 'delivered_only';
    }

    /** Where the "what happens when a parcel comes back" choice is stored. */
    public const RTO_SETTING = 'courier_rto_action';

    /**
     * A parcel the courier could not deliver comes back to the branch. The goods are on the
     * shelf again and a prepaid customer is owed their money, and both are true whether or
     * not anyone is watching the panel — so by default the line is settled the moment the
     * carrier confirms the parcel is back.
     *
     * A branch that wants to open the box first switches this to `notify_only`: the line is
     * flagged and the staff told, and nothing moves until someone cancels it by hand.
     */
    public const RTO_ACTIONS = [
        'settle'      => 'settle_the_line_when_a_parcel_comes_back',
        'notify_only' => 'only_flag_a_returned_parcel_for_staff',
    ];

    public static function rtoAction(): string
    {
        $action = (string) Setting::get_value(self::RTO_SETTING);

        return array_key_exists($action, self::RTO_ACTIONS) ? $action : 'settle';
    }

    /** order_id => Order, so a multi-item update reads the parent once. */
    private array $orders = [];


    /** The item status a carrier stage means. */
    public function statusFor(string $trackingStatus): ?int
    {
        return match ($trackingStatus) {
            TrackingUpdate::CREATED, TrackingUpdate::PICKUP_DUE => OrderStatusList::$processed,
            TrackingUpdate::IN_TRANSIT                          => OrderStatusList::$shipped,
            TrackingUpdate::OUT_FOR_DELIVERY                    => OrderStatusList::$outForDelivery,
            TrackingUpdate::DELIVERED                           => OrderStatusList::$delivered,
            default                                             => null, // rto / cancelled / unknown
        };
    }

    /**
     * Items an AWB covers.
     *
     * Core stores the AWB on each item it shipped (`order_items.tracking_id`), so a
     * webhook can be resolved without asking the plugin — which matters, because the
     * plugin may be disabled by the time a late update arrives.
     *
     * @return \Illuminate\Support\Collection<int,OrderItem>
     */
    public function itemsForAwb(string $awb)
    {
        $awb = trim($awb);

        return $awb === ''
            ? collect()
            : OrderItem::where('tracking_id', $awb)->get();
    }

    /**
     * @param  array<int,int>|null  $itemIds  restrict to these items; null = whatever the AWB covers
     * @return array{applied:int, status:?int, skipped:int, items:array<int,int>}
     */
    public function apply(TrackingUpdate $update, ?array $itemIds = null, ?int $adminId = null): array
    {
        $items = $itemIds
            ? OrderItem::whereIn('id', $itemIds)->get()
            : $this->itemsForAwb((string) $update->awb);

        if ($items->isEmpty()) {
            return ['applied' => 0, 'status' => null, 'skipped' => 0, 'items' => []];
        }

        $target = $this->statusFor($update->status);
        $applied = [];
        $skipped = 0;
        $orderIds = [];

        foreach ($items as $item) {
            $this->recordTracking($item, $update);
            $this->recordException($item, $update);

            /* The parcel is back on the shelf: return the stock, reverse the tax and
               refund a prepaid customer, down the same path an admin's cancel uses. */
            if ($update->status === TrackingUpdate::RTO_COMPLETED) {
                $this->settleReturnToOrigin($item, $update);
                continue;
            }

            if ($target === null || !$this->mayMoveTo($item, $target)) {
                // Nothing to record: order_status holds only a status id, so a repeat of
                // the same stage would add a row saying nothing. The carrier's own
                // wording goes to the log instead.
                $skipped++;
                Log::info("[Shipping] item {$item->id}: " . $this->historyNote($update) . ' (no status change)');
                continue;
            }

            $item->active_status = $target;
            $item->save();

            $this->recordHistory($item, $target, $update, $adminId);

            if ($target === OrderStatusList::$delivered) {
                // Credits the assigned delivery boy's bonus / COD cash when there is one;
                // a courier shipment has none, and the helper is a no-op then.
                CommonHelper::creditOrderItemDelivery($item->fresh());
            }

            $applied[] = (int) $item->id;
            $orderIds[$item->order_id] = true;
        }

        foreach (array_keys($orderIds) as $orderId) {
            CommonHelper::syncEcommerceOrderStatus($orderId);
            $this->settleCodOnDelivery($orderId);
        }

        if ($applied && $this->mayNotifyCustomer($target)) {
            $this->notify($applied);
        }

        return ['applied' => count($applied), 'status' => $target, 'skipped' => $skipped, 'items' => $applied];
    }

    /**
     * A courier collected the cash, so close the order's balance.
     *
     * Only once the whole order is delivered: a COD order part-shipped in two parcels is
     * paid in full at the last doorstep, not twice. The writer is idempotent, so a
     * replayed webhook or a second parcel's delivery adds nothing.
     */
    private function settleCodOnDelivery(int $orderId): void
    {
        $order = Order::find($orderId);
        if (!$order || (int) $order->active_status !== OrderStatusList::$delivered) {
            return;
        }
        if ((string) $order->payment_method !== (string) Transaction::$paymentTypeCod) {
            return;
        }

        CommonHelper::recordCodCollection($order, 'cod_collected_by_courier');
    }

    /**
     * A parcel that came back, settled like the cancellation it is.
     *
     * Reuses the panel's own cancel path rather than repeating its arithmetic: refunds,
     * restocking, tax reversal, promo recalculation and the order's own status all behave
     * exactly as they do when an admin cancels the line, which is the only way the two can
     * be guaranteed not to drift. Idempotent, because that path refuses a line that is
     * already cancelled — so a replayed webhook settles nothing twice.
     */
    private function settleReturnToOrigin(OrderItem $item, TrackingUpdate $update): void
    {
        if (self::rtoAction() === 'notify_only') {
            return;   // flagged by recordException(); a human decides the rest
        }

        $terminal = [OrderStatusList::$cancelled, OrderStatusList::$returned];
        if (in_array((int) $item->active_status, $terminal, true)) {
            return;
        }

        $reason = trim(__('returned_to_origin_by_courier') . ' — ' . ($update->carrierStatus ?: $update->status));

        try {
            $result = app(OrdersApiController::class)->cancelItemReturnedToOrigin((int) $item->id, $reason);
        } catch (\Throwable $e) {
            Log::error("[Shipping] RTO settlement failed for item {$item->id}: " . $e->getMessage());

            return;
        }

        if ($result !== true) {
            // The line keeps its exception flag, so the desk still sees it needs attention.
            Log::warning("[Shipping] RTO settlement refused for item {$item->id}: {$result}");

            return;
        }

        Log::info("[Shipping] item {$item->id} settled as returned to origin ({$reason})");
    }

    /* ---------------------------------------------------------------- internals */

    /**
     * An item may move only forward, and only while it is live.
     */
    private function mayMoveTo(OrderItem $item, int $target): bool
    {
        $current = (int) $item->active_status;

        if (in_array($current, [OrderStatusList::$cancelled, OrderStatusList::$returned, OrderStatusList::$paymentPending], true)) {
            return false;
        }
        if ($current === $target) {
            return false;
        }

        // OrderItem has no order() relation, so the parent is fetched once per order.
        $order = $this->orders[$item->order_id] ??= Order::find($item->order_id);
        $channel = $order->channel ?? 'ecommerce';
        $deliveryType = $order->delivery_type ?? 'delivery';

        return OrderStatusList::rank($target, $channel, $deliveryType)
            > OrderStatusList::rank($current, $channel, $deliveryType);
    }

    /**
     * A failed delivery attempt, written where the panel can act on it.
     *
     * The status is deliberately left alone — "out for delivery" is still true, and
     * there is no honest status for "the courier tried and could not". What changes is
     * that the line now carries the carrier's reason, so an admin sees it beside the
     * item and can ask for another attempt or a return. A later successful scan clears
     * it, because the problem resolved itself.
     */
    private function recordException(OrderItem $item, TrackingUpdate $update): void
    {
        $isException = in_array($update->status, [
            TrackingUpdate::UNDELIVERED,
            TrackingUpdate::RTO,
            TrackingUpdate::RTO_COMPLETED,
        ], true);

        if (!$isException && $item->courier_exception === null) {
            return;   // nothing was wrong, and nothing is wrong
        }

        $item->courier_exception = $isException
            ? mb_substr(trim(($update->carrierStatus ?: $update->status) . ($update->location ? ' — ' . $update->location : '')), 0, 180)
            : null;
        $item->save();

        if ($isException) {
            $this->notifyStaffOfException($item, $update);
        }
    }

    /**
     * Tell the staff, not the customer.
     *
     * The courier has already told the customer it could not deliver. What the customer
     * needs is somebody to act, which is why this reaches the panel rather than their
     * phone — and why it ignores the courier-notification setting, which governs
     * customer messages only.
     */
    private function notifyStaffOfException(OrderItem $item, TrackingUpdate $update): void
    {
        try {
            $order = $this->orders[$item->order_id] ??= Order::find($item->order_id);
            if (!$order) {
                return;
            }

            Log::warning(sprintf(
                '[Shipping] delivery exception on item %d (%s): %s',
                $item->id,
                $order->order_number,
                $update->carrierStatus ?: $update->status
            ));

            dispatch(function () use ($order) {
                CommonHelper::sendOrderNotificationsToAdmins($order, 'order_status_update', $order->delivery_boy_id ?? null);
            })->afterResponse();
        } catch (\Throwable $e) {
            Log::warning('[Shipping] could not raise the delivery exception: ' . $e->getMessage());
        }
    }

    /** Keep the AWB, courier name and tracking URL on the item current. */
    private function recordTracking(OrderItem $item, TrackingUpdate $update): void
    {
        $dirty = false;

        if ($update->awb && $item->tracking_id !== $update->awb) {
            $item->tracking_id = $update->awb;
            $dirty = true;
        }
        if ($update->courierName && $item->courier_agency !== $update->courierName) {
            $item->courier_agency = $update->courierName;
            $dirty = true;
        }
        if ($dirty) {
            $item->save();
        }
    }

    /** The same history row the panel writes, attributed to the system for a webhook. */
    private function recordHistory(OrderItem $item, int $status, TrackingUpdate $update, ?int $adminId): void
    {
        try {
            CommonHelper::setOrderStatus([
                'order_id'      => $item->order_id,
                'order_item_id' => $item->id,
                'status'        => $status,
                // created_by is NOT NULL; a system row carries 0, which is what
                // OrderStatus::createdByName already reads as "system".
                'created_by'    => $adminId ?: 0,
                // A webhook is nobody's click: user_type 0 is the system.
                'user_type'     => $adminId ? OrderStatus::$userTypeAdmin : OrderStatus::$userTypeScript,
            ]);
            Log::info("[Shipping] item {$item->id} -> status {$status}: " . $this->historyNote($update));
        } catch (\Throwable $e) {
            Log::warning('[Shipping] could not write status history: ' . $e->getMessage());
        }
    }

    private function historyNote(TrackingUpdate $update): string
    {
        $parts = array_filter([
            $update->courierName,
            $update->carrierStatus ?: $update->status,
            $update->location,
            $update->awb ? 'AWB ' . $update->awb : null,
        ]);

        return mb_substr(implode(' — ', $parts), 0, 250);
    }

    private function mayNotifyCustomer(int $status): bool
    {
        return match (self::customerNotificationMode()) {
            'every_stage' => true,
            'never'       => false,
            default       => $status === OrderStatusList::$delivered,
        };
    }

    /**
     * One customer message for the whole update, not one per item — the same grouping
     * the panel's bulk actions use.
     */
    private function notify(array $itemIds): void
    {
        try {
            dispatch(function () use ($itemIds) {
                foreach (CommonHelper::groupItemsForNotify($itemIds) as $group) {
                    $proxy = CommonHelper::notifyGroupItem($group);
                    if (!$proxy) {
                        continue;
                    }
                    CommonHelper::sendNotificationOrderStatus($proxy, 'order_item_status_update');
                    CommonHelper::sendSmsOrderStatus($proxy, $proxy->active_status);
                    CommonHelper::sendMailOrderStatus($proxy, false, 'order_item_status_update');
                }
            })->afterResponse();
        } catch (\Throwable $e) {
            Log::error('[Shipping] tracking notification error: ' . $e->getMessage());
        }
    }
}
