<?php

namespace App\Http\Controllers\API\Customer;

use App\Plugins\Contracts\PaymentGateway;
use App\Services\Payment\SignsSdkRequests;
use App\Plugins\Registries\PaymentGatewayRegistry;
use App\Helpers\AddonHelper;
use App\Helpers\CommonHelper;
use App\Services\PaypalService;
use App\Helpers\CustomerProductShaper;
use App\Helpers\ProductHelper;
use App\Services\BuyerTaxIdentity;
use App\Services\TaxService;
use App\Helpers\Paystack;
use App\Helpers\TransactionHelper;
use App\Http\Controllers\Controller;
use App\Models\AppUsage;
use App\Models\Order;
use App\Models\Cart;
use App\Models\Branch;
use App\Models\Zone;
use App\Models\OrderItem;
use App\Models\OrderItemTax;
use App\Models\OrderStatus;
use App\Models\OrderStatusList;
use App\Models\ProductVariant;
use App\Models\ProductVariantAttributeValue;
use App\Models\Setting;
use App\Models\Transaction;
use App\Models\User;
use App\Models\LiveTracking;
use App\Models\PromoCode;
use App\Models\ReturnRequest;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use App\Jobs\SendEmailJob;
use App\Models\Country;
use App\Models\ReturnRequestStatus;
use App\Models\ReturnStatusList;
use App\Models\WalletTransaction;

