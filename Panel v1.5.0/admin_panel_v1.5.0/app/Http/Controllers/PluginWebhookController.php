<?php

namespace App\Http\Controllers;

use App\Plugins\Contracts\PaymentGateway;
use App\Plugins\Dto\PaymentOutcome;
use App\Plugins\PluginRegistry;
use App\Plugins\Registries\PaymentGatewayRegistry;
use App\Plugins\Registries\ShippingProviderRegistry;
use App\Helpers\CommonHelper;
use App\Models\Plugin;
use App\Models\Country;
use App\Models\Order;
use App\Models\Setting;
use App\Services\Payments\PaymentSettlementService;
use App\Services\Shipping\CourierReturnStatusService;
use App\Services\Shipping\CourierStatusService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Support\WebhookLog;
use Illuminate\Support\Facades\Schema;

/**
 * One door for every plugin's inbound webhooks: `/plugin/{slug}/{action}`.
 *
 * Added once, so no plugin ever has to edit core routing or the CSRF exception list. The
 * things an plugin author could otherwise forget are done here instead of in the plugin:
 *
 *  - the signature is verified by calling the provider's own verifyWebhook(), and a
 *    provider that refuses gets a 401 — an plugin cannot "forget" to check;
 *  - deliveries are de-duplicated against `plugin_webhook_events`, because carriers and
 *    gateways retry and a replay must never be applied twice;
 *  - a disabled or expired plugin still gets a short settlement tail, so a shipment or a
 *    payment already in flight can finish.
 *
 * Whatever the provider returns is a DTO in our own vocabulary; core decides what it
 * means for the order.
 */
class PluginWebhookController extends Controller
{
    public function handle(Request $request, string $slug, string $action): JsonResponse|RedirectResponse
    {
        $slug = strtolower($slug);
        $action = strtolower($action);

        // The first segment may be a slug or a webhook alias, so it allows a hyphen too.
        if (!preg_match('/^[a-z][a-z0-9_\-]{2,39}$/', $slug) || !preg_match('/^[a-z0-9_\-]{2,40}$/', $action)) {
            return $this->reply(404, 'not_found');
        }

        $plugin = $this->plugin($slug);
        if (!$plugin) {
            return $this->reply(404, 'not_found');
        }

        // An alias was used: carry on under the plugin's real slug, which is what the
        // registries and the event log are keyed by.
        $slug = $plugin->slug;

        // A licence that has lapsed keeps the door open briefly: money and parcels in
        // flight must still land.
        if (!$plugin->shouldBoot()) {
            WebhookLog::warning("[Webhook:{$slug}/{$action}] rejected: plugin is not active.");

            return $this->reply(403, 'plugin_is_not_active');
        }

        $payload = $this->payload($request);

        // A payment gateway and a courier are handled differently — the gateway's
        // verdict moves money, the courier's moves a status — so the two registries are
        // tried in turn and the matching branch takes over.
        /* A gateway is registered under its payment code, which is what the apps and
           `orders.payment_method` use and therefore what its callback URL carries; a
           courier is registered under its slug. Looking both up by the same string
           would miss every payment whose code differs from its slug. */
        $code = app(PluginRegistry::class)->get($slug)?->code() ?? $slug;

        $gateway = app(PaymentGatewayRegistry::class)->driver($code);
        if ($gateway instanceof PaymentGateway) {
            return $this->handlePayment($request, $slug, $action, $payload, $gateway);
        }

        $provider = app(ShippingProviderRegistry::class)->provider($slug);

        // The plugin may be installed but not booted this request (quarantined, disabled
        // mid-flight). Nothing to hand the delivery to.
        if (!$provider) {
            WebhookLog::warning("[Webhook:{$slug}/{$action}] no handler registered.");

            return $this->reply(503, 'plugin_handler_is_not_available');
        }

        if (!$provider->verifyWebhook($payload, $this->headers($request))) {
            WebhookLog::warning("[Webhook:{$slug}/{$action}] signature rejected.");

            return $this->reply(401, 'webhook_signature_is_invalid');
        }

        $update = null;
        try {
            $update = $provider->parseWebhook($payload, $action);
        } catch (\Throwable $e) {
            WebhookLog::error("[Webhook:{$slug}/{$action}] parse failed: " . $e->getMessage());

            return $this->reply(422, 'webhook_could_not_be_read');
        }

        if (!$update) {
            // A heartbeat or a stage we do not care about: accepted so the carrier stops
            // retrying, recorded so it is visible.
            $this->record($slug, $action, $this->eventKey($slug, $action, $payload), $request, 'ignored', 200, null, null);

            return $this->reply(200, 'ignored');
        }

        // The event key prefers the carrier's own identity for the delivery, so two
        // different stages of one AWB are distinct while a retry of one stage is not.
        $eventKey = $this->eventKey($slug, $action, $payload, $update->awb, $update->status, $update->happenedAt);

        if (!$this->claim($slug, $action, $eventKey, $request, $update->awb)) {
            return $this->reply(200, 'already_processed');
        }

        try {
            $result = app(CourierStatusService::class)->apply($update);

            /* One feed carries both directions. An AWB that matches no order line may be a
               reverse pickup, whose progress belongs on the return request instead. */
            if ($result['applied'] === 0) {
                $returns = app(CourierReturnStatusService::class)->apply($update);
                if ($returns['applied'] > 0) {
                    $this->finish($eventKey, 'applied', 200, "return pickup: {$returns['applied']} request(s)");

                    return $this->reply(200, 'ok');
                }
            }

            $this->finish($eventKey, $result['applied'] > 0 ? 'applied' : 'no_match', 200, $this->summary($result, $update));

            return $this->reply(200, 'ok');
        } catch (\Throwable $e) {
            WebhookLog::error("[Webhook:{$slug}/{$action}] apply failed: " . $e->getMessage());
            // Release the claim so the carrier's retry gets a real attempt.
            $this->release($eventKey);

            return $this->reply(500, 'webhook_could_not_be_applied');
        }
    }

