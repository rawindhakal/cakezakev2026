<?php

namespace App\Helpers;

use App\Models\ProductAddonOption;
use Illuminate\Support\Facades\DB;

/**
 * Addon choices: validating them, and turning them into money.
 *
 * Three rules run through everything here.
 *
 * The price is always resolved from the DATABASE, at the line's own BRANCH, never from
 * anything the client sent. A branch belongs to a zone, a zone to a country, and each
 * country prices in its own currency with no conversion anywhere — so an option the
 * line's branch does not sell is unavailable there, full stop. It is never charged at
 * another branch's number, and never quietly treated as free.
 *
 * The amount is PER UNIT of the dish. Two burgers with extra cheese pay for two portions
 * of cheese. That is what keeps `qty * unit_price == sub_total` true, which both invoices,
 * the delivery receipt, order emails, refunds, report net sales, dashboard revenue, the
 * ecommerce charge splits and the courier declared value all assume.
 *
 * An option can BE a product — "add a Coke". It is then priced from that variant's own
 * branch row (its BASE price, never its quantity slabs, because a slab is a tier on buying
 * that product and must not be reached by ordering more of the dish it rides on), and it
 * draws on that variant's real stock. It never becomes its own cart line.
 */
class AddonHelper
{
    /* Every entry point takes its selections untyped on purpose: a client may send a CSV,
       a JSON string, an id list, `{id, qty}` rows or nothing at all, and parse() is the
       one place that decides what any of it means. */

    /** Resolved option rows, keyed by "<ids>|<branch>" — one cart read, one query. */
    private static array $cache = [];

    /** Ids of products that currently have at least one live addon group. */
    private static ?array $withAddons = null;

    /** Option id => picture URL ('' when there is none), for one request. */
    private static array $images = [];

    /**
     * The sha1 that gives a cart line its identity. Delegates so there is exactly one
     * definition of it in the codebase.
     */
    public static function signature($selections): string
    {
        return ProductHelper::addonSignature(self::parse($selections));
    }

    /**
     * Normalise whatever the client sent into `[['id' => int, 'qty' => int], ...]`.
     *
     * Accepts a CSV of ids, a JSON array, `[3, 5]`, `[{id, qty}]` and `{id: qty}` — every
     * shape an app or an older build might send. Quantities below 1 become 1; duplicates
     * of one option are summed rather than silently dropped.
     */
    public static function parse($raw): array
    {
        if ($raw === null || $raw === '' || $raw === []) {
            return [];
        }

        if (is_string($raw)) {
            $trimmed = trim($raw);
            $decoded = json_decode($trimmed, true);
            $raw = is_array($decoded) ? $decoded : explode(',', $trimmed);
        }

        if (!is_array($raw)) {
            $raw = [$raw];
        }

        $byId = [];
        foreach ($raw as $key => $value) {
            if (is_array($value)) {
                $id  = (int) ($value['id'] ?? $value['option_id'] ?? 0);
                $qty = (int) ($value['qty'] ?? $value['quantity'] ?? 1);
            } elseif (is_int($key)) {
                $id  = (int) $value;
                $qty = 1;
            } else {
                $id  = (int) $key;
                $qty = (int) $value;
            }

            if ($id > 0) {
                $byId[$id] = ($byId[$id] ?? 0) + max(1, $qty);
            }
        }

        ksort($byId, SORT_NUMERIC);

        $out = [];
        foreach ($byId as $id => $qty) {
            $out[] = ['id' => $id, 'qty' => $qty];
        }

        return $out;
    }

    /** Just the option ids, for the callers that only need to know which. */
    public static function parseIds($raw): array
    {
        return array_column(self::parse($raw), 'id');
    }

    /**
     * The per-unit addon amount for a line, priced at $branchId.
     *
     * The hot path: the cart total, the tax passes, the promo base and the order lines all
     * call it. An option the branch does not sell contributes nothing here — callers that
     * must not sell such a line check availability through `describe()`.
     */
    public static function unit($selections, ?int $branchId): float
    {
        $described = self::describe($selections, $branchId);

        return (float) $described['unit'];
    }

