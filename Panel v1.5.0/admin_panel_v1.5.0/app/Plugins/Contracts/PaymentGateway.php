<?php

namespace App\Plugins\Contracts;

use App\Plugins\Dto\PaymentContext;
use App\Plugins\Dto\PaymentInitiation;
use App\Plugins\Dto\PaymentOutcome;
use Illuminate\Http\Request;

/**
 * One payment gateway.
 *
 * Core owns the order, the money and the settlement; a gateway only starts a payment and
 * translates the callback. It never writes a transaction, moves an order or credits a
 * wallet — `PaymentSettlementService` does that from the `PaymentOutcome` returned here,
 * so a faulty plugin cannot invent a paid order.
 *
 * Credentials live where every other gateway's do: the `countries.payment_gateways` JSON
 * column, keyed `{code}_{field}` with `{code}_payment_method` as the per-country switch.
 * Core hands the driver only its own keys.
 */
interface PaymentGateway
{
    /**
     * Stable code, also the value stored in `orders.payment_method`.
     *
     * An instance method, not static: a universal plugin is served by one shared bridge
     * class (App\Plugins\Adapters\PaymentAdapter) that carries a different code
     * per instance, and a static would make every plugin answer with the same one.
     */
    public function code(): string;

    /** Shown in the panel and the apps: 'PayU'. */
    public function label(): string;

    /** Credentials present for this country's config. */
    public function isConfigured(array $gateways): bool;

    /** Start a payment; the return value tells the app how to continue. */
    public function initiate(PaymentContext $context): PaymentInitiation;

    /**
     * Translate a callback into our own vocabulary.
     *
     * `$action` is the webhook path segment the gateway was given
     * (`plugin/{slug}/{action}`), so one driver can serve a server webhook and a
     * browser redirect with different rules.
     */
    public function handleWebhook(Request $request, string $action, array $gateways): PaymentOutcome;

    /**
     * Verify the callback really came from the gateway (signature, hash, IP).
     *
     * Called by core before the payload is parsed, so an plugin cannot forget it.
     */
    public function verifyWebhook(Request $request, string $action, array $gateways): bool;

    public function referenceFromPayload(array $payload): ?string;

    /**
     * Where the shopper should land after a browser redirect callback, or null to use
     * core's default deep link.
     */
    public function redirectTarget(PaymentOutcome $outcome): ?string;

    /** Field keys the customer apps may read (never a secret). */
    public function publicSettingKeys(): array;

    /** The manifest's settings fields, rendered inside the country's payment step. */
    public function settingsSchema(): array;
}
