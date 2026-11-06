<?php

namespace App\Plugins\Adapters;

use App\Plugins\Contracts\PaymentGateway;
use App\Plugins\PluginPackage;
use App\Plugins\Dto\PaymentContext;
use App\Plugins\Dto\PaymentInitiation;
use App\Plugins\Dto\PaymentOutcome;
use App\Models\PluginPaymentIntent;
use App\Models\PaymentConfiguration;
use App\Services\Payment\PaymentInterface;
use App\Services\Payment\WebhookVerifiable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Makes a payment plugin look like one of CakeZake's own gateways.
 *
 * CakeZake's own gateway contract knows about orders, wallet recharges, per-country
 * credentials and signed callbacks. The universal contract knows about an amount and a
 * payment id, because that is all a plugin can rely on across every CakeZake product.
 * This class is where the difference is absorbed, and it is deliberately the only
 * place: the plugin stays portable, and nothing in core learns that a gateway came
 * from a different format.
 *
 * One instance per plugin — the slug and the manifest are constructor state, which is
 * why PaymentGateway::code() is an instance method.
 *
 * The settlement rule is the important part. A plugin is not required to
 * verify a callback, and the one we ship (PayU Payment Links) deliberately does not,
 * so NOTHING the browser or the gateway sends is treated as an outcome. Every outcome
 * in this class comes from asking the gateway directly about a payment id we wrote
 * down before the shopper left. A forged return URL can therefore only trigger a
 * re-check of a real payment, never settle a fake one.
 */
final class PaymentAdapter implements PaymentGateway
{
    public function __construct(private readonly PluginPackage $plugin) {}

    public function code(): string
    {
        return $this->plugin->code();
    }

    public function label(): string
    {
        return $this->plugin->name();
    }

    /** The short brand a transaction or wallet row records. */
    public function paymentLabel(): string
    {
        return $this->plugin->paymentLabel();
    }

    /* ------------------------------------------------------------------- settings */

    /**
     * Every credential the plugin declared has a value.
     *
     * The manifest has no per-field "required" flag, so a declared field is taken as
     * needed unless it says otherwise. A plugin that wants a field optional says
     * `"required": false`, which costs it nothing in hosts that ignore the key.
     */
    public function isConfigured(array $gateways): bool
    {
        $credentials = \App\Helpers\CommonHelper::gatewayCredentials($gateways, $this->code());

        foreach ($this->plugin->settingsFields() as $field) {
            if (($field['required'] ?? true) === false) {
                continue;
            }

            $value = $credentials[$field['column']] ?? null;

            if ($value === null || $value === '') {
                return false;
            }
        }

        return true;
    }

    /** Field keys the customer apps may read. Never a credential. */
    public function publicSettingKeys(): array
    {
        $code = $this->code();
        $keys = [$code . '_payment_method'];

        foreach ($this->plugin->settingsFields() as $field) {
            // Mode is safe and apps use it to label a test checkout; keys never are.
            if (($field['column'] ?? null) === 'payment_mode') {
                $keys[] = $code . '_payment_mode';
            }
        }

        return $keys;
    }