    /**
     * Everything needed to show or store a line's addons: the per-unit amount, and a row
     * per selection carrying the resolved group and option NAMES (so a later rename cannot
     * rewrite history), the quantity, what was charged, whether the branch sells it, and
     * any linked variant so stock can be traced back.
     */
    public static function describe($selections, ?int $branchId): array
    {
        $parsed = self::parse($selections);
        if (empty($parsed)) {
            return ['unit' => 0.0, 'lines' => [], 'unavailable' => []];
        }

        $options = self::loadOptions(array_column($parsed, 'id'), $branchId);

        // Grouped so each line can name the question it answers.
        $byGroup = [];
        foreach ($parsed as $sel) {
            $option = $options[$sel['id']] ?? null;

            if (!$option) {
                // A deleted option still sitting in a cart: name it, charge nothing, and
                // let the caller refuse to sell the line.
                $byGroup[0]['group'] = null;
                $byGroup[0]['items'][] = [
                    'option' => null, 'id' => $sel['id'], 'qty' => $sel['qty'],
                    'price' => 0.0, 'available' => false,
                ];
                continue;
            }

            $groupId = (int) $option->addon_group_id;
            $byGroup[$groupId]['group'] = $option->group;
            $byGroup[$groupId]['items'][] = [
                'option'    => $option,
                'id'        => (int) $option->id,
                'qty'       => $sel['qty'],
                'price'     => self::optionUnitPrice($option, $branchId),
                'available' => self::isOptionSellable($option, $branchId),
            ];
        }

        $lines = [];
        $unit = 0.0;
        $unavailable = [];

        foreach ($byGroup as $entry) {
            $group = $entry['group'] ?? null;

            /* Selections keep the order they were sent in. There is no group-wide free
               allowance to apply, so nothing here has to rank them by price: an option
               that costs nothing says so on itself, through its own Paid/Free setting. */
            foreach ($entry['items'] as $item) {
                $option = $item['option'];

                if (!$item['available']) {
                    $unavailable[] = $item['id'];
                }

                $linePrice = $item['available'] ? round($item['price'] * $item['qty'], 2) : 0.0;
                $unit += $linePrice;

                $lines[] = [
                    'group_id'          => (int) ($group->id ?? 0),
                    'group_name'        => (string) ($group->name ?? ''),
                    'input_type'        => (string) ($group->input_type ?? 'checkbox'),
                    'option_id'         => $item['id'],
                    'option_name'       => (string) ($option->name ?? ''),
                    'qty'               => (int) $item['qty'],
                    'unit_price'        => $item['available'] ? round($item['price'], 2) : 0.0,
                    'line_price'        => $linePrice,
                    // The option itself is given away, which is the only way an addon
                    // costs nothing now.
                    'is_free'           => $item['available'] && $linePrice <= 0.0 ? 1 : 0,
                    'available'         => $item['available'] ? 1 : 0,
                    'linked_variant_id' => $option && $option->linked_variant_id ? (int) $option->linked_variant_id : null,
                ];
            }
        }

        return ['unit' => round($unit, 2), 'lines' => $lines, 'unavailable' => $unavailable];
    }

    /**
     * Add each line's picture, for a response the customer reads.
     *
     * Deliberately NOT part of `describe()`: those lines are exactly what
     * `order_items.addons` branches, and an absolute URL frozen into order history would go
     * stale the day the picture — or the domain — changes. The key is absent when an
     * option has no picture, so a client never has to tell '' from a URL.
     */
    public static function withImages(array $lines): array
    {
        $urls = self::imageUrls(array_column($lines, 'option_id'));

        foreach ($lines as &$line) {
            $url = $urls[(int) ($line['option_id'] ?? 0)] ?? '';
            if ($url !== '') {
                $line['image'] = $url;
            }
        }

        return $lines;
    }