    /**
     * A payment gateway's callback.
     *
     * Core verifies the signature, de-duplicates the delivery and settles the outcome —
     * the driver only says what happened. A browser redirect (`action` = 'redirect')
     * ends at the shopper's storefront instead of a JSON body, because a human is
     * looking at it.
     */
    private function handlePayment(Request $request, string $slug, string $action, array $payload, PaymentGateway $gateway): JsonResponse|RedirectResponse
    {
        $gateways = $this->countryGateways($request, $payload, $gateway);

        if (!$gateway->verifyWebhook($request, $action, $gateways)) {
            WebhookLog::warning("[Webhook:{$slug}/{$action}] payment signature rejected.");

            $this->record(
                $slug,
                $action,
                $this->eventKey($slug, $action, $payload),
                $request,
                'rejected',
                401,
                null,
                'signature rejected'
            );

            return $this->reply(401, 'webhook_signature_is_invalid');
        }

        try {
            $outcome = $gateway->handleWebhook($request, $action, $gateways);
        } catch (\Throwable $e) {
            WebhookLog::error("[Webhook:{$slug}/{$action}] payment parse failed: " . $e->getMessage());

            return $this->reply(422, 'webhook_could_not_be_read');
        }

        $isRedirect = $action === 'redirect';

        if ($outcome->status === PaymentOutcome::IGNORE || $outcome->status === PaymentOutcome::PENDING) {
            $this->record($slug, $action, $this->eventKey($slug, $action, $payload), $request, 'ignored', 200, null, $outcome->message);

            return $isRedirect ? $this->paymentRedirect($gateway, $outcome) : $this->reply(200, 'ignored');
        }

        $eventKey = $this->eventKey($slug, $action, $payload, $outcome->gatewayTxnId, $outcome->status);

        // A gateway that sends both a webhook and a redirect must settle once; the
        // claim plus the settlement service's own txn-id check cover both races.
        if (!$this->claim($slug, $action, $eventKey, $request, $outcome->gatewayTxnId)) {
            return $isRedirect ? $this->paymentRedirect($gateway, $outcome) : $this->reply(200, 'already_processed');
        }

        try {
            $result = app(PaymentSettlementService::class)->settle(
                $outcome,
                'txn_type_' . $gateway->code(),
                method_exists($gateway, 'paymentLabel') ? $gateway->paymentLabel() : $gateway->label()
            );
            $this->finish($eventKey, $result['message'] ?? 'settled', 200, $outcome->status . ': ' . ($result['message'] ?? ''));

            if (empty($result['ok'])) {
                return $isRedirect
                    ? $this->paymentRedirect($gateway, $outcome)
                    : $this->reply(422, (string) ($result['message'] ?? 'settlement_failed'));
            }

            return $isRedirect ? $this->paymentRedirect($gateway, $outcome) : $this->reply(200, 'ok');
        } catch (\Throwable $e) {
            WebhookLog::error("[Webhook:{$slug}/{$action}] settlement failed: " . $e->getMessage());
            $this->release($eventKey);

            return $isRedirect ? $this->paymentRedirect($gateway, $outcome) : $this->reply(500, 'webhook_could_not_be_applied');
        }
    }

