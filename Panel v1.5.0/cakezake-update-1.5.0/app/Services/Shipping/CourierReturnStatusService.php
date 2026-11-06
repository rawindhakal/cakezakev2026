<?php

namespace App\Services\Shipping;

use App\Plugins\Dto\TrackingUpdate;
use App\Helpers\CommonHelper;
use App\Models\Order;
use App\Models\ReturnRequest;
use App\Models\ReturnStatusList;
use Illuminate\Support\Facades\Log;

/**
 * A reverse parcel's progress, written onto the return request.
 *
 * The mirror of CourierStatusService, and it stops in the same place: the courier says
 * where the goods are, and the refund stays a decision an admin makes after looking in
 * the box. Nothing here moves money — a webhook that refunded a return would pay out for
 * a parcel nobody has opened.
 *
 * Statuses only move forward, and only while the request is still live. A request a rider
 * is carrying is never touched, however many stray scans arrive.
 */
final class CourierReturnStatusService
{
    /** The return status a carrier's reverse stage means. */
    public function statusFor(string $trackingStatus): ?int
    {
        return match ($trackingStatus) {
            // Booked, and the courier is coming for it.
            TrackingUpdate::PICKUP_DUE       => ReturnStatusList::$rOutForPickup,
            // Collected: it is out of the customer's hands and travelling back.
            TrackingUpdate::IN_TRANSIT,
            TrackingUpdate::OUT_FOR_DELIVERY => ReturnStatusList::$rReceivedFromCustomer,
            // Dropped at the branch — the end of the courier's part.
            TrackingUpdate::DELIVERED        => ReturnStatusList::$rReturnToBranch,
            // created / undelivered / rto / cancelled say nothing about where the goods are.
            default                          => null,
        };
    }

    /** Return requests a reverse AWB covers. */
    public function requestsForAwb(string $awb)
    {
        $awb = trim($awb);

        return $awb === ''
            ? collect()
            : ReturnRequest::where('tracking_id', $awb)->whereNotNull('courier_shipment_id')->get();
    }

    /**
     * @param  array<int,int>|null  $returnIds  restrict to these requests; null = whatever the AWB covers
     * @return array{applied:int, status:?int, skipped:int, requests:array<int,int>}
     */
    public function apply(TrackingUpdate $update, ?array $returnIds = null): array
    {
        $requests = $returnIds
            ? ReturnRequest::whereIn('id', $returnIds)->get()
            : $this->requestsForAwb((string) $update->awb);

        if ($requests->isEmpty()) {
            return ['applied' => 0, 'status' => null, 'skipped' => 0, 'requests' => []];
        }

        $target = $this->statusFor($update->status);
        $applied = [];
        $skipped = 0;

        foreach ($requests as $return) {
            $this->recordException($return, $update);

            if ($target === null || !$this->mayMoveTo($return, $target)) {
                $skipped++;
                Log::info("[Shipping] return {$return->id}: " . ($update->carrierStatus ?: $update->status) . ' (no status change)');
                continue;
            }

            $return->status = $target;
            $return->save();

            // created_by 0: a carrier's scan has no admin behind it.
            CommonHelper::setReturnRequestStatus((int) $return->id, $target, 0, null);

            $applied[] = (int) $return->id;

            if ($this->mayNotifyCustomer($target)) {
                $this->notify($return);
            }
        }

        return ['applied' => count($applied), 'status' => $target, 'skipped' => $skipped, 'requests' => $applied];
    }

    /* ---------------------------------------------------------------- internals */

    /** Forward only, and never over a rider's work or a finished request. */
    private function mayMoveTo(ReturnRequest $return, int $target): bool
    {
        if ((int) $return->delivery_boy_id > 0) {
            return false;
        }

        $current = (int) $return->status;
        if (in_array($current, [ReturnStatusList::$rRejected, ReturnStatusList::$rRefundCompleted], true)) {
            return false;
        }

        return ReturnStatusList::rank($target) > ReturnStatusList::rank($current);
    }

    /**
     * A collection that failed, written where the panel can act on it.
     *
     * The status is left alone: "out for pickup" is still true, and there is no honest
     * status for "the courier went and came back empty". A later successful scan clears
     * the flag, because the problem resolved itself.
     */
    private function recordException(ReturnRequest $return, TrackingUpdate $update): void
    {
        $isException = in_array($update->status, [
            TrackingUpdate::UNDELIVERED,
            TrackingUpdate::RTO,
            TrackingUpdate::RTO_COMPLETED,
            TrackingUpdate::CANCELLED,
        ], true);

        if (!$isException && $return->courier_exception === null) {
            return;
        }

        $return->courier_exception = $isException
            ? mb_substr(trim(($update->carrierStatus ?: $update->status) . ($update->location ? ' — ' . $update->location : '')), 0, 180)
            : null;
        $return->save();

        /* The carrier called the collection off — their own cancellation, a reverse parcel
           they sent back, whatever it was. Left as it is, the request would read as booked
           for ever: no courier coming, and the panel offering nothing because it thinks one
           is. The handles are cleared so a pickup can be arranged again, and the reason is
           kept on the request so nobody wonders why. */
        if ($isException
            && in_array($update->status, [TrackingUpdate::CANCELLED, TrackingUpdate::RTO_COMPLETED], true)
            && ReturnStatusList::rank((int) $return->status) < ReturnStatusList::rank(ReturnStatusList::$rReceivedFromCustomer)) {
            $return->courier_provider = null;
            $return->courier_shipment_id = null;
            $return->tracking_id = null;
            $return->tracking_url = null;
            $return->save();
        }

        if ($isException) {
            Log::warning(sprintf(
                '[Shipping] return pickup exception on request %d (%s): %s',
                $return->id,
                (string) $return->tracking_id,
                (string) ($update->carrierStatus ?: $update->status)
            ));

            try {
                $order = Order::find($return->order_id);
                if ($order) {
                    CommonHelper::sendOrderNotificationsToAdmins($order, 'return_status_update', null);
                }
            } catch (\Throwable $e) {
                Log::error('[Shipping] return exception notice failed: ' . $e->getMessage());
            }
        }
    }

    /**
     * Whether this stage is the customer's business.
     *
     * The same setting the forward flow honours, for the same reason: the courier texts
     * the customer itself at each scan, so by default we stay quiet until the parcel is
     * back with the shop — the one event that ends their wait and starts the refund.
     */
    private function mayNotifyCustomer(int $target): bool
    {
        return match (CourierStatusService::customerNotificationMode()) {
            'every_stage' => true,
            'never'       => false,
            default       => $target === ReturnStatusList::$rReturnToBranch,
        };
    }

    /** The customer is told the same things a rider's pickup tells them. */
    private function notify(ReturnRequest $return): void
    {
        try {
            CommonHelper::sendReturnRequestNotification($return);
        } catch (\Throwable $e) {
            Log::error('[Shipping] return notification failed: ' . $e->getMessage());
        }
    }
}
