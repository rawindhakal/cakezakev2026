<?php

namespace App\Services\Shipping;

use App\Models\ProductVariant;

/**
 * Turns a set of variants and quantities into one parcel.
 *
 * The same arithmetic has to serve a cart (quoting a rate at checkout) and an order
 * (booking the parcel), so it lives here rather than twice. Nothing is ever snapshotted:
 * fixing a variant's weight fixes the next quote and the next label.
 *
 * Heuristic for the box: the widest and longest item set the footprint and the heights
 * stack, which is what a single carton of mixed items actually looks like.
 */
final class ParcelCalculator
{
    /** A courier refuses a parcel with no weight, so something has to be sent. */
    public const FALLBACK_WEIGHT_KG = 0.5;
    public const FALLBACK_BOX_CM    = 10.0;

    /** Most Indian couriers divide L × B × H by this; a few use 4000. */
    public const DEFAULT_VOLUMETRIC_DIVISOR = 5000;

    /**
     * @param  array<int,array{variant_id:?int, quantity:float, name?:string, value?:float}>  $lines
     * @param  array $options  volumetric_divisor, overrides
     */
    public function fromLines(array $lines, array $options = []): array
    {
        $variantIds = array_values(array_filter(array_map(fn ($l) => (int) ($l['variant_id'] ?? 0), $lines)));
        $variants = $variantIds
            ? ProductVariant::whereIn('id', $variantIds)->get(['id', 'weight', 'length', 'breadth', 'height'])->keyBy('id')
            : collect();

        $weight = 0.0;
        $maxLength = 0.0;
        $maxBreadth = 0.0;
        $height = 0.0;
        $value = 0.0;
        $estimated = [];

        foreach ($lines as $line) {
            $units = max(1.0, (float) ($line['quantity'] ?? 1));
            $variant = $variants[(int) ($line['variant_id'] ?? 0)] ?? null;
            $value += (float) ($line['value'] ?? 0);

            $unitWeight = (float) ($variant->weight ?? 0);
            if ($unitWeight <= 0) {
                $unitWeight = self::FALLBACK_WEIGHT_KG;
                $estimated[] = [
                    'id'   => (int) ($line['id'] ?? ($line['variant_id'] ?? 0)),
                    'name' => (string) ($line['name'] ?? ''),
                ];
            }
            $weight += $unitWeight * $units;

            $maxLength = max($maxLength, (float) ($variant->length ?? 0));
            $maxBreadth = max($maxBreadth, (float) ($variant->breadth ?? 0));
            $height += (float) ($variant->height ?? 0) * $units;
        }

        $contentsWeight = round(max(0.01, $weight), 3);

        $box = [
            'length'  => round($maxLength > 0 ? $maxLength : self::FALLBACK_BOX_CM, 2),
            'breadth' => round($maxBreadth > 0 ? $maxBreadth : self::FALLBACK_BOX_CM, 2),
            'height'  => round($height > 0 ? $height : self::FALLBACK_BOX_CM, 2),
        ];

        $weightKnown = empty($estimated);

        /* Per side, not just "the box is known". A product can carry a length and no
           height, and the dialog has to leave exactly the empty field empty rather than
           filling three guesses because one was missing. */
        $sideKnown = [
            'length'  => $maxLength > 0,
            'breadth' => $maxBreadth > 0,
            'height'  => $height > 0,
        ];

        /* Whatever the admin typed wins, and once they have typed it the numbers are
           measured rather than guessed — that is the whole point of the override. */
        $overrides = (array) ($options['overrides'] ?? []);

        /* What the products weigh is what we start from. The box, the tape and the filler
           differ from parcel to parcel, so nothing is added here on a guess — whoever packs
           it can raise the total in the ship dialog, and that figure then stands for the
           whole parcel. */
        $deadWeight = $contentsWeight;

        if (isset($overrides['weight']) && (float) $overrides['weight'] > 0) {
            $deadWeight = round((float) $overrides['weight'], 3);
            $weightKnown = true;
        }
        foreach (['length', 'breadth', 'height'] as $side) {
            if (isset($overrides[$side]) && (float) $overrides[$side] > 0) {
                $box[$side] = round((float) $overrides[$side], 2);
                $sideKnown[$side] = true;
            }
        }

        $boxKnown = $sideKnown['length'] && $sideKnown['breadth'] && $sideKnown['height'];

        /* A light, bulky parcel is billed on the space it occupies, not its weight, and
           that is where unexpected courier bills come from. Both numbers are returned so
           the panel can show which one will be charged. */
        $divisor = max(1, (int) ($options['volumetric_divisor'] ?? self::DEFAULT_VOLUMETRIC_DIVISOR));
        $volumetric = round(($box['length'] * $box['breadth'] * $box['height']) / $divisor, 3);

        return [
            'weight'          => $deadWeight,
            'length'          => $box['length'],
            'breadth'         => $box['breadth'],
            'height'          => $box['height'],
            'declared_value'  => round($value, 2),
            'estimated_items' => $weightKnown ? [] : $estimated,
            'weight_known'    => $weightKnown,
            'box_known'       => $boxKnown,
            /* What is actually known, with null where it is not.
             *
             * The numbers above always carry a figure because the quote, the volumetric
             * sum and the booking all need one — but a fallback is a guess, and a guess
             * typed into the ship dialog looks exactly like a measurement. Whoever packs
             * the parcel has to be able to see which is which, so the dialog reads this
             * and leaves an unknown field blank. */
            'measured'        => [
                'weight'  => $weightKnown ? $deadWeight : null,
                'length'  => $sideKnown['length'] ? $box['length'] : null,
                'breadth' => $sideKnown['breadth'] ? $box['breadth'] : null,
                'height'  => $sideKnown['height'] ? $box['height'] : null,
            ],
            'contents_weight'   => $contentsWeight,
            'volumetric_weight' => $volumetric,
            'billable_weight'   => round(max($deadWeight, $volumetric), 3),
            'billed_on'         => $volumetric > $deadWeight ? 'volumetric' : 'dead',
            'volumetric_divisor' => $divisor,
        ];
    }

    /** Cart rows: whatever the cart API already holds per line. */
    public function fromCartItems($items, array $options = []): array
    {
        return $this->fromLines(collect($items)->map(fn ($i) => [
            'id'         => (int) ($i->id ?? 0),
            'variant_id' => (int) ($i->product_variant_id ?? 0),
            'quantity'   => (float) ($i->qty ?? $i->quantity ?? 1),
            'name'       => (string) ($i->product_name ?? ''),
            'value'      => (float) (($i->discounted_price ?? $i->price ?? 0) * (float) ($i->qty ?? $i->quantity ?? 1)),
        ])->all(), $options);
    }

    /** Order items: the parcel a courier is actually being handed. */
    public function fromOrderItems($items, array $options = []): array
    {
        return $this->fromLines(collect($items)->map(fn ($i) => [
            'id'         => (int) $i->id,
            'variant_id' => (int) ($i->product_variant_id ?? 0),
            'quantity'   => (float) $i->quantity,
            'name'       => (string) $i->product_name,
            'value'      => (float) $i->sub_total,
        ])->all(), $options);
    }
}