    /**
     * Picture URLs for a set of options, memoised for the request.
     *
     * A cart response shapes one item at a time, so without the memo this would be a
     * query per line. A linked option wears its own product's image, which is why the
     * variant and its product come along.
     */
    private static function imageUrls(array $optionIds): array
    {
        $missing = array_values(array_diff(
            array_unique(array_map('intval', array_filter($optionIds))),
            array_keys(self::$images)
        ));

        if (!empty($missing)) {
            $rows = ProductAddonOption::with(['linkedVariant:id,product_id,image', 'linkedVariant.product:id,image'])
                ->whereIn('id', $missing)
                ->get(['id', 'image', 'linked_variant_id']);

            foreach ($missing as $id) {
                self::$images[$id] = '';
            }
            foreach ($rows as $row) {
                self::$images[(int) $row->id] = $row->imageUrl();
            }
        }

        return self::$images;
    }

    /**
     * How many units of each catalogue variant ONE unit of the dish pulls from stock.
     * Returns `[variant_id => units]`; empty when nothing is linked. Multiply by the cart
     * line's own quantity for the real demand.
     *
     * Deliberately NOT filtered by availability. Whatever was reserved has to be
     * releasable later, and an option can fall out of availability while it sits in a
     * cart — skipping it here would strand its reservation forever.
     */
    public static function stockDemand($selections, ?int $branchId): array
    {
        $demand = [];
        foreach (self::describe($selections, $branchId)['lines'] as $line) {
            if (!$line['linked_variant_id']) {
                continue;
            }
            $vid = (int) $line['linked_variant_id'];
            $demand[$vid] = ($demand[$vid] ?? 0) + (int) $line['qty'];
        }

        return $demand;
    }

    /**
     * The same figure read straight out of an order item's frozen snapshot, with no
     * lookup at all. An order must put back exactly what it took, even if the option has
     * since been repriced, relinked or deleted — so after placement the snapshot, never
     * the live menu, is the source of truth for stock.
     */
    public static function snapshotDemand($addons): array
    {
        if (is_string($addons)) {
            $addons = json_decode($addons, true);
        }
        if (!is_array($addons)) {
            return [];
        }

        $demand = [];
        foreach ($addons as $line) {
            if (!is_array($line) || empty($line['linked_variant_id'])) {
                continue;
            }
            $vid = (int) $line['linked_variant_id'];
            $demand[$vid] = ($demand[$vid] ?? 0) + max(1, (int) ($line['qty'] ?? 1));
        }

        return $demand;
    }

    /**
     * Move the stock a line's linked addons occupy. $action mirrors the product's own
     * lifecycle exactly — reserve on add, release when it leaves the cart, commit when
     * the order is paid for, restock on cancel or return — so a linked Coke behaves like
     * a Coke sold on its own, which is the point of linking it.
     */
    public static function applyStock(array $demand, ?int $branchId, int $lineQty, string $action): void
    {
        if (!$branchId || $lineQty === 0 || empty($demand)) {
            return;
        }

        foreach ($demand as $variantId => $perUnit) {
            $qty = (int) $perUnit * abs($lineQty);
            if ($qty <= 0) {
                continue;
            }
            match ($action) {
                'reserve' => ProductHelper::reserveStock($variantId, $branchId, $qty),
                'release' => ProductHelper::releaseStock($variantId, $branchId, $qty),
                'commit'  => ProductHelper::commitReservedStock($variantId, $branchId, $qty),
                'restock' => ProductHelper::restockStock($variantId, $branchId, $qty),
                default   => null,
            };
        }
    }

    /** Move the linked stock behind a CART line, from its live selections. */
    public static function moveCartStock($selections, ?int $branchId, int $lineQty, string $action): void
    {
        self::applyStock(self::stockDemand($selections, $branchId), $branchId, $lineQty, $action);
    }

    /**
     * Move the linked stock behind an ORDER item, from its snapshot. $branchOverride is for
     * the commit at placement, which must settle against the branch the cart reserved from.
     */
    public static function moveOrderItemStock($orderItem, string $action, ?int $branchOverride = null): void
    {
        if (!$orderItem) {
            return;
        }
        $addons = is_object($orderItem) ? ($orderItem->addons ?? null) : ($orderItem['addons'] ?? null);
        $qty    = (int) (is_object($orderItem) ? ($orderItem->quantity ?? 0) : ($orderItem['quantity'] ?? 0));
        $branch  = $branchOverride ?: (int) (is_object($orderItem) ? ($orderItem->branch_id ?? 0) : ($orderItem['branch_id'] ?? 0));

        self::applyStock(self::snapshotDemand($addons), $branch ?: null, $qty, $action);
    }

