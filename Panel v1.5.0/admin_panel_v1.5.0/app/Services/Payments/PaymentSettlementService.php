<?php

namespace App\Services\Payments;

use App\Plugins\Dto\PaymentOutcome;
use App\Helpers\CommonHelper;
use App\Jobs\SendEmailJob;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusList;
use App\Models\Transaction;
use App\Models\User;
use App\Models\WalletTransaction;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use App\Support\WebhookLog;

/**
 * Turns a gateway's verdict into money moved.
 *
 * Lifted from WebhookController's Cashfree branch — the cleanest copy of the ~60-line
 * success path — so a payment plugin settles through exactly the code that has been
 * settling core gateways, rather than its own approximation. Cashfree now calls this
 * too, which is the point: one settle path, one place to fix.
 *
 * Three invariants, all of which existed before and are preserved here:
 *
 *  - **idempotent on the gateway's txn id** — gateways retry, and a replay must not
 *    write a second transaction or credit a wallet twice;
 *  - **the reference decides what is paid for** — `order-{id}-{userId}` settles an
 *    order, `wallet-{YmdHis}-{userId}[-c{countryId}]` a recharge; nothing else is touched;
 *  - **notifications go out after the response**, so a slow SMTP or FCM cannot make a
 *    gateway's webhook time out and retry.
 */
final class PaymentSettlementService
{
    /**
     * Settle whatever the gateway reported.
     *
     * @param  string $txnType      `transactions.type`, e.g. Transaction::$typeCashfree or an plugin's own
     * @param  string $paymentType  `Transaction::$paymentType*`-style label for wallet rows
     * @return array{ok:bool, message:string, duplicate?:bool}
     */
    public function settle(PaymentOutcome $outcome, string $txnType, string $paymentType): array
    {
        if ($outcome->status === PaymentOutcome::IGNORE || $outcome->status === PaymentOutcome::PENDING) {
            return ['ok' => true, 'message' => 'ignored'];
        }

        $ref = $this->parseReference($outcome->reference);
        if (!$ref) {
            WebhookLog::warning('[Payments] unrecognised reference: ' . $outcome->reference);

            return ['ok' => false, 'message' => 'invalid_payment_reference'];
        }

        if ($outcome->gatewayTxnId && $this->alreadyRecorded($outcome->gatewayTxnId)) {
            WebhookLog::info('[Payments] duplicate settlement ignored for txn ' . $outcome->gatewayTxnId);

            return ['ok' => true, 'message' => 'already_processed', 'duplicate' => true];
        }

        if ($ref['purpose'] === 'order') {
            return $outcome->isSuccess()
                ? $this->orderPaid($ref, $outcome, $txnType, $paymentType)
                : $this->orderFailed($ref, $outcome, $txnType);
        }

        return $outcome->isSuccess()
            ? $this->walletRecharged($ref, $outcome, $paymentType)
            : $this->walletFailed($ref, $outcome, $paymentType);
    }

    /**
     * `order-12-34` → order 12, user 34.
     * `wallet-20260928153000-34[-c1]` → a recharge for user 34 in country 1.
     *
     * The formats are core's own, already used by every gateway's return URLs.
     *
     * @return array{purpose:string, order_id:?int, user_id:?int, parts:array}|null
     */
    public function parseReference(string $reference): ?array
    {
        $parts = explode('-', trim($reference));
        $purpose = strtolower($parts[0] ?? '');

        if ($purpose === 'order' && isset($parts[1], $parts[2]) && is_numeric($parts[1])) {
            return ['purpose' => 'order', 'order_id' => (int) $parts[1], 'user_id' => (int) $parts[2], 'parts' => $parts];
        }
        if ($purpose === 'wallet' && isset($parts[1], $parts[2]) && is_numeric($parts[2])) {
            return ['purpose' => 'wallet', 'order_id' => null, 'user_id' => (int) $parts[2], 'parts' => $parts];
        }

        return null;
    }

