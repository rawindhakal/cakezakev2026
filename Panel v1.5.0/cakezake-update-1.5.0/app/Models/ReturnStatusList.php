<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ReturnStatusList extends Model
{
    use HasFactory;

    public $timestamps = false;

    // New flow: pending -> accepted/rejected -> delivery boy assigned -> out for
    // pickup -> received from customer -> return to branch -> refund completed.
    public static $rPending = 1;
    public static $rAccepted = 2;
    public static $rRejected = 3;
    public static $rDeliveryBoyAssigned = 4;
    public static $rOutForPickup = 5;
    public static $rReceivedFromCustomer = 6;
    public static $rReturnToBranch = 7;
    public static $rRefundCompleted = 8;

    public static $requestPending = "Return Requested";
    public static $accepted = "Accepted";
    public static $requestRejected = "Request Rejected";
    public static $deliveryBoyAssigned = "Delivery Boy Assigned";
    public static $outForPickup = "Out for Pickup";
    public static $receivedFromCustomer = "Received from Customer";
    public static $returnToBranch = "Return to Branch";
    public static $refundCompleted = "Refund Completed";

    public static function getStatusName($status)
    {
        switch ((int) $status) {
            case self::$rPending:
                return self::$requestPending;
            case self::$rAccepted:
                return self::$accepted;
            case self::$rRejected:
                return self::$requestRejected;
            case self::$rDeliveryBoyAssigned:
                return self::$deliveryBoyAssigned;
            case self::$rOutForPickup:
                return self::$outForPickup;
            case self::$rReceivedFromCustomer:
                return self::$receivedFromCustomer;
            case self::$rReturnToBranch:
                return self::$returnToBranch;
            case self::$rRefundCompleted:
                return self::$refundCompleted;
            default:
                return "Unknown Status";
        }
    }

    /**
     * How far along a return is, so a status can only move forward.
     *
     * Accepted and Rejected share a step: they are the two answers to the same question.
     * Kept here rather than in a controller because the panel, the delivery boy app and a
     * courier's webhook all have to agree about what "forward" means.
     */
    public static function rank($status): int
    {
        return [
            self::$rPending              => 1,
            self::$rAccepted             => 2,
            self::$rRejected             => 2,
            self::$rDeliveryBoyAssigned  => 3,
            self::$rOutForPickup         => 4,
            self::$rReceivedFromCustomer => 5,
            self::$rReturnToBranch        => 6,
            self::$rRefundCompleted      => 7,
        ][(int) $status] ?? 0;
    }

    public static function getAllStatuses()
    {
        return [
            self::$rPending              => self::$requestPending,
            self::$rAccepted             => self::$accepted,
            self::$rRejected             => self::$requestRejected,
            self::$rDeliveryBoyAssigned  => self::$deliveryBoyAssigned,
            self::$rOutForPickup         => self::$outForPickup,
            self::$rReceivedFromCustomer => self::$receivedFromCustomer,
            self::$rReturnToBranch        => self::$returnToBranch,
            self::$rRefundCompleted      => self::$refundCompleted,
        ];
    }

    public static function getDeliveryBoyStatuses()
    {
        return [
            self::$rOutForPickup         => self::$outForPickup,
            self::$rReceivedFromCustomer => self::$receivedFromCustomer,
            self::$rReturnToBranch        => self::$returnToBranch,
        ];
    }

    public static function getTranslationKey(int $statusId): string
    {
        $statusKeys = [
            self::$rPending              => 'return_requested',
            self::$rAccepted             => 'accepted',
            self::$rRejected             => 'rejected',
            self::$rDeliveryBoyAssigned  => 'delivery_boy_assigned',
            self::$rOutForPickup         => 'out_for_pickup',
            self::$rReceivedFromCustomer => 'received_from_customer',
            self::$rReturnToBranch        => 'return_to_branch',
            self::$rRefundCompleted      => 'refund_completed',
        ];

        return $statusKeys[$statusId] ?? '';
    }

    public static function getTranslatedName(int $statusId): string
    {
        $key = self::getTranslationKey($statusId);

        if (empty($key)) {
            return self::getStatusName($statusId);
        }

        $translated = __($key);

        // If __() returns the key itself (untranslated), fall back to the static name
        return ($translated !== $key) ? $translated : self::getStatusName($statusId);
    }
}
