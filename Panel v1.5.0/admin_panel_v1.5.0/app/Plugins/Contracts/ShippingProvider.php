<?php

namespace App\Plugins\Contracts;

use App\Plugins\Dto\ShipmentRequest;
use App\Plugins\Dto\ShipmentResult;
use App\Plugins\Dto\ShippingQuoteRequest;
use App\Plugins\Dto\TrackingUpdate;

/**
 * One courier integration.
 *
 * Core owns the order, the items and the money; a provider only answers "can you carry
 * this, for how much" and "here is the parcel, give me an AWB". Everything it returns
 * is a plain DTO, so the panel and the settlement code never see a carrier's payload.
 */
interface ShippingProvider
{
    /** Stable key, also the plugin slug: 'shiprocket'. */
    public function key(): string;

    /** Shown in the panel: 'Shiprocket'. */
    public function label(): string;

    /** Sales channels this provider can serve: ['ecommerce'], or both. */
    public function channels(): array;

    /** 'weight' for parcel couriers, 'distance' for hyperlocal riders. */
    public function quotesOn(): string;

    /** Countries it operates in, as ISO codes. Empty means unrestricted. */
    public function countries(): array;

    /** Credentials present and usable. */
    public function isConfigured(): bool;

    /**
     * Can this pincode be served, and at what price.
     *
     * @return array<int,\App\Plugins\Dto\ShippingQuote> cheapest first; empty = not serviceable
     */
    public function quote(ShippingQuoteRequest $request): array;

    /** Hand over a parcel: creates the shipment and assigns an AWB. */
    public function createShipment(ShipmentRequest $request): ShipmentResult;

    /** Ask the carrier to collect. Returns false when it could not be scheduled. */
    public function schedulePickup(string $shipmentId): bool;

    /** A printable label, or null when the carrier has none yet. */
    public function labelUrl(string $shipmentId): ?string;

    /** Cancel before pickup. */
    /**
     * @param  string       $shipmentId       the carrier's shipment handle
     * @param  string|null  $providerOrderId  its order handle, when the carrier gave one
     *
     * Both, because carriers disagree about which one cancels: Shiprocket's endpoint
     * works on order ids and refuses a shipment id. A provider uses whichever it needs.
     */
    public function cancelShipment(string $shipmentId, ?string $providerOrderId = null): bool;

    /**
     * Register this branch as a collection point with the carrier.
     *
     * Carriers identify a pickup address by their own handle, not by the address text,
     * so the two systems have to agree on one. Letting core register the branch's own
     * address — rather than having an admin type it into two panels — is what keeps them
     * from drifting apart.
     *
     * Carriers that need no registration should return ok with a null handle.
     *
     * @param  array $branch  as Branch::pickupInfo() returns it
     * @return array{ok:bool, nickname:?string, verified:bool, message:string}
     */
    public function registerPickup(array $branch): array;

    /**
     * Can this branch actually be collected from?
     *
     * Asked from the branch form, before any order exists. A courier answers two
     * different questions here — is the pincode one it collects from at all, and is
     * this branch's address registered on the account it ships under — because a branch
     * that fails either cannot ship, and an admin should find that out while editing
     * the branch rather than at the first order.
     *
     * @param  array $branch  as Branch::pickupInfo() returns it
     * @return array{ok:bool, serviceable:bool, registered:bool, nickname:?string, couriers:int, message:string}
     */
    public function verifyPickup(array $branch): array;

    /** Current state, for reconciliation when a webhook was missed. */
    public function track(string $awb): ?TrackingUpdate;

    /** Translate an inbound webhook body into our own update, or null to ignore it. */
    public function parseWebhook(array $payload, string $action): ?TrackingUpdate;

    /** Verify the webhook really came from the carrier. */
    public function verifyWebhook(array $payload, array $headers): bool;
}
