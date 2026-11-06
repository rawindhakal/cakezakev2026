<?php

namespace App\Http\Controllers\API;

use App\Helpers\AddonHelper;
use App\Helpers\CommonHelper;
use App\Helpers\ProductHelper;
use App\Http\Controllers\Controller;
use App\Models\Admin;
use App\Models\ReturnRequest;
use App\Models\ReturnStatusList;
use App\Models\Role;
use App\Models\User;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusList;
use App\Models\DeliveryBoy;
use App\Models\DeliveryBoySettlement;
use App\Models\ReturnRequestStatus;
use App\Models\Zone;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
class ReturnRequestsApiController extends Controller
{
    public function index()
    {
        $search = request()->get('search');
        $query = ReturnRequest::select(
            'return_requests.*',
            'users.name as customer_name',
            'users.name',
            'users.mobile as customer_mobile',
            'users.country_code as user_country_code',
            'users.email as customer_email',
            'orders.currency as currency',
            'orders.order_number as order_number',
            'orders.zone_id as zone_id',
            'order_items.product_variant_id',
            'order_items.quantity',
            'order_items.price',
            'order_items.sub_total',
            'order_items.discounted_price',
            'order_items.product_name',
            'products.id as product_id',
            // Assigned rider, so the slider can show who is handling the pickup.
            'delivery_boys.name as delivery_boy_name',
            'delivery_boys.mobile as delivery_boy_mobile',
            'delivery_boys.country_code as delivery_boy_country_code',
        )
            ->leftJoin('users', 'return_requests.user_id', '=', 'users.id')
            ->leftJoin('order_items', 'return_requests.order_item_id', '=', 'order_items.id')
            ->leftJoin('orders', 'return_requests.order_id', '=', 'orders.id')
            ->leftJoin('delivery_boys', 'return_requests.delivery_boy_id', '=', 'delivery_boys.id')
            ->leftJoin('product_variants', 'return_requests.product_variant_id', '=', 'product_variants.id')
            ->leftJoin('products', 'product_variants.product_id', '=', 'products.id')
            ->when(request('country_id'), fn ($q) => $q->where('orders.country_id', request('country_id')))
            ->when(request('zone_id'), fn ($q) => $q->where('orders.zone_id', request('zone_id')))
            ->when($search, function ($q) use ($search) {
                if (is_numeric($search)) {
                    $q->where(function ($sub) use ($search) {
                        $sub->where('return_requests.id', $search)
                            ->orWhere('return_requests.user_id', $search)
                            ->orWhere('order_items.quantity', $search)
                            ->orWhere('order_items.sub_total', $search);
                    });
                } else {
                    $timestamp = strtotime($search);
                    if ($timestamp !== false) {
                        // Check if the search string looks like a date/time (contains separators or month names)
                        if (preg_match('/[\/\-\.\s]/', $search) || preg_match('/(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/i', $search)) {
                            $q->whereDate('return_requests.created_at', date('Y-m-d', $timestamp));
                            return;
                        }
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

                    $q->where(function ($sub) use ($search, $statusValue) {
                        $sub->where('order_items.product_name', 'like', "%{$search}%")
                            ->orWhere('return_requests.return_reason', 'like', "%{$search}%")
                            ->orWhere('return_requests.return_number', 'like', "%{$search}%")
                            ->orWhere('orders.order_number', 'like', "%{$search}%")
                            ->orWhere('order_items.invoice_number', 'like', "%{$search}%")
                            ->orWhere('users.name', 'like', "%{$search}%");
                        if ($statusValue !== null) {
                            $sub->orWhere('return_requests.status', $statusValue);
                        }
                    });
                }
            })
            ->orderBy('return_requests.id', 'DESC');

        $rows = $query->get();

        // Bulk-fetch status history for all rows, grouped by return request (for the timeline).
        $statusRows = ReturnRequestStatus::whereIn('return_request_id', $rows->pluck('id'))
            ->orderBy('id', 'ASC')
            ->get();
        $timelines = $statusRows->groupBy('return_request_id');
        // Resolve "updated by" names once — customers (user_type null) live in users,
        // admins/super-admins/delivery boys in admins.
        $userNames = User::whereIn('id', $statusRows->whereNull('user_type')->pluck('created_by')->filter()->unique())->pluck('name', 'id');
        $adminNames = Admin::whereIn('id', $statusRows->whereNotNull('user_type')->pluck('created_by')->filter()->unique())->pluck('username', 'id');

        $returnRequests = $rows->map(function (ReturnRequest $rr) use ($timelines, $userNames, $adminNames) {
            $rr->makeHidden(['created_at', 'updated_at']);
            $row = $rr->toArray();
            $row['date'] = $rr->getAttributes()['created_at'] ?? null;
            foreach (['price', 'sub_total', 'discounted_price', 'final_total'] as $f) {
                if (isset($row[$f])) {
                    $row[$f] = (float) $row[$f];
                }
            }
            // Full order item detail (product, variant attributes, refund amount).
            $row['return_item'] = CommonHelper::buildReturnItem($rr->order_id, $rr->order_item_id);
            $row['pickup_address'] = CommonHelper::addressObject($rr->address);
            $row['delivery_methods'] = CommonHelper::deliveryMethodsForZone(
                Zone::find((int) ($rr->zone_id ?? 0))
            );
            $row['timeline'] = collect($timelines->get($rr->id, []))
                ->map(fn ($s) => [
                    'status'      => (int) $s->status,
                    'status_name' => ReturnStatusList::getTranslatedName((int) $s->status),
                    'updated_by'  => CommonHelper::returnTimelineUpdaterName($s, $userNames, $adminNames),
                    'datetime'    => $s->created_at,
                ])->values()->all();
            return $row;
        });

        return CommonHelper::responseWithData($returnRequests);
    }

    public function update(Request $request)
    {
        $user = auth()->user();

        if ($user->role_id == Role::$roleDeliveryBoy) {
            // Delivery Boys can only update to these statuses: Out for Pickup, Received from Customer, Return to Branch
            $allowedStatuses = [
                ReturnStatusList::$rOutForPickup,
                ReturnStatusList::$rReceivedFromCustomer,
                ReturnStatusList::$rReturnToBranch
            ];

            if (!in_array($request->status, $allowedStatuses)) {
                return CommonHelper::responseError('you_dont_have_permission_to_update_to_this_status');
            }

            $returnRequest = ReturnRequest::where('id', $request->id)
                ->where('delivery_boy_id', $user->deliveryBoy->id)
                ->first();

            if (!$returnRequest) {
                return CommonHelper::responseError('return_request_not_found_or_not_assigned_to_you');
            }
        } else {
            // Admin, Super Admin can access all return requests and all statuses
            $returnRequest = ReturnRequest::find($request->id);
            if (!$returnRequest) {
                return CommonHelper::responseError('return_request_not_found');
            }
        }

        // Validate status update
        $validationError = $this->validateStatusUpdate($returnRequest, $request->status);
        if ($validationError) {
            return CommonHelper::responseError($validationError);
        }

        return $this->processUpdate($request, $returnRequest, $user);
    }

    /**
     * Another courier's waybill, typed in by hand.
     *
     * The returns twin of an order's manual tracking: a shop that books its own reverse
     * pickup with a courier the panel has no plugin for still needs the number recorded, so
     * the customer can follow the parcel and the desk knows it is on its way. Nothing is
     * called out to — these are somebody else's shipments.
     */
    public function saveTracking(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'id'             => 'required|integer|exists:return_requests,id',
            'courier_agency' => 'nullable|string|max:191',
            'tracking_id'    => 'nullable|string|max:191',
            'tracking_url'   => 'nullable|url|max:500',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $returnRequest = ReturnRequest::find($request->id);
        if (!$returnRequest) {
            return CommonHelper::responseError('return_request_not_found');
        }

        // A parcel an plugin booked is the plugin's to change; this is for the other kind.
        if (!empty($returnRequest->courier_shipment_id)) {
            return CommonHelper::responseError('this_return_is_already_booked_with_a_courier');
        }
        if ((int) $returnRequest->delivery_boy_id > 0) {
            return CommonHelper::responseError('this_return_is_assigned_to_a_delivery_boy');
        }
        if (in_array((int) $returnRequest->status, [ReturnStatusList::$rRejected, ReturnStatusList::$rRefundCompleted], true)) {
            return CommonHelper::responseError('cannot_update_tracking_for_this_return');
        }

        $returnRequest->courier_agency = $request->filled('courier_agency') ? trim((string) $request->courier_agency) : null;
        $returnRequest->tracking_id = $request->filled('tracking_id') ? trim((string) $request->tracking_id) : null;
        $returnRequest->tracking_url = $request->filled('tracking_url') ? trim((string) $request->tracking_url) : null;
        $returnRequest->save();

        return CommonHelper::responseSuccess('updated_successfully');
    }

    public function delete(Request $request)
    {
        if (isset($request->id)) {
            $returnRequest = ReturnRequest::find($request->id);
            if ($returnRequest) {
                $returnRequest->delete();
                return CommonHelper::responseSuccess('return_request_deleted_successfully');
            } else {
                return CommonHelper::responseSuccess('return_request_already_deleted');
            }
        }
    }

    public function deliveryBoyReturnRequests(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'delivery_boy_id' => 'required|integer',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $returnRequests = ReturnRequest::select(
            'return_requests.*',
            'users.name as customer_name',
            'users.name',
            'users.mobile as customer_mobile',
            'users.email as customer_email',
            'order_items.product_variant_id',
            'order_items.quantity',
            'order_items.price',
            'order_items.sub_total',
            'order_items.discounted_price',
            'order_items.product_name',
            'products.id as product_id',
        )
            ->leftJoin('users', 'return_requests.user_id', '=', 'users.id')
            ->leftJoin('order_items', 'return_requests.order_item_id', '=', 'order_items.id')
            ->leftJoin('product_variants', 'return_requests.product_variant_id', '=', 'product_variants.id')
            ->leftJoin('products', 'product_variants.product_id', '=', 'products.id')
            ->where('return_requests.delivery_boy_id', $request->delivery_boy_id)
            ->orderBy('return_requests.id', 'DESC')
            ->get();

        return CommonHelper::responseWithData($returnRequests);
    }

    private function validateStatusUpdate($returnRequest, $requestStatus)
    {
        // Terminal states — nothing can change after a return is rejected or refunded.
        if ($returnRequest->status == ReturnStatusList::$rRejected || $returnRequest->status == ReturnStatusList::$rRefundCompleted) {
            $statusName = ReturnStatusList::getTranslatedName((int) $returnRequest->status);
            return __('cannot_update_return_request_status_is_already') . $statusName . '.';
        }

        if ($returnRequest->status == $requestStatus) {
            $statusName = ReturnStatusList::getTranslatedName((int) $returnRequest->status);
            return __('this_return_request_is_already') . $statusName . '.';
        }

        $currentStatus = $returnRequest->status;
        $newStatus = $requestStatus;

        /* Flow: pending -> accepted/rejected -> delivery boy assigned -> out for
           pickup -> received from customer -> return to branch -> refund completed. The
           ranking lives on the model, because a courier's webhook moves these too. */
        $currentRank = ReturnStatusList::rank($currentStatus);
        $newRank = ReturnStatusList::rank($newStatus);

        if ($currentRank === 0 || $newRank === 0) {
            return __('invalid_status_for_return_request');
        }

        if ($newRank < $currentRank) {
            $currentName = ReturnStatusList::getTranslatedName((int) $currentStatus);
            $newName = ReturnStatusList::getTranslatedName((int) $newStatus);
            return __('cannot_update_status_from_to') . $currentName . __('to_status_to_status_to') . $newName . "'";
        }

        if ($newRank === $currentRank) {
            $statusName = ReturnStatusList::getTranslatedName((int) $currentStatus);
            return __('this_return_request_is_already') . $statusName . '.';
        }

        return null;
    }

    private function processUpdate(Request $request, $returnRequest, $user)
    {
        $validator = Validator::make($request->all(), [
            'id' => 'required|integer|exists:return_requests,id',
            'status' => 'required',
            'delivery_boy_id' => [
                'required_if:status,' . ReturnStatusList::$rDeliveryBoyAssigned,
                'integer',
                function ($attribute, $value, $fail) use ($request) {
                    $existingRequest = ReturnRequest::where('id', $request->id)
                        ->where('status', ReturnStatusList::$rRefundCompleted)
                        ->first();

                    if ($existingRequest) {
                        $fail('This return request is already refunded.');
                    }

                    if ($request->status == ReturnStatusList::$rDeliveryBoyAssigned && $value <= 0) {
                        $fail('Please assign a delivery boy when the return request is assigned.');
                    }
                },
            ],
            'reject_reason' => [
                'nullable',
                'required_if:status,' . ReturnStatusList::$rRejected,
                'string',
                'max:500',
            ],
        ], [
            'id.required' => 'Return request ID is required.',
            'id.integer' => 'Return request ID must be a valid integer.',
            'id.exists' => 'Return request not found.',
            'delivery_boy_id.required_if' => 'Please assign a delivery boy when the return request is assigned.',
            'reject_reason.required_if' => 'A reject reason is required when rejecting a return request.',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        /* A zone with no riders of its own cannot be handed one, whatever a stale tab
           offers — unless this request already has one, which stays editable so a pickup
           in progress can always be finished. */
        if ((int) $request->status === ReturnStatusList::$rDeliveryBoyAssigned
            && (int) $returnRequest->delivery_boy_id === 0) {
            $zone = Zone::find((int) (Order::where('id', $returnRequest->order_id)->value('zone_id') ?? 0));
            $methods = CommonHelper::deliveryMethodsForZone($zone);
            if (!in_array(Zone::DELIVERY_BOY, $methods, true)) {
                return CommonHelper::responseError('this_zone_does_not_deliver_with_a_delivery_boy');
            }
        }

        /* The pickup legs need somebody to be collecting it — a rider, a courier the
           panel booked, or another courier whose waybill was typed in. Pending, accepted,
           rejected and refunded need nobody. */
        $statusesRequiringPickup = [
            ReturnStatusList::$rOutForPickup,
            ReturnStatusList::$rReceivedFromCustomer,
            ReturnStatusList::$rReturnToBranch,
        ];

        $pickupArranged = (int) $returnRequest->delivery_boy_id > 0
            || !empty($returnRequest->courier_shipment_id)
            || !empty($returnRequest->tracking_id);

        if (in_array($request->status, $statusesRequiringPickup) && !$pickupArranged) {
            return CommonHelper::responseError('cannot_update_to_this_status_please_arrange_a_pickup_first');
        }

        $returnRequest->remarks = $request->remark;
        $returnRequest->status = $request->status;

        if ($user->role_id != Role::$roleDeliveryBoy) {
            $returnRequest->delivery_boy_id = $request->delivery_boy_id ?? 0;
        }

        // On delivery boy assignment, compute the return commission. It is credited
        // later, when the item reaches the branch ("Return to Branch").
        if ($request->status == ReturnStatusList::$rDeliveryBoyAssigned && $returnRequest->delivery_boy_id > 0) {
            $this->computeReturnCommission($returnRequest);
        }

        // Credit the computed return commission to the delivery boy's wallet.
        if ($request->status == ReturnStatusList::$rReturnToBranch) {
            $this->creditReturnCommission($returnRequest);
        }

        if ($request->status == ReturnStatusList::$rPending) {
            $returnRequest->delivery_boy_id = 0;
        } elseif ($request->status == ReturnStatusList::$rRefundCompleted) {
            $orderItem = OrderItem::find($returnRequest->order_item_id);
            $order = Order::find($orderItem->order_id);

            // Return refund (item-wise): item value + refundable additional/surge charges.
            // Delivery charge and non-refundable charges are NOT refunded on a return.
            $refund = CommonHelper::computeOrderItemRefund($orderItem, false);

            $orderItem->refund_amount = $refund;
            $orderItem->active_status = OrderStatusList::$returned;
            $orderItem->save();

            CommonHelper::reverseOrderItemTax($orderItem);

            if ($refund > 0) {
                // Credit the order's country wallet (wallets are country-wise).
                CommonHelper::addUserWalletBalance($refund, $returnRequest->user_id, $order->country_id);
                CommonHelper::addWalletTransaction($orderItem->order_id, $orderItem->id, $returnRequest->user_id, 'credit', $refund, 'wallet_order_item_returned');
                CommonHelper::notifyWalletRefundReturned($order, $orderItem, $refund, $returnRequest->id);
            }

            // Reduce the order's outstanding totals by the returned item.
            $order->refund_amount = floatval($order->refund_amount) + $refund;
            $order->remaining_total = max(0, floatval($order->remaining_total) - floatval($orderItem->sub_total));
            $order->remaining_final = max(0, floatval($order->remaining_final) - $refund);
            $order->save();

            // Restock the returned item per-branch (PVSS).
            ProductHelper::restockStock($orderItem->product_variant_id, $orderItem->branch_id, (int) $orderItem->quantity);
            AddonHelper::moveOrderItemStock($orderItem, 'restock');
            // Ecommerce: order status follows its items after a return.
            CommonHelper::syncEcommerceOrderStatus($order);
        } elseif ($request->status == ReturnStatusList::$rRejected) {
            $returnRequest->delivery_boy_id = 0;
            $returnRequest->reject_reason = $request->reject_reason;
        }
        $returnRequest->save();

        // Record this change in the status history (for the timeline).
        CommonHelper::setReturnRequestStatus(
            $returnRequest->id,
            (int) $request->status,
            $user->id ?? null,
            $user->role_id ?? null
        );

        dispatch(function () use ($returnRequest) {
            try {
                CommonHelper::sendReturnRequestNotification($returnRequest);
            } catch (\Exception $e) {
                Log::error("Return request notification error: " . $e->getMessage());
            }

            // Panel + FCM notification to admins/boy for the return's order.
            try {
                $order = Order::find($returnRequest->order_id);
                if ($order) {
                    CommonHelper::sendOrderNotificationsToAdmins($order, 'return_status_update', $returnRequest->delivery_boy_id ?? null);
                }
            } catch (\Exception $e) {
                Log::error("Return request admin notification error: " . $e->getMessage());
            }
        })->afterResponse();

        return CommonHelper::responseSuccess('return_request_status_updated_successfully');
    }

    /**
     * Compute the delivery boy's return commission for this request and store it on
     * the row (not yet credited). Mirrors the order-bonus calculation but uses the
     * delivery boy's return_bonus_* fields and the returned item's value as the base.
     */
    private function computeReturnCommission(ReturnRequest $returnRequest): void
    {
        $deliveryBoy = DeliveryBoy::find($returnRequest->delivery_boy_id);
        if (!$deliveryBoy) {
            return;
        }

        $orderItem = OrderItem::find($returnRequest->order_item_id);
        $baseTotal = $orderItem ? floatval($orderItem->sub_total) : 0;

        $bonusType = (int) ($deliveryBoy->return_bonus_type ?? 0);
        $details = ['base_total' => $baseTotal, 'bonus_type' => $bonusType];
        $amount = 0;

        if ($bonusType == DeliveryBoy::$bonusCommission) {
            $percentage = floatval($deliveryBoy->return_bonus_percentage);
            $minAmount = floatval($deliveryBoy->return_bonus_min_amount);
            $maxAmount = floatval($deliveryBoy->return_bonus_max_amount);
            $amount = floatval(($baseTotal * $percentage) / 100);
            if ($amount < $minAmount && $minAmount != 0) {
                $amount = $minAmount;
            }
            if ($amount > $maxAmount && $maxAmount != 0) {
                $amount = $maxAmount;
            }
            $details['bonus_type_name'] = DeliveryBoy::$commission;
            $details['bonus_percentage'] = $percentage;
            $details['bonus_min_amount'] = $minAmount;
            $details['bonus_max_amount'] = $maxAmount;
        } else {
            $details['bonus_type_name'] = DeliveryBoy::$fixed;
        }
        $details['bonus_amount'] = $amount;

        $returnRequest->delivery_boy_bonus_amount = $amount;
        $returnRequest->delivery_boy_bonus_details = $details;
        $returnRequest->bonus_credited = 0;
    }

    /** Credit the previously-computed return commission to the delivery boy (idempotent). */
    private function creditReturnCommission(ReturnRequest $returnRequest): void
    {
        if ((int) $returnRequest->bonus_credited === 1) {
            return;
        }

        // Commission may not have been computed yet (e.g. status jumped straight to
        // "Return to Branch") — compute it now from the assigned delivery boy.
        if (floatval($returnRequest->delivery_boy_bonus_amount) <= 0 && $returnRequest->delivery_boy_id > 0) {
            $this->computeReturnCommission($returnRequest);
        }

        $amount = floatval($returnRequest->delivery_boy_bonus_amount);
        $deliveryBoy = DeliveryBoy::find($returnRequest->delivery_boy_id);
        if (!$deliveryBoy || $amount <= 0) {
            // Nothing to pay — still flag so we don't reprocess.
            $returnRequest->bonus_credited = 1;
            return;
        }

        CommonHelper::addDeliveryBoySettlement($deliveryBoy->id, $amount, DeliveryBoySettlement::$typeCredit, 'return_commission');

        $returnRequest->bonus_credited = 1;
    }
}