    /**
     * Validate a customer's choice for one product at one branch, before it reaches the
     * cart. Returns ['ok' => true, 'selections', 'signature', 'unit', 'lines'] or
     * ['ok' => false, 'error' => '<translated message>'].
     *
     * Nothing here trusts the request beyond the list of ids: each option must exist, be
     * active, belong to a group of THIS product, be sold by THIS branch, and satisfy its
     * group's own radio/checkbox, required, min/max and per-option quantity rules.
     */
    public static function validate(int $productId, ?int $branchId, $selections, int $lineQty = 1): array
    {
        $parsed = self::parse($selections);
        $groups = self::productGroups($productId, $branchId);

        if (empty($parsed)) {
            if ($missing = self::firstUnsatisfiedRequirement($groups, [])) {
                return ['ok' => false, 'error' => $missing];
            }

            return ['ok' => true, 'selections' => [], 'signature' => '', 'unit' => 0.0, 'lines' => []];
        }

        $options = self::loadOptions(array_column($parsed, 'id'), $branchId);

        $byGroup = [];
        foreach ($parsed as $sel) {
            $option = $options[$sel['id']] ?? null;
            if (!$option || (int) $option->status !== 1) {
                return ['ok' => false, 'error' => __('addon_option_not_available')];
            }

            $groupId = (int) $option->addon_group_id;
            if (!isset($groups[$groupId])) {
                // Active, but not a question THIS product asks.
                return ['ok' => false, 'error' => __('addon_option_not_available')];
            }

            if (!self::isOptionSellable($option, $branchId)) {
                return ['ok' => false, 'error' => __('addon_option_not_available_at_this_branch')];
            }

            $group = $groups[$groupId];
            $maxQty = max(1, (int) ($group->max_qty_per_option ?? 1));
            if ($sel['qty'] > $maxQty) {
                return ['ok' => false, 'error' => __('addon_option_quantity_too_high')];
            }

            $byGroup[$groupId][] = $sel;
        }

        foreach ($byGroup as $groupId => $chosen) {
            $group = $groups[$groupId];
            $count = count($chosen);

            if ($group->input_type === 'radio' && $count > 1) {
                return ['ok' => false, 'error' => __('addon_group_allows_one_choice')];
            }
            $max = (int) ($group->max_select ?? 0);
            if ($max > 0 && $count > $max) {
                return ['ok' => false, 'error' => __('addon_group_max_choices_exceeded')];
            }
            $min = (int) ($group->min_select ?? 0);
            if ($min > 0 && $count < $min) {
                return ['ok' => false, 'error' => __('addon_group_min_choices_not_met')];
            }
        }

        if ($missing = self::firstUnsatisfiedRequirement($groups, $byGroup)) {
            return ['ok' => false, 'error' => $missing];
        }

        /* Availability so far has only asked "can one of these be served". A line of three
           burgers each carrying a Coke needs three Cokes, so the real demand is checked
           against the shelf before the line is allowed into the cart. */
        foreach (self::stockDemand($parsed, $branchId) as $variantId => $perUnit) {
            $needed = $perUnit * max(1, $lineQty);
            if (ProductHelper::isVariantUnlimited($variantId, $branchId)) {
                continue;
            }
            if (ProductHelper::branchAvailableStock($variantId, $branchId) < $needed) {
                return ['ok' => false, 'error' => __('addon_option_not_enough_stock')];
            }
        }

        $described = self::describe($parsed, $branchId);

        return [
            'ok'         => true,
            'selections' => $parsed,
            'signature'  => self::signature($parsed),
            'unit'       => $described['unit'],
            'lines'      => $described['lines'],
        ];
    }

