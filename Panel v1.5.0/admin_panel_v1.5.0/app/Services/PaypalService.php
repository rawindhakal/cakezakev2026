<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * PayPal Orders v2 + webhooks.
 *
 * Replaces the classic Web Payments Standard form (cgi-bin/webscr) and IPN. The
 * difference that matters: the buyer's return is captured server-side, so the outcome
 * is known immediately instead of arriving later on an IPN — which is why the old flow
 * could only ever redirect with "status=pending".
 *
 * Credentials are per country (Countries → Payment Gateways): client id, secret,
 * webhook id and mode.
 */
class PaypalService
{
    private array $gateways;

    public function __construct(array $gateways = [])
    {
        $this->gateways = $gateways;
    }

    public function isConfigured(): bool
    {
        return $this->clientId() !== '' && $this->secret() !== '';
    }

    private function clientId(): string
    {
        return trim((string) ($this->gateways['paypal_client_id'] ?? ''));
    }

    private function secret(): string
    {
        return trim((string) ($this->gateways['paypal_client_secret'] ?? ''));
    }

    public function webhookId(): string
    {
        return trim((string) ($this->gateways['paypal_webhook_id'] ?? ''));
    }

    public function currency(): string
    {
        return strtoupper(trim((string) ($this->gateways['paypal_currency_code'] ?? 'USD'))) ?: 'USD';
    }

    /** Sandbox until the country's gateway is switched to live. */
    private function baseUrl(): string
    {
        $mode = strtolower((string) ($this->gateways['paypal_mode'] ?? 'sandbox'));

        return $mode === 'live' || $mode === 'production'
            ? 'https://api-m.paypal.com'
            : 'https://api-m.sandbox.paypal.com';
    }

    /** OAuth2 client-credentials token. Short-lived; fetched per operation. */
    private function token(): ?string
    {
        try {
            $res = Http::asForm()
                ->withBasicAuth($this->clientId(), $this->secret())
                ->timeout(20)
                ->post($this->baseUrl() . '/v1/oauth2/token', ['grant_type' => 'client_credentials']);

            if (!$res->successful()) {
                Log::error('PayPal token failed', ['status' => $res->status(), 'body' => $res->body()]);

                return null;
            }

            return $res->json('access_token');
        } catch (\Throwable $e) {
            Log::error('PayPal token error: ' . $e->getMessage());

            return null;
        }
    }

    /**
     * Create an order and return ['id' => ..., 'approve_url' => ...].
     *
     * `$customId` travels with the payment and comes back on capture and on the
     * webhook — it is how a payment is tied to an order or a wallet recharge.
     */
    public function createOrder(float $amount, string $customId, string $returnUrl, string $cancelUrl, string $brandName = ''): ?array
    {
        $token = $this->token();
        if (!$token) {
            return null;
        }

        try {
            $res = Http::withToken($token)->timeout(20)->post($this->baseUrl() . '/v2/checkout/orders', [
                'intent' => 'CAPTURE',
                'purchase_units' => [[
                    'custom_id' => $customId,
                    'amount' => [
                        'currency_code' => $this->currency(),
                        // PayPal rejects a value with the wrong scale for the currency.
                        'value' => number_format($amount, 2, '.', ''),
                    ],
                ]],
                'payment_source' => [
                    'paypal' => [
                        'experience_context' => [
                            'brand_name' => $brandName !== '' ? mb_substr($brandName, 0, 127) : 'Branch',
                            'user_action' => 'PAY_NOW',
                            'return_url' => $returnUrl,
                            'cancel_url' => $cancelUrl,
                        ],
                    ],
                ],
            ]);

            if (!$res->successful()) {
                Log::error('PayPal create order failed', ['status' => $res->status(), 'body' => $res->body()]);

                return null;
            }

            $approve = collect($res->json('links') ?? [])
                ->first(fn ($l) => ($l['rel'] ?? '') === 'payer-action' || ($l['rel'] ?? '') === 'approve');

            return [
                'id'          => $res->json('id'),
                'approve_url' => $approve['href'] ?? null,
            ];
        } catch (\Throwable $e) {
            Log::error('PayPal create order error: ' . $e->getMessage());

            return null;
        }
    }