    /** Has this gateway transaction already been settled, either way? */
    public function alreadyRecorded(string $gatewayTxnId): bool
    {
        if ($gatewayTxnId === '') {
            return false;
        }

        return Transaction::where('txn_id', $gatewayTxnId)->exists()
            || WalletTransaction::where('txn_id', $gatewayTxnId)->exists();
    }

    /* -------------------------------------------------------------- order paid */

    private function orderPaid(array $ref, PaymentOutcome $outcome, string $txnType, string $paymentType): array
    {
        $order = Order::withTrashed()->find($ref['order_id']);
        if (!$order) {
            return ['ok' => false, 'message' => 'invalid_order_id'];
        }

        $alreadyPaid = Transaction::where('order_id', (string) $order->id)
            ->where('status', Transaction::$statusSuccess)
            ->exists();

        /* A successful transaction is not proof the order was settled. The two used to
           be written one after the other outside a transaction, so a failure in between
           — or a crash, or a timeout — left a paid transaction against an order still
           sitting on payment_pending. Every later retry then saw "already paid", wrote
           another duplicate row and left the order exactly as stuck as it was.

           So the question asked here is whether the ORDER is settled, not whether a
           transaction exists. If money arrived and the order never moved, this finishes
           the job rather than filing another note about it. */
        $settled = (int) $order->active_status !== OrderStatusList::$paymentPending;

        if ($alreadyPaid && $settled) {
            WebhookLog::warning("[Payments] order {$order->id} is already paid; recording txn "
                . $outcome->gatewayTxnId . ' without settling it again.');

            Transaction::create([
                'user_id'          => $ref['user_id'],
                'order_id'         => $order->id,
                'type'             => $txnType,
                'txn_id'           => (string) $outcome->gatewayTxnId,
                'payu_txn_id'      => '',
                'amount'           => $outcome->amount ?: (float) $order->final_total,
                'status'           => Transaction::$statusSuccess,
                'message'          => 'txn_order_payment_duplicate',
                'transaction_date' => now(),
            ]);

            return ['ok' => true, 'message' => 'already_processed', 'duplicate' => true];
        }

        if ($alreadyPaid) {
            WebhookLog::warning("[Payments] order {$order->id} has a paid transaction but was never "
                . 'settled; completing it now.');
        }

        /* One commit, or none.
         *
         * The money record and the order's state are the same fact. Written separately
         * they can disagree, and the way they disagree is the worst one: a paid
         * transaction against an unpaid order, which every retry then mistakes for work
         * already done. Anything that throws in here now rolls the whole lot back, the
         * webhook answers 500, and the gateway's own retry settles it properly. */
        $transaction = DB::transaction(function () use ($ref, $order, $outcome, $txnType) {
            $transaction = Transaction::create([
                'user_id'          => $ref['user_id'],
                'order_id'         => $order->id,
                'type'             => $txnType,
                'txn_id'           => (string) $outcome->gatewayTxnId,
                'payu_txn_id'      => '',
                'amount'           => $outcome->amount ?: (float) $order->final_total,
                'status'           => Transaction::$statusSuccess,
                'message'          => 'txn_order_payment',
                'transaction_date' => now(),
            ]);

            $order->active_status = OrderStatusList::$received;
            $order->transaction_id = $transaction->id ?? 0;

            // Part-paid by wallet: that part is deducted only now, when the rest is confirmed.
            if ((float) ($order->wallet_balance ?? 0) > 0) {
                $user = User::find($ref['user_id']);
                if ($user) {
                    $balance = (float) $user->balance;
                    $new = $balance < (float) $order->wallet_balance ? 0 : $balance - (float) $order->wallet_balance;
                    CommonHelper::updateUserWalletBalance($new, $user->id);
                    CommonHelper::addWalletTransaction(
                        $order->id,
                        0,
                        $user->id,
                        'debit',
                        $order->wallet_balance,
                        'wallet_used_against_order_placement',
                        1,
                        // The wallet is what moved this money; $paymentType paid the rest.
                        Transaction::$paymentTypeWallet
                    );
                }
            }

            $order->save();

            // Items follow the order, except the ones already out of the flow.
            OrderItem::where('order_id', $order->id)
                ->whereNotIn('active_status', [OrderStatusList::$cancelled, OrderStatusList::$returned])
                ->update(['active_status' => $order->active_status]);

            return $transaction;
        });

        // Stock was reserved at placement; payment confirmed commits it and clears the cart.
        CommonHelper::finalizeOnlineOrderSuccess($order);

        $this->notifyOrderPaid($order);

        return ['ok' => true, 'message' => 'payment_settled'];
    }