class OrderApiController extends Controller
{
    public function placeOrder(Request $request)
    {
        try {
            // Delivery or self pickup — the app must say which. A pickup order has no
            // delivery address.
            $deliveryType = strtolower(trim((string) $request->input('delivery_type', '')));
            if ($deliveryType === '') {
                return CommonHelper::responseError(__('delivery_type_is_required'));
            }
            if (!in_array($deliveryType, ['delivery', 'pickup'], true)) {
                return CommonHelper::responseError(__('invalid_delivery_type'));
            }
            $isPickup = $deliveryType === 'pickup';

            $validator = Validator::make($request->all(), [
                'payment_method' => 'required',
                'address_id' => $isPickup ? 'nullable' : 'required',
                'order_note' => 'nullable|string|max:256',
                // Gifting
                'recipient_name' => 'nullable|string|max:191',
                'recipient_phone' => 'nullable|string|max:32',
                'recipient_relationship' => 'nullable|string|max:191',
                'occasion' => 'nullable|string|max:191',
                'delivery_date' => 'nullable|date_format:Y-m-d',
                'delivery_slot_id' => 'nullable|integer',
                'delivery_slot' => 'nullable|string|max:64',
                'gift_delivery_type' => 'nullable|string|max:64',
                'gift_message' => 'nullable|string|max:500',
                'sender_name' => 'nullable|string|max:191',
                'is_surprise' => 'nullable|boolean',
                'personalization' => 'nullable|string|max:500',
                'prescription' => 'nullable|array',
                'prescription.*' => 'file|mimes:jpg,jpeg,png,webp,pdf,svg|max:5120',
            ], [
                'required' => 'The :attribute field is required.',
                'order_note.max' => 'Order note cannot exceed 256 characters.',
                'prescription.*.mimes' => __('prescription_must_be_an_image_or_pdf'),
                'prescription.*.max' => __('prescription_file_is_too_large'),
            ]);

            if ($validator->fails()) {
                return CommonHelper::responseError($validator->errors()->first());
            }

            $user = auth()->user();
            if (!isset($user->status) || $user->status == 0) {
                return CommonHelper::responseError(__('not_allowed_to_place_order_as_your_account_is_de_activated'));
            }

            // ---- Channel (quick = single-branch instant; ecommerce = multi-branch) ----
            $channel = strtolower(trim((string) $request->header('channel')));
            if (!in_array($channel, ['quick', 'ecommerce'], true)) {
                return CommonHelper::responseError(__('invalid_or_missing_channel'));
            }

            // Order only this channel's cart lines (plus legacy NULL-channel rows).
            $cartItems = Cart::select('carts.*', 'product_variants.name as product_name', 'products.sales_channel', 'products.product_type', 'products.is_prescription_required', 'branches.name as branch_name')
                ->join('products', 'carts.product_id', '=', 'products.id')
                ->join('product_variants', 'carts.product_variant_id', '=', 'product_variants.id')
                ->leftJoin('branches', 'carts.branch_id', '=', 'branches.id')
                ->where('user_id', '=', $user->id)
                ->where(function ($q) use ($channel) {
                    $q->where('carts.channel', $channel)->orWhereNull('carts.channel');
                })
                ->get();

            if ($cartItems->isEmpty()) {
                return CommonHelper::responseError(__('cart_is_empty'));
            }

            // Cart line -> resolved branch (cart holds the correct per-channel branch).
            // keyBy() collapses two lines of one variant, so this map answers only
            // questions that are the same for both — the branch, and the prescription
            // file, which the app still sends per variant. Everything per LINE is keyed
            // by cart row id below.
            $cartBranchByVariant = $cartItems->keyBy('product_variant_id');
            $cartLineById       = $cartItems->keyBy('id');
            $cartBranchIds = array_values(array_unique(array_filter($cartItems->pluck('branch_id')->all())));

            // Quick orders must be fulfilled by a single branch — and so must a pickup
            // order: the customer walks into one branch.
            if ($channel === 'quick' && count($cartBranchIds) > 1) {
                return CommonHelper::responseError(__('quick_order_items_must_be_from_single_branch'));
            }
            if ($isPickup && count($cartBranchIds) !== 1) {
                return CommonHelper::responseError(__('pickup_order_items_must_be_from_single_branch'));
            }

            // Every item must be sellable on the requested channel.
            foreach ($cartItems as $ci) {
                $sc = $ci->sales_channel ?? 'both';
                if (!in_array($sc, [$channel, 'both'], true)) {
                    return CommonHelper::responseErrorWithData(__('item_not_available_for_this_channel'), $ci->product_name);
                }
            }

            // ---- Prescriptions (medical products) ----
            // Each medical item flagged prescription-required needs its own file, sent as
            // prescription[<product_variant_id>].
            $prescriptionFiles = $request->file('prescription') ?: [];
            $prescriptionPaths = [];
            foreach ($cartItems as $ci) {
                if ((int) ($ci->product_type ?? 0) !== 5) {
                    continue;
                }

                $file = $prescriptionFiles[$ci->product_variant_id] ?? null;

                if (!$file || !$file->isValid()) {
                    if ((int) ($ci->is_prescription_required ?? 0) === 1) {
                        return CommonHelper::responseErrorWithData(__('prescription_is_required_for_this_product'), $ci->product_name);
                    }
                    continue;
                }

                $prescriptionPaths[$ci->product_variant_id] = $file;
            }

            $address_id = $request->address_id ?? 0;
            $mobile = '';
            $latitude = '';
            $longitude = '';

            $user_address = $request->address_id ? CommonHelper::getUserAddress($request->address_id) : null;
            if (!empty($user_address)) {
                $addressData = CommonHelper::userAddressData($user_address);
                $mobile = $addressData['mobile'];
                $latitude = $user_address->latitude;   // local only (zone resolution)
                $longitude = $user_address->longitude;
            } elseif ($isPickup) {
                $authUser = auth()->user();
                $address_id = 0;
                $addressData = [
                    'name'             => (string) ($authUser->name ?? ''),
                    'address'          => '',
                    'mobile'           => trim(($authUser->country_code ?? '') . ' ' . ($authUser->mobile ?? '')),
                    'alternate_mobile' => '',
                    'latitude'         => '',
                    'longitude'        => '',
                ];
                $mobile = $addressData['mobile'];
            } else {
                return CommonHelper::responseError(__('something_is_missing_in_your_address'));
            }
            if ($isPickup) {
                $address_id = 0;
            }

            $billingSameAsShipping = (int) $request->input('billing_same_as_shipping', 1) === 1;
            $billingAddressData = null;

            if ($isPickup) {
                $billingSameAsShipping = !empty($user_address);
                if (!$billingSameAsShipping && !$request->filled('billing_address')) {
                    return CommonHelper::responseError(__('billing_address_required_for_pickup'));
                }
            }

            if (!$billingSameAsShipping) {
                $billingValidator = Validator::make($request->all(), [
                    'billing_name'    => 'required|string|max:191',
                    'billing_mobile'  => 'required|string|max:32',
                    'billing_address' => 'required|string|max:500',
                    'billing_city'    => 'required|string|max:191',
                    'billing_state'   => 'required|string|max:191',
                    'billing_pincode' => 'required|string|max:32',
                    'billing_country' => 'required|string|max:191',
                    'billing_region_id' => 'nullable|exists:regions,id',
                ]);
                if ($billingValidator->fails()) {
                    return CommonHelper::responseError($billingValidator->errors()->first());
                }

                $billingAddressData = CommonHelper::billingAddressData($request->all());
            }

            $taxValidator = Validator::make($request->all(), [
                'buyer_tax_number'    => 'nullable|string|max:64',
                'buyer_business_name' => 'nullable|string|max:191',
            ]);
            if ($taxValidator->fails()) {
                return CommonHelper::responseError($taxValidator->errors()->first());
            }

            $buyerTaxCountryId = $billingSameAsShipping && !empty($user_address)
                ? BuyerTaxIdentity::countryIdForAddress($user_address)
                : BuyerTaxIdentity::countryIdForAddress([
                    'region_id' => $request->input('billing_region_id'),
                    'country'   => $request->input('billing_country'),
                ]);

            $buyerTaxError = BuyerTaxIdentity::validate($buyerTaxCountryId, $request->input('buyer_tax_number'));
            if ($buyerTaxError) {
                return CommonHelper::responseError($buyerTaxError);
            }

            $pickupBranch = null;
            if ($isPickup) {
                // The branch the cart was priced at is the branch the customer collects from.
                $pickupBranch = Branch::with('zone')->find((int) $cartBranchIds[0]);
                if (!$pickupBranch || (int) $pickupBranch->status !== Branch::$statusActive || !$pickupBranch->zone) {
                    return CommonHelper::responseError(__('self_pickup_not_available_for_this_branch'));
                }
                if (!$pickupBranch->offersPickup($channel)) {
                    return CommonHelper::responseError(__('self_pickup_not_available_for_this_branch'));
                }
                // If the app says where the customer is now, it must still be this branch's
                // zone — the cart may have been priced before they moved.
                if ($request->filled('latitude') && $request->filled('longitude')) {
                    $hereZone = CommonHelper::getDeliverableCity((float) $request->latitude, (float) $request->longitude, $channel);
                    if ($hereZone && (int) $hereZone->id !== (int) $pickupBranch->zone_id) {
                        return CommonHelper::responseError(__('pickup_branch_changed_refresh_cart'));
                    }
                }
                $orderZone = $pickupBranch->zone;
                $zoneBranchId = (int) $pickupBranch->id;
                // Everything zone-based below (currency, tax region) reads the branch's point.
                $latitude = $pickupBranch->latitude;
                $longitude = $pickupBranch->longitude;
            } else {
                // Resolve the delivery zone once (reused for min-order, currency snapshot).
                $orderZone = CommonHelper::getDeliverableCity($latitude, $longitude, $channel);

                // Fulfilling branch for this order/zone. Price is per-branch (PVSS), so the
                // pricing branch is the zone's active branch, falling back to the cart line's
                // pinned branch. Resolved once and reused for pricing + the item snapshot.
                $zoneBranchId = null;
                if ($orderZone) {
                    $zoneBranchId = Branch::where('zone_id', $orderZone->id)
                        ->where('status', Branch::$statusActive)
                        ->value('id');
                }
                // A pickup-only branch does not deliver.
                if ($zoneBranchId) {
                    $zoneBranch = Branch::find($zoneBranchId);
                    if ($zoneBranch && !$zoneBranch->offersDelivery()) {
                        return CommonHelper::responseError(__('branch_offers_pickup_only'));
                    }
                }
            }

            // Quick commerce can't place an order while the branch is closed
            if ($channel === 'quick' && $zoneBranchId) {
                $orderBranch = Branch::find($zoneBranchId);
                if ($orderBranch && !CommonHelper::isBranchOpenNow($orderBranch)) {
                    return CommonHelper::responseError(__('branch_is_closed'));
                }
            }
            $branchForVariant = function ($variant_id) use ($zoneBranchId, $cartBranchByVariant) {
                $row = $cartBranchByVariant[$variant_id] ?? null;
                return $zoneBranchId ?: (($row && !empty($row->branch_id)) ? (int) $row->branch_id : null);
            };

            $user_id = auth()->user()->id;
            $order_note = (isset($request->order_note) && !empty($request->order_note)) ? $request->order_note : "";
            $wallet_used = (isset($request->wallet_used) && !empty($request->wallet_used) == 'true') ? 'true' : 'false';

            // Items, quantities and subtotal are authoritative from the server cart.
            // Client-sent total / final_total / delivery_charge / surge / additional /
            // item lists are ignored to prevent price tampering.
            // Tax region first: pickup is supplied at the branch, delivery at the address.
            // The cart total must be priced with it, or it will not match the per-line
            // figures written on the order items below.
            $buyerRegionId = $isPickup
                ? ($orderZone->region_id ? (int) $orderZone->region_id : null)
                : ($user_address->region_id ? (int) $user_address->region_id : null);
            $cartData     = CommonHelper::getCartCount($user_id, $channel, $buyerRegionId);
            $item_arr     = array_values(array_filter(explode(",", (string) ($cartData->product_variant_id ?? '')), fn($v) => $v !== ''));
            $quantity_arr = explode(",", (string) ($cartData->quantity ?? ''));
            $sub_total    = (float) ($cartData->total_amount ?? 0); // tax-included subtotal
            $total        = $sub_total;

            // Surge / additional charges are recomputed from the zone below.
            $surge_charges      = [];
            $additional_charges = [];

            $promo_code = "";
            $promo_discount = 0;
            $promo_code_id = 0;
            $cashback_amount = 0;
            $promoFreeDelivery = 0;

            if (isset($request->promocode_id) && $request->promocode_id && $request->promocode_id != "") {

                $code = PromoCode::find($request->promocode_id);

                if (empty($code)) {
                    return CommonHelper::responseError("Promo code not found!");
                }
                $promo = CommonHelper::validatePromoCode($user_id, $code->promo_code, $sub_total, [
                    'latitude'      => $latitude ?? null,
                    'longitude'     => $longitude ?? null,
                    'channel'       => $channel ?? null,
                    'delivery_type' => $isPickup ? 'pickup' : 'delivery',
                ]);

                if ($promo['is_applicable'] == 0) {
                    return CommonHelper::responseError($promo['message']);
                }
                if ($isPickup && (int) ($promo['free_delivery'] ?? 0) === 1) {
                    return CommonHelper::responseError(__('free_delivery_coupon_not_applicable_for_pickup'));
                }

                if (isset($promo['promo_code_id']) && $request->promocode_id == $promo['promo_code_id']) {
                    // Wallet-type promo = cashback credited on delivery; it does NOT reduce the
                    // payable total. Instant-type reduces the total as before.
                    if (($promo['discount_apply_type'] ?? '') === 'wallet') {
                        $cashback_amount = $promo['discount'];
                        $promo_discount = 0;
                    } else {
                        $promo_discount = $promo['discount'];
                    }
                    $promo_code = $promo['promo_code'] . "(" . $promo['discount'] . ")";
                    $promo_code_id = $promo['promo_code_id'];
                    $promoFreeDelivery = (int) ($promo['free_delivery'] ?? 0);
                }
            }

            $wallet_balance = (isset($request->wallet_balance) && is_numeric($request->wallet_balance)) ? $request->wallet_balance : 0;
            $payment_method = $request->payment_method;

            // Only COD, pay-at-counter and the manually verified methods are accepted.
            if ($payment_method !== 'Wallet'
                && !(\App\Services\OfflinePayments::enabled((string) $payment_method, optional($orderZone)->country))) {
                return CommonHelper::responseError(__('payment_method_not_configured'));
            }

            $active_status = ($payment_method == Transaction::$paymentTypeCod || in_array($payment_method, \App\Services\OfflinePayments::ALL, true))
                ? OrderStatusList::$received : OrderStatusList::$paymentPending;
            if ($payment_method == 'Wallet') {
                $active_status = OrderStatusList::$received;
            }

            // Status-history snapshot stored on each order_item (order_items.status).
            $status[] = array($active_status, date("d-m-Y h:i:sa"));

            if (empty($item_arr)) {
                return CommonHelper::responseError(__('cart_is_empty'));
            }

            /* The authoritative list is one entry per CART ROW, not per variant: the same
               pizza with cheese and without are two lines of one variant, and every map
               below must keep them apart or the second one silently disappears between
               the cart and the invoice. */
            $cartLines = $cartData->lines ?? [];

            $demandByVariantBranch = [];
            $reservedByVariantBranch = [];
            foreach ($cartLines as $line) {
                $k = $line['variant_id'] . ':' . (int) $line['branch_id'];
                $demandByVariantBranch[$k]   = ($demandByVariantBranch[$k] ?? 0) + (int) $line['qty'];
                $reservedByVariantBranch[$k] = ($reservedByVariantBranch[$k] ?? 0) + (int) $line['qty'];
            }

            foreach ($demandByVariantBranch as $k => $requested_qty) {
                [$vid, $sid] = array_map('intval', explode(':', $k));
                $variant = ProductVariant::where("id", $vid)->first();

                // Check if the variant exists
                if (empty($variant)) {
                    return CommonHelper::responseError(__('found_one_or_more_items_in_order_is_not_available_for_order'));
                }

                $check_branch_id = $sid ?: null;
                $reservedForLine = (int) ($reservedByVariantBranch[$k] ?? 0);

                // Check stock availability (branch-wise)
                if (!ProductHelper::isItemAvailableWithStock(null, $vid, $requested_qty, $check_branch_id, $reservedForLine)) {
                    $available = ($check_branch_id
                        ? ProductHelper::branchAvailableStock($vid, $check_branch_id)
                        : ProductHelper::totalStock($vid)) + $reservedForLine;
                    return CommonHelper::responseError(__("Low stock: Only {$available} available for {$variant->product->name}"));
                }
            }

            $item_details = CommonHelper::getProductByVariantId($item_arr);

            // Price is per-branch (PVSS): copy each line's fulfilling-branch pricing onto
            // the in-memory variant so tax/subtotal/slab math reads the branch price.
            foreach ($item_details as $it) {
                ProductHelper::applyBranchPrice($it, $branchForVariant($it->id));
            }
            // Branch id aligned to $item_arr order for the savings calc below.
            $branch_arr = array_map(fn ($vid) => $branchForVariant((int) $vid), $item_arr);

            TaxService::warmFor(
                array_map(fn ($it) => (int) $it->product_id, $item_details->all()),
                $branch_arr
            );

            /* One resolved variant per id; each LINE gets its own copy, priced at its own
               branch. getProductByVariantId() deduplicates, so without the clone two lines
               of one variant would share — and overwrite — each other's figures. */
            $variantById = $item_details->keyBy('id');

            $taxByLine = [];
            $addonByLine = [];
            $order_total_tax_amt = 0.0;
            $taxable_value_total = 0.0;
            foreach ($cartLines as $line) {
                $cartId      = (int) $line['cart_id'];
                $lineBranchId = $branchForVariant((int) $line['variant_id']);
                $lineQty     = max(1, (int) $line['qty']);

                $it = $variantById[$line['variant_id']] ?? null;
                if (!$it) {
                    return CommonHelper::responseError(__('found_one_or_more_items_in_order_is_not_available_for_order'));
                }
                $it = clone $it;
                ProductHelper::applyBranchPrice($it, $lineBranchId);

                $addonSelections = AddonHelper::parse($line['addons'] ?? []);
                $check = AddonHelper::validate((int) $line['product_id'], $lineBranchId, $addonSelections, $lineQty);
                if (!$check['ok']) {
                    return CommonHelper::responseErrorWithData($check['error'], $it->product_name ?? '');
                }

                $addons = AddonHelper::describe($addonSelections, $lineBranchId);
                if (!empty($addons['unavailable'])) {
                    return CommonHelper::responseErrorWithData(
                        __('addon_option_not_available_at_this_branch'),
                        $it->product_name ?? ''
                    );
                }
                $addonUnit = (float) $addons['unit'];
                $addonByLine[$cartId] = $addons;

                // The addon sits INSIDE the unit price: qty * unit == sub_total is what
                // every invoice, report and refund downstream assumes.
                $lineUnit = (float) ProductHelper::lineUnitPrice($it, $lineQty, $addonUnit);

                $resolved = TaxService::forProduct((int) $it->product_id, $lineBranchId, $buyerRegionId);
                // applyBranchPrice() put this on $it from the line's branch price row.
                $lineInclusive = (bool) ($it->is_tax_inclusive ?? false);
                $calc = TaxService::calculate(
                    $lineUnit * $lineQty,
                    $resolved['components'] ?? [],
                    $lineInclusive
                );

                $taxByLine[$cartId] = [
                    'calc'      => $calc,
                    'resolved'  => $resolved,
                    'unit'      => $lineUnit,
                    'addon'     => $addonUnit,
                    'variant'   => $it,
                    'branch_id'  => $lineBranchId,
                    'qty'       => $lineQty,
                    'inclusive' => $lineInclusive,
                ];
                $order_total_tax_amt += $calc['tax'];
                $taxable_value_total += $calc['taxable'];
            }
            $order_total_tax_amt = round($order_total_tax_amt, 2);
            $taxable_value_total = round($taxable_value_total, 2);
            // Display-only blended rate. The old code SUMMED each line's percentage, so a
            // two-line 18% order reported 36%; the honest figure is tax over taxable value.
            $order_total_tax_per = $taxable_value_total > 0
                ? round($order_total_tax_amt / $taxable_value_total * 100, 2)
                : 0;

            // Savings vs base price (MRP) — same calc the cart exposes as saved_amount.
            $amountTotals = CommonHelper::calculateTotalAmount($item_arr, $quantity_arr, $branch_arr);
            $saved_amount = max(0, $amountTotals['save_price'] - $amountTotals['total_amount']);

            $generate_otp = Setting::get_value("generate_otp");

            if ($generate_otp == 1 && !$isPickup) {
                $otp_number = mt_rand(100000, 999999);
            } else {
                $otp_number = 0;
            }

            /* check for wallet balance — wallets are country-wise (user_wallets),
               the order's country comes from the delivery location's zone. */
            $orderCountryId = $orderZone ? (int) ($orderZone->country_id ?? 0) : 0;
            if ($wallet_used == 'true') {
                $user_wallet_balance = CommonHelper::getUserWalletBalance(auth()->user()->id, $orderCountryId ?: null);
                if ($user_wallet_balance < $wallet_balance) {
                    return CommonHelper::responseError('insufficient_wallet_balance');
                }
            }

            /* Recompute delivery + surge + additional charges from the zone — never
               trust client amounts. free_delivery promo zeroes only delivery_charge. */
            // At placement the payment method IS known, so a courier-priced zone quotes
            // the COD rate when that is what the customer chose.
            $courierContext = $isPickup ? [] : CommonHelper::courierContextFor(
                $cartItems,
                $address_id ? (int) $address_id : null,
                $payment_method == Transaction::$paymentTypeCod,
                (string) (optional(optional($orderZone)->country)->code ?? '') ?: null
            );
            $deliveryResp = $isPickup
                ? CommonHelper::getPickupCharges($orderZone, $channel, $buyerRegionId)
                : CommonHelper::getAllDeliveryCharge($latitude, $longitude, $cartBranchIds, $sub_total, $channel, $buyerRegionId, $courierContext);
            if (($deliveryResp['status'] ?? 0) == 0 && !isDemoMode()) {
                return CommonHelper::responseError($deliveryResp['message'] ?? __('sorry_we_are_not_delivering_on_selected_address'));
            }
            $deliveryData       = $deliveryResp['data'] ?? [];
            $delivery_charge    = $promoFreeDelivery ? 0 : (float) ($deliveryData['total_delivery_charge'] ?? 0);
            $surge_total        = (float) ($deliveryData['surge_total'] ?? 0);
            $additional_total   = (float) ($deliveryData['additional_total'] ?? 0);
            $surge_charges      = $deliveryData['surge_charges'] ?? [];
            $additional_charges = $deliveryData['additional_charges'] ?? [];

            // Gifting: the chosen delivery type (express, midnight...) can carry an extra charge.
            $giftType = trim((string) $request->input('gift_delivery_type', ''));
            if ($giftType !== '') {
                $gt = DB::table('gift_delivery_types')->where('slug', $giftType)->where('status', 1)->first();
                if (!$gt) {
                    return CommonHelper::responseError('Invalid delivery type.');
                }
                if ((float) $gt->extra_charge > 0) {
                    $additional_total += (float) $gt->extra_charge;
                    $additional_charges[] = [
                        'name' => $gt->name, 'amount' => (float) $gt->extra_charge, 'tax_amount' => 0,
                        'tax_name' => null, 'tax_rate' => 0, 'is_refundable' => false,
                    ];
                }
            }

            // Scheduled delivery: date + time slot (validated: window, closures, lead time, capacity).
            $scheduling = app(\App\Services\DeliverySchedulingService::class);
            $schedule = $scheduling->resolve($request->input('delivery_date'), $request->input('delivery_slot_id'), $giftType ?: null);
            if (!$schedule['ok']) {
                return CommonHelper::responseError($schedule['message']);
            }
            if ($schedule['extra'] > 0) {
                $additional_total += $schedule['extra'];
                $additional_charges[] = [
                    'name' => $schedule['extra_name'] ?? 'Time slot', 'amount' => $schedule['extra'], 'tax_amount' => 0,
                    'tax_name' => null, 'tax_rate' => 0, 'is_refundable' => false,
                ];
            }

            // Gross order value (before wallet).
            $gross_total = $sub_total + $delivery_charge + $surge_total + $additional_total - $promo_discount;
            $gross_total = $gross_total < 0 ? 0 : $gross_total;

            // Wallet amount actually applied (never more than the order value).
            $walletvalue = ($wallet_used == 'true') ? min((float) $wallet_balance, (float) $gross_total) : 0;

            $final_total = round(max(0, $gross_total - $walletvalue), 2);

            // Wallet covers the entire order -> paid at placement (like a Wallet
            // payment) even if an online method was selected. Mark received + finalize now
            // (deduct wallet, notify, no gateway) instead of leaving it payment-pending.
            $walletFullyPays = ($wallet_used == 'true' && (float) $gross_total > 0 && $final_total <= 0);
            if ($walletFullyPays) {
                $active_status = OrderStatusList::$received;
            }
            // Payments settled at placement (no gateway round-trip needed).
            $immediatePayment = ($payment_method == Transaction::$paymentTypeCod
                || in_array($payment_method, \App\Services\OfflinePayments::ALL, true)
                || $payment_method == Transaction::$paymentTypeWallet
                || $walletFullyPays);

            /* Minimum order amount: quick orders honour the delivery zone's
               minimum_order_amount (when set) — checked against the gross order
               value (wallet portion included). */
            if ($channel === 'quick' && !$isPickup) {
                $zoneMinOrder = $orderZone ? (float) ($orderZone->minimum_order_amount ?? 0) : 0;
                if ($zoneMinOrder > 0 && $gross_total < $zoneMinOrder) {
                    return CommonHelper::responseError("Minimum order amount is " . $zoneMinOrder . ".");
                }
            }

            $branch_ids = array_values(array_unique(array_filter(array_column($item_details->toArray(), "branch_id"))));
            if (empty($branch_ids)) {
                return CommonHelper::responseError(__('found_one_or_more_items_in_order_is_not_available_for_order'));
            }
            if (!$isPickup && !CommonHelper::isDeliverableOrder($latitude, $longitude, $branch_ids[0], $channel) && !isDemoMode()) {
                return CommonHelper::responseError(__('sorry_we_are_not_delivering_on_selected_address'));
            }

            /* insert data into order table */
            DB::beginTransaction();
            try {
                // Re-check the slot under a row lock so two simultaneous orders cannot overbook it.
                $schedule = $scheduling->resolve($request->input('delivery_date'), $request->input('delivery_slot_id'), $giftType ?: null, true);
                if (!$schedule['ok']) {
                    DB::rollBack();
                    return CommonHelper::responseError($schedule['message']);
                }

                $order = new Order();
                $order->user_id = $user_id;
                $order->delivery_boy_id = 0;
                $order->transaction_id = 0;
                $order->otp = ($channel === 'ecommerce') ? 0 : $otp_number;
                $order->mobile = $mobile;
                $order->order_note = $order_note;
                foreach (['recipient_name', 'recipient_phone', 'recipient_relationship', 'occasion',
                    'gift_delivery_type', 'gift_message', 'sender_name', 'personalization'] as $giftField) {
                    $order->{$giftField} = $request->input($giftField);
                }
                foreach ($schedule['data'] as $col => $val) {
                    $order->{$col} = $val;
                }
                $order->is_surprise = $request->boolean('is_surprise');
                $order->total = $total;
                $order->remaining_total = $total;
                $order->delivery_charge = $delivery_charge;
                $order->tax_amount = $order_total_tax_amt;
                $order->tax_percentage = $order_total_tax_per;
                $order->taxable_value = $taxable_value_total;
                $order->buyer_region_id = $buyerRegionId;
                $order->place_of_supply = TaxService::placeOfSupplyLabel($buyerRegionId);
                $order->wallet_balance = $walletvalue;
                $order->paid_wallet = $walletvalue;
                $order->promo_code_id = $promo_code_id;
                $order->promo_code = $promo_code;
                $order->promo_discount = $promo_discount;
                $order->cashback_amount = $cashback_amount;
                $order->saved_amount = $saved_amount;
                $order->final_total = $final_total;
                $order->remaining_final = $final_total;
                $order->payment_method = $payment_method;
                if (\App\Services\OfflinePayments::isManual($payment_method)) {
                    $order->payment_verification = 'pending';
                }
                if ($isPickup) {
                    $bill = !empty($user_address)
                        ? [
                            'name'      => $addressData['name'],
                            'mobile'    => $mobile,
                            'address'   => $addressData['address'],
                            'city'      => (string) ($user_address->city ?? ''),
                            'state'     => (string) ($user_address->state ?? ''),
                            'pincode'   => (string) ($user_address->pincode ?? ''),
                            'country'   => (string) ($user_address->country ?? ''),
                            'region_id' => $user_address->region_id ? (int) $user_address->region_id : null,
                        ]
                        : $billingAddressData + [
                            'city'      => trim((string) $request->input('billing_city', '')),
                            'state'     => trim((string) $request->input('billing_state', '')),
                            'pincode'   => trim((string) $request->input('billing_pincode', '')),
                            'country'   => trim((string) $request->input('billing_country', '')),
                            'region_id' => $request->filled('billing_region_id') ? (int) $request->billing_region_id : null,
                        ];
                    if (!empty($bill['mobile'])) {
                        $order->mobile = $bill['mobile'];
                    }
                    $order->address = $bill + [
                        'alternate_mobile'         => '',
                        'pickup'                   => 1,
                        'branch_id'                 => (int) $pickupBranch->id,
                        'billing_same_as_shipping' => 1,
                    ];
                } else {
                    $order->address = $billingSameAsShipping
                        ? $addressData + ['billing_same_as_shipping' => 1]
                        : $addressData + ['billing_same_as_shipping' => 0, 'billing' => $billingAddressData];
                }

                /* Buyer tax identity, frozen on the order — the only copy there is.
                   The LABEL is stored with the number: a country's wording can be edited
                   later, and an invoice that silently relabels a GSTIN as a VAT number is
                   a document nobody can rely on. */
                $buyerTaxNumber = BuyerTaxIdentity::normalize($request->input('buyer_tax_number'));
                if ($buyerTaxNumber !== '') {
                    $order->buyer_tax_number = $buyerTaxNumber;
                    $order->buyer_tax_label = BuyerTaxIdentity::config($buyerTaxCountryId)['label'];
                }
                $buyerBusinessName = trim((string) $request->input('buyer_business_name', ''));
                if ($buyerBusinessName !== '') {
                    $order->buyer_business_name = $buyerBusinessName;
                }

                $order->delivery_pincode = $isPickup
                    ? null
                    : (trim((string) ($addressData['pincode'] ?? '')) ?: null);

                $order->delivery_type = $deliveryType;
                $order->active_status = $active_status;
                $order->channel = $channel;
                // Country/zone stamp + currency snapshot (currency is country-wise now, so
                // history stays correct even if the country's currency is later edited).
                $orderCountry = $orderZone ? $orderZone->country : null;
                $order->country_id = $orderCountry->id ?? null;
                $order->zone_id = $orderZone->id ?? null;
                $order->currency = $orderCountry->currency ?? null;
                $order->currency_code = $orderCountry->currency_code ?? null;
                $order->address_id = $address_id;
                // Both are array-cast on the model, so assign the arrays directly —
                // json_encode()ing surge_charges here double-encoded it.
                $order->additional_charges = $additional_charges;
                $order->surge_charges = $surge_charges;
                $order->save();

                $order_id = $order->id;
                if ($order_id == "") {
                    return CommonHelper::responseError(__('order_can_not_place_due_to_some_reason_try_again_after_some_time'));
                }

                $order->order_number = CommonHelper::formatNumber(Setting::get_value('order_prefix') ?: 'ORD-', $order_id);
                $orderInvoiceNumber = CommonHelper::formatNumber(Setting::get_value('invoice_prefix') ?: 'INV-', $order_id);
                $order->invoice_number = $orderInvoiceNumber;
                $order->saveQuietly();
                /* Pre-pass: compute each line's amounts + sub_total (needed to split
                   the order's charges proportionally for ecommerce). Price/cost are
                   per-branch (PVSS) and already copied onto $item_details above via the
                   line's fulfilling branch; that branch is also recorded on the item. */
                $lines = [];
                foreach ($cartLines as $key => $cartLine) {
                    $cartId             = (int) $cartLine['cart_id'];
                    $lineTax            = $taxByLine[$cartId] ?? null;
                    $item               = $lineTax['variant'] ?? null;
                    if (!$item) {
                        return CommonHelper::responseError(__('found_one_or_more_items_in_order_is_not_available_for_order'));
                    }
                    $product_variant_id = $item->id;
                    $lineBranchId = $lineTax['branch_id'] ?? $branchForVariant((int) $product_variant_id);
                    // Stock was reserved against the cart line's branch at add-to-cart;
                    // the commit must release from that same branch.
                    $cartRow = $cartLineById[$cartId] ?? null;
                    $cartBranchId = ($cartRow && !empty($cartRow->branch_id)) ? (int) $cartRow->branch_id : $lineBranchId;
                    $addonUnit = (float) ($lineTax['addon'] ?? 0);
                    $addonSnapshot = $addonByLine[$cartId]['lines'] ?? [];
                    // The comparison price carries the addon too, or discounted_price
                    // would sit above it and the item would look like it had no offer.
                    $price = (float) $item->price + $addonUnit;

                    $purchase_price = (float) ($item->purchase_price ?? 0)
                        + AddonHelper::snapshotCost($addonSnapshot, $cartBranchId);
                    $quantity = (int) ($lineTax['qty'] ?? $cartLine['qty'] ?? 1);
                    // Slab-aware effective pre-tax unit price, addons folded in; recorded
                    // as discounted_price when it beats the base so tax/subtotal math
                    // reflects the slab.
                    $effectiveUnit = (float) ($lineTax['unit'] ?? ProductHelper::lineUnitPrice($item, $quantity, $addonUnit));
                    $discounted_price = ($effectiveUnit < (float) $price) ? $effectiveUnit : 0;
                    $lineCalc       = $lineTax['calc'] ?? ['taxable' => $effectiveUnit * $quantity, 'tax' => 0.0, 'rate' => 0.0, 'lines' => []];
                    $lineResolved   = $lineTax['resolved'] ?? null;
                    $tax_percentage = (float) $lineCalc['rate'];
                    $line_tax_total = (float) $lineCalc['tax'];
                    // tax_amount stays PER-UNIT: getOrderDetails() and the return flow both
                    // read it that way. tax_total carries the line figure.
                    $tax_amt        = $quantity > 0 ? round($line_tax_total / $quantity, 4) : 0;
                    $item_sub_total = round((float) $lineCalc['taxable'] + $line_tax_total, 2);
                    $lineBranch     = $lineResolved['branch'] ?? null;
                    $lines[] = [
                        'cart_id'      => $cartId,
                        'variant_id'   => $product_variant_id,
                        'addons'       => $addonSnapshot,
                        // Display and reporting only — the money is already inside
                        // price / discounted_price / sub_total.
                        'addon_total'  => round($addonUnit * $quantity, 2),
                        'product_name' => $item->product_name,
                        'hsn_code'     => $item->hsn_code ?? null,
                        'price'        => $price,
                        'purchase_price' => $purchase_price,
                        'quantity'     => $quantity,
                        'discounted'   => $discounted_price,
                        'tax_pct'      => $tax_percentage,
                        'tax_amt'      => $tax_amt,
                        'tax_total'    => round($line_tax_total, 2),
                        'taxable_value' => round((float) $lineCalc['taxable'], 2),
                        'tax_lines'    => $lineCalc['lines'],
                        'tax_rule_id'  => $lineResolved['rule_id'] ?? null,
                        'tax_inclusive' => (bool) ($lineTax['inclusive'] ?? false),
                        'branch_region_id'  => $lineBranch['region_id'] ?? null,
                        'branch_tax_number' => $lineBranch['tax_number'] ?? null,
                        'sub_total'    => $item_sub_total,
                        'cart_branch'   => $cartBranchId,
                        'branch_id'     => $lineBranchId ?? "",
                        'cancelable_status' => (int) ($item->cancelable_status ?? 0),
                        'till_status'       => (($channel === 'quick' || $isPickup) ? $item->till_status_quick : $item->till_status_ecommerce) ?? 0,
                        'return_status'     => (int) ($item->return_status ?? 0),
                        'return_days'       => (int) ($item->return_days ?? 0),
                    ];
                }

                // Ecommerce orders are item-wise: split each order-level charge across
                // items by sub_total (last item absorbs rounding). Quick stays order-wise.
                $isEcommerce = ($channel === 'ecommerce');
                $weights = array_column($lines, 'sub_total');

                if ($promo_discount > 0 && array_sum($weights) > 0) {
                    $taxCut = CommonHelper::splitByWeight($weights, (float) $promo_discount);

                    foreach ($lines as $i => $ln) {
                        $share = (float) ($taxCut[$i] ?? 0);

                        if ($share <= 0 || (float) $ln['tax_total'] <= 0) {
                            continue;
                        }

                        $components = $taxByLine[(int) $ln['cart_id']]['resolved']['components'] ?? [];
                        $discounted = max(0, round((float) $ln['sub_total'] - $share, 2));
                        $calc = TaxService::calculate($discounted, $components, true);
                        $qty = (int) $ln['quantity'];

                        $lines[$i]['tax_total']     = round((float) $calc['tax'], 2);
                        $lines[$i]['taxable_value'] = round((float) $calc['taxable'], 2);
                        $lines[$i]['tax_lines']     = $calc['lines'];
                        $lines[$i]['tax_amt']       = $qty > 0 ? round((float) $calc['tax'] / $qty, 4) : 0;
                    }

                    $order_total_tax_amt = round(array_sum(array_column($lines, 'tax_total')), 2);
                    $taxable_value_total = round(array_sum(array_column($lines, 'taxable_value')), 2);
                    $order_total_tax_per = $taxable_value_total > 0
                        ? round($order_total_tax_amt / $taxable_value_total * 100, 2)
                        : 0;

                    $order->tax_amount     = $order_total_tax_amt;
                    $order->taxable_value  = $taxable_value_total;
                    $order->tax_percentage = $order_total_tax_per;
                    $order->saveQuietly();
                }

                $deliveryShares = $promoShares = [];
                $addlPerItem = $surgePerItem = array_fill(0, count($lines), []);
                $walletShares = [];
                if ($isEcommerce) {
                    $deliveryShares = CommonHelper::splitByWeight($weights, (float) $delivery_charge);
                    $promoShares    = CommonHelper::splitByWeight($weights, (float) $promo_discount);
                    $walletShares   = CommonHelper::splitByWeight($weights, (float) $walletvalue);
                    foreach ((array) $additional_charges as $c) {
                        $amts = CommonHelper::splitByWeight($weights, (float) ($c['amount'] ?? 0));
                        $taxes = CommonHelper::splitByWeight($weights, (float) ($c['tax_amount'] ?? 0));
                        foreach ($amts as $i => $a) {
                            if ($a != 0) {
                                $addlPerItem[$i][] = [
                                    'name'          => $c['name'] ?? '',
                                    'amount'        => $a,
                                    'tax_amount'    => (float) ($taxes[$i] ?? 0),
                                    'tax_name'      => $c['tax_name'] ?? null,
                                    'tax_rate'      => (float) ($c['tax_rate'] ?? 0),
                                    'is_refundable' => (bool) ($c['is_refundable'] ?? false),
                                ];
                            }
                        }
                    }
                    foreach ((array) $surge_charges as $s) {
                        $amts = CommonHelper::splitByWeight($weights, (float) ($s['charge'] ?? 0));
                        $taxes = CommonHelper::splitByWeight($weights, (float) ($s['tax_amount'] ?? 0));
                        foreach ($amts as $i => $a) {
                            if ($a != 0) {
                                $surgePerItem[$i][] = [
                                    'label'         => $s['label'] ?? '',
                                    'charge'        => $a,
                                    'tax_amount'    => (float) ($taxes[$i] ?? 0),
                                    'tax_name'      => $s['tax_name'] ?? null,
                                    'tax_rate'      => (float) ($s['tax_rate'] ?? 0),
                                    'is_refundable' => (bool) ($s['is_refundable'] ?? false),
                                ];
                            }
                        }
                    }
                }

                $order_item_status = json_encode($status);
                foreach ($lines as $i => $ln) {
                    $order_item = new OrderItem();
                    $order_item->user_id = $user_id;
                    $order_item->order_id = $order_id;
                    $order_item->invoice_number = $orderInvoiceNumber . '-' . ($i + 1);
                    $order_item->product_name = $ln['product_name'];
                    $order_item->hsn_code = $ln['hsn_code'];
                    // Snapshot the variant's attribute name/value pairs.
                    $order_item->variant_attributes = ProductVariantAttributeValue::with(['attribute', 'attributeValue'])
                        ->where('product_variant_id', $ln['variant_id'])->get()
                        ->map(fn($av) => [
                            'name'  => $av->attribute ? (string) $av->attribute->name : '',
                            'value' => $av->attributeValue ? (string) $av->attributeValue->value : '',
                        ])
                        ->filter(fn($a) => $a['name'] !== '' || $a['value'] !== '')
                        ->values()->all();
                    $order_item->product_variant_id = $ln['variant_id'];
                    // Snapshot this item's prescription (medical items only; validated above).
                    $order_item->prescription = isset($prescriptionPaths[$ln['variant_id']])
                        ? CommonHelper::uploadFile($prescriptionPaths[$ln['variant_id']], null, 'prescription')
                        : null;
                    $order_item->quantity = $ln['quantity'];
                    $order_item->price = $ln['price'];
                    $order_item->discounted_price = $ln['discounted'];
                    $order_item->purchase_price = $ln['purchase_price'];
                    $order_item->tax_amount = $ln['tax_amt'];
                    $order_item->tax_percentage = $ln['tax_pct'];
                    $order_item->tax_total = $ln['tax_total'];
                    $order_item->taxable_value = $ln['taxable_value'];
                    $order_item->is_tax_inclusive = $ln['tax_inclusive'] ? 1 : 0;
                    $order_item->branch_region_id = $ln['branch_region_id'];
                    $order_item->branch_tax_number = $ln['branch_tax_number'];
                    $order_item->sub_total = $ln['sub_total'];
                    /* Resolved NAMES, not just ids: renaming or deleting an option later
                       must not rewrite what this customer ordered. The amount is already
                       inside price / discounted_price / sub_total — addon_total exists so
                       the invoice can show it, and nothing does arithmetic with it. */
                    $order_item->addons = $ln['addons'] ?: null;
                    $order_item->addon_total = $ln['addon_total'];
                    $order_item->status = $order_item_status;
                    $order_item->active_status = $active_status;
                    $order_item->branch_id = $ln['branch_id'];
                    // Frozen cancel/return policy (snapshot at placement).
                    $order_item->cancelable_status = $ln['cancelable_status'];
                    $order_item->till_status = $ln['till_status'];
                    $order_item->return_status = $ln['return_status'];
                    $order_item->return_days = $ln['return_days'];

                    if ($isEcommerce) {
                        $itemDelivery   = $deliveryShares[$i] ?? 0;
                        $itemAddl       = $addlPerItem[$i] ?? [];
                        $itemSurge      = $surgePerItem[$i] ?? [];
                        $itemAddlTotal  = array_sum(array_column($itemAddl, 'amount'));
                        $itemSurgeTotal = array_sum(array_column($itemSurge, 'charge'));
                        $itemPromo      = $promoShares[$i] ?? 0;
                        $itemWallet     = $walletShares[$i] ?? 0;
                        $itemFinal = round(max(0, $ln['sub_total'] + $itemDelivery + $itemAddlTotal + $itemSurgeTotal - $itemPromo - $itemWallet), 2);
                        $order_item->delivery_charge    = $itemDelivery;
                        $transitDays = $isPickup ? 0 : (int) ($orderZone->ecommerce_delivery_days ?? 0);
                        $order_item->estimated_delivery_date = $transitDays > 0
                            ? now()->addDays($transitDays)->toDateString()
                            : null;
                        $order_item->additional_charges = $itemAddl;
                        $order_item->surge_charges      = $itemSurge;
                        $order_item->promo_discount     = $itemPromo;
                        $order_item->wallet_balance     = $itemWallet;
                        $order_item->final_total        = $itemFinal;
                        // Per-item OTP for ecommerce (each item has its own delivery boy).
                        $order_item->otp = ($generate_otp == 1 && !$isPickup) ? mt_rand(100000, 999999) : 0;
                    } else {
                        // Quick orders: OTP lives on orders.otp — items always 0.
                        $order_item->otp = 0;
                    }
                    $order_item->save();

                    if (!empty($ln['tax_lines'])) {
                        $taxLineRows = [];
                        foreach ($ln['tax_lines'] as $tl) {
                            $taxLineRows[] = [
                                'order_id'       => $order_id,
                                'order_item_id'  => $order_item->id,
                                'tax_rule_id'    => $ln['tax_rule_id'],
                                'component_name' => $tl['name'],
                                'rate'           => $tl['rate'],
                                'taxable_value'  => $tl['taxable_value'],
                                'amount'         => $tl['amount'],
                                'source'         => 'item',
                                'source_ref'     => null,
                                'hsn_code'       => $ln['hsn_code'],
                                'is_reversal'    => 0,
                                'created_at'     => now(),
                            ];
                        }
                        OrderItemTax::insert($taxLineRows);
                    }

                    // Ecommerce is item-wise: seed each item's status history so its
                    // timeline isn't empty at placement.
                    if ($isEcommerce) {
                        CommonHelper::setOrderStatus([
                            'order_id'      => $order_id,
                            'order_item_id' => $order_item->id,
                            'status'        => $active_status,
                            'created_by'    => $user_id,
                            'user_type'     => OrderStatus::$userTypeUser,
                        ]);
                    }

                    // Stock reservation is committed (reserved -= qty) only when payment
                    // is settled at placement (COD / Wallet). For online gateway orders the
                    // stock stays RESERVED until the payment is confirmed — committed then in
                    // the success handler, or released if the pending order is abandoned.
                    if ($immediatePayment) {
                        ProductHelper::commitReservedStock($ln['variant_id'], $ln['cart_branch'], $ln['quantity']);
                        // Linked addons settle against the same branch their reservation
                        // was taken from, or the Coke stays reserved for ever.
                        AddonHelper::applyStock(
                            AddonHelper::snapshotDemand($ln['addons'] ?? []),
                            $ln['cart_branch'],
                            (int) $ln['quantity'],
                            'commit'
                        );
                    }
                }

                $chargeTaxRows = [];
                $pushChargeTax = function (array $lines, string $source, ?string $ref) use (&$chargeTaxRows, $order_id) {
                    foreach ($lines as $line) {
                        $chargeTaxRows[] = [
                            'order_id'       => $order_id,
                            'order_item_id'  => null,
                            'tax_rule_id'    => null,
                            'component_name' => $line['name'],
                            'rate'           => $line['rate'],
                            'taxable_value'  => $line['taxable_value'],
                            'amount'         => $line['amount'],
                            'source'         => $source,
                            'source_ref'     => $ref,
                            'hsn_code'       => null,
                            'is_reversal'    => 0,
                            'created_at'     => now(),
                        ];
                    }
                };
                if (!$promoFreeDelivery) {
                    $pushChargeTax($deliveryData['delivery_charge_tax_lines'] ?? [], 'delivery', null);
                }
                // Charge rows carry only tax_name/tax_rate; the component split arrives
                // flattened, each line already tagged with the row it belongs to.
                foreach (($deliveryData['surge_tax_lines'] ?? []) as $sl) {
                    $pushChargeTax([$sl], 'surge', $sl['source_ref'] ?? null);
                }
                foreach (($deliveryData['additional_tax_lines'] ?? []) as $al) {
                    $pushChargeTax([$al], 'additional', $al['source_ref'] ?? null);
                }
                if (!empty($chargeTaxRows)) {
                    OrderItemTax::insert($chargeTaxRows);
                }

                // Cart clearing is payment-timing aware:
                //  - COD / Wallet / wallet-fully-paid (immediate): consume the cart now.
                //  - Online gateway: KEEP the cart until the payment is confirmed
                //    (cleared in addTransaction / gateway webhooks when the order is
                //    marked received) so the customer can retry a failed payment.
                if ($immediatePayment) {
                    // By cart ROW id: deleting by variant would also take the customer's
                    // other line of the same item, the one with different addons.
                    Cart::where('user_id', $user_id)
                        ->whereIn('id', array_column($lines, 'cart_id'))
                        ->delete();
                }

                if ($wallet_used == 'true' && $immediatePayment) {
                    /* deduct the balance & set the wallet transaction for payments settled at placement
                       (COD/Wallet, or online fully covered by wallet). For online payments still awaiting
                       a gateway charge, wallet is deducted after confirmation in addTransaction/webhook.
                       Wallet is country-wise — deduct from the order's country wallet. */
                    $walletCountryId = $order->country_id;
                    $curBal = CommonHelper::getUserWalletBalance($user_id, $walletCountryId);
                    $new_balance = $curBal < $walletvalue ? 0 : $curBal - $walletvalue;
                    CommonHelper::updateUserWalletBalance($new_balance, $user_id, $walletCountryId);
                    CommonHelper::addWalletTransaction($order_id, 0, $user_id, 'debit', $walletvalue, 'wallet_used_against_order_placement', 1, Transaction::$paymentTypeWallet);
                }

                DB::commit();
            } catch (\Exception $e) {
                DB::rollBack();
                throw $e;
            }
            if (!empty($order) && $immediatePayment) {
                try {
                    dispatch(function () use ($order) {
                        //push notification
                        CommonHelper::sendNotificationOrderStatus($order);
                        // Send notifications to super admin (role_id=1) and branches (role_id=3) whose items are in the order
                        CommonHelper::sendOrderNotificationsToAdmins($order, 'new_order', $order->delivery_boy_id ?? null);
                    })->afterResponse();
                } catch (\Exception $e) {
                    Log::error("Place orderNotification error :", [$e->getMessage()]);
                }
                try {

                    Log::info("Place order send mail :", [$order]);
                    dispatch(new SendEmailJob($order))->afterResponse();
                } catch (\Exception $e) {
                    Log::error("Place order Send mail error :", [$e->getMessage()]);
                }

                //Place Order Send SMS
                try {
                    CommonHelper::sendSmsOrderStatus($order, $order->active_status);
                } catch (\Exception $e) {
                    Log::error("Place order SMS error :", [$e->getMessage()]);
                }
            }

            if ($immediatePayment) {
                $order_status = array();
                $order_status['order_id'] = $order->id;
                $order_status['order_item_id'] = 0;
                $order_status['status'] = OrderStatusList::$received;
                $order_status['created_by'] = $user_id;
                $order_status['user_type'] = OrderStatus::$userTypeUser;
                CommonHelper::setOrderStatus($order_status);
            }

            $responseData = [
                'order_id'      => $order->id,
                'order_item_id' => optional($order->items()->orderBy('id')->first())->id,
            ];
            return CommonHelper::responseSuccessWithData(__('order_placed_successfully'), $responseData);
        } catch (\Exception $e) {
            Log::error("Place order error :", [$e->getMessage()]);
            return CommonHelper::responseError(__('could_not_place_order_try_again'));
        }
    }

