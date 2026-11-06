<?php

namespace App\Http\Controllers;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Jobs\SendEmailJob;
use App\Models\Country;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusList;
use App\Models\Setting;
use App\Models\Transaction;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\Payments\PaymentSettlementService;
use App\Services\PaypalService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use App\Support\WebhookLog;
use Illuminate\Support\Facades\Log;
class WebhookController extends Controller
{
    private static function wlog(string $level, string $message, array $context = []): void
    {
        WebhookLog::write($level, $message, $context);
    }

    /**
     * Payment failed / expired: record a FAILED transaction row (mirroring the
     * success branch, which previously left failures with no ledger entry) and
     * notify the customer that their order was cancelled. Shared across every
     * gateway webhook — pass the gateway's Transaction::$type* constant.
     */
    private static function recordFailedPayment($order_id, string $txn_id, string $message, ?string $txnType = null): void
    {
        // Behaviour moved verbatim into PaymentSettlementService so plugin gateways
        // record a failure exactly the way the core ones do. Every existing caller
        // keeps working through this wrapper.
        app(PaymentSettlementService::class)->orderPaymentFailed($order_id, $txn_id, $message, $txnType);
    }

    /**
     * Wallet recharge payment failed via a gateway webhook: record a FAILED
     * wallet_transaction row (the success path branches one; failures stored nothing)
     * and notify the customer. Shared across every gateway — pass the gateway's
     * Transaction::$paymentType* constant. Idempotent on txn_id.
     */
    private static function recordFailedWalletRecharge($userId, $amount, string $txnId, string $paymentType, $countryId): void
    {
        // Same move as recordFailedPayment: one implementation, in the settlement service.
        app(PaymentSettlementService::class)->walletRechargeFailed($userId, $amount, $txnId, $paymentType, $countryId);
    }