    /** Push + admin panel, mail and SMS — each isolated so one channel cannot break the rest. */
    private function notifyOrderPaid(Order $order): void
    {
        try {
            dispatch(function () use ($order) {
                CommonHelper::sendNotificationOrderStatus($order);
                CommonHelper::sendOrderNotificationsToAdmins($order, 'new_order', $order->delivery_boy_id ?? null);
            })->afterResponse();
        } catch (\Throwable $e) {
            WebhookLog::error('[Payments] order notification error: ' . $e->getMessage());
        }

        try {
            dispatch(new SendEmailJob($order))->afterResponse();
        } catch (\Throwable $e) {
            WebhookLog::error('[Payments] order mail error: ' . $e->getMessage());
        }

        try {
            dispatch(function () use ($order) {
                CommonHelper::sendSmsOrderStatus($order, $order->active_status);
            })->afterResponse();
        } catch (\Throwable $e) {
            WebhookLog::error('[Payments] order SMS error: ' . $e->getMessage());
        }
    }

    /* ------------------------------------------------------------ order failed */

    /**
     * Payment refused: the order is cancelled, its tax reversed and the customer told.
     * Same behaviour as WebhookController::recordFailedPayment, which now calls this.
     */
    public function orderPaymentFailed($orderId, string $gatewayTxnId, string $message, ?string $txnType = null): void
    {
        try {
            if (empty($orderId) || !is_numeric($orderId)) {
                return;
            }
            $order = Order::find($orderId);
            if (!$order) {
                return;
            }

            /* Already paid? Then this is a late or duplicate failure event — gateways do
               send both, and a redirect can arrive after the server callback. Cancelling
               a settled order here would refund-by-accident: the shopper paid, the stock
               was committed and the cart cleared. Record nothing but the log line. */
            $paid = Transaction::where('order_id', (string) $order->id)
                ->where('status', Transaction::$statusSuccess)
                ->exists();
            if ($paid) {
                WebhookLog::warning("[Payments] ignoring failure for order {$order->id}: a successful payment is already recorded.");

                return;
            }

            $transaction = $gatewayTxnId !== '' ? Transaction::where('txn_id', $gatewayTxnId)->first() : null;
            if ($transaction) {
                $transaction->status = Transaction::$statusFailed;
                $transaction->message = $message;
                $transaction->save();
            } else {
                $transaction = Transaction::create([
                    'user_id'          => $order->user_id,
                    'order_id'         => $order->id,
                    'type'             => $txnType,
                    'txn_id'           => $gatewayTxnId,
                    'payu_txn_id'      => '',
                    'amount'           => $order->total,
                    'status'           => Transaction::$statusFailed,
                    'message'          => $message,
                    'transaction_date' => date('Y-m-d H:i:s'),
                ]);
            }

            $order->transaction_id = $transaction->id ?? $order->transaction_id;
            $order->active_status = OrderStatusList::$cancelled;
            $order->promo_code_id = 0;
            $order->save();

            CommonHelper::reverseOrderTax($order);

            try {
                dispatch(function () use ($order) {
                    CommonHelper::sendPaymentFailedNotification($order);
                })->afterResponse();
            } catch (\Throwable $e) {
                WebhookLog::error('[Payments] payment failed notification error: ' . $e->getMessage());
            }
        } catch (\Throwable $e) {
            WebhookLog::error('[Payments] orderPaymentFailed error: ' . $e->getMessage());
        }
    }