    /**
     * The manifest's fields, translated into the shape our panel renders.
     *
     * Two formats describe a field differently — `column` against `key`, a
     * `{value: label}` map against a list of options — and the panel only knows ours.
     *
     * The catalogue may also override presentation: the order fields are asked in, a
     * starting value, or a narrower set of options than the package declares. That
     * belongs to the host because it is a judgement about this product's admins, not
     * about the gateway, and because the package is shared and must not be edited.
     */
    public function settingsSchema(): array
    {
        $code = $this->code();
        $overrides = $this->fieldOverrides();
        $fields = [];

        foreach ($this->plugin->settingsFields() as $index => $field) {
            $column = (string) $field['column'];
            $override = $overrides[$column] ?? [];
            $type = (string) ($override['type'] ?? $field['type'] ?? 'text');

            $out = [
                'key'      => $code . '_' . $column,
                'type'     => $type === 'password' ? 'password' : $type,
                'label'    => (string) ($override['label'] ?? $field['label'] ?? $column),
                'required' => ($override['required'] ?? $field['required'] ?? true) !== false,
                'secret'   => $type === 'password',
                /* Seeded into a new country's gateway settings, so an admin is not
                   asked to pick the only sensible answer. */
                'default'  => $override['default'] ?? $field['default'] ?? '',
                // Manifest order unless the catalogue says otherwise; the offset keeps
                // un-overridden fields clear of a low explicit position.
                '_position' => (int) ($override['position'] ?? (50 + $index)),
            ];

            $options = $override['options'] ?? $field['options'] ?? null;

            if (!empty($options) && is_array($options)) {
                $out['options'] = [];

                foreach ($options as $value => $label) {
                    // A map keys value => label; a plain list has neither, so the
                    // entry doubles as both.
                    $out['options'][] = is_int($value)
                        ? ['value' => (string) $label, 'label' => (string) $label]
                        : ['value' => (string) $value, 'label' => (string) $label];
                }
            }

            $fields[] = $out;
        }

        // Stable: two fields sharing a position keep the order the manifest gave them.
        usort($fields, fn (array $a, array $b) => $a['_position'] <=> $b['_position']);

        return array_map(function (array $field) {
            unset($field['_position']);

            return $field;
        }, $fields);
    }

    /** Presentation overrides for this plugin's fields, keyed by column. */
    private function fieldOverrides(): array
    {
        $entry = app(\App\Services\Plugin\PluginCatalog::class)->find($this->plugin->slug);
        $fields = $entry['fields'] ?? [];

        return is_array($fields) ? $fields : [];
    }

    /* -------------------------------------------------------------------- payment */

    public function initiate(PaymentContext $context): PaymentInitiation
    {
        $plugin = $this->plugin($context->credentials, $context->successUrl, $context->failureUrl);

        if (!$plugin) {
            return PaymentInitiation::failed('payment_gateway_is_unavailable');
        }

        // Written before the call, so a gateway that answers while our own request dies
        // still leaves a reference we can reconcile against later.
        $intent = PluginPaymentIntent::updateOrCreate(
            ['reference' => $context->reference],
            [
                'plugin_slug' => $this->code(),
                'amount'     => $context->amount,
                'currency'   => $context->currencyCode,
                'user_id'    => $context->userId,
                'country_id' => $context->countryId,
                'purpose'    => $context->purpose,
                'status'     => 'pending',
            ]
        );

        try {
            $result = $plugin->createAndFormatPaymentIntent($context->amount, [
                'reference'     => $context->reference,
                'purpose'       => $context->purpose,
                'order_id'      => $context->orderId,
                'order_number'  => $context->orderNumber,
                'user_id'       => $context->userId,
                'platform_type' => $context->meta['platform_type'] ?? 'app',
            ]);
        } catch (\Throwable $e) {
            Log::error("[Plugin:{$this->code()}] initiate failed", ['message' => $e->getMessage()]);

            return PaymentInitiation::failed($e->getMessage() ?: 'payment_could_not_be_started');
        }

        $gatewayPaymentId = $result['id'] ?? null;
        $url = $result['payment_url'] ?? null;

        if ($gatewayPaymentId) {
            $intent->update(['gateway_payment_id' => (string) $gatewayPaymentId]);
        }

        if (!$url) {
            // A plugin that returns no hosted URL has nowhere to send the shopper.
            // Reported rather than guessed at: the alternative is a blank page.
            Log::error("[Plugin:{$this->code()}] returned no payment_url", ['result' => array_keys($result)]);

            return PaymentInitiation::failed('payment_gateway_did_not_return_a_checkout_url');
        }

        return PaymentInitiation::redirect((string) $url, $gatewayPaymentId ? (string) $gatewayPaymentId : null);
    }