    /**
     * Where a shopper lands after a redirect callback: the driver's own target, else the
     * storefront's payment-status page every core gateway already returns to.
     */
    private function paymentRedirect(PaymentGateway $gateway, PaymentOutcome $outcome): RedirectResponse
    {
        $target = $gateway->redirectTarget($outcome);
        if ($target) {
            return redirect()->away($target);
        }

        $website = rtrim((string) Setting::get_value('website_url'), '/');
        $status = $outcome->isSuccess() ? 'success' : 'failed';
        $parts = app(PaymentSettlementService::class)->parseReference($outcome->reference);

        if ($website === '') {
            return redirect('/?status=' . $status);
        }

        return redirect()->away($website . '/web-payment-status?status=' . $status
            . '&type=' . ($parts['purpose'] ?? '')
            . '&order_id=' . ($parts['order_id'] ?? '')
            . '&payment_method=' . urlencode(
                method_exists($gateway, 'paymentLabel') ? $gateway->paymentLabel() : $gateway->label()
            ));
    }

    /**
     * The credentials the driver needs to check a signature.
     *
     * A webhook carries no session, so the country is recovered from the reference the
     * gateway echoes back: the order's country, or the `c{id}` marker in a recharge
     * reference. Falls back to the only country that has this gateway switched on.
     */
    private function countryGateways(Request $request, array $payload, PaymentGateway $gateway): array
    {
        $code = $gateway->code();
        $reference = (string) ($gateway->referenceFromPayload($payload)
            ?: ($payload['reference'] ?? $payload['ref'] ?? $request->input('ref', '')));
        $parts = app(PaymentSettlementService::class)->parseReference($reference);

        $countryId = null;
        if ($parts && $parts['purpose'] === 'order' && $parts['order_id']) {
            $countryId = Order::where('id', $parts['order_id'])->value('country_id');
        } elseif ($parts) {
            $countryId = CommonHelper::parseRechargeCountryId($parts['parts']);
        }

        if ($countryId) {
            return CommonHelper::countryPaymentGateways(Country::find($countryId));
        }

        // Unknown country: the one country with this gateway enabled is unambiguous, and
        // more than one means the driver must key off the payload itself.
        $candidates = Country::all()->filter(
            fn ($c) => (CommonHelper::countryPaymentGateways($c)[$code . '_payment_method'] ?? 0) == 1
        );

        return $candidates->count() === 1
            ? CommonHelper::countryPaymentGateways($candidates->first())
            : [];
    }

    /* ---------------------------------------------------------------- helpers */

    /**
     * The plugin a webhook path segment refers to.
     *
     * Usually the slug, but a gateway is addressed by its short code everywhere else —
     * `orders.payment_method`, the country's credential keys — so the URL a carrier or
     * gateway was handed carries that code, and it has to resolve back here. A
     * manifest may also name a `webhook_alias` for a provider that cannot be told
     * which path to call.
     */
    private function plugin(string $segment): ?Plugin
    {
        $segment = strtolower(trim($segment));

        try {
            $plugin = Plugin::where('slug', $segment)->first();

            if ($plugin) {
                return $plugin;
            }

            $catalogue = app(\App\Services\Plugin\PluginCatalog::class);

            foreach (Plugin::all() as $candidate) {
                $code = strtolower(trim((string) ($catalogue->find($candidate->slug)['payment_code'] ?? '')));

                if ($code !== '' && $code === $segment) {
                    return $candidate;
                }

                $alias = \App\Plugins\PluginManifest::webhookSegment($candidate->slug, (array) $candidate->manifest);

                if ($alias !== $candidate->slug && $alias === $segment) {
                    return $candidate;
                }
            }

            return null;
        } catch (\Throwable $e) {
            return null;
        }
    }