    private function orderFailed(array $ref, PaymentOutcome $outcome, string $txnType): array
    {
        $this->orderPaymentFailed(
            $ref['order_id'],
            (string) $outcome->gatewayTxnId,
            $outcome->message ?: 'txn_payment_failed',
            $txnType
        );

        return ['ok' => true, 'message' => 'payment_failure_recorded'];
    }

    /* ----------------------------------------------------------------- wallet */

    private function walletRecharged(array $ref, PaymentOutcome $outcome, string $paymentType): array
    {
        $parts = $ref['parts'];
        $userId = $ref['user_id'];
        $meta = CommonHelper::rechargeWalletMeta(CommonHelper::parseRechargeCountryId($parts), $userId);

        // The reference carries the moment the recharge was started (YmdHis).
        $date = now()->toDateTimeString();
        try {
            $date = Carbon::createFromFormat('YmdHis', (string) ($parts[1] ?? ''))->format('Y-m-d H:i:s');
        } catch (\Throwable $e) {
            // Keep now() — a malformed timestamp must not lose the recharge.
        }

        // The statement line and the balance are one fact, same as an order's are.
        $walletTransaction = DB::transaction(function () use ($userId, $paymentType, $outcome, $date, $meta) {
            $walletTransaction = WalletTransaction::create([
                'user_id'          => $userId,
                'order_id'         => '',
                'type'             => 'credit',
                'payment_type'     => $paymentType,
                'txn_id'           => (string) $outcome->gatewayTxnId,
                'amount'           => $outcome->amount,
                'status'           => Transaction::$statusSuccess,
                'message'          => 'wallet_successfully_recharged',
                'transaction_date' => $date,
                'country_id'       => $meta['country_id'],
                'currency'         => $meta['currency'],
                'currency_code'    => $meta['currency_code'],
            ]);

            CommonHelper::addUserWalletBalance($outcome->amount, $userId, $meta['country_id']);

            return $walletTransaction;
        });
        CommonHelper::notifyWalletRecharge($userId, $outcome->amount, $meta['country_id'], $walletTransaction->txn_id ?? null);

        return ['ok' => true, 'message' => 'wallet_recharged'];
    }

    /**
     * A failed recharge is recorded too — before this existed, a failure stored nothing
     * and the customer saw no reason their money had not arrived.
     * Same behaviour as WebhookController::recordFailedWalletRecharge.
     */
    public function walletRechargeFailed($userId, $amount, string $gatewayTxnId, string $paymentType, $countryId): void
    {
        try {
            $amount = round((float) $amount, 2);
            if (empty($userId) || !is_numeric($userId) || $amount <= 0) {
                return;
            }
            if ($gatewayTxnId !== '' && WalletTransaction::where('txn_id', $gatewayTxnId)->exists()) {
                return;
            }

            $meta = CommonHelper::rechargeWalletMeta($countryId, $userId);
            WalletTransaction::create([
                'user_id'          => $userId,
                'order_id'         => '',
                'type'             => 'credit',
                'payment_type'     => $paymentType,
                'txn_id'           => $gatewayTxnId,
                'amount'           => $amount,
                'status'           => WalletTransaction::$statusFailed,
                'message'          => 'wallet_recharge_failed',
                'transaction_date' => date('Y-m-d H:i:s'),
                'country_id'       => $meta['country_id'],
                'currency'         => $meta['currency'],
                'currency_code'    => $meta['currency_code'],
            ]);

            $cid = $meta['country_id'];
            dispatch(function () use ($userId, $amount, $cid) {
                CommonHelper::sendWalletRechargeFailedNotification($userId, $amount, $cid);
            })->afterResponse();
        } catch (\Throwable $e) {
            WebhookLog::error('[Payments] walletRechargeFailed error: ' . $e->getMessage());
        }
    }

    private function walletFailed(array $ref, PaymentOutcome $outcome, string $paymentType): array
    {
        $this->walletRechargeFailed(
            $ref['user_id'],
            $outcome->amount,
            (string) $outcome->gatewayTxnId,
            $paymentType,
            CommonHelper::parseRechargeCountryId($ref['parts'])
        );

        return ['ok' => true, 'message' => 'payment_failure_recorded'];
    }
}