    public function stripeWebhook(Request $request)
    {

        // Stripe credentials are country-wise now, but the webhook endpoint is global.
        // Identify the country by trying each Stripe-enabled country's webhook secret
        // until the signature verifies — that country's keys are right for this event.
        $payload = @file_get_contents('php://input');
        $sig_header = $_SERVER['HTTP_STRIPE_SIGNATURE'] ?? '';
        $event = null;
        $stripe_secret_key = '';

        $peek = json_decode((string) $payload, true);
        $metaCountryId = $peek['data']['object']['metadata']['country_id'] ?? null;
        if ($metaCountryId) {
            $c = Country::find($metaCountryId);
            if ($c) {
                $g = CommonHelper::countryPaymentGateways($c);
                $endpoint_secret = $g['stripe_webhook_secret_key'] ?? '';
                $secret = $g['stripe_secret_key'] ?? '';
                if ($endpoint_secret && $secret) {
                    try {
                        $event = \Stripe\Webhook::constructEvent($payload, $sig_header, $endpoint_secret);
                        $stripe_secret_key = $secret;
                    } catch (\Stripe\Exception\SignatureVerificationException $e){}
                }
            }
        }

        foreach ($event ? [] : Country::whereNotNull('payment_gateways')->get() as $c) {
            $g = CommonHelper::countryPaymentGateways($c);
            $endpoint_secret = $g['stripe_webhook_secret_key'] ?? '';
            $secret = $g['stripe_secret_key'] ?? '';
            if (!$endpoint_secret || !$secret) {
                continue;
            }
            try {
                $event = \Stripe\Webhook::constructEvent($payload, $sig_header, $endpoint_secret);
                $stripe_secret_key = $secret;
                break;
            } catch (\UnexpectedValueException $e) {
                // Malformed payload — same for every zone, bail out.
                http_response_code(400);
                exit();
            } catch (\Stripe\Exception\SignatureVerificationException $e) {
                // Wrong zone's secret — try the next zone.
                continue;
            } 
        }

        if (!$event && !empty($peek['id']) && str_starts_with((string) $peek['id'], 'evt_')) {
            $eventId = (string) $peek['id'];
            $candidates = [];
            if ($metaCountryId && ($mc = Country::find($metaCountryId))) {
                $candidates[$mc->id] = $mc;
            }
            foreach (Country::whereNotNull('payment_gateways')->get() as $cc) {
                $candidates[$cc->id] = $cc;
            }
            foreach ($candidates as $cc) {
                $sk = CommonHelper::countryPaymentGateways($cc)['stripe_secret_key'] ?? '';
                if (!$sk) {
                    continue;
                }
                try {
                    \Stripe\Stripe::setApiKey($sk);
                    $fetched = \Stripe\Event::retrieve($eventId);
                    if ($fetched && ($fetched->id ?? '') === $eventId) {
                        $event = $fetched;
                        $stripe_secret_key = $sk;
                        self::wlog('info', 'Stripe Webhook : verified via event re-fetch (country ' . $cc->id . ').');
                        break;
                    }
                } catch (\Throwable $e) {
                    // Wrong account's key for this event id — try the next country.
                    continue;
                }
            }
        }

        if (!$event) {
            self::wlog('info', "Stripe Webhook : no zone secret verified the signature. Skip.");
            http_response_code(400);
            exit();
        }

        \Stripe\Stripe::setApiKey($stripe_secret_key);

        // Resolve metadata - for charge events, metadata lives on the payment intent, not the charge
        $metadata = $event->data->object->metadata ?? null;
        $txn_id = "";
        $order_id = 0;
        $user_id = 0;
        $amount = 0;
        $transaction = null;

        if (!empty($event->data->object)) {
            $txn_id = $event->data->object->payment_intent ?? $event->data->object->id ?? "";
            $amount = $event->data->object->amount ?? 0;
            $event->data->object->balance_transaction ?? 0;

            // For charge events, metadata is on the payment intent - fetch it via Stripe API
            if (!empty($txn_id) && (empty($metadata) || count((array)$metadata) === 0) && isset($event->data->object->payment_intent)) {
                try {
                    $stripe = new \Stripe\StripeClient($stripe_secret_key);
                    $paymentIntent = $stripe->paymentIntents->retrieve($txn_id);
                    $metadata = $paymentIntent->metadata ?? null;
                } catch (\Exception $e) {
                    self::wlog('error', 'Stripe Webhook: Failed to fetch payment intent metadata: ' . $e->getMessage());
                }
            }

            // Try to find existing transaction by txn_id
            if (!empty($txn_id)) {
                $transaction = Transaction::where('txn_id', $txn_id)->first();
                if ($transaction) {
                    $order_id = $transaction['order_id'];
                    $user_id = $transaction['user_id'];
                }
            }

            if (!$transaction && !empty($metadata)) {
                $order_id = $metadata->order_id ?? 0;
                $user_id = $metadata->user_id ?? 0;

                if (!empty($order_id) && is_numeric($order_id) && empty($user_id)) {
                    $order_data = Order::where('id', $order_id)->first();
                    $user_id = $order_data['user_id'] ?? 0;
                }
            }
        }

        // Handle wallet refill pattern: wallet-refill-user-{user_id}-{timestamp}-{random}
        if (!empty($order_id) && !is_numeric($order_id) && strpos($order_id, "wallet-refill-user") !== false) {
            $temp = explode("-", $order_id);
            if (isset($temp[3]) && is_numeric($temp[3]) && !empty($temp[3])) {
                $user_id = $temp[3];
            }
        }

        if (in_array($event->type, ['charge.succeeded', 'payment_intent.succeeded'])) {
            if (!empty($order_id)) {
                /* Wallet recharge — credit the current-location country wallet. */
                if (strpos($order_id, "wallet-refill-user") !== false) {
                    // Country from the metadata (or the identifier marker), current-location.
                    $rechargeCid = ($metadata->country_id ?? null) ?: CommonHelper::parseRechargeCountryId($order_id);
                    $rechargeMeta = CommonHelper::rechargeWalletMeta($rechargeCid, $user_id);
                    $walletAmount = (float) $amount / 100;

                    // Idempotency: webhooks can fire more than once for the same charge.
                    $already = WalletTransaction::where('txn_id', $txn_id)->where('type', 'credit')->exists();
                    if ($user_id && $walletAmount > 0 && !$already) {
                        WalletTransaction::create([
                            'user_id'          => $user_id,
                            'type'             => 'credit',
                            'payment_type'     => Transaction::$paymentTypeStripe,
                            'txn_id'           => $txn_id,
                            'amount'           => $walletAmount,
                            'status'           => WalletTransaction::$statusSuccess,
                            'message'          => 'wallet_successfully_recharged',
                            'transaction_date' => date('Y-m-d H:i:s'),
                            'country_id'       => $rechargeMeta['country_id'],
                            'currency'         => $rechargeMeta['currency'],
                            'currency_code'    => $rechargeMeta['currency_code'],
                        ]);
                        CommonHelper::addUserWalletBalance($walletAmount, $user_id, $rechargeMeta['country_id']);
                        CommonHelper::notifyWalletRecharge($user_id, $walletAmount, $rechargeMeta['country_id'], $txn_id);
                    }
                } else {
                    /* process the order and mark it as received */
                    $order = Order::where('id', $order_id)->first();
                    // Idempotency: Stripe retries webhooks. If this charge was already
                    // processed (success txn + order received) skip re-crediting/notifying.
                    $alreadyDone = $transaction && $transaction->status === Transaction::$statusSuccess
                        && $order && (int) $order->active_status === (int) OrderStatusList::$received;
                    if (isset($order['user_id']) && !$alreadyDone) {

                        if (!$transaction) {
                            $transactionData = array();
                            $transactionData['user_id'] = $order->user_id;
                            $transactionData['order_id'] = $order->id;
                            $transactionData['type'] = Transaction::$typeStripe;
                            $transactionData['txn_id'] = $txn_id;
                            $transactionData['payu_txn_id'] = "";
                            $transactionData['amount'] = $order->total;
                            $transactionData['status'] = Transaction::$statusSuccess;
                            $transactionData['message'] = 'txn_order_payment';
                            $transactionData['transaction_date'] = date('Y-m-d H:i:s');
                            $transaction = Transaction::create($transactionData);
                        } else {
                            $transaction->status = Transaction::$statusSuccess;
                            $transaction->save();
                        }

                        if ($transaction) {
                            $order->active_status = OrderStatusList::$received;
                            $order->transaction_id = $transaction->id ?? 0;

                            if (isset($order->wallet_balance) && $order->wallet_balance > 0) {
                                $user = User::find($order->user_id);
                                if ($user) {
                                    $user_wallet_balance = $user->balance;
                                    $new_balance = $user_wallet_balance < $order->wallet_balance ? 0 : $user_wallet_balance - $order->wallet_balance;
                                    CommonHelper::updateUserWalletBalance($new_balance, $user->id);
                                    CommonHelper::addWalletTransaction($order->id, 0, $user->id, 'debit', $order->wallet_balance, 'wallet_used_against_order_placement', 1, Transaction::$paymentTypeWallet);
                                }
                            }

                            $order->save();

                            $excludedStatuses = [OrderStatusList::$cancelled, OrderStatusList::$returned];
                            // Update the order items
                            OrderItem::where("order_id", $order->id)
                                ->whereNotIn("active_status", $excludedStatuses)
                                ->update(['active_status' => $order->active_status]);

                            // Online payment confirmed -> commit reservation + consume the cart.
                            CommonHelper::finalizeOnlineOrderSuccess($order);

                            // Notifications (push + admin + SMS) run after the response so a
                            // slow gateway can't stall the webhook (Stripe times out ~10s).
                            $orderStatusForSms = $order->active_status;
                            try {
                                dispatch(function () use ($order, $orderStatusForSms) {
                                    CommonHelper::sendNotificationOrderStatus($order);
                                    CommonHelper::sendOrderNotificationsToAdmins($order, 'new_order', $order->delivery_boy_id ?? null);
                                    try {
                                        CommonHelper::sendSmsOrderStatus($order, $orderStatusForSms);
                                    } catch (\Exception $e) {
                                        self::wlog('error', "Place order SMS error :", [$e->getMessage()]);
                                    }
                                })->afterResponse();
                            } catch (\Exception $e) {
                                self::wlog('error', "Place orderNotification error :", [$e->getMessage()]);
                            }
                            try {
                                dispatch(new SendEmailJob($order))->afterResponse();
                            } catch (\Exception $e) {
                                self::wlog('error', "Place order Send mail error :", [$e->getMessage()]);
                            }
                        }
                    }
                }
            } else {
                self::wlog('info', "Stripe Webhook Order id not found : ", [$event]);
            }
            $response['error'] = false;
            $response['transaction_status'] = $event->type;
            $response['message'] = "Transaction successfully done";
            echo json_encode($response);
            return false;
            exit();
        } elseif (in_array($event->type, ['charge.failed', 'payment_intent.payment_failed', 'payment_intent.canceled'])) {
            if (!empty($order_id) && strpos((string) $order_id, 'wallet-refill-user') !== false) {
                $cid = ($metadata->country_id ?? null) ?: CommonHelper::parseRechargeCountryId($order_id);
                self::recordFailedWalletRecharge($user_id, $amount / 100, $txn_id, Transaction::$paymentTypeStripe, $cid);
            } else {
                Order::where('id', $order_id)->update(['active_status' => OrderStatusList::$cancelled]);
                self::recordFailedPayment($order_id, $txn_id, 'txn_payment_failed');
            }

            $response['error'] = true;
            $response['transaction_status'] = $event->type;
            $response['message'] = "Transaction is failed. ";
            self::wlog('info', 'Stripe Webhook | Transaction is failed --> ', [$event]);
            echo json_encode($response);
            return false;
            exit();
        } elseif ($event->type == 'charge.pending') {
            $response['error'] = false;
            $response['transaction_status'] = $event->type;
            $response['message'] = "Waiting customer to finish transaction ";
            self::wlog('info', 'Stripe Webhook | Waiting customer to finish transaction --> ', [$event]);
            echo json_encode($response);
            return false;
            exit();
        } elseif ($event->type == 'charge.expired') {
            if (!empty($order_id) && strpos((string) $order_id, 'wallet-refill-user') !== false) {
                $cid = ($metadata->country_id ?? null) ?: CommonHelper::parseRechargeCountryId($order_id);
                self::recordFailedWalletRecharge($user_id, $amount / 100, $txn_id, Transaction::$paymentTypeStripe, $cid);
            } elseif (!empty($order_id)) {
                Order::where('id', $order_id)->update(['active_status' => OrderStatusList::$cancelled]);
                self::recordFailedPayment($order_id, $txn_id, 'txn_payment_expired');
            }

            $response['error'] = true;
            $response['transaction_status'] = $event->type;
            $response['message'] = "Transaction is expired.";
            self::wlog('info', 'Stripe Webhook | Transaction is expired --> ', [$event]);
            echo json_encode($response);
            return false;
            exit();
        } elseif ($event->type == 'charge.refunded') {
            if (!empty($order_id)) {
                Order::where('id', $order_id)->update(['active_status' => OrderStatusList::$cancelled]);
            }

            $response['error'] = true;
            $response['transaction_status'] = $event->type;
            $response['message'] = "Transaction is refunded.";
            self::wlog('info', 'Stripe Webhook | Transaction is refunded --> ', [$event]);
            echo json_encode($response);
            return false;
            exit();
        } elseif (in_array($event->type, ['payment_intent.requires_action', 'payment_intent.created', 'payment_intent.processing', 'charge.updated'])) {
            // Informational events - no action needed
            self::wlog('info', 'Stripe Webhook | Acknowledged event: ' . $event->type);
            $response['error'] = false;
            $response['transaction_status'] = $event->type;
            $response['message'] = "Event acknowledged.";
            echo json_encode($response);
            return false;
            exit();
        } else {
            $response['error'] = true;
            $response['transaction_status'] = $event->type;
            $response['message'] = "Transaction could not be detected.";
            self::wlog('info', 'Stripe Webhook | Unhandled event type: ' . $event->type);
            echo json_encode($response);
            return false;
            exit();
        }

        http_response_code(200);
    }

