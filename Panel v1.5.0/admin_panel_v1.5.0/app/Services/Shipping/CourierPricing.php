<?php

namespace App\Services\Shipping;

use App\Plugins\Dto\ShippingQuoteRequest;
use App\Plugins\Registries\ShippingProviderRegistry;
use App\Models\Branch;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Prices ecommerce delivery from a live courier quote.
 *
 * Used by the `courier` zone pricing strategy. Every failure — no plugin installed, no
 * credentials, pincode not serviceable, carrier down — returns null, and the caller
 * falls back to the zone's own flat rule. A shopper must never be blocked from checking
 * out because a carrier's API is having a bad afternoon.
 */
final class CourierPricing
{
    /** A quote is stable for a few minutes; the cart is recalculated far more often. */
    private const TTL = 300;

    public function __construct(private ShippingProviderRegistry $registry) {}

    /** Is a courier quote even possible right now? */
    public function available(?string $countryCode = null): bool
    {
        return $this->registry->default('ecommerce', $countryCode) !== null;
    }

    /**
     * The cheapest quote for this parcel.
     *
     * @param  array{delivery_pincode?:string, pickup_pincode?:string, branch_id?:int, weight?:float,
     *               length?:float, breadth?:float, height?:float, cod?:bool, declared_value?:float,
     *               country_code?:string}  $context
     * @return array{charge:float, courier_id:string, courier_name:string, eta_days:?int, eta_text:?string, provider:string}|null
     */
    public function cheapest(array $context): ?array
    {
        $quotes = $this->quotes($context);

        return $quotes['cheapest'] ?? null;
    }

    /**
     * Every courier option for this parcel, plus the cheapest.
     *
     * `checked` separates the two answers that must never be confused: false means we
     * could not ask at all (no plugin, no pincode, carrier down), true means the carrier
     * answered. Only a carrier's own "no" may ever turn a shopper away.
     *
     * @return array{checked:bool, serviceable:bool, provider:?string, couriers:array, cheapest:?array}
     */
    public function quotes(array $context): array
    {
        $empty = ['checked' => false, 'serviceable' => false, 'provider' => null, 'couriers' => [], 'cheapest' => null];

        $deliveryPincode = trim((string) ($context['delivery_pincode'] ?? ''));
        if ($deliveryPincode === '') {
            return $empty;
        }

        $countryCode = $context['country_code'] ?? null;
        $provider = $this->registry->default('ecommerce', $countryCode);
        if (!$provider) {
            return $empty;
        }

        $pickupPincode = trim((string) ($context['pickup_pincode'] ?? ''));
        if ($pickupPincode === '' && !empty($context['branch_id'])) {
            $pickupPincode = (string) Branch::where('id', $context['branch_id'])->value('pincode');
        }
        if ($pickupPincode === '') {
            // Nothing to quote from: the branch has no pickup pincode yet.
            return $empty;
        }

        $request = new ShippingQuoteRequest(
            pickupPincode: $pickupPincode,
            deliveryPincode: $deliveryPincode,
            weight: (float) ($context['weight'] ?? ParcelCalculator::FALLBACK_WEIGHT_KG),
            cod: (bool) ($context['cod'] ?? false),
            declaredValue: (float) ($context['declared_value'] ?? 0),
            length: isset($context['length']) ? (float) $context['length'] : null,
            breadth: isset($context['breadth']) ? (float) $context['breadth'] : null,
            height: isset($context['height']) ? (float) $context['height'] : null,
            branchId: isset($context['branch_id']) ? (int) $context['branch_id'] : null,
            channel: 'ecommerce',
            countryCode: $countryCode,
        );

        try {
            $couriers = Cache::remember(
                $provider->key() . ':' . $request->cacheKey(),
                self::TTL,
                fn () => array_map(fn ($q) => $q->toArray(), $provider->quote($request))
            );
        } catch (\Throwable $e) {
            // Never propagate: the caller falls back to the zone's own rule.
            Log::warning('[Shipping] courier quote failed, falling back: ' . $e->getMessage());

            return $empty;
        }

        if (empty($couriers)) {
            // The carrier answered and nothing of its fleet serves this pincode.
            return array_merge($empty, ['checked' => true, 'provider' => $provider->key()]);
        }

        // Cheapest wins; a recommended courier only breaks a tie on price.
        usort($couriers, fn ($a, $b) => [$a['rate'], !$a['recommended']] <=> [$b['rate'], !$b['recommended']]);
        $best = $couriers[0];

        return [
            'checked'     => true,
            'serviceable' => true,
            'provider'    => $provider->key(),
            'couriers'    => $couriers,
            'cheapest'    => [
                'charge'       => round((float) $best['rate'], 2),
                'courier_id'   => (string) $best['courier_id'],
                'courier_name' => (string) $best['courier_name'],
                'eta_days'     => $best['eta_days'] ?? null,
                'eta_text'     => $best['eta_text'] ?? null,
                'provider'     => $provider->key(),
            ],
        ];
    }
}