    /**
     * Nothing to verify, and nothing is trusted either.
     *
     * A plugin that implements WebhookVerifiable is asked to prove the request; one
     * that does not is let through, because the outcome below is read from the gateway
     * and not from this request. That asymmetry is the point: an unsigned callback is
     * treated as a hint that something happened, never as what happened.
     */
    public function verifyWebhook(Request $request, string $action, array $gateways): bool
    {
        $plugin = $this->plugin($gateways);

        if ($plugin instanceof WebhookVerifiable) {
            try {
                $plugin->verifyWebhook($request);

                return true;
            } catch (\Throwable $e) {
                Log::warning("[Plugin:{$this->code()}] webhook verification failed", ['message' => $e->getMessage()]);

                return false;
            }
        }

        return true;
    }

    public function handleWebhook(Request $request, string $action, array $gateways): PaymentOutcome
    {
        $reference = $this->referenceFromPayload($request->all());

        if (!$reference) {
            return PaymentOutcome::ignore('no_reference_in_callback');
        }

        $intent = PluginPaymentIntent::where('reference', $reference)
            ->where('plugin_slug', $this->code())
            ->first();

        if (!$intent) {
            return PaymentOutcome::ignore('unknown_reference');
        }

        if (!$intent->gateway_payment_id) {
            // The gateway never told us its id, so there is nothing to ask about.
            return PaymentOutcome::pending($reference, null, 'payment_was_never_started_at_the_gateway');
        }

        $plugin = $this->plugin($gateways);

        if (!$plugin) {
            return PaymentOutcome::pending($reference, $intent->gateway_payment_id, 'payment_gateway_is_unavailable');
        }

        try {
            $verified = $plugin->retrievePaymentIntent($intent->gateway_payment_id);
        } catch (\Throwable $e) {
            Log::error("[Plugin:{$this->code()}] confirm failed", [
                'reference' => $reference,
                'message'   => $e->getMessage(),
            ]);

            // Pending, never failed: a gateway we could not reach has not refused.
            return PaymentOutcome::pending($reference, $intent->gateway_payment_id, 'payment_could_not_be_confirmed');
        }

        $status = (string) ($verified['status'] ?? 'pending');
        $amount = (float) ($verified['amount'] ?? $intent->amount);

        if ($status === 'succeed') {
            $intent->update(['status' => 'succeed']);

            return PaymentOutcome::success($reference, (string) $intent->gateway_payment_id, $amount, $verified);
        }

        if ($status === 'failed') {
            $intent->update(['status' => 'failed']);

            return PaymentOutcome::failed($reference, (string) $intent->gateway_payment_id, $amount, 'payment_failed', $verified);
        }

        return PaymentOutcome::pending($reference, (string) $intent->gateway_payment_id, 'payment_is_still_processing');
    }

    /** Our own reference, which core puts on the return URL as `ref`. */
    public function referenceFromPayload(array $payload): ?string
    {
        foreach (['ref', 'reference', 'udf1', 'merchant_reference'] as $key) {
            $value = $payload[$key] ?? null;

            if (is_string($value) && $value !== '') {
                return $value;
            }
        }

        return null;
    }

    public function redirectTarget(PaymentOutcome $outcome): ?string
    {
        return null; // Core's deep link, same as every other gateway.
    }

    /* --------------------------------------------------------------------- wiring */

    /**
     * Build the plugin, handed this country's credentials in the format's own shape.
     *
     * Constructed per call rather than cached: credentials are per country, and the
     * same plugin can serve two countries inside one request.
     */
    private function plugin(array $credentialsOrGateways, ?string $successUrl = null, ?string $failedUrl = null): ?PaymentInterface
    {
        $class = $this->plugin->mainClass();

        if (!$class || !class_exists($class) || !is_subclass_of($class, PaymentInterface::class)) {
            Log::error("[Plugin:{$this->code()}] main_class is missing or does not implement PaymentInterface.");

            return null;
        }

        $config = PaymentConfig::build($this->code(), $credentialsOrGateways);

        try {
            return new $class($config, $successUrl, $failedUrl);
        } catch (\Throwable $e) {
            Log::error("[Plugin:{$this->code()}] could not be constructed", ['message' => $e->getMessage()]);

            return null;
        }
    }
}