    /* ================= Midtrans ================= */

    public function midtransWebhook(Request $request)
    {
        $notification = $request->all();

        try {
            if ($notification['status_code'] == 200) {
                // Process the notification data here
                // Example: Update your database based on the notification

                // Transaction
                $order_id = $notification['order_id'];
                $explode = explode('-', $order_id);

                // Idempotency: the webhook can be delivered more than once — skip if this
                // txn is already recorded (return 200 so Midtrans stops retrying).
                $mtTxnId = $notification['transaction_id'] ?? '';
                if ($mtTxnId && (Transaction::where('txn_id', $mtTxnId)->exists()
                    || WalletTransaction::where('txn_id', $mtTxnId)->exists())) {
                    self::wlog('info', "Midtrans Callback - duplicate ignored for txn_id: " . $mtTxnId);
                    return CommonHelper::responseSuccess('already_processed');
                }

                if ($explode[0] == 'order') {
                    $transactionData = [
                        'user_id' => $explode[2],
                        'order_id' => $explode[1],
                        'type' => Transaction::$typeMidtrans,
                        'txn_id' => $notification['transaction_id'],
                        'payu_txn_id' => "",
                        'amount' => $notification['gross_amount'] / 1000,
                        'status' => Transaction::$statusSuccess,
                        'message' => 'txn_order_payment',
                        'transaction_date' => $notification['transaction_time'],
                    ];

                    $transaction = Transaction::create($transactionData);
                    $order = Order::withTrashed()->where('id', $explode[1])->first();
                    $user = User::where('id', $explode[2])->first();
                    $user_wallet_balance = $user->balance;

                    if (!$order) {
                        return CommonHelper::responseError("Invalid Order Id");
                    }

                    $order->active_status = OrderStatusList::$received;
                    $order->transaction_id = $transaction->id ?? 0;

                    if (isset($order->wallet_balance) && $order->wallet_balance > 0) {
                        // Deduct the balance & set the wallet transaction
                        $new_balance = $user_wallet_balance < $order->wallet_balance ? 0 : $user_wallet_balance - $order->wallet_balance;
                        CommonHelper::updateUserWalletBalance($new_balance, $user->id);
                        CommonHelper::addWalletTransaction($order->id, 0, $user->id, 'debit', $order->wallet_balance, 'wallet_used_against_order_placement', 1, Transaction::$paymentTypeWallet);
                    }

                    $order->save();
                    $excludedStatuses = [OrderStatusList::$cancelled, OrderStatusList::$returned];

                    // Update the order items
                    OrderItem::where("order_id", $order->id)
                        ->whereNotIn("active_status", $excludedStatuses)
                        ->update(['active_status' => $order->active_status]);

                    // Online payment confirmed -> commit reservation + consume the cart.
                    CommonHelper::finalizeOnlineOrderSuccess($order);

                    try {
                        dispatch(function () use ($order) {
                            CommonHelper::sendNotificationOrderStatus($order);
                            CommonHelper::sendOrderNotificationsToAdmins($order, 'new_order', $order->delivery_boy_id ?? null);
                        })->afterResponse();
                    } catch (\Exception $e) {
                        self::wlog('error', "Place orderNotification error :", [$e->getMessage()]);
                    }
                    try {
                        dispatch(new SendEmailJob($order))->afterResponse();
                    } catch (\Exception $e) {
                        self::wlog('error', "Place order Send mail error :", [$e->getMessage()]);
                    }

                    //Place Order Send SMS (after response so a slow SMS gateway can't stall the webhook)
                    try {
                        dispatch(function () use ($order) {
                            CommonHelper::sendSmsOrderStatus($order, $order->active_status);
                        })->afterResponse();
                    } catch (\Exception $e) {
                        self::wlog('error', "Place order SMS error :", [$e->getMessage()]);
                    }

                    return CommonHelper::responseSuccess("Order Placed Successfully");
                } elseif ($explode[0] == 'wallet') {
                    self::wlog('info', "Midtrans Callback wallet: " . print_r($notification, true));

                    $rechargeMeta = CommonHelper::rechargeWalletMeta(CommonHelper::parseRechargeCountryId($explode), $explode[2]);
                    $walletTransactionData = [
                        'user_id' => $explode[2],
                        'order_id' => '',
                        'type' => 'credit',
                        'payment_type' => 'Midtrans',
                        'txn_id' => $notification['transaction_id'],
                        'amount' => $notification['gross_amount'] / 1000,
                        'status' => WalletTransaction::$statusSuccess,
                        'message' => 'wallet_successfully_recharged',
                        'transaction_date' => $notification['transaction_time'],
                        'country_id' => $rechargeMeta['country_id'],
                        'currency' => $rechargeMeta['currency'],
                        'currency_code' => $rechargeMeta['currency_code'],
                    ];

                    $wallet_transaction = WalletTransaction::create($walletTransactionData);
                    $user = User::where('id', $explode[2])->first();

                    // Mark credit amount in the user's (current-location country) wallet.
                    $newBalance = CommonHelper::addUserWalletBalance($walletTransactionData['amount'], $user->id, $rechargeMeta['country_id']);
                    CommonHelper::notifyWalletRecharge($user->id, $walletTransactionData['amount'], $rechargeMeta['country_id'], $wallet_transaction->txn_id ?? null);
                    $data = ['user_balance' => $newBalance];

                    return CommonHelper::responseSuccessWithData("Amount Added in Wallet Successfully", $data);
                }
            } else {
                $order_id = $notification['order_id'];
                $explode = explode('-', $order_id);
                if ($explode[0] == 'order') {
                    Order::where('id', $explode[1])->update(['active_status' => OrderStatusList::$cancelled]);
                    self::recordFailedPayment($explode[1], $notification['transaction_id'] ?? '', 'txn_payment_failed', Transaction::$typeMidtrans);
                } elseif ($explode[0] == 'wallet') {
                    self::recordFailedWalletRecharge($explode[2] ?? null, ($notification['gross_amount'] ?? 0) / 1000, $notification['transaction_id'] ?? '', Transaction::$paymentTypeMidtrans, CommonHelper::parseRechargeCountryId($explode));
                }
            }
        } catch (\Exception $e) {
            self::wlog('error', "Error processing Midtrans callback: " . $e->getMessage());
            return CommonHelper::responseError("An error occurred while processing the callback.");
        }
    }