    public function deletePaymentPendingOrder(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_id' => 'required'
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $order = Order::find($request->order_id);

        if (empty($order)) {
            return CommonHelper::responseError("Order Not found!");
        }

        if ($order->active_status != OrderStatusList::$paymentPending) {
            $statusName = OrderStatusList::where('id', $order->active_status)->value('status');
            return CommonHelper::responseError("Now you order status is " . $statusName);
        }

        DB::beginTransaction();
        try {
            // Retrieve the order items before deletion
            $orderItems = OrderItem::where('order_id', $request->order_id)->get();

            // Delete the order items
            OrderItem::where('order_id', $request->order_id)->delete();

            // Payment-pending orders are ONLINE + unpaid, so their stock is still
            // RESERVED (never committed). Release it: reserved -= qty, available += qty.
            foreach ($orderItems as $item) {
                ProductHelper::releaseStock($item->product_variant_id, $item->branch_id, (int) $item->quantity);
                AddonHelper::moveOrderItemStock($item, 'release');
            }
            $order->delete();

            DB::commit();
        } catch (\Exception $e) {
            DB::rollBack();
            Log::info("Error : " . $e->getMessage());
            throw $e;
            return CommonHelper::responseError(__('something_went_wrong'));
        }
        return CommonHelper::responseSuccess(__('order_deleted_successfully'));
    }