    /**
     * A required group that was not answered, or answered with too few options.
     *
     * A group this branch sells nothing from is skipped: the product detail does not offer
     * it, so insisting on it would make the dish unorderable here for a reason the
     * customer can neither see nor fix.
     */
    private static function firstUnsatisfiedRequirement(array $groups, array $byGroup): ?string
    {
        foreach ($groups as $groupId => $group) {
            if (!$group->is_required || ($group->sellable_options ?? 0) < 1) {
                continue;
            }
            $count = count($byGroup[$groupId] ?? []);
            $need = max(1, (int) ($group->min_select ?? 0));
            if ($count < $need) {
                return __('addon_group_requires_a_choice', ['group' => $group->name]);
            }
        }

        return null;
    }

    /** What one unit of an option costs at a branch. */
    private static function optionUnitPrice(ProductAddonOption $option, ?int $branchId): float
    {
        // Marked free by the admin: no price is read at all, at any branch.
        if ((int) $option->is_free === 1) {
            return 0.0;
        }

        if ($option->followsCatalogue()) {
            /* The linked variant's BASE branch price — deliberately not slabUnitPrice().
               A slab is a tier on how many of that product you buy; it must not be reached
               by ordering more of the dish this rides on. */
            $row = ProductHelper::branchPriceRow($option->linked_variant_id, $branchId);
            if (!$row) {
                return 0.0;
            }
            $price = (float) $row->price;
            $offer = (float) $row->discounted_price;
            $base  = ($offer > 0 && $offer < $price) ? $offer : $price;

            return round($base, 2);
        }

        $row = $option->branchRow($branchId);

        return $row ? round($row->chargeablePrice(), 2) : 0.0;
    }

    /**
     * Can this branch actually serve this option right now?
     *
     * Switching an option or its group off has to stop it being SOLD, not merely stop it
     * being offered — a line already in a cart would otherwise keep being charged for it
     * right through checkout.
     */
    private static function isOptionSellable(ProductAddonOption $option, ?int $branchId): bool
    {
        if ((int) $option->status !== 1 || (int) ($option->group->status ?? 0) !== 1) {
            return false;
        }
        if (!$branchId) {
            return false;
        }

        if ($option->isLinked()) {
            // A linked option is only as available as the product behind it.
            $row = ProductHelper::branchPriceRow($option->linked_variant_id, $branchId);
            if (!$row || (int) $row->is_listed !== 1) {
                return false;
            }

            if (!ProductHelper::isStockRowInStock($row)) {
                return false;
            }

            // Free still has to be switched on for this branch; it just has no price.
            if ((int) $option->is_free === 1) {
                $own = $option->branchRow($branchId);

                return $own !== null && (bool) $own->is_available;
            }

            // A custom price still has to exist and be switched on for this branch.
            if (!$option->followsCatalogue()) {
                $own = $option->branchRow($branchId);

                return $own !== null && (bool) $own->is_available;
            }

            return true;
        }

        $own = $option->branchRow($branchId);

        /* Free or paid, the branch still decides whether it is offered here — only the
           money differs, and optionUnitPrice() has already forced that to zero. */
        return $own !== null && (bool) $own->is_available;
    }

    /**
     * The active groups this product asks, each carrying how many of its options the given
     * branch can actually serve.
     */
    private static function productGroups(int $productId, ?int $branchId): array
    {
        $groups = DB::table('product_addon_groups')
            ->where('product_id', $productId)
            ->whereNull('deleted_at')
            ->where('status', 1)
            ->orderBy('sort_order')->orderBy('id')
            ->get();

        if ($groups->isEmpty()) {
            return [];
        }

        $optionIds = DB::table('product_addon_options')
            ->whereIn('addon_group_id', $groups->pluck('id'))
            ->whereNull('deleted_at')->where('status', 1)
            ->pluck('id')->all();

        $loaded = empty($optionIds) ? collect() : self::loadOptions($optionIds, $branchId);

        $out = [];
        foreach ($groups as $group) {
            $group->sellable_options = $loaded
                ->where('addon_group_id', $group->id)
                ->filter(fn ($o) => self::isOptionSellable($o, $branchId))
                ->count();
            $out[(int) $group->id] = $group;
        }

        return $out;
    }