    /* ================= Cashfree ================= */

    public function cashfreeWebhook(Request $request)
    {

        $notification = $request->all();

        try {
            // NOTE: '??' binds looser than '==', so the old inline condition mis-parsed.
            // Read the status explicitly (order status, else payment status).
            $paymentStatus = $notification['data']['order']['transaction_status']
                ?? $notification['data']['payment']['payment_status']
                ?? '';
            if ($paymentStatus === 'SUCCESS') {
                // transaction
                $order_id = $notification['data']['link_id'] ?? $notification['data']['order']['order_tags']['link_id'] ?? $notification['data']['order']['order_id'] ?? '';

                self::wlog('info', "Cashfree Callback - link_id/order_id: " . $order_id);

                $explode = explode('-', $order_id);
                self::wlog('info', "Cashfree Callback - Exploded parts: " . json_encode($explode));

                // Idempotency: Cashfree delivers the webhook more than once (retries +
                // separate order/payment events). Skip if this txn is already recorded,
                // returning 200 so Cashfree stops retrying.
                $cfTxnId = $notification['data']['order']['transaction_id'] ?? $notification['data']['payment']['cf_payment_id'] ?? '';
                if ($cfTxnId && (Transaction::where('txn_id', $cfTxnId)->exists()
                    || WalletTransaction::where('txn_id', $cfTxnId)->exists())) {
                    self::wlog('info', "Cashfree Callback - duplicate ignored for txn_id: " . $cfTxnId);
                    return CommonHelper::responseSuccess('already_processed');
                }

                if ($explode[0] == 'order' || $explode[0] == 'wallet') {
                    self::wlog('info', "Cashfree Callback {$explode[0]}: " . print_r($notification, true));

                    // One settle path for every gateway, core and plugin alike: this is
                    // the code that used to live inline here (see
                    // PaymentSettlementService), so behaviour is unchanged.
                    $amount = (float) ($notification['data']['order']['order_amount']
                        ?? $notification['data']['payment']['payment_amount'] ?? 0);

                    $result = app(PaymentSettlementService::class)->settle(
                        \App\Plugins\Dto\PaymentOutcome::success($order_id, (string) $cfTxnId, $amount, $notification),
                        Transaction::$typeCashfree,
                        Transaction::$paymentTypeCashfree
                    );

                    if (empty($result['ok'])) {
                        self::wlog('error', 'Cashfree settlement failed: ' . ($result['message'] ?? ''));

                        return CommonHelper::responseError($result['message'] ?? 'settlement_failed');
                    }
                }
            } else {
                $order_id = $notification['data']['order']['order_tags']['link_id'];
                $explode = explode('-', $order_id);
                if ($explode[0] == 'order') {
                    Order::where('id', $explode[1])->update(['active_status' => OrderStatusList::$cancelled]);
                    $cfTxnId = $notification['data']['payment']['cf_payment_id'] ?? ($notification['data']['order']['transaction_id'] ?? '');
                    self::recordFailedPayment($explode[1], (string) $cfTxnId, 'txn_payment_failed', Transaction::$typeCashfree);
                } elseif ($explode[0] == 'wallet') {
                    $cfAmt = $notification['data']['order']['order_amount'] ?? ($notification['data']['payment']['payment_amount'] ?? 0);
                    $cfTxnId = $notification['data']['payment']['cf_payment_id'] ?? ($notification['data']['order']['transaction_id'] ?? '');
                    self::recordFailedWalletRecharge($explode[2] ?? null, $cfAmt, (string) $cfTxnId, Transaction::$paymentTypeCashfree, CommonHelper::parseRechargeCountryId($explode));
                }
            }
        } catch (\Exception $e) {
            self::wlog('error', "Error processing Cashfree callback: " . $e->getMessage());
            return CommonHelper::responseError("An error occurred while processing the callback.");
        }
    }

    public function cashfreeRedirect(Request $request)
    {
        $order_id = (string) $request->order;
        self::wlog('info', 'Cashfree Redirect - received', ['order' => $order_id]);
        $explode = explode('-', $order_id);
        $status = Transaction::$statusFailed; // safe default when the ref can't be parsed
        try {
            if (($explode[0] ?? '') === 'order' && isset($explode[1], $explode[2])) {
                $order_status = Order::where('id', $explode[1])->where('user_id', $explode[2])->value('active_status');
                $status = $order_status != OrderStatusList::$cancelled
                    ? (Transaction::where('order_id', $explode[1])->where('user_id', $explode[2])->value('status') ?? Transaction::$statusFailed)
                    : Transaction::$statusFailed;
            } elseif (($explode[0] ?? '') === 'wallet' && isset($explode[1], $explode[2])) {
                $formattedDateTime = Carbon::createFromFormat('YmdHis', $explode[1])->format('Y-m-d H:i:s');
                $status = WalletTransaction::where('transaction_date', $formattedDateTime)->where('user_id', $explode[2])->value('status') ?? 'failed';
            } else {
                self::wlog('error', 'Cashfree Redirect - unparseable ref', ['order' => $order_id]);
            }
        } catch (\Throwable $e) {
            self::wlog('error', 'Cashfree Redirect - error: ' . $e->getMessage(), ['order' => $order_id]);
        }

        self::wlog('info', 'Cashfree Redirect - resolved', ['order' => $order_id, 'status' => $status]);

        $website_url = Setting::get_value('website_url') ?? "";
        if (isset($website_url) && !empty($website_url)) {
            $redirect_url = $website_url . '/web-payment-status?status=' . $status . '&type=' . ($explode[0] ?? '') . '&order_id=' . ($explode[1] ?? '') . '&payment_method=Cashfree';
            return redirect($redirect_url);
        } else {
            return redirect()->route('/', ['status' => $status]);
        }
    }

    /* ================= Paytabs ================= */