    /**
     * Capture an approved order. Returns the capture details, or null when the capture
     * did not complete — the caller must treat anything but COMPLETED as unpaid.
     *
     * @return array{status:string, capture_id:string, amount:float, custom_id:string}|null
     */
    public function captureOrder(string $orderId): ?array
    {
        $token = $this->token();
        if (!$token) {
            return null;
        }

        try {
            // Body must be an empty JSON OBJECT. Passing [] to post() encodes as `[]`
            // (a JSON array), which PayPal rejects with MALFORMED_REQUEST_JSON.
            $res = Http::withToken($token)
                ->timeout(30)
                ->withBody('{}', 'application/json')
                ->post($this->baseUrl() . "/v2/checkout/orders/{$orderId}/capture");

            if (!$res->successful()) {
                // A webview that loads the return URL twice sends a second capture, and
                // PayPal answers ORDER_ALREADY_CAPTURED. The money IS taken, so read the
                // order back rather than reporting a failure.
                if ($this->errorName($res->json()) === 'ORDER_ALREADY_CAPTURED') {
                    return $this->capturedDetails($orderId, $token);
                }

                Log::error('PayPal capture failed', ['status' => $res->status(), 'body' => $res->body()]);

                return null;
            }

            $capture = $res->json('purchase_units.0.payments.captures.0') ?? [];

            return [
                'status'     => (string) ($capture['status'] ?? $res->json('status') ?? ''),
                'capture_id' => (string) ($capture['id'] ?? $orderId),
                'amount'     => (float) ($capture['amount']['value'] ?? 0),
                'custom_id'  => (string) ($capture['custom_id'] ?? $res->json('purchase_units.0.custom_id') ?? ''),
            ];
        } catch (\Throwable $e) {
            Log::error('PayPal capture error: ' . $e->getMessage());

            return null;
        }
    }

    /** PayPal reports the reason under `name`, or per-issue under `details[].issue`. */
    private function errorName(?array $body): string
    {
        if (!is_array($body)) {
            return '';
        }
        $issue = $body['details'][0]['issue'] ?? '';

        return (string) ($issue !== '' ? $issue : ($body['name'] ?? ''));
    }

    /** Read an already-captured order back, so a repeated return still settles once. */
    private function capturedDetails(string $orderId, string $token): ?array
    {
        try {
            $res = Http::withToken($token)->timeout(20)
                ->get($this->baseUrl() . "/v2/checkout/orders/{$orderId}");

            if (!$res->successful()) {
                return null;
            }

            $capture = $res->json('purchase_units.0.payments.captures.0') ?? [];
            if (($capture['status'] ?? '') === '') {
                return null;
            }

            return [
                'status'     => (string) $capture['status'],
                'capture_id' => (string) ($capture['id'] ?? $orderId),
                'amount'     => (float) ($capture['amount']['value'] ?? 0),
                'custom_id'  => (string) ($capture['custom_id'] ?? $res->json('purchase_units.0.custom_id') ?? ''),
            ];
        } catch (\Throwable $e) {
            Log::error('PayPal order lookup error: ' . $e->getMessage());

            return null;
        }
    }

    /**
     * Verify a webhook against PayPal, so a forged POST cannot mark an order paid.
     * Without a configured webhook id there is nothing to verify against, and the
     * event is rejected rather than trusted.
     */
    public function verifyWebhook(array $headers, array $event): bool
    {
        $webhookId = $this->webhookId();
        if ($webhookId === '') {
            Log::error('PayPal webhook rejected: no webhook id configured');

            return false;
        }

        $token = $this->token();
        if (!$token) {
            return false;
        }

        $header = fn (string $k) => $headers[strtolower($k)][0] ?? '';

        try {
            $res = Http::withToken($token)->timeout(20)
                ->post($this->baseUrl() . '/v1/notifications/verify-webhook-signature', [
                    'auth_algo'         => $header('paypal-auth-algo'),
                    'cert_url'          => $header('paypal-cert-url'),
                    'transmission_id'   => $header('paypal-transmission-id'),
                    'transmission_sig'  => $header('paypal-transmission-sig'),
                    'transmission_time' => $header('paypal-transmission-time'),
                    'webhook_id'        => $webhookId,
                    'webhook_event'     => $event,
                ]);

            return $res->successful() && $res->json('verification_status') === 'SUCCESS';
        } catch (\Throwable $e) {
            Log::error('PayPal webhook verify error: ' . $e->getMessage());

            return false;
        }
    }
}
