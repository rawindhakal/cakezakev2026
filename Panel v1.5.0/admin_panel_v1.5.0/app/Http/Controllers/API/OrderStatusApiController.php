<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\OrderStatusList;
use App\Models\ReturnStatusList;
use App\Services\LanguageService;
use Illuminate\Http\Request;

class OrderStatusApiController extends Controller
{
    private const RETURN_STATUS_KEYS = [
        1 => 'return_requested',           // rPending
        2 => 'accepted',                   // rAccepted
        3 => 'rejected',                   // rRejected
        4 => 'delivery_boy_assigned',      // rDeliveryBoyAssigned
        5 => 'out_for_pickup',             // rOutForPickup
        6 => 'received_from_customer',     // rReceivedFromCustomer
        7 => 'return_to_branch',            // rReturnToBranch
        8 => 'refund_completed',           // rRefundCompleted
    ];

    public function getOrderStatus(?Request $request = null)
    {
        if (!$request) {
            // Use the bound request (carries query params) — a fresh Request()
            // would be empty, dropping the ?channel filter.
            $request = request();
        }
        $excludeIds = [];
        // When is_till_cancelable=1, exclude delivered, returned, cancelled from data
        if ($request->input('is_till_cancelable') == 1) {
            $excludeIds = [
                OrderStatusList::$delivered,
                OrderStatusList::$returned,
                OrderStatusList::$cancelled,
            ];
        }

        // Status set for one kind of order: by channel, and by delivery type — a self
        // pickup order walks its own flow whatever the channel. Pass order_id and both
        // are read off the order; unknown/empty channel returns the full catalog.
        $channel = strtolower(trim((string) $request->input('channel', '')));
        $deliveryType = strtolower(trim((string) $request->input('delivery_type', '')));
        if ($request->filled('order_id') && ($order = Order::find((int) $request->input('order_id')))) {
            $channel = (string) $order->channel;
            $deliveryType = (string) ($order->delivery_type ?? 'delivery');
        }
        $channelIds = ($channel !== '' || $deliveryType === 'pickup')
            ? OrderStatusList::flowFor($channel ?: null, $deliveryType ?: null)
            : null;

        // Detect delivery-boy route (used below to restrict both order + return statuses).
        $isDeliveryBoyRoute = false;
        $backtrace = debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 2);
        if (isset($backtrace[1]['class'])) {
            $isDeliveryBoyRoute = $backtrace[1]['class'] === 'App\\Http\\Controllers\\DeliveryBoyController';
        }

        if ($isDeliveryBoyRoute) {
            $channelIds = $channel === 'ecommerce'
                ? [OrderStatusList::$outForDelivery, OrderStatusList::$delivered]
                : [OrderStatusList::$readyForPickup, OrderStatusList::$pickedUp, OrderStatusList::$outForDelivery, OrderStatusList::$delivered];
        }

        $orderStatusQuery = OrderStatusList::whereNotIn('id', $excludeIds);
        if ($channelIds !== null) {
            $orderStatusQuery->whereIn('id', $channelIds);
        }
        $orderStatuses = $orderStatusQuery->get();

        // Preserve the channel's logical flow order (else fall back to id order).
        if ($channelIds !== null) {
            $order = array_flip($channelIds);
            $orderStatuses = $orderStatuses->sortBy(fn($s) => $order[$s->id] ?? 999)->values();
        } else {
            $orderStatuses = $orderStatuses->sortBy('id')->values();
        }

        $returnStatuses = [];

        if ($isDeliveryBoyRoute) {
            $returnStatuses = [
                ['id' => ReturnStatusList::$rOutForPickup, 'status' => ReturnStatusList::$outForPickup],
                ['id' => ReturnStatusList::$rReceivedFromCustomer, 'status' => ReturnStatusList::$receivedFromCustomer],
                ['id' => ReturnStatusList::$rReturnToBranch, 'status' => ReturnStatusList::$returnToBranch],
            ];
        } else {
            $returnStatuses = [
                ['id' => ReturnStatusList::$rPending, 'status' => ReturnStatusList::$requestPending],
                ['id' => ReturnStatusList::$rAccepted, 'status' => ReturnStatusList::$accepted],
                ['id' => ReturnStatusList::$rRejected, 'status' => ReturnStatusList::$requestRejected],
                ['id' => ReturnStatusList::$rDeliveryBoyAssigned, 'status' => ReturnStatusList::$deliveryBoyAssigned],
                ['id' => ReturnStatusList::$rOutForPickup, 'status' => ReturnStatusList::$outForPickup],
                ['id' => ReturnStatusList::$rReceivedFromCustomer, 'status' => ReturnStatusList::$receivedFromCustomer],
                ['id' => ReturnStatusList::$rReturnToBranch, 'status' => ReturnStatusList::$returnToBranch],
                ['id' => ReturnStatusList::$rRefundCompleted, 'status' => ReturnStatusList::$refundCompleted],
            ];
        }

        if ($orderStatuses->isEmpty()) {
            return CommonHelper::responseError('status_not_found');
        }

        $useContentLanguage = $request->header('Content-Language') !== null
            && trim((string) $request->header('Content-Language')) !== '';
        $languageService = app(LanguageService::class);
        $previousLocale = app()->getLocale();

        // When Content-Language is present, set app locale so __() and getTranslatedName() return that language
        if ($useContentLanguage) {
            $langCode = app()->has('lang_code') ? app('lang_code') : 'en';
            app()->setLocale($langCode);
        }

        // Order statuses: add status_name (single lang or all langs)
        $data = $orderStatuses->map(function ($row) use ($useContentLanguage, $languageService, $deliveryType) {
            $key = OrderStatusList::getTranslationKey($row->id);
            // On a pickup order the customer collects; nobody "delivers" it.
            if ($deliveryType === 'pickup' && (int) $row->id === OrderStatusList::$delivered) {
                $key = 'collected';
            }

            $item = ['id' => $row->id, 'status' => $row->status];
            if ($useContentLanguage) {
                $item['status_name'] = $key !== '' ? __($key) : $row->status;
            } else {
                $statusNames = (object) [];
                foreach ($languageService->getActiveLanguages() as $lang) {
                    $code = $lang->code ?? '';
                    if ($code !== '' && $key !== '') {
                        app()->setLocale($code);
                        $statusNames->{$code} = __($key);
                    }
                }
                $item['status_name'] = $statusNames;
            }
            return $item;
        })->values();

        // Return statuses: add status_name (single lang or all langs)
        $returnStatusesTranslated = array_map(function ($rs) use ($useContentLanguage, $languageService) {
            $item = ['id' => $rs['id'], 'status' => $rs['status']];
            $key = self::RETURN_STATUS_KEYS[$rs['id']] ?? '';
            if ($key === '') {
                $item['status_name'] = $useContentLanguage ? $rs['status'] : (object) ['en' => $rs['status']];
                return $item;
            }
            if ($useContentLanguage) {
                $item['status_name'] = __($key);
            } else {
                $statusNames = (object) [];
                foreach ($languageService->getActiveLanguages() as $lang) {
                    $code = $lang->code ?? '';
                    if ($code !== '') {
                        app()->setLocale($code);
                        $statusNames->{$code} = __($key);
                    }
                }
                $item['status_name'] = $statusNames;
            }
            return $item;
        }, $returnStatuses);

        app()->setLocale($previousLocale);

        return response()->json([
            'status' => 1,
            'message' => 'success',
            'data' => $data,
            'return_statuses' => $returnStatusesTranslated,
        ]);
    }
}