    public function paytabsWebhook(Request $request)
    {

        $notification = $request->all();
        $website_url = Setting::get_value('website_url') ?? "";

        try {
            if ($notification['payment_result']['response_status'] == 'A') {
                // transaction
                $order_id = $notification['cart_id'];

                $explode = explode('-', $order_id);

                // Idempotency: Paytabs may deliver the callback more than once — skip if
                // this txn is already recorded (return 200 so it stops retrying).
                $ptTxnId = $notification['tran_ref'] ?? '';
                if ($ptTxnId && (Transaction::where('txn_id', $ptTxnId)->exists()
                    || WalletTransaction::where('txn_id', $ptTxnId)->exists())) {
                    self::wlog('info', "Paytabs Callback - duplicate ignored for txn_id: " . $ptTxnId);
                    return CommonHelper::responseSuccess('already_processed');
                }

                if ($explode[0] == 'order') {
                    $transactionData = array();
                    $transactionData['user_id'] = $explode[2];
                    $transactionData['order_id'] = $explode[1];
                    $transactionData['type'] = Transaction::$typePaytabs;
                    $transactionData['txn_id'] = $notification['tran_ref'];
                    $transactionData['payu_txn_id'] = "";
                    $transactionData['amount'] = $notification['tran_total'];
                    $transactionData['status'] = Transaction::$statusSuccess;
                    $transactionData['message'] = 'txn_order_payment';
                    $transactionData['transaction_date'] = now();

                    $transaction = Transaction::create($transactionData);
                    $order = Order::withTrashed()->where('id', $explode[1])->first();
                    $user = User::where('id', $explode[2])->first();
                    $user_wallet_balance = $user->balance;
                    if (!$order) {
                        return CommonHelper::responseError("Invalid Order Id");
                    }
                    $order->active_status = OrderStatusList::$received;
                    $order->transaction_id = $transaction->id ?? 0;

                    if (isset($order->wallet_balance) && $order->wallet_balance > 0) {
                        // Deduct the balance & set the wallet transaction
                        $new_balance = $user_wallet_balance < $order->wallet_balance ? 0 : $user_wallet_balance - $order->wallet_balance;
                        CommonHelper::updateUserWalletBalance($new_balance, $user->id);
                        CommonHelper::addWalletTransaction($order->id, 0, $user->id, 'debit', $order->wallet_balance, 'wallet_used_against_order_placement', 1, Transaction::$paymentTypeWallet);
                    }

                    $order->save();
                    $excludedStatuses = [OrderStatusList::$cancelled, OrderStatusList::$returned];

                    // Update the order items
                    OrderItem::where("order_id", $order->id)
                        ->whereNotIn("active_status", $excludedStatuses)
                        ->update(['active_status' => $order->active_status]);

                    // Online payment confirmed -> commit reservation + consume the cart.
                    CommonHelper::finalizeOnlineOrderSuccess($order);

                    try {
                        dispatch(function () use ($order) {
                            CommonHelper::sendNotificationOrderStatus($order);
                            CommonHelper::sendOrderNotificationsToAdmins($order, 'new_order', $order->delivery_boy_id ?? null);
                        })->afterResponse();
                    } catch (\Exception $e) {
                        self::wlog('error', "Place orderNotification error :", [$e->getMessage()]);
                    }
                    try {
                        dispatch(new SendEmailJob($order))->afterResponse();
                    } catch (\Exception $e) {
                        self::wlog('error', "Place order Send mail error :", [$e->getMessage()]);
                    }

                    //Place Order Send SMS (after response so a slow SMS gateway can't stall the webhook)
                    try {
                        dispatch(function () use ($order) {
                            CommonHelper::sendSmsOrderStatus($order, $order->active_status);
                        })->afterResponse();
                    } catch (\Exception $e) {
                        self::wlog('error', "Place order SMS error :", [$e->getMessage()]);
                    }

                    if (isset($website_url) && !empty($website_url)) {
                        $redirect_url = $website_url . '/web-payment-status?status=' . $notification['payment_result']['response_status'] . '&type=order&payment_method=Paytabs';
                        return redirect($redirect_url);
                    } else {
                        return redirect()->route('paytabs.redirect', ['order' => $order->id]);
                    }
                } elseif ($explode[0] == 'wallet') {
                    $dateTime = Carbon::createFromFormat('YmdHis', $explode[1]);
                    $formattedDateTime = $dateTime->format('Y-m-d H:i:s');
                    $rechargeMeta = CommonHelper::rechargeWalletMeta(CommonHelper::parseRechargeCountryId($explode), $explode[2]);
                    $walletTransactionData = array();
                    $walletTransactionData['user_id'] = $explode[2];
                    $walletTransactionData['order_id'] = '';
                    $walletTransactionData['type'] = 'credit';
                    $walletTransactionData['payment_type'] = Transaction::$paymentTypePaytabs;
                    $walletTransactionData['txn_id'] = $notification['tran_ref'];
                    $walletTransactionData['amount'] = $notification['tran_total'];
                    $walletTransactionData['status'] = Transaction::$statusSuccess;
                    $walletTransactionData['message'] = 'wallet_successfully_recharged';
                    $walletTransactionData['transaction_date'] = $formattedDateTime;
                    $walletTransactionData['country_id'] = $rechargeMeta['country_id'];
                    $walletTransactionData['currency'] = $rechargeMeta['currency'];
                    $walletTransactionData['currency_code'] = $rechargeMeta['currency_code'];
                    $wallet_transaction = WalletTransaction::create($walletTransactionData);

                    CommonHelper::addUserWalletBalance($walletTransactionData['amount'], $explode[2], $rechargeMeta['country_id']);
                    CommonHelper::notifyWalletRecharge($explode[2], $walletTransactionData['amount'], $rechargeMeta['country_id'], $wallet_transaction->txn_id ?? null);

                    if (isset($website_url) && !empty($website_url)) {
                        $redirect_url = $website_url . '/web-payment-status?status=' . $notification['payment_result']['response_status'] . '&type=wallet&payment_method=Paytabs';
                        return redirect($redirect_url);
                    } else {
                        return redirect()->route('paytabs.redirect', ['order' => $order_id]);
                    }
                }
            } else {
                $order_id = $notification['data']['order']['order_tags']['link_id'];
                $explode = explode('-', $order_id);
                if ($explode[0] == 'order') {
                    Order::where('id', $explode[1])->update(['active_status' => OrderStatusList::$cancelled]);
                    $ptTxnId = $notification['tran_ref'] ?? ($notification['payment_result']['tran_ref'] ?? '');
                    self::recordFailedPayment($explode[1], (string) $ptTxnId, 'txn_payment_failed', Transaction::$typePaytabs);
                } elseif ($explode[0] == 'wallet') {
                    $ptTxnId = $notification['tran_ref'] ?? ($notification['payment_result']['tran_ref'] ?? '');
                    self::recordFailedWalletRecharge($explode[2] ?? null, $notification['tran_total'] ?? 0, (string) $ptTxnId, Transaction::$paymentTypePaytabs, CommonHelper::parseRechargeCountryId($explode));
                }
            }
        } catch (\Exception $e) {
            self::wlog('error', "Error processing Paytabs callback: " . $e->getMessage());
            return CommonHelper::responseError("An error occurred while processing the callback.");
        }
    }

    public function paytabsRedirect(Request $request)
    {
        $order_id = (string) $request->order;
        self::wlog('info', 'Paytabs Redirect - received', ['order' => $order_id]);
        $explode = explode('-', $order_id);
        $status = Transaction::$statusFailed; // safe default when the ref can't be parsed
        try {
            if (($explode[0] ?? '') === 'order' && isset($explode[1], $explode[2])) {
                $order_status = Order::where('id', $explode[1])->where('user_id', $explode[2])->value('active_status');
                $status = $order_status != OrderStatusList::$cancelled
                    ? (Transaction::where('order_id', $explode[1])->where('user_id', $explode[2])->value('status') ?? Transaction::$statusFailed)
                    : Transaction::$statusFailed;
            } elseif (($explode[0] ?? '') === 'wallet' && isset($explode[1], $explode[2])) {
                $formattedDateTime = Carbon::createFromFormat('YmdHis', $explode[1])->format('Y-m-d H:i:s');
                $status = WalletTransaction::where('transaction_date', $formattedDateTime)->where('user_id', $explode[2])->value('status') ?? 'failed';
            } else {
                self::wlog('error', 'Paytabs Redirect - unparseable ref', ['order' => $order_id]);
            }
        } catch (\Throwable $e) {
            self::wlog('error', 'Paytabs Redirect - error: ' . $e->getMessage(), ['order' => $order_id]);
        }

        self::wlog('info', 'Paytabs Redirect - resolved', ['order' => $order_id, 'status' => $status]);

        $website_url = Setting::get_value('website_url') ?? "";
        if (isset($website_url) && !empty($website_url)) {
            $redirect_url = $website_url . '/web-payment-status?status=' . $status . '&type=' . ($explode[0] ?? '') . '&payment_method=Paytabs&order_id=' . ($explode[1] ?? '');
            return redirect($redirect_url);
        } else {
            return redirect()->route('/', ['status' => $status]);
        }
    }