    /** JSON body when there is one, form fields otherwise. */
    private function payload(Request $request): array
    {
        $json = $request->json()->all();

        return is_array($json) && !empty($json) ? $json : $request->all();
    }

    /**
     * Headers a provider may need to check a signature. Lower-cased single values —
     * providers should never have to know Symfony's header bag.
     */
    private function headers(Request $request): array
    {
        $out = [];
        foreach ($request->headers->all() as $name => $values) {
            $out[strtolower($name)] = is_array($values) ? (string) ($values[0] ?? '') : (string) $values;
        }

        return $out;
    }

    /**
     * A stable identity for one delivery.
     *
     * The carrier's AWB + stage is the natural key; a hash of the body is the fallback
     * for a provider that sends neither.
     */
    private function eventKey(string $slug, string $action, array $payload, ?string $awb = null, ?string $status = null, ?string $at = null): string
    {
        $seed = $awb
            ? implode('|', [$slug, $action, $awb, (string) $status, (string) $at])
            : implode('|', [$slug, $action, md5(json_encode($payload) ?: '')]);

        return hash('sha256', $seed);
    }

    /**
     * Take the delivery, or discover somebody already has.
     *
     * The unique index on `event_key` is what actually prevents a double apply: two
     * simultaneous retries both try to insert and exactly one succeeds.
     */
    private function claim(string $slug, string $action, string $key, Request $request, ?string $awb): bool
    {
        if (!Schema::hasTable('plugin_webhook_events')) {
            return true; // pre-1.4.0 schema: better to process than to drop
        }

        try {
            DB::table('plugin_webhook_events')->insert([
                'slug'            => $slug,
                'action'          => $action,
                'event_key'       => $key,
                'external_id'     => $awb,
                'outcome'         => 'processing',
                'ip'              => $request->ip(),
                'payload_excerpt' => mb_substr((string) json_encode($this->payload($request)), 0, 2000),
                'created_at'      => now(),
            ]);

            return true;
        } catch (\Illuminate\Database\QueryException $e) {
            // 23000 = duplicate key: a retry of a delivery we already have.
            if ((string) $e->getCode() === '23000') {
                WebhookLog::info("[Webhook:{$slug}/{$action}] duplicate delivery ignored.");

                return false;
            }
            WebhookLog::error("[Webhook:{$slug}/{$action}] could not record delivery: " . $e->getMessage());

            return true;
        }
    }

    private function finish(string $key, string $outcome, int $httpCode, ?string $message): void
    {
        if (!Schema::hasTable('plugin_webhook_events')) {
            return;
        }

        try {
            DB::table('plugin_webhook_events')->where('event_key', $key)->update([
                'outcome'   => $outcome,
                'http_code' => $httpCode,
                'message'   => $message ? mb_substr($message, 0, 250) : null,
            ]);
        } catch (\Throwable $e) {
            WebhookLog::warning('[Webhook] could not update delivery record: ' . $e->getMessage());
        }
    }

    /** An apply that blew up must not block the carrier's retry. */
    private function release(string $key): void
    {
        if (!Schema::hasTable('plugin_webhook_events')) {
            return;
        }

        try {
            DB::table('plugin_webhook_events')->where('event_key', $key)->delete();
        } catch (\Throwable $e) {
            WebhookLog::warning('[Webhook] could not release delivery record: ' . $e->getMessage());
        }
    }

    /** Record a delivery that was never claimed (ignored, unparsed). */
    private function record(string $slug, string $action, string $key, Request $request, string $outcome, int $httpCode, ?string $awb, ?string $message): void
    {
        if ($this->claim($slug, $action, $key, $request, $awb)) {
            $this->finish($key, $outcome, $httpCode, $message);
        }
    }

    private function summary(array $result, $update): string
    {
        return sprintf(
            '%s: applied %d, skipped %d%s',
            $update->status,
            $result['applied'],
            $result['skipped'],
            $result['items'] ? ' (items ' . implode(',', $result['items']) . ')' : ''
        );
    }

    private function reply(int $code, string $message): JsonResponse
    {
        return response()->json(['status' => $code < 400 ? 1 : 0, 'message' => $message], $code);
    }
}