    public function initiateTransaction(Request $request)
    {
        // Online gateways are retired: payments are COD / counter / manually verified only.
        return CommonHelper::responseError(__('payment_method_not_configured'));

        $validator = Validator::make($request->all(), [
            'payment_method' => 'required',
            'type' => 'required|in:order,wallet',
            'order_id' => 'required_if:type,order',
            'wallet_amount' => 'required_if:type,wallet',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        // Gateways + currency are zone-wise. For an order, use the order's zone; for a
        // wallet recharge (no order) the app must send the current location.
        $channel = strtolower(trim((string) $request->header('channel')));
        $channel = in_array($channel, ['quick', 'ecommerce'], true) ? $channel : null;
        if ($request->type == 'order') {
            $order = Order::with('user')->where('id', $request->order_id)
                ->first();
            if (!$order) {
                return CommonHelper::responseError("Order not found!");
            }
            $zone = CommonHelper::resolveOrderZone($order);
        } else {
            if (!$request->filled('latitude') || !$request->filled('longitude')) {
                return CommonHelper::responseError(__('location_required_for_wallet_recharge'));
            }
            $zone = CommonHelper::getDeliverableCity($request->latitude, $request->longitude, $channel);
        }
        if (!$zone) {
            return CommonHelper::responseError(__('not_deliverable_to_this_location'));
        }
        $gateways     = CommonHelper::countryPaymentGateways($zone?->country);
        $currencyCode = $zone->currency_code ?: 'INR';
        // Country the payment is charged in (recharge credits this country's wallet).
        $paymentCountryId = $zone->country_id ?? null;

        $out['payment_method'] = $request->payment_method;

        $transaction_id = "";

        if ($request->payment_method == "Razorpay") {

            Log::error("payment_method = " . $request->payment_method);

            $transaction_id = TransactionHelper::createOrderonRazorpay($request->type, $request->order_id ?? 0, $request->wallet_amount ?? 0, $gateways, $currencyCode);
            if ($transaction_id == "") {
                return CommonHelper::responseError("Error while communicating with razorpay server");
            }
        } else if ($request->payment_method == "Paypal") {

            $paypal = new PaypalService($gateways);
            if (!$paypal->isConfigured()) {
                return CommonHelper::responseError(__('payment_method_not_configured'));
            }

            $userId = auth()->user()->id;
            $fromWebsite = $request->request_from == 'website';

            if ($request->type == 'order') {
                $order = Order::where('id', $request->order_id)->first();
                if (!$order) {
                    return CommonHelper::responseError("Order not found!");
                }
                $amount = (float) $order->final_total;

                $customId = (string) $order->id;
            } else {
                $amount = (float) $request->wallet_amount;
                $customId = 'wallet_recharge-' . $userId . CommonHelper::rechargeCountrySuffix($paymentCountryId);
            }

            $ctx = '?custom=' . urlencode($customId) . '&type=' . $request->type
                . ($fromWebsite ? '&request_from=website' : '');
            $created = $paypal->createOrder(
                $amount,
                $customId,
                url('paypal/return' . $ctx),
                url('paypal/cancel' . $ctx),
                (string) Setting::get_value('app_name')
            );

            if (!$created || empty($created['approve_url'])) {
                return CommonHelper::responseError("Error while communicating with paypal server");
            }

            $transaction_id = $created['id'];
            // Same key the clients already open; only the destination changed.
            $out['paypal_redirect_url'] = $created['approve_url'];
        } else if ($request->payment_method == "Stripe") {

            Log::error("payment_method = " . $request->payment_method);

            if ($request->type == 'order') {
                $order_id = $request->order_id;
                $order = Order::where('id', $order_id)->first();

                if (!empty($order)) {
                    $response = TransactionHelper::createOrderOnStripe($order->final_total, 'order', $order->id, $gateways, $paymentCountryId);
                }
            } elseif ($request->type == 'wallet') {
                $response = TransactionHelper::createOrderOnStripe($request->wallet_amount, 'wallet', 0, $gateways, $paymentCountryId);
            }

            if ($response == "") {
                return CommonHelper::responseError("Error while communicating with Stripe server");
            }
            $out = $response->toArray();
        } else  if ($request->payment_method == "Midtrans") {
            $midtrans_redirect_url = TransactionHelper::createOrderonMidtrans($request->type, $request->order_id ?? 0, $request->wallet_amount ?? 0, $gateways, $paymentCountryId);
            if ($midtrans_redirect_url == "") {
                return CommonHelper::responseError("Error while communicating with Midtrans server");
            }

            return CommonHelper::responseWithData($midtrans_redirect_url);
        } else  if ($request->payment_method == "Phonepe") {
            $phonepay_data = TransactionHelper::createOrderonPhonepe($request->type, $request->order_id ?? 0, $request->wallet_amount ?? 0, $gateways, $paymentCountryId);
            if ($phonepay_data == "") {
                return CommonHelper::responseError("Error while communicating with Phonepe server");
            }
            return $phonepay_data;
        } else  if ($request->payment_method == "Cashfree") {
            $cashfree_redirect_url = TransactionHelper::createOrderonCashfree($request->type, $request->order_id ?? 0, $request->wallet_amount ?? 0, $gateways, $currencyCode, $paymentCountryId);
            if ($cashfree_redirect_url == "") {
                return CommonHelper::responseError("Error while communicating with Cashfree server");
            }
            return CommonHelper::responseWithData($cashfree_redirect_url);
        } else  if ($request->payment_method == "Paytabs") {
            $paytabs_redirect_url = TransactionHelper::createOrderonPaytabs($request->type, $request->order_id ?? 0, $request->wallet_amount ?? 0, $gateways, $currencyCode, $paymentCountryId);

            if ($paytabs_redirect_url == "") {
                return CommonHelper::responseError("Error while communicating with Paytabs server");
            }
            return CommonHelper::responseWithData($paytabs_redirect_url);
        } else if (app(PaymentGatewayRegistry::class)->has($request->payment_method)) {
            /* An plugin's gateway. Reached only where the chain above used to give up, so
               no core gateway's behaviour changes. Core builds the context — the driver
               never reads the order or the country row itself. */
            $driver = app(PaymentGatewayRegistry::class)->driver($request->payment_method);
            if (!$driver instanceof PaymentGateway) {
                return CommonHelper::responseError("Invalid payment methods.");
            }
            if (!$driver->isConfigured($gateways)) {
                return CommonHelper::responseError(__('payment_method_not_configured'));
            }

            $context = CommonHelper::paymentContextFor(
                $driver->code(),
                $request->type,
                $request->type == 'order' ? $order : null,
                (float) ($request->type == 'order' ? ($order->final_total ?? 0) : $request->wallet_amount),
                $currencyCode,
                $paymentCountryId,
                $gateways,
                auth()->user()
            );

            $initiation = $driver->initiate($context);
            if (!$initiation->ok) {
                return CommonHelper::responseError($initiation->error ?: __('something_went_wrong'));
            }

            $out = array_merge($out, $initiation->toArray());
            $transaction_id = (string) ($initiation->gatewayOrderId ?? '');
        } else {
            return CommonHelper::responseError("Invalid payment methods.");
        }
        if ($request->type == 'order') {
            $order->payment_method = $request->payment_method;
            $order->save();
            $out['order_id'] = $order->id;
        }

        if ($transaction_id != "") {
            $out['transaction_id'] = $transaction_id;
        }
        return CommonHelper::responseWithData($out);
    }

    public function paymentSdkHash(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'payment_method' => 'required|string|max:40',
            'hash_name'      => 'required|string|max:80',
            'hash_string'    => 'required|string|max:512',
            'order_id'       => 'sometimes|integer',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $registry = app(PaymentGatewayRegistry::class);
        $driver = $registry->driver($request->input('payment_method'));

        if (!$driver instanceof PaymentGateway || !$driver instanceof SignsSdkRequests) {
            return CommonHelper::responseError(__('payment_method_does_not_support_this'));
        }
        $zone = CommonHelper::getDeliverableCity($request->latitude, $request->longitude, $request->header('channel', 'ecommerce'));
        $gateways = CommonHelper::countryPaymentGateways($zone?->country ?? Country::find($request->input('country_id')));

        if (!$driver->isConfigured($gateways)) {
            return CommonHelper::responseError(__('payment_method_not_configured'));
        }

        $order = null;
        if ($request->filled('order_id')) {
            $order = Order::where('id', (int) $request->input('order_id'))
                ->where('user_id', auth()->user()->id)
                ->first();

            if (!$order) {
                return CommonHelper::responseError('invalid_order_id');
            }
        }

        $hash = $driver->signSdkRequest(
            (string) $request->input('hash_name'),
            (string) $request->input('hash_string'),
            $gateways,
            ['user_id' => auth()->user()->id, 'order' => $order]
        );

        if ($hash === null) {
            return CommonHelper::responseError(__('this_request_cannot_be_signed'));
        }

        return CommonHelper::responseWithData([
            'hash_name' => (string) $request->input('hash_name'),
            'hash'      => $hash,
        ]);
    }

    public function addTransaction(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'type' => 'required|in:order,wallet',
            'order_id' => 'required_if:type,order',
            'wallet_amount' => 'required_if:type,wallet',
            'latitude' => 'required_if:type,wallet',
            'longitude' => 'required_if:type,wallet',
            'device_type' => 'required',
            'app_version' => 'required',
            'payment_method' => 'required', // Razorpay / Paystack
            'transaction_id' => 'required',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $user = auth()->user();
        if ($request->type == 'order') {
            $order = Order::withTrashed()->where('id', $request->order_id)->first();
            if (!$order) {
                return CommonHelper::responseError("Invalid Order Id");
            }
        }

        // Gateway verification creds come from the zone (order's zone, or the request
        // location for a wallet recharge).
        if ($request->type == 'order') {
            $zone = CommonHelper::resolveOrderZone($order);
        } else {
            $zone = CommonHelper::getDeliverableCity($request->latitude, $request->longitude, strtolower(trim((string) $request->header('channel'))) ?: null);
            if (!$zone) {
                return CommonHelper::responseError(__('not_deliverable_to_this_location'));
            }
        }
        $gateways = $zone ? CommonHelper::countryPaymentGateways($zone?->country) : [];
        // Country the recharge credits (current location).
        $rechargeCountryId = ($request->type == 'wallet') ? ($zone->country_id ?? null) : null;

        if ($request->device_type) {
            $app_usage = array();
            $app_usage['device_type'] = $request->device_type;
            $app_usage['app_version'] = $request->app_version;

            if ($request->type == 'order') {
                $app_usage['order_id'] = $order->id ?? null;
            } else {
                $app_usage['order_id'] = 'wallet';
            }

            AppUsage::create($app_usage);
        }

        $status = Transaction::$statusFailed;

        $txn_id = $request->transaction_id;

        if (
            isset($request->payment_method) && in_array(
                $request->payment_method,
                array(
                    Transaction::$paymentTypeRazorpay,
                    Transaction::$paymentTypePaystack
                )
            )
        ) {
            if ($request->payment_method == Transaction::$paymentTypeRazorpay) {
                if (TransactionHelper::verifyRazorpayPayment($txn_id, $gateways)) {
                    $status = Transaction::$statusSuccess;
                }
            } else if ($request->payment_method == Transaction::$paymentTypePaystack) {

                $paystack = new Paystack($gateways);
                $payment = $paystack->verify_transaction($txn_id);

                if (!empty($payment)) {
                    $payment = json_decode($payment, true);
                    if (isset($payment['data']['status']) && $payment['data']['status'] == 'success') {
                        $status = Transaction::$statusSuccess;
                    }
                }
            }
            // Map gateway payment method to normalized key for transactions.type
            $paymentMethod = $request->payment_method;
            $paymentTypeKeyMap = [
                Transaction::$paymentTypeRazorpay => Transaction::$typeRazorpay,
                Transaction::$paymentTypePaystack => Transaction::$typePaystack,
                Transaction::$paymentTypeStripe   => Transaction::$typeStripe,
                Transaction::$paymentTypePaypal   => Transaction::$typePaypal,
                Transaction::$paymentTypeMidtrans => Transaction::$typeMidtrans,
                Transaction::$paymentTypePhonepe  => Transaction::$typePhonepe,
                Transaction::$paymentTypeCashfree => Transaction::$typeCashfree,
                Transaction::$paymentTypePaytabs  => Transaction::$typePaytabs,
            ];
            $paymentTypeKey = $paymentTypeKeyMap[$paymentMethod] ?? $paymentMethod;

            if ($request->type == 'order') {
                $transactionData = array();
                $transactionData['user_id'] = $order->user_id;
                $transactionData['order_id'] = $order->id;
                $transactionData['type'] = $paymentTypeKey;
                $transactionData['txn_id'] = $txn_id;
                $transactionData['payu_txn_id'] = "";
                $transactionData['amount'] = $order->final_total;
                $transactionData['status'] = $status;
                $transactionData['message'] = ($status == Transaction::$statusSuccess) ? 'txn_order_payment' : 'txn_payment_failed';
                $transactionData['transaction_date'] = date('Y-m-d H:i:s');

                $transaction = Transaction::create($transactionData);
                if ($status == Transaction::$statusSuccess) {

                    $order->active_status = OrderStatusList::$received;
                    $order->transaction_id = $transaction->id ?? 0;
                    $order->save();

                    $excludedStatuses = [OrderStatusList::$cancelled, OrderStatusList::$returned];
                    // Update the order items
                    OrderItem::where("order_id", $order->id)
                    ->whereNotIn("active_status", $excludedStatuses)
                    ->update(['active_status' => $order->active_status]);

                    // Online payment confirmed -> commit reservation + consume the cart.
                    CommonHelper::finalizeOnlineOrderSuccess($order);

                    /* deduct wallet balance now that online payment is confirmed (order's country wallet) */
                    if ($order->wallet_balance > 0) {
                        $current_balance = CommonHelper::getUserWalletBalance($order->user_id, $order->country_id);
                        $new_balance = $current_balance < $order->wallet_balance ? 0 : $current_balance - $order->wallet_balance;
                        CommonHelper::updateUserWalletBalance($new_balance, $order->user_id, $order->country_id);
                        CommonHelper::addWalletTransaction($order->id, 0, $order->user_id, 'debit', $order->wallet_balance, 'wallet_used_against_order_placement', 1, Transaction::$paymentTypeWallet);
                    }

                    // Online payment confirmed -> all notifications (push + email + SMS)
                    // run AFTER the response so the app isn't blocked on slow gateways.
                    $orderStatusForSms = $order->active_status;
                    try {
                        dispatch(function () use ($order, $orderStatusForSms) {
                            CommonHelper::sendNotificationOrderStatus($order);
                            CommonHelper::sendOrderNotificationsToAdmins($order, 'new_order', $order->delivery_boy_id ?? null);
                            try {
                                CommonHelper::sendSmsOrderStatus($order, $orderStatusForSms);
                            } catch (\Exception $e) {
                                Log::error("addTransaction SMS error :", [$e->getMessage()]);
                            }
                        })->afterResponse();
                    } catch (\Exception $e) {
                        Log::error("addTransaction notification error :", [$e->getMessage()]);
                    }
                    try {
                        dispatch(new SendEmailJob($order))->afterResponse();
                    } catch (\Exception $e) {
                        Log::error("addTransaction send mail error :", [$e->getMessage()]);
                    }

                    return CommonHelper::responseSuccessWithData("Order Placed Successfully", [
                        'order_id'      => $order->id,
                        'order_item_id' => optional($order->items()->orderBy('id')->first())->id,
                    ]);
                } else {
                    $order->active_status = OrderStatusList::$paymentPending;
                    $order->transaction_id = $transaction->id ?? 0;
                    $order->save();
                    try {
                        dispatch(function () use ($order) {
                            CommonHelper::sendPaymentFailedNotification($order);
                        })->afterResponse();
                    } catch (\Exception $e) {
                        Log::error("addTransaction payment failed notification error :", [$e->getMessage()]);
                    }
                    return CommonHelper::responseError("Transaction Failed, Please try again!");
                }
            } elseif ($request->type == 'wallet') {

                $rechargeMeta = CommonHelper::rechargeWalletMeta($rechargeCountryId, $user->id);
                $walletTransactionData = array();
                $walletTransactionData['user_id'] =  $user->id;
                $walletTransactionData['order_id'] = '';
                $walletTransactionData['type'] = 'credit';
                $walletTransactionData['payment_type'] = $request->payment_method;
                $walletTransactionData['txn_id'] = $txn_id;
                $walletTransactionData['amount'] = $request->wallet_amount;
                $walletTransactionData['status'] = $status;
                $walletTransactionData['message'] = ($status == WalletTransaction::$statusSuccess) ? 'wallet_successfully_recharged' : 'wallet_recharge_failed';
                $walletTransactionData['transaction_date'] = date('Y-m-d H:i:s');
                $walletTransactionData['country_id'] = $rechargeMeta['country_id'];
                $walletTransactionData['currency'] = $rechargeMeta['currency'];
                $walletTransactionData['currency_code'] = $rechargeMeta['currency_code'];
                $wallet_transaction = WalletTransaction::create($walletTransactionData);
                if ($status == WalletTransaction::$statusSuccess) {

                    //Mark credit amount in the user's (country-wise) wallet.
                    $newBalance = CommonHelper::addUserWalletBalance($request->wallet_amount, $user->id, $rechargeMeta['country_id']);
                    // Notify after the response (mail/sms/push are slow external calls).
                    $rechargeUserId = (int) $user->id;
                    $rechargeAmount = (float) $request->wallet_amount;
                    $rechargeCid    = $rechargeMeta['country_id'];
                    $rechargeTxn    = $wallet_transaction->txn_id ?? null;
                    try {
                        dispatch(function () use ($rechargeUserId, $rechargeAmount, $rechargeCid, $rechargeTxn) {
                            CommonHelper::notifyWalletRecharge($rechargeUserId, $rechargeAmount, $rechargeCid, $rechargeTxn);
                        })->afterResponse();
                    } catch (\Exception $e) {
                        Log::error("addTransaction wallet recharge notification error :", [$e->getMessage()]);
                    }
                    $data = array();
                    $data['user_balance'] = $newBalance;
                    return CommonHelper::responseSuccessWithData("Amount Added in Wallet Successfully", $data);
                } else {
                    // Capture only scalars in the closure (never $request/models) to keep it serializable.
                    $failUserId    = (int) $user->id;
                    $failAmount    = (float) $request->wallet_amount;
                    $failCountryId = $rechargeMeta['country_id'];
                    try {
                        dispatch(function () use ($failUserId, $failAmount, $failCountryId) {
                            CommonHelper::sendWalletRechargeFailedNotification($failUserId, $failAmount, $failCountryId);
                        })->afterResponse();
                    } catch (\Exception $e) {
                        Log::error("addTransaction wallet recharge failed notification error :", [$e->getMessage()]);
                    }
                    return CommonHelper::responseError("Transaction Failed, Please try again!");
                }
            }
        }
    }

    public function updateOrderStatus(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        // Quick orders cancel the whole order, so the app sends order_id (no item).
        // Ecommerce sends order_item_id. Accept either.
        if (empty($request->order_item_id) && empty($request->order_id)) {
            return CommonHelper::responseError('order_item_id_or_order_id_is_required');
        }

        if (!empty($request->order_item_id)) {
            $order_item = OrderItem::select("*")->where("id", $request->order_item_id)->first();
            if (empty($order_item)) {
                return CommonHelper::responseError('Order Item Not found.');
            }
            $id = $request->order_id ?? $order_item->order_id;
            $order = Order::select("*")->where("id", $id)->first();
        } else {
            // order_id only (quick whole-order operation): use a representative item.
            $order = Order::select("*")->where("id", $request->order_id)->first();
            if (empty($order)) {
                return CommonHelper::responseError('Order Not found.');
            }
            $order_item = OrderItem::where('order_id', $order->id)
                ->where('active_status', '!=', OrderStatusList::$cancelled)
                ->first()
                ?? OrderItem::where('order_id', $order->id)->first();
        }

        if (empty($order)) {
            return CommonHelper::responseError('Order Not found.');
        }
        if (empty($order_item)) {
            return CommonHelper::responseError('Order Item Not found.');
        }
        $order_item_id = $order_item->id;
        $orderWise = $order->channel === 'quick' || $order->isPickup();

        $user = User::select("*")->where('id', $order->user_id)->first();
        if (empty($user)) {
            return CommonHelper::responseError('User Not found.');
        }

        $postStatus = $request->status;
        $status = OrderStatusList::where('id', $postStatus)->first();
        if (empty($status)) {
            return CommonHelper::responseError('Status Not found.');
        }
        $selectedStatus = $status->status;
        if ($order_item->active_status == $postStatus) {
            return CommonHelper::responseError("This Order Item is already " . $selectedStatus . "!");
        }

        /* Cannot return order unless it is delivered */
        if (CommonHelper::isOrderItemReturned($order_item->active_status, $postStatus)) {
            return CommonHelper::responseError(__('cannot_return_order_unless_it_is_delivered'));
        }

        /* Could not update order status once cancelled or returned! */
        if (CommonHelper::isOrderItemCancelled($order_item_id)) {
            return CommonHelper::responseError(__('could_not_update_order_status_cancelled_or_returned'));
        }

        /* No status change while payment is still pending (item- or order-level). */
        if ((int) $order_item->active_status === OrderStatusList::$paymentPending
            || (int) $order->active_status === OrderStatusList::$paymentPending) {
            return CommonHelper::responseError(__('cannot_update_status_while_payment_pending'));
        }

        if (!empty($postStatus)) {

            if ($postStatus == OrderStatusList::$delivered) {

                if ($order->payment_method == Transaction::$paymentTypeCod) {

                    // Save Device details
                    if ($request->device_type) {
                        $app_usage = array();
                        $app_usage['order_id'] = $order->id;
                        $app_usage['device_type'] = $request->device_type;
                        $app_usage['app_version'] = $request->app_version;
                        AppUsage::create($app_usage);
                    }

                    $transactionData = array();
                    $transactionData['user_id'] = $order->user_id;
                    $transactionData['order_id'] = $order->id;
                    $transactionData['type'] = "COD";
                    $transactionData['txn_id'] = round(microtime(true) * 1000);
                    $transactionData['payu_txn_id'] = "";
                    $transactionData['amount'] = $order->total;
                    $transactionData['status'] = Transaction::$statusSuccess;
                    $transactionData['message'] = "";
                    $transactionData['transaction_date'] = date('Y-m-d H:i:s');
                    $transaction = Transaction::create($transactionData);
                    $order->transaction_id = $transaction->id ?? 0;
                }

                $order->active_status = OrderStatusList::$delivered;
                $order->save();

                // Credit wallet-type promo cashback now that the order is delivered.
                CommonHelper::creditOrderCashback($order);

                if ($orderWise) {
                    // Quick = one status for the whole single-branch order.
                    OrderItem::where('order_id', $order->id)
                        ->whereNotIn('active_status', [OrderStatusList::$cancelled, OrderStatusList::$returned])
                        ->update(['active_status' => OrderStatusList::$delivered]);
                } else {
                    $order_item->active_status = OrderStatusList::$delivered;
                    $order_item->save();
                }

                CommonHelper::sendOrderItemStatusMailNotification($order_item, 'order_item_status_update');
                return CommonHelper::responseSuccessWithData('order_status_updated_successfully', $this->orderResponsePayload($order));
                /*Send Notification*/
            } else if ($postStatus == OrderStatusList::$cancelled) {
                DB::transaction(function () use (&$order, &$order_item, $request, $postStatus, $orderWise) {
                    // Re-read under the lock: the row may have changed while we queued.
                    $order = Order::whereKey($order->id)->lockForUpdate()->first();
                    $order_item = OrderItem::whereKey($order_item->id)->lockForUpdate()->first();
                    if (!$order || !$order_item) {
                        return;
                    }
                    // Someone else cancelled it while we waited for the lock.
                    if ((int) $order_item->active_status === OrderStatusList::$cancelled) {
                        return;
                    }


                    if ($orderWise) {
                        // Quick = single-branch, one status. Cancelling any item cancels the
                        // whole order: pre-cancel + restock the siblings so the current item
                        // becomes the "last item" and the full-order refund path below runs once.
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
                        }
                    }

                    // Count total items and how many are still not cancelled (before we save this one).
                    $itemNum = OrderItem::where("order_id", $order->id)->count();
                    $lastItemNum = OrderItem::where("order_id", $order->id)
                        ->where('active_status', '!=', OrderStatusList::$cancelled)
                        ->count();

                    if ($itemNum == 1 || $lastItemNum == 1) {
                        $order->active_status = OrderStatusList::$cancelled;
                        $order->promo_code_id = 0;
                        $order->save();
                    }
                    // COD: cash isn't collected before delivery, so the only money paid is
                    // the wallet balance applied at checkout. Prepaid: the full amount is paid.
                    $isCod = $order->payment_method === Transaction::$paymentTypeCod;

                    if ($orderWise) {
                        // Quick = whole-order cancel. Charges live at the ORDER level (not split
                        // per item), so refund = all item sub_totals (less promo) + delivery +
                        // refundable additional + refundable surge charges. COD: only the wallet
                        // actually applied at checkout was paid.
                        $items = OrderItem::where('order_id', $order->id)->get();
                        $subTotal = floatval($items->sum('sub_total'));

                        if ($isCod) {
                            $refundable = floatval($order->wallet_balance);
                        } else {
                            $addl = CommonHelper::refundableCharges($order->additional_charges);
                            $addlTotal = array_sum(array_column($addl, 'amount'));
                            $surge = CommonHelper::refundableCharges($order->surge_charges);
                            $surgeTotal = array_sum(array_column($surge, 'charge'));
                            $refundable = max(0, round(
                                $subTotal
                                - floatval($order->promo_discount)
                                + floatval($order->delivery_charge)
                                + $addlTotal
                                + $surgeTotal,
                                2
                            ));
                        }
                        // Split the actual refunded amount across items by sub_total so each
                        // item's refund_amount sums to the order-level refund (order.refund_amount).
                        $weights = $items->values()->map(fn ($it) => (float) $it->sub_total)->all();
                        $shares = CommonHelper::splitByWeight($weights, $refundable);
                        foreach ($items->values() as $idx => $it) {
                            $it->refund_amount = $shares[$idx] ?? 0;
                            $it->save();
                            CommonHelper::reverseOrderItemTax($it);
                        }
                        CommonHelper::reverseOrderChargeTax($order->id);
                        if ($refundable > 0) {
                            CommonHelper::addUserWalletBalance($refundable, $order->user_id, $order->country_id);
                            CommonHelper::addWalletTransaction($order->id, $order_item->id, $order->user_id, 'credit', $refundable, 'wallet_order_item_cancelled');
                            CommonHelper::notifyWalletRefundCancelled($order, $order_item, $refundable);
                        }
                        $order->refund_amount = $refundable;
                        $order->remaining_total = 0;
                        $order->remaining_final = 0;
                        $order->wallet_balance = 0;
                        $order->save();
                    } else {
                        // Ecommerce = item-wise cancel. Refund this item's value + delivery +
                        // refundable charges (prepaid), or just its wallet portion (COD).
                        if ($isCod) {
                            $refundable = floatval($order_item->wallet_balance);
                        } else {
                            $refundable = CommonHelper::computeOrderItemRefund($order_item, true);
                        }
                        $order_item->refund_amount = $refundable;
                        CommonHelper::reverseOrderItemTax($order_item);
                        if ($refundable > 0) {
                            CommonHelper::addUserWalletBalance($refundable, $order->user_id, $order->country_id);
                            CommonHelper::addWalletTransaction($order->id, $order_item->id, $order->user_id, 'credit', $refundable, 'wallet_order_item_cancelled');
                            CommonHelper::notifyWalletRefundCancelled($order, $order_item, $refundable);
                        }
                        // Reduce the order's outstanding totals by this item.
                        $order->refund_amount = floatval($order->refund_amount) + $refundable;
                        $order->remaining_total = max(0, floatval($order->remaining_total) - floatval($order_item->sub_total));
                        $order->remaining_final = max(0, floatval($order->remaining_final) - $refundable);
                        if (floatval($order->wallet_balance) > 0) {
                            $order->wallet_balance = max(0, floatval($order->wallet_balance) - floatval($order_item->wallet_balance));
                        }
                        $order->save();
                    }
                    $order_item->active_status = $postStatus;
                    $order_item->cancellation_reason = $request->cancellation_reason;
                    $order_item->canceled_at = now();
                    $order_item->save();

                    // Quick = whole-order cancel → order-level timeline row (order_item_id 0,
                    CommonHelper::setOrderStatus([
                        'order_id'      => $order->id,
                        'order_item_id' => $orderWise ? 0 : $order_item->id,
                        'status'        => $postStatus,
                        'created_by'    => auth()->user()->id,
                        'user_type'     => OrderStatus::$userTypeUser,
                    ]);

                    // Restock the cancelled item per-branch (PVSS); product_variants.stock removed.
                    ProductHelper::restockStock($order_item->product_variant_id, $order_item->branch_id, (int) $order_item->quantity);
                    AddonHelper::moveOrderItemStock($order_item, 'restock');
                    // Ecommerce: order status follows its remaining items.
                    CommonHelper::syncEcommerceOrderStatus($order);
                    if (isset($order->promo_code) && $order->promo_code != null && isset($order->promo_discount) && $order->promo_discount != null) {
                        $promo_code = explode("(", $order->promo_code);
                        $minimum_order_amount = PromoCode::where('promo_code', $promo_code[0])->first()->minimum_order_amount;
                        if (isset($minimum_order_amount) && $minimum_order_amount != null && $order->total < $minimum_order_amount) {
                            $order_id = $order->id;
                            CommonHelper::updateOrderPromoCode($order_id, $order->promo_discount);
                        }
                    }

                }, 3);
                CommonHelper::sendOrderItemStatusMailNotification($order_item, 'order_item_status_update');
                //Order Item cancelled Send SMS
                try {
                    CommonHelper::sendSmsOrderStatus($order_item, OrderStatusList::$cancelled); // case 7
                } catch (\Exception $e) {
                    Log::error("Place order SMS error :", [$e->getMessage()]);
                }
                try {
                    dispatch(function () use ($order) {
                        CommonHelper::sendOrderNotificationsToAdmins($order, 'order_status_update', $order->delivery_boy_id ?? null);
                    })->afterResponse();
                } catch (\Exception $e) {
                    Log::error("updateOrderStatus admin notification error: " . $e->getMessage());
                }
                return CommonHelper::responseSuccessWithData('order_cancelled_successfully', $this->orderResponsePayload($order));
            } elseif ($postStatus == OrderStatusList::$returned) {
                // Nothing collected in person is returnable — refused before any address is asked for.
                if ($order->isPickup()) {
                    return CommonHelper::responseError('returns_not_available_for_pickup_orders');
                }
                $validator = Validator::make($request->all(), [
                    'order_item_id' => [
                        'required',
                        Rule::unique('return_requests')->ignore($request->order_item_id),
                    ],
                    // Pickup address for the return (must belong to the customer).
                    'address_id' => [
                        'required',
                        Rule::exists('user_addresses', 'id')->where('user_id', $order_item->user_id),
                    ],
                ], [
                    'order_item_id.unique' => 'Return request has been sent already.',
                ]);
                if ($validator->fails()) {
                    return CommonHelper::responseError($validator->errors()->first());
                }
                // Quick orders are cancel-only — no returns.
                if ($order->channel === 'quick') {
                    return CommonHelper::responseError('returns_are_not_available_for_quick_orders');
                }

                $returnRequest = new ReturnRequest();
                $returnRequest->user_id = $order_item->user_id;
                $returnRequest->product_variant_id = $order_item->product_variant_id;
                $returnRequest->order_id = $request->order_id;
                $returnRequest->order_item_id = $request->order_item_id;
                $returnRequest->address_id = $request->address_id;
                // Snapshot the pickup address object (same shape as orders.address).
                $addressRow = CommonHelper::getUserAddress($request->address_id);
                $returnRequest->address = CommonHelper::userAddressData($addressRow);
                $returnRequest->pickup_pincode = trim((string) ($addressRow->pincode ?? '')) ?: null;
                $returnRequest->return_reason = $request->return_reason;
                $returnRequest->status = 1;    //request is pending
                $returnRequest->delivery_boy_id = 0;    //request is pending, so no delivery boy assigned
                $returnRequest->remarks = $request->remarks ?? '';
                $returnRequest->save();

                $returnRequest->return_number = CommonHelper::formatNumber(Setting::get_value('return_request_prefix') ?: 'RET-', $returnRequest->id);
                $returnRequest->saveQuietly();

                // Seed the status history with the initial pending state (for the timeline).
                CommonHelper::setReturnRequestStatus($returnRequest->id, $returnRequest->status, $order_item->user_id, null);

                // Push notifications to customer (return_request_customer)
                CommonHelper::sendReturnRequestNotification($returnRequest);
                // Panel notifications for branch and admin: "You have a request for product return".
                CommonHelper::sendReturnRequestPanelNotifications($returnRequest);

                CommonHelper::sendOrderItemStatusMailNotification($order_item, 'return_request_sent');
            
                return CommonHelper::responseSuccessWithData('order_return_request_sent_successfully', $this->orderResponsePayload($order));
            } else {

                if ($orderWise) {
                    // Quick = one status for the whole single-branch order.
                    $order->active_status = $postStatus;
                    $order->save();
                    OrderItem::where('order_id', $order->id)
                        ->whereNotIn('active_status', [OrderStatusList::$cancelled, OrderStatusList::$returned])
                        ->update(['active_status' => $postStatus]);
                } else {
                    $order_item->active_status = $postStatus;
                    $order_item->save();
                }
                CommonHelper::sendOrderItemStatusMailNotification($order_item, 'order_item_status_update');

                try {
                    dispatch(function () use ($order) {
                        CommonHelper::sendOrderNotificationsToAdmins($order, 'order_status_update', $order->delivery_boy_id ?? null);
                    })->afterResponse();
                } catch (\Exception $e) {
                    Log::error("updateOrderStatus admin notification error: " . $e->getMessage());
                }

                return CommonHelper::responseSuccessWithData('order_status_updated_successfully', $this->orderResponsePayload($order));
            }
        }
    }

    /**
     * Post cancel/return payload in the SAME shape the order lists use, scoped to this
     * one order: quick -> getOrders shape, ecommerce -> getEcomOrders (item-wise).
     */
    private function orderResponsePayload($order)
    {
        $req = new Request(['order_id' => $order->id, 'limit' => 200, 'offset' => 0]);
        $resp = ($order->channel === 'quick') ? $this->getOrders($req) : $this->getEcomOrders($req);
        $payload = (is_object($resp) && method_exists($resp, 'getData')) ? $resp->getData(true) : [];
        return $payload['data'] ?? [];
    }

    public function getOrders(Request $request)
    {
        $limit = ($request->limit) ?? 12;
        $offset = ($request->offset) ?? 0;

        $order_id = $request->order_id;
        $user_id = auth()->user()->id;
        // Quick orders only — ecommerce orders are listed item-wise via getEcomOrders.
        $channel = 'quick';

        // Optional date range (inclusive), on the order date.
        $startDate = (!empty($request->start_date)) ? $request->start_date . ' 00:00:00' : null;
        $endDate   = (!empty($request->end_date)) ? $request->end_date . ' 23:59:59' : null;

        $sql = Order::select(DB::raw("count(id) as total"))
            ->where("user_id", $user_id)
            ->where("channel", $channel);
        if (!empty($order_id)) {
            $sql = $sql->where("id", $order_id);
        }
        if ($startDate && $endDate) {
            $sql = $sql->whereBetween('created_at', [$startDate, $endDate]);
        }

        if (isset($request->order_status_id) && $request->order_status_id != 0 && $request->order_status_id != "") {
            $sql = $sql->where("active_status", "=", $request->order_status_id);
        }

        if (isset($request->type)) {
            $activeTypeStatus = [OrderStatusList::$paymentPending, OrderStatusList::$received, OrderStatusList::$processed, OrderStatusList::$outForDelivery, OrderStatusList::$shipped, OrderStatusList::$preparing, OrderStatusList::$readyForPickup, OrderStatusList::$pickedUp];
            $previousTypeStatus = [OrderStatusList::$delivered, OrderStatusList::$cancelled, OrderStatusList::$returned];
            if ($request->type == Order::$activeType) {
                $sql = $sql->whereIn('orders.active_status', $activeTypeStatus);
            } else {
                $sql = $sql->whereIn('orders.active_status', $previousTypeStatus);
            }
        }

        $total = $sql->first();
        $sql = Order::select(
            "orders.*",
            'orders.id as order_id',
            "dboys.name as delivery_boy_name",
            "dboys.mobile as delivery_boy_mobile",
            DB::raw('(select name from users as u where u.id = orders.user_id) as user_name')
        )->from("orders")
            ->leftJoin('delivery_boys as dboys', 'orders.delivery_boy_id', '=', 'dboys.id')
            ->where("orders.user_id", "=", $user_id)
            ->where("orders.channel", $channel);
        if (!empty($order_id)) {
            $sql = $sql->where("orders.id", "=", $order_id);
        }
        if ($startDate && $endDate) {
            $sql = $sql->whereBetween('orders.created_at', [$startDate, $endDate]);
        }

        if (isset($request->order_status_id) && $request->order_status_id != 0 && $request->order_status_id != "") {
            $sql = $sql->where("orders.active_status", "=", $request->order_status_id);
        }

        if (isset($request->type)) {
            $activeTypeStatus = [OrderStatusList::$paymentPending, OrderStatusList::$received, OrderStatusList::$processed, OrderStatusList::$outForDelivery, OrderStatusList::$shipped, OrderStatusList::$preparing, OrderStatusList::$readyForPickup, OrderStatusList::$pickedUp];
            $previousTypeStatus = [OrderStatusList::$delivered, OrderStatusList::$cancelled, OrderStatusList::$returned];
            if ($request->type == Order::$activeType) {
                $sql = $sql->whereIn('orders.active_status', $activeTypeStatus);
            } else {
                $sql = $sql->whereIn('orders.active_status', $previousTypeStatus);
            }
        }
        $res = $sql->orderBy("orders.id", "DESC")->skip($offset)->take($limit)->get();

        $productRatingSetting = (int) (Setting::get_value('product_rating') ?? 0);
        $isProductRatingEnabled = $productRatingSetting === 1;
        $res = $res->makeHidden(['image', 'updated_at', 'deleted_at', 'current_status', 'address_id', 'order_id', 'orders_id', 'status', 'buyer_region_id', 'place_of_supply', 'delivery_charge']);

        $langCode = app('lang_code') ?? 'en';
        app()->setLocale($langCode);

        $i = 0;
        foreach ($res as $key => $row) {
            $rowDeliveryType = (string) ($row->delivery_type ?? 'delivery');
            $rowIsPickup = $rowDeliveryType === 'pickup';
            $res[$key]->order_status_name = OrderStatusList::getCustomerTranslatedName((int) $row->active_status, $rowDeliveryType);
            $res[$key]->saved_amount = (float) ($row->saved_amount ?? 0);
            $res[$key]->refund_amount = (float) ($row->refund_amount ?? 0);
            // Order-wise status timeline (replaces the legacy `status` JSON snapshot).
            $res[$key]->timeline = CommonHelper::orderProgressTimeline(
                OrderStatus::where('order_id', $row->id)->where('order_item_id', 0)->orderBy('id', 'ASC')->get(),
                'quick',
                fn ($sid) => OrderStatusList::getCustomerTranslatedName($sid, $rowDeliveryType),
                null,
                null,
                $rowDeliveryType
            );
            // `address` is the snapshot object (orders.address array cast).
            if (is_string($row->additional_charges)) {
                $res[$i]['additional_charges'] = json_decode($row->additional_charges, true) ?? [];
            } elseif (is_array($row->additional_charges)) {
                $res[$i]['additional_charges'] = $row->additional_charges;
            } else {
                $res[$i]['additional_charges'] = [];
            }
            if (is_string($row->surge_charges)) {
                $res[$i]['surge_charges'] = json_decode($row->surge_charges, true) ?? [];
            } elseif (is_array($row->surge_charges)) {
                $res[$i]['surge_charges'] = $row->surge_charges;
            } else {
                $res[$i]['surge_charges'] = [];
            }

            $generate_otp = Setting::get_value("generate_otp");
            if ($generate_otp == 0) {
                $res[$key]->otp = 0;
            }
            $product_rating = Setting::get_value("product_rating");
            $res[$key]->product_rating = $product_rating ?? 0;

            $row->promo_code = explode('(', $row->promo_code)[0];

            $res[$i]['date'] = $row->created_at;
            $res[$i]['created_at'] = $row->created_at;

            $orderStatus = orderStatus::where('order_id', $row['id'])->get();
            $data = array();
            foreach ($orderStatus as $status) {
                $subData = array();
                array_push($subData, $status->status, $status->created_at);
                array_push($data, $subData);
            }
            $res[$i]['status'] = json_encode($data);

            $items = OrderItem::with('images')->select(
                'oi.*',
                'v.id as variant_id',
                'p.id as product_id',
                'v.name',
                'p.image',
                'p.product_type',
                'p.manufacturer',
                'p.made_in',
                's.name as branch_name',
                's.preparation_time as branch_preparation_time',
                's.formatted_address as branch_address',
                's.latitude as branch_latitude',
                's.longitude as branch_longitude',
                DB::raw('(SELECT status FROM return_requests WHERE order_item_id = oi.id) as return_requested'),
                DB::raw('(SELECT return_reason FROM return_requests WHERE order_item_id = oi.id) as return_reason'),
                DB::raw('(SELECT remarks FROM return_requests WHERE order_item_id = oi.id) as return_remarks'),
                DB::raw('(SELECT courier_agency FROM return_requests WHERE order_item_id = oi.id) as return_courier_agency'),
                DB::raw('(SELECT tracking_id FROM return_requests WHERE order_item_id = oi.id) as return_tracking_id'),
                DB::raw('(SELECT tracking_url FROM return_requests WHERE order_item_id = oi.id) as return_tracking_url')
            )
                ->from('order_items as oi')
                ->leftJoin('product_variants as v', 'oi.product_variant_id', '=', 'v.id')
                ->leftJoin('products as p', 'v.product_id', '=', 'p.id')
                ->leftJoin('branches as s', 'oi.branch_id', '=', 's.id')
                ->where('oi.order_id', '=', $row['id'])
                ->orderBy('p.id', 'ASC')
                ->orderBy('oi.id', 'ASC')
                ->get();

            $orderTax = CommonHelper::attachCustomerTaxLines($items);
            $res[$i]['tax_breakdown'] = $orderTax[$row['id']]['tax_breakdown'] ?? [];
            $res[$i]['decimal_point'] = CommonHelper::countryDecimalPoint($row->country_id ?? null);
            $deliveryTax = $orderTax[$row['id']]['delivery_charge_tax'] ?? ['tax_amount' => 0, 'tax_name' => null, 'tax_rate' => 0];
            $deliveryAmount = round((float) ($row->delivery_charge ?? 0), 2);
            $res[$i]['delivery_charges'] = CommonHelper::deliveryChargeObject($deliveryAmount, $deliveryTax);
            $firstItem = $items->first();
            $prepMinutes = (int) (optional($firstItem)->branch_preparation_time ?? 0);

            $travelMinutes = 0;
            $orderZone = $row->zone_id ? Zone::find($row->zone_id) : null;
            $perUnit = (float) ($orderZone->travel_time_per_km ?? 0);
            $addr = CommonHelper::orderAddressObject($row->address ?? null);
            // A pickup order does not travel: the wait is the branch's preparation time.
            if (!$rowIsPickup && $perUnit > 0 && $firstItem && $addr
                && $firstItem->branch_latitude !== null && $firstItem->branch_longitude !== null
                && !empty($addr['latitude']) && !empty($addr['longitude'])) {
                $km = CommonHelper::straightLineDistanceKm(
                    $addr['latitude'], $addr['longitude'],
                    $firstItem->branch_latitude, $firstItem->branch_longitude
                );
                $dist = CommonHelper::convertKmToUnit($km, $orderZone->distance_unit ?? 'km');
                if ($dist !== null) {
                    $travelMinutes = (int) ceil($dist * $perUnit);
                }
            }

            $res[$i]['preparation_time']   = CustomerProductShaper::formatDeliveryTime($prepMinutes, false);
            $res[$i]['time_to_deliver']    = CustomerProductShaper::formatDeliveryTime($travelMinutes, false);
            $res[$i]['total_deliver_time'] = CustomerProductShaper::formatDeliveryTime($prepMinutes + $travelMinutes, false);
            // Where to collect, for a pickup order.
            $res[$i]['delivery_type'] = $rowDeliveryType;
            $res[$i]['pickup_branch'] = ($rowIsPickup && $firstItem && $firstItem->branch_id)
                ? optional(Branch::find($firstItem->branch_id))?->pickupInfo()
                : null;

            $cancelableStatusList = array(OrderStatusList::$received, OrderStatusList::$processed, OrderStatusList::$shipped, OrderStatusList::$outForDelivery, OrderStatusList::$preparing, OrderStatusList::$readyForPickup, OrderStatusList::$pickedUp, );

            // Quick = order-wise cancel: the whole order is cancellable only when EVERY
            // item is cancellable (one non-cancelable product blocks the order) and the
            // ORDER status is still within each item's till_status (in-progress only).
            $orderCancellable = count($items) > 0;

            foreach ($items as $subkey => $item) {

                $items[$subkey]->made_in = $item->made_in ?? "";
                $items[$subkey]->product_type = (int) ($item->product_type ?? 0);
                $items[$subkey]->created_at = $item->created_at;
                /* The addon snapshot is a JSON column, and getEcomOrders() hands it back
                   decoded. Leaving it as a string here would mean the same field had two
                   shapes depending on the channel. */
                $rawAddons = $item->addons ?? null;
                $items[$subkey]->addons = is_string($rawAddons)
                    ? (json_decode($rawAddons, true) ?: [])
                    : (is_array($rawAddons) ? $rawAddons : []);
                $items[$subkey]->addon_total = (float) ($item->addon_total ?? 0);

                $percentage = (float) ($item->tax_percentage ?? 0);
                $inclusive = (bool) ($item->is_tax_inclusive ?? false);
                $basePrice = (float) $item->price;
                // discounted_price: DB value when > 0, else fall back to the base price.
                $baseDisc  = (float) ($item->discounted_price > 0 ? $item->discounted_price : $item->price);
                $items[$subkey]->price = (float) CommonHelper::doubleNumber(TaxService::applyTax($basePrice, $percentage, $inclusive));
                $items[$subkey]->discounted_price = (float) CommonHelper::doubleNumber(TaxService::applyTax($baseDisc, $percentage, $inclusive));

                // Pickup stages are not ordered by id (10 sits before 6), so compare by
                // position in the flow there.
                $withinTill = $rowIsPickup
                    ? OrderStatusList::rank((int) $row->active_status, $row->channel, 'pickup')
                        <= OrderStatusList::rank((int) $item->till_status, $row->channel, 'pickup')
                    : intval($row->active_status) <= intval($item->till_status);
                $itemCancellable = (($item->cancelable_status == 1)
                    && $withinTill
                    && in_array($row->active_status, $cancelableStatusList));
                $orderCancellable = $orderCancellable && $itemCancellable;

                $items[$subkey]->item_rating = CommonHelper::productRatingOfUser($item->product_id, $item->user_id);
            }
            $items = $items->makeHidden(['image', 'images', 'updated_at', 'deleted_at', 'status', 'current_status', 'cancelable_status', 'till_status', 'return_status', 'return_days', 'courier_agency', 'tracking_id', 'tracking_url', 'branch_preparation_time', 'courier_provider', 'courier_shipment_id', 'courier_label_url']);

            $res[$i]['items'] = $items;
            // Order-level flags for quick orders (cancel order-wise, never returnable).
            $res[$i]['is_cancellable'] = $orderCancellable;
            $res[$i]['is_returnable'] = false;
            $res[$i]['product_rating'] = $isProductRatingEnabled;
            // Quick orders aren't returnable → forward-delivery chat visibility only.
            // A pickup order has no rider to chat with.
            $res[$i]['is_delivery_boy_chat_visible'] = !$rowIsPickup && CommonHelper::isDeliveryBoyChatVisibleForward(
                $row->delivery_boy_id ? (int) $row->delivery_boy_id : null,
                (int) $row->active_status
            );

            $i++;
        }

        if (!empty($res) && $total->total !== 0) {
            return CommonHelper::responseWithData($res, $total->total);
        } else {
            return CommonHelper::responseError(__('no_orders_found'));
        }
    }

    /**
     * Ecommerce orders are managed item-wise, so the customer list is paginated by
     * ORDER ITEM. Each entry = one item (its own status, charges, delivery boy,
     * payable) + its order context + sibling items of the same order.
     */
    public function getEcomOrders(Request $request)
    {
        $limit  = (int) ($request->limit ?? 12);
        $offset = (int) ($request->offset ?? 0);
        $user_id = auth()->user()->id;

        $base = OrderItem::from('order_items as oi')
            ->join('orders as o', 'oi.order_id', '=', 'o.id')
            ->where('o.user_id', $user_id)
            ->where('o.channel', 'ecommerce');

        if (!empty($request->order_id)) {
            $base->where('oi.order_id', $request->order_id);
        }
        if (!empty($request->order_item_id)) {
            $base->where('oi.id', $request->order_item_id);
        }
        // Optional date range (inclusive), on the order date.
        if (!empty($request->start_date) && !empty($request->end_date)) {
            $base->whereBetween('o.created_at', [$request->start_date . ' 00:00:00', $request->end_date . ' 23:59:59']);
        }
       
        if (isset($request->type)) {
            $active = [OrderStatusList::$paymentPending, OrderStatusList::$received, OrderStatusList::$processed, OrderStatusList::$outForDelivery, OrderStatusList::$shipped, OrderStatusList::$preparing, OrderStatusList::$readyForPickup, OrderStatusList::$pickedUp];
            $previous = [OrderStatusList::$delivered, OrderStatusList::$cancelled, OrderStatusList::$returned];
            $base->whereIn('oi.active_status', $request->type == Order::$activeType ? $active : $previous);
        }

        $total = (clone $base)->count('oi.id');

        $items = (clone $base)->select(
            'oi.*',
            'o.id as order_id', 'o.order_number', 'o.channel', 'o.delivery_type', 'o.payment_method', 'o.address as order_address',
            'o.currency', 'o.currency_code', 'o.created_at as order_created_at',
            'o.delivery_charge as order_delivery_charge',
            'o.country_id as order_country_id',
            'o.cashback_amount', 'o.cashback_credited', 'o.saved_amount',
            // Buyer tax identity, so an item row can show the same bill-to as the invoice.
            'o.buyer_tax_number', 'o.buyer_tax_label', 'o.buyer_business_name',
            'v.id as variant_id', 'v.name', 'p.id as product_id', 'p.image', 'p.product_type',
            's.name as branch_name',
            'db.name as delivery_boy_name', 'db.mobile as delivery_boy_mobile',
            DB::raw('(SELECT status FROM return_requests WHERE order_item_id = oi.id) as return_requested'),
            DB::raw('(SELECT reject_reason FROM return_requests WHERE order_item_id = oi.id AND status = 3 LIMIT 1) as return_reject_reason'),
            DB::raw('(SELECT return_reason FROM return_requests WHERE order_item_id = oi.id LIMIT 1) as return_reason'),
            DB::raw('(SELECT courier_agency FROM return_requests WHERE order_item_id = oi.id LIMIT 1) as return_courier_agency'),
            DB::raw('(SELECT tracking_id FROM return_requests WHERE order_item_id = oi.id LIMIT 1) as return_tracking_id'),
            DB::raw('(SELECT tracking_url FROM return_requests WHERE order_item_id = oi.id LIMIT 1) as return_tracking_url')
            )
            ->leftJoin('product_variants as v', 'oi.product_variant_id', '=', 'v.id')
            ->leftJoin('products as p', 'v.product_id', '=', 'p.id')
            ->leftJoin('branches as s', 'oi.branch_id', '=', 's.id')
            ->leftJoin('delivery_boys as db', 'oi.delivery_boy_id', '=', 'db.id')
            ->orderBy('oi.id', 'DESC')
            ->skip($offset)->take($limit)->get();

        if ($items->isEmpty()) {
            return CommonHelper::responseWithData([], $total);
        }

        $ecomOrderTax = CommonHelper::attachCustomerTaxLines($items);

        $isProductRatingEnabled = ((int) (Setting::get_value('product_rating') ?? 0)) === 1;

        // Bulk-fetch siblings (other items of the same orders) for the "other items" list.
        $orderIds = $items->pluck('order_id')->unique()->values()->all();
        $siblingsByOrder = OrderItem::from('order_items as oi')
            ->leftJoin('product_variants as v', 'oi.product_variant_id', '=', 'v.id')
            ->leftJoin('products as p', 'v.product_id', '=', 'p.id')
            ->whereIn('oi.order_id', $orderIds)
            ->orderBy('oi.id', 'ASC')
            ->get(['oi.id', 'oi.order_id', 'oi.product_name', 'oi.quantity', 'oi.active_status',
                'oi.final_total', 'oi.wallet_balance', 'p.image', 'p.product_type'])
            ->groupBy('order_id');

        // Return-request status per sibling item (for other_items' order_item_status).
        $siblingIds = $siblingsByOrder->flatten(1)->pluck('id')->map(fn ($id) => (int) $id)->all();
        $returnStatusByItem = ReturnRequest::whereIn('order_item_id', $siblingIds)->pluck('status', 'order_item_id');

        foreach ($items as $item) {
            // Frozen rate from the order line — see the note in getOrders().
            $percentage = (float) ($item->tax_percentage ?? 0);
            $inclusive = (bool) ($item->is_tax_inclusive ?? false);
            $basePrice = (float) $item->price;
            $baseDisc  = (float) ($item->discounted_price > 0 ? $item->discounted_price : $item->price);
            $item->price = (float) CommonHelper::doubleNumber(TaxService::applyTax($basePrice, $percentage, $inclusive));
            $item->discounted_price = (float) CommonHelper::doubleNumber(TaxService::applyTax($baseDisc, $percentage, $inclusive));
            $item->image = CommonHelper::imageUrl($item->image);
            $item->product_type = (int) ($item->product_type ?? 0);
            $item->otp = (!empty($item->tracking_id)) ? 0 : (int) $item->otp;
            $itemDeliveryType = (string) ($item->delivery_type ?? 'delivery');
            $itemIsPickup = $itemDeliveryType === 'pickup';
            $item->order_status_name = OrderStatusList::getCustomerTranslatedName((int) $item->active_status, $itemDeliveryType);
            // Item status name: the return status once a return exists, else the active status.
            $item->order_item_status = ($item->return_requested !== null)
                ? ReturnStatusList::getTranslatedName((int) $item->return_requested)
                : OrderStatusList::getCustomerTranslatedName((int) $item->active_status, $itemDeliveryType);
            // Where to collect, for a pickup order.
            $item->pickup_branch = ($itemIsPickup && $item->branch_id) ? optional(Branch::find($item->branch_id))?->pickupInfo() : null;
            $item->date = $item->order_created_at;

            $item->address = CommonHelper::orderAddressObject($item->order_address);
            unset($item->order_address);
            // Ratings (parity with quick orders): user's rating of this product + feature flag.
            $item->item_rating = CommonHelper::productRatingOfUser($item->product_id, $user_id);
            $item->product_rating = $isProductRatingEnabled;
            // Decode per-item charge JSON, and the addon snapshot with it.
            foreach (['additional_charges', 'surge_charges', 'addons'] as $jf) {
                $v = $item->{$jf} ?? null;
                $item->{$jf} = is_string($v) ? (json_decode($v, true) ?: []) : (is_array($v) ? $v : []);
            }
            $item->cashback_amount = (float) $item->cashback_amount;
            $item->saved_amount = (float) ($item->saved_amount ?? 0);

            $item->tax_breakdown = CommonHelper::itemTaxBreakdown($item);
            $item->decimal_point = CommonHelper::countryDecimalPoint($item->order_country_id ?? null);
            // Same format the cart promised it in — one date, one rendering.
            $item->estimated_delivery_date = CommonHelper::formatDateForCountry(
                $item->estimated_delivery_date, $item->order_country_id ?? null
            );
          
            unset($item->tax_lines);

            $deliveryTax = $ecomOrderTax[$item->order_id]['delivery_charge_tax'] ?? ['tax_amount' => 0, 'tax_name' => null, 'tax_rate' => 0];
            $itemDeliveryCharge = round((float) ($item->delivery_charge ?? 0), 2);
            $orderDeliveryCharge = (float) ($item->order_delivery_charge ?? 0);
            $share = $orderDeliveryCharge > 0 ? $itemDeliveryCharge / $orderDeliveryCharge : 0;
            $item->delivery_charges = CommonHelper::deliveryChargeObject($itemDeliveryCharge, [
                'tax_amount' => (float) $deliveryTax['tax_amount'] * $share,
                'tax_name'   => $deliveryTax['tax_name'],
                'tax_rate'   => $deliveryTax['tax_rate'],
            ]);
            unset($item->order_delivery_charge, $item->order_country_id);

            // Delivery-boy chat visibility (ecommerce, item-wise): forward delivery while live,
            // or the return pickup while a return is in progress.
            $item->is_delivery_boy_chat_visible = !$itemIsPickup && CommonHelper::isDeliveryBoyChatVisibleForOrderItem(
                (int) $item->id,
                $item->delivery_boy_id ? (int) $item->delivery_boy_id : null,
                (int) $item->active_status
            );

            // Cancelable / returnable for this item.
            $cancelableStatusList = [OrderStatusList::$received, OrderStatusList::$processed, OrderStatusList::$shipped, OrderStatusList::$outForDelivery, OrderStatusList::$preparing, OrderStatusList::$readyForPickup, OrderStatusList::$pickedUp];
            // Once a return has been applied (a request exists) or the item is already
            // cancelled, it can be neither cancelled nor returned again.
            $returnRequestId = ReturnRequest::where('order_item_id', $item->id)->value('id');
            $blocked = $returnRequestId !== null || (int) $item->active_status === OrderStatusList::$cancelled;

            // Ecommerce: cancel allowed when the product is cancelable and the ITEM's
            // active status is still within the configured till_status (in-progress only).
            // Pickup stages are not ordered by id, so compare by position there.
            $withinTill = $itemIsPickup
                ? OrderStatusList::rank((int) $item->active_status, 'ecommerce', 'pickup')
                    <= OrderStatusList::rank((int) $item->till_status, 'ecommerce', 'pickup')
                : (int) $item->active_status <= (int) $item->till_status;
            $item->is_cancellable = (!$blocked
                && $item->cancelable_status == 1
                && in_array((int) $item->active_status, $cancelableStatusList, true)
                && $withinTill) ? true : false;

            $statusRows = OrderStatus::where('order_id', $item->order_id)
                ->where('order_item_id', $itemIsPickup ? 0 : $item->id)
                ->orderBy('id', 'ASC')
                ->get();

            // Return allowed when returnable, within return_days of placement, and delivered.
            // Never on a pickup order — collected in person, handled at the counter.
            $deliveredAt = optional(
                $statusRows->last(fn ($row) => (int) $row->status === OrderStatusList::$delivered)
            )->created_at;

            $returnBase = $deliveredAt ?: ($item->updated_at ?: $item->order_created_at);
            $returnDays = abs((int) (date_diff(
                date_create(date('Y-m-d', strtotime((string) $returnBase))),
                date_create(date('Y-m-d'))
            )->format('%R%a')));

            $item->is_returnable = (!$blocked
                && !$itemIsPickup
                && $item->return_status == 1
                && $returnDays <= (int) $item->return_days
                && (int) $item->active_status === OrderStatusList::$delivered) ? true : false;
            unset($item->order_created_at); // internal only — not exposed
            // Per-item timeline. A pickup order is order-wise, so its timeline lives on
            // the order-level rows (order_item_id = 0), the same as a quick order.
            $item->timeline = CommonHelper::orderProgressTimeline(
                $statusRows,
                'ecommerce',
                fn ($sid) => OrderStatusList::getCustomerTranslatedName($sid, $itemDeliveryType),
                null,
                null,
                $itemDeliveryType
            );
            // If the item was returned, append the return request's status timeline after
            // the order timeline (so it continues right after the "returned" entry).
            if ($returnRequestId) {
                $returnTimeline = ReturnRequestStatus::where('return_request_id', $returnRequestId)
                    ->orderBy('id', 'ASC')->get()
                    ->map(fn ($s) => [
                        'status' => (int) $s->status,
                        'status_name' => ReturnStatusList::getTranslatedName((int) $s->status),
                        'datetime' => $s->created_at,
                        'is_return' => true,
                    ])->values();
                if ($returnTimeline->isNotEmpty()) {
                    $item->timeline = collect($item->timeline)->concat($returnTimeline)->values();
                }
            }
            // Other items of the same order.
            $item->other_items = collect($siblingsByOrder->get($item->order_id, collect()))
                ->reject(fn ($s) => (int) $s->id === (int) $item->id)
                ->map(fn ($s) => [
                    'order_item_id' => (int) $s->id,
                    'product_name'  => $s->product_name,
                    'product_type'  => (int) ($s->product_type ?? 0),
                    'quantity'      => $s->quantity,
                    'final_total'   => round((float) $s->final_total + (float) $s->wallet_balance, 2),
                    'image'         => CommonHelper::imageUrl($s->image),
                    'status'        => (int) $s->active_status,
                    'status_name'   => OrderStatusList::getCustomerTranslatedName((int) $s->active_status, $itemDeliveryType),
                    'order_item_status' => $returnStatusByItem->has((int) $s->id)
                        ? ReturnStatusList::getTranslatedName((int) $returnStatusByItem[(int) $s->id])
                        : OrderStatusList::getCustomerTranslatedName((int) $s->active_status, $itemDeliveryType),
                ])->values();
        }

        $items = $items->makeHidden([
            'created_at', 'updated_at', 'deleted_at', 'status', 'image_url',
            'cancelable_status', 'till_status', 'return_status',
            'courier_provider', 'courier_shipment_id', 'courier_label_url',
        ]);
        return CommonHelper::responseWithData($items, $total);
    }

    public function downloadOrderInvoice(Request $request)
    {
        $data = CommonHelper::getOrderDetails($request->order_id, true);
        if (!$data["order"]) {
            return CommonHelper::responseError("Order Not found!");
        }
        CommonHelper::AdditionalChargesArray($data['order']);
        return CommonHelper::downloadOrderInvoice($request->order_id);
    }
    
    public function getLiveTrackingDetails(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'order_id' => 'required|numeric|exists:orders,id',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // Retrieve the order ID from the request
        $orderId = $request->input('order_id');

        // Fetch the live tracking details based on the order ID
        $trackingData = LiveTracking::where('order_id', $orderId)
            ->orderBy('id', 'desc')
            ->first();

        if (!$trackingData) {
            return CommonHelper::responseError("Live Tracking Not available.");
        }

        $order = Order::find($orderId);
        // Nothing to track: a pickup order never leaves the branch.
        if ($order && $order->isPickup()) {
            return CommonHelper::responseError('live_tracking_not_available_for_pickup_orders');
        }
        $address = CommonHelper::orderAddressObject($order->address ?? null);
        $zone = $order && $order->zone_id ? Zone::find($order->zone_id) : null;

        $unit = CommonHelper::normalizeDistanceUnit($zone->distance_unit ?? 'km');
        $distance = null;
        $minutes = 0;

        if ($address && !empty($address['latitude']) && !empty($address['longitude'])) {
            $km = CommonHelper::straightLineDistanceKm(
                $trackingData->latitude, $trackingData->longitude,
                $address['latitude'], $address['longitude']
            );
            $converted = CommonHelper::convertKmToUnit($km, $unit);
            if ($converted !== null) {
                $distance = round($converted, 2);
                $perUnit = (float) ($zone->travel_time_per_km ?? 0);
                if ($perUnit > 0) {
                    $minutes = (int) ceil($distance * $perUnit);
                }
            }
        }

        $data = $trackingData->toArray();
        $data['distance']         = $distance;
        $data['distance_unit']    = $unit;
        // Worded like every other ETA in the app; '' when the zone quotes no per-km time.
        $data['time_to_deliver']  = CustomerProductShaper::formatDeliveryTime($minutes, false);

        return CommonHelper::responseSuccessWithData("Live Tracking Detail fetched successfully.", $data);
    }

    /** Customer uploads the proof (screenshot + reference) for a manual payment. */
    public function submitPaymentProof(Request $request)
    {
        $v = Validator::make($request->all(), [
            'order_id' => 'required|integer',
            'reference' => 'nullable|string|max:191',
            'proof' => 'required|image|max:6144',
        ]);
        if ($v->fails()) return CommonHelper::responseError($v->errors()->first());

        $order = Order::where('id', $request->order_id)->where('user_id', $request->user()->id)->first();
        if (!$order || !\App\Services\OfflinePayments::isManual($order->payment_method)) {
            return CommonHelper::responseError(__('order_not_found'));
        }
        if ($order->payment_verification === 'verified') {
            return CommonHelper::responseError(__('payment_already_verified'));
        }
        $order->payment_proof = $request->file('proof')->store('payment_proofs', 'public');
        $order->payment_reference = $request->input('reference');
        $order->payment_verification = 'pending';
        $order->save();
        return CommonHelper::responseSuccess(__('payment_proof_submitted'));
    }
}