    /* ================= PayPal (Orders v2 + webhooks) ================= */

    /**
     * Where PayPal returns the buyer after approval. The payment is CAPTURED here, so
     * the outcome is known before the customer sees a page — the old IPN flow could
     * only redirect with "pending" and hope the notification arrived.
     *
     * Query: custom (order id or wallet marker), type, request_from, plus PayPal's
     * own `token` (the v2 order id).
     */
    public function paypalReturn(Request $request)
    {
        $customId = (string) $request->input('custom', '');
        $paypalOrderId = (string) $request->input('token', '');
        $type = $request->input('type') === 'wallet' ? 'wallet' : 'order';

        $gateways = self::paypalGatewaysFor($customId);
        $service = new PaypalService($gateways);

        // A webview can load this URL more than once (Flutter logs the navigation twice).
        // If the payment already settled, answer from our own records instead of
        // capturing again.
        if (self::paypalAlreadySettled($customId)) {
            return self::paypalFinishRedirect($request, 'success', $type, $customId);
        }

        $status = 'failed';
        if ($paypalOrderId !== '' && $service->isConfigured()) {
            $capture = $service->captureOrder($paypalOrderId);
            if ($capture && strtoupper($capture['status']) === 'COMPLETED') {
                // Trust the capture's own custom_id when PayPal echoes it back.
                $settleId = $capture['custom_id'] !== '' ? $capture['custom_id'] : $customId;
                self::paypalSettleSuccess($settleId, $capture['capture_id'], $capture['amount']);
                $status = 'success';
            } else {
                // Report the failure, but do NOT cancel anything here: a capture can fail
                // for reasons that say nothing about the payment (a network blip, a second
                // return hitting an order mid-capture). Only an explicit buyer cancel or a
                // DENIED/REVERSED webhook cancels an order.
                self::wlog('error', 'PayPal capture not completed', [
                    'paypal_order' => $paypalOrderId,
                    'status'       => $capture['status'] ?? null,
                    'custom_id'    => $customId,
                ]);
            }
        }

        return self::paypalFinishRedirect($request, $status, $type, $customId);
    }

    /** Has this payment already been recorded? Makes a repeated return harmless. */
    private static function paypalAlreadySettled(string $customId): bool
    {
        if ($customId === '') {
            return false;
        }

        if (is_numeric($customId)) {
            $order = Order::find((int) $customId);

            return $order && (int) $order->active_status === (int) OrderStatusList::$received;
        }

        return WalletTransaction::where('order_id', $customId)
            ->where('status', Transaction::$statusSuccess)
            ->exists();
    }

    /** The buyer backed out on PayPal's side. Nothing was captured. */
    public function paypalCancel(Request $request)
    {
        $customId = (string) $request->input('custom', '');
        $type = $request->input('type') === 'wallet' ? 'wallet' : 'order';
        // Guard the double-load case here too: a cancel must never undo a settled payment.
        if (self::paypalAlreadySettled($customId)) {
            return self::paypalFinishRedirect($request, 'success', $type, $customId);
        }
        self::paypalSettleFailure($customId, '');

        return self::paypalFinishRedirect($request, 'failed', $type, $customId);
    }

    /**
     * Asynchronous safety net: a buyer who closes the tab after paying never hits the
     * return URL, so the capture event settles the payment here instead. Signature is
     * verified with PayPal before anything is written.
     */
    public function paypalWebhook(Request $request)
    {
        $event = $request->all();
        $eventType = (string) ($event['event_type'] ?? '');
        $resource = $event['resource'] ?? [];
        $customId = (string) ($resource['custom_id'] ?? '');

        self::wlog('info', 'PayPal webhook received', ['event' => $eventType, 'custom_id' => $customId]);

        $service = new PaypalService(self::paypalGatewaysFor($customId));
        if (!$service->verifyWebhook($request->headers->all(), $event)) {
            self::wlog('error', 'PayPal webhook signature rejected', ['event' => $eventType]);

            return response()->json(['status' => 'invalid'], 400);
        }

        $txnId = (string) ($resource['id'] ?? '');
        $amount = (float) ($resource['amount']['value'] ?? 0);

        switch ($eventType) {
            case 'PAYMENT.CAPTURE.COMPLETED':
                self::paypalSettleSuccess($customId, $txnId, $amount);
                break;
            case 'PAYMENT.CAPTURE.DENIED':
            case 'PAYMENT.CAPTURE.REVERSED':
            case 'PAYMENT.CAPTURE.REFUNDED':
                self::paypalSettleFailure($customId, $txnId);
                break;
        }

        // 200 for every verified event: PayPal retries anything else for days.
        return response()->json(['status' => 'ok']);
    }

    /**
     * The country's PayPal credentials for a payment. An order carries its zone; a
     * wallet recharge carries its country in the marker.
     */
    private static function paypalGatewaysFor(string $customId): array
    {
        if (is_numeric($customId)) {
            $order = Order::find((int) $customId);

            return $order ? CommonHelper::countryPaymentGateways(CommonHelper::resolveOrderZone($order)?->country) : [];
        }

        $countryId = CommonHelper::parseRechargeCountryId($customId);

        return $countryId ? CommonHelper::countryPaymentGateways(Country::find($countryId)) : [];
    }

    /**
     * Website goes to its own status page; the app is sent to a fixed URL carrying the
     * result, so a webview can decide by watching the address bar.
     */
    private static function paypalFinishRedirect(Request $request, string $status, string $type, string $customId)
    {
        $websiteUrl = rtrim((string) Setting::where('variable', 'website_url')->value('value'), '/');

        $query = 'status=' . $status . '&type=' . $type . '&payment_method=Paypal';
        if ($type === 'order' && is_numeric($customId)) {
            $query .= '&order_id=' . (int) $customId;
        }

        if ($request->input('request_from') === 'website' && $websiteUrl !== '') {
            return redirect()->away($websiteUrl . '/web-payment-status?' . $query);
        }

        // App: one predictable landing URL — /paypal/status?status=success|failed — that a
        // webview can match on. Capture already happened, so this is only the hand-off.
        return redirect()->to(url('paypal/status?' . $query));
    }

    /**
     * The app's landing page. Carries the outcome in the URL (for a webview watching
     * navigations) and posts it to an opener when there is one (popup flows).
     */
    public function paypalStatus(Request $request)
    {
        $status = $request->input('status') === 'success' ? 'success' : 'failed';
        $websiteUrl = rtrim((string) Setting::where('variable', 'website_url')->value('value'), '/');
        $title = $status === 'success' ? __('payment_successful') : __('payment_failed');

        return response(
            '<html><head><meta name="viewport" content="width=device-width, initial-scale=1">'
            . '<title>' . e($title) . '</title></head>'
            . '<body style="font-family:sans-serif;text-align:center;padding:48px 16px">'
            . '<h3>' . e($title) . '</h3>'
            . '<script>'
            . 'window.paypalPaymentStatus = "' . $status . '";'
            . 'window.addEventListener("load", function(){'
            . 'if (window.opener) { window.opener.postMessage("' . $status . '", "' . addslashes($websiteUrl ?: '*') . '"); window.close(); }'
            . '});'
            . '</script></body></html>'
        )->header('Content-Type', 'text/html');
    }

