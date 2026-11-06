<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

/**
 * Every product is available in every branch: a product is never tied to a single branch.
 *
 * A variant's first branch row is the template (price, discount, tax flag, slabs, purchase price). Missing rows
 * for other branches are copied from it, listed and unlimited (items are made to order, so there is no stock).
 * Rows that already exist are never touched, so a deliberate per-branch price or an unlisted row is preserved.
 */
class BranchCatalogSync
{
    private const COLUMNS = 'product_variant_id, branch_id, is_listed, is_unlimited_stock, stock_status, available, reserved, min_alert, '
        . 'price, discounted_price, is_tax_inclusive, pricing_slabs, purchase_price, created_at, updated_at';

    private function select(string $branchExpr, string $extraWhere, array $bindings): int
    {
        $sql = "INSERT IGNORE INTO product_variant_branch_stocks (" . self::COLUMNS . ")
            SELECT r.product_variant_id, {$branchExpr}, 1, 1, 1, 0, 0, 0,
                   r.price, r.discounted_price, r.is_tax_inclusive, r.pricing_slabs, r.purchase_price, NOW(), NOW()
            FROM product_variant_branch_stocks r
            JOIN product_variants v ON v.id = r.product_variant_id AND v.deleted_at IS NULL
            WHERE r.id = (SELECT MIN(x.id) FROM product_variant_branch_stocks x WHERE x.product_variant_id = r.product_variant_id)
            {$extraWhere}";
        return DB::affectingStatement($sql, $bindings);
    }

    /** Give one branch every variant it is missing. */
    public function syncBranch(int $branchId): int
    {
        return $this->select('?', 'AND NOT EXISTS (SELECT 1 FROM product_variant_branch_stocks e WHERE e.product_variant_id = r.product_variant_id AND e.branch_id = ?)', [$branchId, $branchId]);
    }

    /** Give one variant a row in every branch that lacks one. */
    public function syncVariant(int $variantId): int
    {
        $total = 0;
        foreach (DB::table('branches')->whereNull('deleted_at')->pluck('id') as $branchId) {
            $total += $this->select('?', 'AND r.product_variant_id = ? AND NOT EXISTS (SELECT 1 FROM product_variant_branch_stocks e WHERE e.product_variant_id = r.product_variant_id AND e.branch_id = ?)',
                [(int) $branchId, $variantId, (int) $branchId]);
        }
        return $total;
    }

    /** Whole catalogue x all branches. Returns rows added. */
    public function syncAll(): int
    {
        $total = 0;
        foreach (DB::table('branches')->whereNull('deleted_at')->pluck('id') as $branchId) {
            $total += $this->syncBranch((int) $branchId);
        }
        return $total;
    }
}
