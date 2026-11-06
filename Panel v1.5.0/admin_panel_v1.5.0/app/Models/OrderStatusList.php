<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class OrderStatusList extends Model
{
    use HasFactory;

    public $timestamps = false;

    public static $paymentPending = 1;
    public static $received = 2;
    public static $processed = 3;
    public static $shipped = 4;
    public static $outForDelivery = 5;
    public static $delivered = 6;
    public static $cancelled = 7;
    public static $returned = 8;
    // Quick-channel specific statuses. Received(2), Out For Delivery(5),
    // Payment Pending(1), Delivered(6) and Cancelled(7) are shared with ecommerce.
    public static $preparing = 9;
    public static $readyForPickup = 10;
    public static $pickedUp = 11;

    /**
     * The stages an order walks, by channel and delivery type. A self-pickup order is
     * order-wise on both channels and walks the quick stages minus the rider ones —
     * there is no courier and nobody to hand it to.
     */
    public const FLOWS = [
        'quick'     => [1, 2, 9, 10, 11, 5, 6, 7],
        'ecommerce' => [1, 2, 3, 4, 5, 6, 7, 8],
        'pickup'    => [1, 2, 9, 10, 6, 7],
    ];

    /** Full status flow for an order of this channel + delivery type. */
    public static function flowFor(?string $channel, ?string $deliveryType = null): array
    {
        if ($deliveryType === 'pickup') {
            return self::FLOWS['pickup'];
        }

        return self::FLOWS[$channel] ?? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    }

    /** The progress plan: the flow without payment-pending and the terminal cancel/return. */
    public static function progressPlanFor(?string $channel, ?string $deliveryType = null): array
    {
        return array_values(array_diff(self::flowFor($channel, $deliveryType), [self::$paymentPending, self::$cancelled, self::$returned]));
    }

    /** Position of a status in the flow — ids are not ordered, 10 comes before 6. */
    public static function rank(int $statusId, ?string $channel, ?string $deliveryType = null): int
    {
        $pos = array_search($statusId, self::flowFor($channel, $deliveryType), true);

        return $pos === false ? PHP_INT_MAX : $pos;
    }

    public static $orderPaymentPending = "Payment Pending";
    public static $orderReceived = "Received";
    public static $orderProcessed = "Processed";
    public static $orderShipped = "Shipped";
    public static $orderOutForDelivery = "Out For Delivery";
    public static $orderDelivered = "Delivered";
    public static $orderCancelled = "Cancelled";
    public static $orderReturned = "Returned";
    public static $orderPreparing = "Preparing";
    public static $orderReadyForPickup = "Ready for Pickup";
    public static $orderPickedUp = "Picked Up";

    public static function getTranslationKey(int $statusId): string
    {
        $statusKeys = [
            self::$paymentPending     => 'payment_pending',      // ID 1
            self::$received           => 'received',             // ID 2
            self::$processed          => 'processed',            // ID 3
            self::$shipped            => 'shipped',              // ID 4
            self::$outForDelivery     => 'outForDelivery',       // ID 5
            self::$delivered          => 'delivered',            // ID 6
            self::$cancelled          => 'cancelled',            // ID 7
            self::$returned           => 'returned',             // ID 8
            self::$preparing          => 'preparing',            // ID 9  (quick)
            self::$readyForPickup     => 'ready_for_pickup',     // ID 10 (quick)
            self::$pickedUp           => 'picked_up',            // ID 11 (quick)
        ];

        return $statusKeys[$statusId] ?? '';
    }

    public static function getTranslatedName(int $statusId): string
    {
        $key = self::getTranslationKey($statusId);

        // Return empty string if no key found
        if (empty($key)) {
            return '';
        }

        return __($key);
    }

    public static function getCustomerTranslatedName(int $statusId, ?string $deliveryType = null): string
    {
        if ($statusId === self::$received) {
            return __('order_placed');
        }
        // "Delivered" is the wrong word for something the customer walked in and took.
        if ($statusId === self::$delivered && $deliveryType === 'pickup') {
            return __('collected');
        }
        return self::getTranslatedName($statusId);
    }
}