    /**
     * Mark a captured payment as paid — order or wallet recharge. Idempotent: PayPal
     * can deliver the capture twice (return + webhook), and the same txn id must not
     * credit a wallet or place an order twice.
     */
    private static function paypalSettleSuccess(string $customId, string $txnId, float $amount): void
    {
        if ($customId === '' || $txnId === '') {
            return;
        }
        if (Transaction::where('txn_id', $txnId)->exists() || WalletTransaction::where('txn_id', $txnId)->exists()) {
            self::wlog('info', 'PayPal duplicate settle ignored', ['txn_id' => $txnId]);

            return;
        }

        // --- wallet recharge ---
        if (!is_numeric($customId) && str_contains($customId, 'wallet_recharge')) {
            $parts = explode('-', $customId);
            $userId = isset($parts[1]) && is_numeric($parts[1]) ? (int) $parts[1] : 0;
            if (!$userId) {
                return;
            }

            $meta = CommonHelper::rechargeWalletMeta(CommonHelper::parseRechargeCountryId($customId), $userId);
            $walletTransaction = WalletTransaction::create([
                'payment_type'     => Transaction::$paymentTypePaypal,
                'user_id'          => $userId,
                'order_id'         => $customId,
                'type'             => 'credit',
                'txn_id'           => $txnId,
                'payu_txn_id'      => '',
                'amount'           => $amount,
                'status'           => Transaction::$statusSuccess,
                'message'          => 'Wallet successfully recharged.',
                'transaction_date' => date('Y-m-d H:i:s'),
                'country_id'       => $meta['country_id'],
                'currency'         => $meta['currency'],
                'currency_code'    => $meta['currency_code'],
            ]);

            CommonHelper::addUserWalletBalance($amount, $userId, $meta['country_id']);
            CommonHelper::notifyWalletRecharge($userId, $amount, $meta['country_id'], $walletTransaction->txn_id ?? null);

            return;
        }

        // --- order ---
        $order = Order::find((int) $customId);
        if (!$order) {
            self::wlog('error', 'PayPal settle: order not found', ['custom_id' => $customId]);

            return;
        }
        if ((int) $order->active_status === (int) OrderStatusList::$received) {
            return; // already settled by the other path
        }

        $transaction = Transaction::create([
            'transaction_type' => 'Transaction',
            'user_id'          => $order->user_id,
            'order_id'         => $order->id,
            'type'             => Transaction::$typePaypal,
            'txn_id'           => $txnId,
            'payu_txn_id'      => '',
            'amount'           => $amount ?: $order->final_total,
            'status'           => Transaction::$statusSuccess,
            'message'          => 'txn_order_payment',
            'transaction_date' => date('Y-m-d H:i:s'),
        ]);

        $order->active_status = OrderStatusList::$received;
        $order->transaction_id = $transaction->id ?? 0;

        if (isset($order->wallet_balance) && $order->wallet_balance > 0) {
            $user = User::find($order->user_id);
            if ($user) {
                $newBalance = $user->balance < $order->wallet_balance ? 0 : $user->balance - $order->wallet_balance;
                CommonHelper::updateUserWalletBalance($newBalance, $user->id);
                CommonHelper::addWalletTransaction($order->id, 0, $user->id, 'debit', $order->wallet_balance, 'wallet_used_against_order_placement', 1, Transaction::$paymentTypeWallet);
            }
        }

        $order->save();

        // Items follow the order — the old IPN handler skipped this, unlike every other
        // gateway, so ecommerce items were left behind at their placement status.
        OrderItem::where('order_id', $order->id)
            ->whereNotIn('active_status', [OrderStatusList::$cancelled, OrderStatusList::$returned])
            ->update(['active_status' => $order->active_status]);

        CommonHelper::finalizeOnlineOrderSuccess($order);

        try {
            dispatch(function () use ($order) {
                CommonHelper::sendSmsOrderStatus($order, $order->active_status);
            })->afterResponse();
        } catch (\Exception $e) {
            self::wlog('error', 'PayPal order SMS error', [$e->getMessage()]);
        }
        try {
            dispatch(function () use ($order) {
                CommonHelper::sendOrderNotificationsToAdmins($order, 'new_order', $order->delivery_boy_id ?? null);
            })->afterResponse();
        } catch (\Exception $e) {
            self::wlog('error', 'PayPal admin notification error', [$e->getMessage()]);
        }
    }

    /** Declined, reversed or abandoned: cancel the order / record the failed recharge. */
    private static function paypalSettleFailure(string $customId, string $txnId): void
    {
        if ($customId === '') {
            return;
        }

        if (!is_numeric($customId) && str_contains($customId, 'wallet_recharge')) {
            $parts = explode('-', $customId);
            $userId = isset($parts[1]) && is_numeric($parts[1]) ? (int) $parts[1] : 0;
            if ($userId) {
                self::recordFailedWalletRecharge($userId, 0, $txnId, Transaction::$paymentTypePaypal, CommonHelper::parseRechargeCountryId($customId));
            }

            return;
        }

        self::recordFailedPayment((int) $customId, $txnId, 'txn_payment_failed', Transaction::$typePaypal);
    }

    /* ================= PhonePe (status poll) ================= */