    /** Options with their group, this branch's price row and any linked variant. */
    private static function loadOptions(array $ids, ?int $branchId)
    {
        $ids = array_values(array_unique(array_map('intval', $ids)));
        sort($ids, SORT_NUMERIC);
        $key = implode(',', $ids) . '|' . (int) $branchId;

        if (!isset(self::$cache[$key])) {
            self::$cache[$key] = ProductAddonOption::with([
                'group',
                'branchPrices' => fn ($q) => $q->where('branch_id', (int) $branchId),
            ])->whereIn('id', $ids)->get()->keyBy('id');
        }

        return self::$cache[$key];
    }

    /**
     * What the linked products inside one unit of a line COST, from its snapshot.
     *
     * A linked option is a real product being given away with the dish, so its purchase
     * price belongs in the parent item's cost. Without this, margin reports would count
     * the whole addon charge as profit. Custom options carry no cost — the known gap.
     */
    public static function snapshotCost(array $addons, ?int $branchId): float
    {
        $cost = 0.0;

        foreach ($addons as $line) {
            if (!is_array($line) || empty($line['linked_variant_id'])) {
                continue;
            }
            $row = ProductHelper::branchPriceRow((int) $line['linked_variant_id'], $branchId);
            if (!$row) {
                continue;
            }
            $cost += (float) ($row->purchase_price ?? 0) * max(1, (int) ($line['qty'] ?? 1));
        }

        return round($cost, 2);
    }

    /**
     * The most of this option a customer may take on ONE unit of the dish.
     *
     * The group's own cap, lowered to what the shelf can actually serve when the option
     * is a real product. Without this the client would offer a stepper up to the group
     * cap and only learn at add-to-cart that the stock was not there.
     */
    public static function maxSelectableQty(ProductAddonOption $option, ?int $branchId, int $groupCap): int
    {
        $cap = max(1, $groupCap);

        if (!$option->linked_variant_id) {
            return $cap;
        }

        $row = ProductHelper::branchPriceRow($option->linked_variant_id, $branchId);
        if ((int) ($row->is_unlimited_stock ?? 0) === 1) {
            return $cap;
        }

        $stock = ProductHelper::isStockRowInStock($row) ? (int) $row->available : 0;

        return max(1, min($cap, $stock));
    }

    /**
     * What this option costs at a branch BEFORE any offer, so the client can strike it
     * through. Equal to the charged price when nothing is discounted.
     */
    public static function listPrice(ProductAddonOption $option, ?int $branchId): float
    {
        if ((int) $option->is_free === 1) {
            return 0.0;
        }

        if ($option->followsCatalogue()) {
            $row = ProductHelper::branchPriceRow($option->linked_variant_id, $branchId);

            return $row ? round((float) $row->price, 2) : 0.0;
        }

        $row = $option->branchRow($branchId);

        return $row ? round((float) $row->price, 2) : 0.0;
    }

    /**
     * Does this product ask any addon questions?
     *
     * Card and cart queries do not carry the addon relation — loading it everywhere just
     * to answer yes/no would be wasteful, and a per-product lookup inside a listing loop
     * would be N+1. One memoised id set answers for the whole request instead.
     */
    public static function productHasAddons(?int $productId): bool
    {
        if (!$productId) {
            return false;
        }

        if (self::$withAddons === null) {
            self::$withAddons = array_flip(
                DB::table('product_addon_groups')
                    ->where('status', 1)
                    ->whereNull('deleted_at')
                    ->distinct()
                    ->pluck('product_id')
                    ->map(fn ($id) => (int) $id)
                    ->all()
            );
        }

        return isset(self::$withAddons[$productId]);
    }

    /** Drops the memoised rows — wired to the queue worker boundary in AppServiceProvider. */
    public static function flushCache(): void
    {
        self::$cache = [];
        self::$withAddons = null;
        self::$images = [];
    }
}