    public function getOrderStatusPhonepe(Request $request)
    {
        $request->validate([
            'transaction_id' => 'required|string'
        ]);
        try {
            $transactionId = $request->transaction_id;

            // PhonePe mode is zone-wise; resolve from the order or the request location.
            $zone = null;
            if ($request->filled('order_id')) {
                $zone = CommonHelper::resolveOrderZone(Order::find($request->order_id));
            } elseif ($request->filled('latitude') && $request->filled('longitude')) {
                $zone = CommonHelper::getDeliverableCity($request->latitude, $request->longitude, strtolower(trim((string) $request->header('channel'))) ?: null);
            }
            $gw = $zone ? CommonHelper::countryPaymentGateways($zone?->country) : [];
            $mode = $gw['phonepay_mode'] ?? null; // 'uat' or 'production'

            // Get access token from your stored method or regenerate (better to cache it)
            $accessToken = $request->token; // Replace with dynamic token generation
            if (empty($accessToken)) {
                self::wlog('error', 'PhonePe status token missing');
                return CommonHelper::responseError("Missing PhonePe token.");
            }

            $statusUrl = $mode === 'production'
                ? "https://api.phonepe.com/apis/pg/v1/status/$transactionId"
                : "https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/order/$transactionId/status";

            $curl = curl_init();

            curl_setopt_array($curl, [
                CURLOPT_URL => $statusUrl,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_ENCODING => '',
                CURLOPT_MAXREDIRS => 10,
                CURLOPT_TIMEOUT => 0,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
                CURLOPT_CUSTOMREQUEST => 'GET',
                CURLOPT_HTTPHEADER => [
                    'Content-Type: application/json',
                    'Authorization: O-Bearer ' . $accessToken
                ],
            ]);

            $response = curl_exec($curl);
            unset($curl);

            $response = json_decode($response, true);

            // Guard against empty / invalid responses so we do not access null offsets.
            if (!$response) {
                self::wlog('error', 'PhonePe status empty response', ['raw' => $response]);
                return CommonHelper::responseError("Unable to read PhonePe response.");
            }

            // PhonePe wraps data under "data" sometimes; fall back to root.
            $statusPayload = $response['data'] ?? $response;

            $paymentDetails = $statusPayload['paymentDetails'][0] ?? null;
            $metaInfo = $statusPayload['metaInfo'] ?? null;

            if (!$paymentDetails || !$metaInfo) {
                self::wlog('error', 'PhonePe status missing data', ['payload' => $statusPayload]);
                return CommonHelper::responseError("PhonePe status not available yet. Try again.");
            }

            try {
                if (($paymentDetails['state'] ?? '') == 'COMPLETED') {
                    // transaction

                    $order_id = $metaInfo['order_id'] ?? 0;

                    // Idempotency: the app polls this until COMPLETED — if the txn is
                    // already recorded, return the same status without re-processing.
                    $ppTxnId = $paymentDetails['transactionId'] ?? '';
                    if ($ppTxnId && (Transaction::where('txn_id', $ppTxnId)->exists()
                        || WalletTransaction::where('txn_id', $ppTxnId)->exists())) {
                        return CommonHelper::responseWithData(['status' => $paymentDetails['state'], 'order_id' => $metaInfo['order_id'] ?? null, 'user_id' => $metaInfo['user_id'] ?? null, 'type' => $metaInfo['type'] ?? null]);
                    }

                    if (($metaInfo['type'] ?? '') == 'order') {

                        $transactionData = array();
                        $transactionData['user_id'] = $metaInfo['user_id'] ?? 0;
                        $transactionData['order_id'] = $metaInfo['order_id'] ?? 0;
                        $transactionData['type'] = Transaction::$typePhonepe;
                        $transactionData['txn_id'] = $paymentDetails['transactionId'] ?? '';
                        $transactionData['payu_txn_id'] = "";
                        $transactionData['amount'] = ($paymentDetails['amount'] ?? 0) / 100;
                        $transactionData['status'] = Transaction::$statusSuccess;
                        $transactionData['message'] = 'txn_order_payment';
                        $transactionData['transaction_date'] = now();

                        $transaction = Transaction::create($transactionData);
                        $order = Order::withTrashed()->where('id', $metaInfo['order_id'] ?? 0)->first();
                        $user = User::where('id', $metaInfo['user_id'] ?? 0)->first();
                        $user_wallet_balance = $user->balance;
                        if (!$order) {
                            return CommonHelper::responseError("Invalid Order Id");
                        }

                        $order->active_status = OrderStatusList::$received;
                        $order->transaction_id = $transaction->id ?? 0;

                        if (isset($order->wallet_balance) && $order->wallet_balance > 0) {
                            // Deduct the balance & set the wallet transaction
                            $new_balance = $user_wallet_balance < $order->wallet_balance ? 0 : $user_wallet_balance - $order->wallet_balance;
                            CommonHelper::updateUserWalletBalance($new_balance, $user->id);
                            CommonHelper::addWalletTransaction($order_id, 0, $user->id, 'debit', $order->wallet_balance, 'wallet_used_against_order_placement', 1, Transaction::$paymentTypeWallet);
                        }

                        $order->save();

                        $excludedStatuses = [OrderStatusList::$cancelled, OrderStatusList::$returned];
                        // Update the order items
                        OrderItem::where("order_id", $order->id)
                            ->whereNotIn("active_status", $excludedStatuses)
                            ->update(['active_status' => $order->active_status]);

                        // Online payment confirmed -> commit reservation + consume the cart.
                        CommonHelper::finalizeOnlineOrderSuccess($order);

                        try {
                            dispatch(function () use ($order) {
                                CommonHelper::sendSmsOrderStatus($order, $order->active_status);
                            })->afterResponse();
                        } catch (\Exception $e) {
                            self::wlog('error', "Phonepe order SMS error :", [$e->getMessage()]);
                        }

                        try {
                            dispatch(function () use ($order) {
                                CommonHelper::sendOrderNotificationsToAdmins($order, 'new_order', $order->delivery_boy_id ?? null);
                            })->afterResponse();
                        } catch (\Exception $e) {
                            self::wlog('error', "Phonepe admin notification error :", [$e->getMessage()]);
                        }

                        return CommonHelper::responseWithData(['status' => $paymentDetails['state'], 'order_id' => $metaInfo['order_id'], 'user_id' => $metaInfo['user_id'], 'type' => $metaInfo['type']]);
                    } elseif (($metaInfo['type'] ?? '')  == 'wallet') {

                        $rechargeCid = $metaInfo['country_id'] ?? CommonHelper::parseRechargeCountryId($metaInfo['order_id'] ?? '');
                        $rechargeMeta = CommonHelper::rechargeWalletMeta($rechargeCid, $metaInfo['user_id'] ?? 0);
                        $walletTransactionData = array();
                        $walletTransactionData['user_id'] =  $metaInfo['user_id'] ?? 0;
                        $walletTransactionData['order_id'] = '';
                        $walletTransactionData['type'] = 'credit';
                        $walletTransactionData['payment_type'] = Transaction::$paymentTypePhonepe;
                        $walletTransactionData['txn_id'] =  $paymentDetails['transactionId'] ?? '';
                        $walletTransactionData['amount'] = ($paymentDetails['amount'] ?? 0) / 100;
                        $walletTransactionData['status'] = Transaction::$statusSuccess;
                        $walletTransactionData['message'] = 'wallet_successfully_recharged';
                        $walletTransactionData['transaction_date'] = now();
                        $walletTransactionData['country_id'] = $rechargeMeta['country_id'];
                        $walletTransactionData['currency'] = $rechargeMeta['currency'];
                        $walletTransactionData['currency_code'] = $rechargeMeta['currency_code'];
                        $wallet_transaction = WalletTransaction::create($walletTransactionData);

                        CommonHelper::addUserWalletBalance($walletTransactionData['amount'], $metaInfo['user_id'] ?? 0, $rechargeMeta['country_id']);
                        CommonHelper::notifyWalletRecharge($metaInfo['user_id'] ?? 0, $walletTransactionData['amount'], $rechargeMeta['country_id'], $wallet_transaction->txn_id ?? null);

                        return CommonHelper::responseWithData(['status' => $paymentDetails['state'], 'order_id' => $metaInfo['order_id'], 'user_id' => $metaInfo['user_id'], 'type' => $metaInfo['type']]);
                    }
                } else {

                    if (($metaInfo['type'] ?? '') == 'order') {
                        Order::where('id', $metaInfo['order_id'] ?? 0)->update(['active_status' => OrderStatusList::$cancelled]);
                        self::recordFailedPayment($metaInfo['order_id'] ?? 0, (string) ($paymentDetails['transactionId'] ?? ''), 'txn_payment_failed', Transaction::$typePhonepe);
                        return CommonHelper::responseWithData(['status' => $paymentDetails['state'] ?? 'FAILED', 'order_id' => $metaInfo['order_id'], 'user_id' => $metaInfo['user_id'], 'type' => $metaInfo['type']]);
                    } elseif (($metaInfo['type'] ?? '') == 'wallet') {
                        $rechargeCid = $metaInfo['country_id'] ?? CommonHelper::parseRechargeCountryId($metaInfo['order_id'] ?? '');
                        self::recordFailedWalletRecharge($metaInfo['user_id'] ?? null, ($paymentDetails['amount'] ?? 0) / 100, (string) ($paymentDetails['transactionId'] ?? ''), Transaction::$paymentTypePhonepe, $rechargeCid);
                        return CommonHelper::responseWithData(['status' => $paymentDetails['state'] ?? 'FAILED', 'order_id' => $metaInfo['order_id'], 'user_id' => $metaInfo['user_id'], 'type' => $metaInfo['type']]);
                    }
                }
            } catch (\Exception $e) {
                self::wlog('error', "Error processing Phonepe callback: " . $e->getMessage());
                return CommonHelper::responseError("An error occurred while processing the callback.");
            }
        } catch (\Exception $e) {
            self::wlog('error', 'PhonePe Status Check Error: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => $e->getMessage()
            ], 500);
        }
    }
}
