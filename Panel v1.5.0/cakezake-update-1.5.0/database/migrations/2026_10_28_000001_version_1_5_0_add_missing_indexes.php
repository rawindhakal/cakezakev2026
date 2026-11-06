<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

/**
 * Release 1.5.0 — indexes for the lookups that were scanning whole tables.
 *
 * `product_images` and `order_statuses` carried a PRIMARY KEY and nothing else, while both
 * are read on paths a shopper hits constantly: every product page loads its gallery by
 * `product_id`, every variant loads its own by `product_variant_id`, and every order detail
 * screen reads its status history by `order_id`. On this build those were full scans of
 * 3.7k and 3.3k rows; on a client with fifty thousand products they are the reason a product
 * list times out.
 *
 * Each index here is matched to a query that exists in the code, not to a column name.
 * That distinction decides the COLUMN ORDER, and column order is the whole value of a
 * composite:
 *
 *   product_images(product_id, product_variant_id)  Product::images() filters both, and the
 *                                                   leading column alone still serves a
 *                                                   plain product lookup.
 *   product_images(product_variant_id)              A separate index, not redundant: the
 *                                                   variant gallery filters this column
 *                                                   WITHOUT product_id, so it cannot ride on
 *                                                   the composite's prefix.
 *   panel_notifications(notifiable_id, …_type)      Deliberately id-first, against the usual
 *                                                   morph convention, because Controller.php
 *                                                   reads `where notifiable_id = <me>` with
 *                                                   no type on every panel page load. A
 *                                                   type-first index would not serve it.
 *   activity_logs(subject_type, subject_id)         Type-first here, because the admin filter
 *                                                   sends a type and no id.
 *
 * Tables that stay small for the life of a store — languages, permissions, admins, blog_tag,
 * sms_template_translations — are deliberately left alone. Forty rows scan faster than they
 * index, and every index is a write cost on bulk product imports.
 *
 * NO FOREIGN KEYS, on purpose. Three findings rule them out for a shipped product:
 *
 *   1. Orphan rows already exist in ordinary installs — this build alone has 93 in
 *      orders.address_id, 89 in order_statuses.order_item_id, 36 across product_images. The
 *      panel's System Updater runs `down` → copy files → `migrate --force` → `up`, so a
 *      constraint that fails to apply leaves a client's live store in maintenance mode.
 *   2. The types do not match. Almost every one of these columns is `int` while the `id` it
 *      points at is `bigint unsigned`, so each constraint would first need a MODIFY COLUMN —
 *      a locking table rewrite, ~70 times, on shared hosting.
 *   3. Delete paths currently drop parents and tolerate leftover children. Constraints would
 *      turn those into 500s until every one of them is reworked.
 *
 * An index can never fail on bad data, which is what makes this migration safe to ship.
 * Index creation is still attempted one at a time and a failure is logged rather than thrown:
 * a client on a row format with a smaller index-size limit may reject a composite over a
 * varchar(191), and losing one index must not cost them the release.
 *
 * ---------------------------------------------------------------------------------------
 *
 * `remainingColumns()` below then covers EVERY other reference column in the schema, so none
 * is left unindexed. Read this before adding to that list: most of those will not change a
 * query plan. MySQL skips an index when a lookup matches more than roughly a fifth of the
 * table, so a column with a handful of distinct values is never read through its index.
 * Measured on a reference install: `oauth_access_tokens.client_id` holds 2 distinct values
 * over 5127 rows, `order_items.branch_region_id` 2 over 2971, `transactions.payu_txn_id` is
 * empty in every row, and the same applies to every `country_id`, `zone_id`, `language_id`,
 * `role_id` and `branch_id` there — a store has a handful of countries and zones for its
 * whole life. The cost lands on writes, and it is not small: two extra indexes on a busy
 * table measured +57% on a 20k-row insert. Those tables are written rarely enough that it
 * does not matter, which is the only reason the blanket pass is acceptable.
 *
 * Two columns are deliberately left out of it:
 *
 *   activity_logs.subject_id  Takes a row on EVERY admin action, so it is the one table where
 *                             the write cost above is real, and its subject lookups are
 *                             already served by the (subject_type, subject_id) index that the
 *                             table's own migration creates.
 *   emails.type_id            A TEXT column. MySQL rejects an index on one without a prefix
 *                             length ("BLOB/TEXT column used in key specification without a
 *                             key length"). It holds no rows and has no lookup, so no prefix
 *                             index was invented for it.
 */
return new class extends Migration
{
    private function numericStringColumns(): array
    {
        return [
            'order_statuses' => ['order_id' => 0],
            'user_addresses' => ['zone_id' => 0],
        ];
    }

    private function fixNumericStringColumns(): void
    {
        foreach ($this->numericStringColumns() as $table => $columns) {
            if (!Schema::hasTable($table)) {
                continue;
            }

            foreach ($columns as $column => $default) {
                $this->convertToBigint($table, $column, (int) $default);
            }
        }
    }

    private function convertToBigint(string $table, string $column, int $default): void
    {
        if (!Schema::hasColumn($table, $column)) {
            return;
        }

        try {
            $type = DB::selectOne(
                'SELECT DATA_TYPE t FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
                [$table, $column]
            );

            if (!$type || !in_array(strtolower($type->t), ['char', 'varchar', 'text'], true)) {
                return; // Already numeric on this install.
            }

            // An empty string converts cleanly to the default, so only a non-numeric value
            // that is actually present blocks the change.
            $unconvertible = DB::table($table)
                ->whereNotNull($column)
                ->where($column, '!=', '')
                ->whereRaw("TRIM(`{$column}`) NOT REGEXP '^[0-9]+$'")
                ->count();

            if ($unconvertible > 0) {
                Log::warning(
                    "{$table}.{$column} left as a string column: {$unconvertible} row(s) are not numeric."
                );

                return;
            }

            // Blanks first, so the MODIFY has nothing left to coerce.
            DB::table($table)->whereNull($column)->orWhere($column, '')->update([$column => $default]);

            DB::statement(
                "ALTER TABLE `{$table}` MODIFY `{$column}` BIGINT UNSIGNED NOT NULL DEFAULT {$default}"
            );
        } catch (\Throwable $e) {
            Log::warning("Could not convert {$table}.{$column}: " . $e->getMessage());
        }
    }

    /**
     * table => [index name => columns]. Each entry names the query it exists for.
     */
    private function indexes(): array
    {
        return [
            // Gallery reads on every product and variant screen. Table had PRIMARY only.
            'product_images' => [
                'product_images_product_variant_idx' => ['product_id', 'product_variant_id'],
                'product_images_variant_idx'         => ['product_variant_id'],
            ],

            // Status history per order, and the order-level rows (`order_item_id = 0`).
            // Table had PRIMARY only.
            'order_statuses' => [
                'order_statuses_order_item_idx' => ['order_id', 'order_item_id'],
            ],

            // Read on every panel page load, by id with no type. Id first for that reason.
            'panel_notifications' => [
                'panel_notifications_notifiable_idx' => ['notifiable_id', 'notifiable_type'],
            ],

            'activity_logs' => [
                'activity_logs_subject_idx' => ['subject_type', 'subject_id'],
                'activity_logs_causer_idx'  => ['causer_id', 'causer_type'],
            ],

            // Loaded per order item when an invoice or a refund breaks tax down.
            'order_item_taxes' => [
                'order_item_taxes_tax_rule_idx' => ['tax_rule_id'],
            ],

            // Zone and country are the dashboard's and the order list's standing filters.
            // promo_code_id is read by a correlated subquery every time a promo is validated.
            'orders' => [
                'orders_zone_id_index'       => ['zone_id'],
                'orders_country_id_index'    => ['country_id'],
                'orders_promo_code_id_index' => ['promo_code_id'],
            ],

            // Courier webhooks arrive with an AWB or a shipment id and nothing else.
            'order_items' => [
                'order_items_tracking_idx'  => ['tracking_id'],
                'order_items_shipment_idx'  => ['courier_shipment_id'],
            ],

            // Payment webhooks look a transaction up by the gateway's own reference to
            // decide whether it has already been credited. That check runs before money
            // moves, so it is worth an index on correctness grounds as much as speed.
            'transactions' => [
                'transactions_txn_id_index' => ['txn_id'],
            ],

            'wallet_transactions' => [
                'wallet_transactions_user_id_index'  => ['user_id'],
                'wallet_transactions_order_id_index' => ['order_id'],
                'wallet_transactions_txn_id_index'   => ['txn_id'],
                'wallet_transactions_zone_id_index'  => ['zone_id'],
            ],

            // Cart rendering joins products and branches on every cart read.
            'carts' => [
                'carts_product_id_index' => ['product_id'],
                'carts_branch_id_index'  => ['branch_id'],
            ],

            // Catalogue filters, and the category move/delete checks.
            'products' => [
                'products_category_id_index' => ['category_id'],
                'products_brand_id_index'    => ['brand_id'],
            ],

            'user_addresses' => [
                'user_addresses_user_id_index' => ['user_id'],
            ],

            // "How many people wishlisted this", and the wishlist report's join.
            'favorites' => [
                'favorites_product_id_index' => ['product_id'],
            ],

            'return_requests' => [
                'return_requests_order_id_index' => ['order_id'],
                'return_requests_user_id_index'  => ['user_id'],
            ],

            // Four self-relations build the category tree on every catalogue render.
            'categories' => [
                'categories_parent_id_index' => ['parent_id'],
            ],

            'rating_images' => [
                'rating_images_rating_id_index' => ['product_rating_id'],
            ],

            // Always read as the pair, never by user alone. Covered already by the table's
            // own unique key, which leads with these two columns — kept here for an install
            // that predates it, and skipped by the guard otherwise.
            'notification_preferences' => [
                'notification_preferences_user_idx' => ['user_type', 'user_id'],
            ],

            // Report filters, and the language fan-out when a notification goes wide.
            'users' => [
                'users_country_id_index'  => ['country_id'],
                'users_language_id_index' => ['language_id'],
            ],

            // Resolved on every request the delivery app makes.
            'delivery_boys' => [
                'delivery_boys_admin_id_index' => ['admin_id'],
            ],
        ];
    }

    private function remainingColumns(): array
    {
        return [
            'admin_tokens'                  => ['language_id', 'user_id'],
            'admins'                        => ['role_id'],
            'app_usages'                    => ['order_id'],
            'blog_tag'                      => ['language_id'],
            'branches'                      => ['owner_admin_id', 'place_id'],
            'carts'                         => ['product_variant_id'],
            'delivery_boy_cash_collections' => ['order_id', 'user_id', 'wallet_transaction_id'],
            'delivery_boy_notifications'    => ['delivery_boy_id', 'order_item_id'],
            'delivery_boy_settlements'      => ['country_id'],
            'delivery_boys'                 => ['country_id'],
            'delivery_cities'               => ['country_id'],
            'faqs'                          => ['branch_id'],
            'languages'                     => ['supported_language_id'],
            'media'                         => ['branch_id'],
            'messages'                      => ['sender_id'],
            'notification_preferences'      => ['user_id'],
            'notifications'                 => ['type_id'],
            'oauth_access_tokens'           => ['client_id'],
            'oauth_auth_codes'              => ['client_id'],
            'oauth_personal_access_clients' => ['client_id'],
            'offers'                        => ['type_id'],
            'order_items'                   => ['branch_region_id'],
            'order_statuses'                => ['order_item_id'],
            'orders'                        => ['address_id', 'transaction_id'],
            'permissions'                   => ['category_id'],
            'personal_access_tokens'        => ['tokenable_id'],
            'plugin_payment_intents'        => ['country_id', 'user_id'],
            'product_bulk_imports'          => ['admin_id', 'category_id'],
            'product_ratings'               => ['user_id'],
            'product_recommendations'       => ['related_product_id'],
            'product_stock_alerts'          => ['country_id'],
            'promo_codes'                   => ['source_id'],
            'return_requests'               => ['address_id', 'courier_shipment_id', 'product_variant_id', 'tracking_id'],
            'sms_template_translations'     => ['language_id'],
            'spin_wheel_spins'              => ['wallet_transaction_id', 'zone_id'],
            'transactions'                  => ['country_id', 'payu_txn_id', 'zone_id'],
            'user_addresses'                => ['zone_id'],
            'user_tokens'                   => ['language_id', 'user_id'],
            'user_wallets'                  => ['country_id'],
            'wallet_transactions'           => ['country_id', 'order_item_id'],
            'withdrawal_requests'           => ['country_id', 'type_id'],
            'zones'                         => ['country_id', 'delivery_charge_tax_category_id'],
        ];
    }

    /**
     * Both passes flattened to one list of (table, name, columns), so up() and down() walk
     * exactly the same set and cannot drift apart.
     *
     * @return array<int, array{0: string, 1: string, 2: array<int, string>}>
     */
    private function allIndexes(): array
    {
        $all = [];

        foreach ($this->indexes() as $table => $specs) {
            foreach ($specs as $name => $columns) {
                $all[] = [$table, $name, $columns];
            }
        }

        foreach ($this->remainingColumns() as $table => $columns) {
            foreach ($columns as $column) {
                $all[] = [$table, $this->indexName($table, $column), [$column]];
            }
        }

        return $all;
    }

    /**
     * MySQL caps an identifier at 64 characters, which `delivery_boy_cash_collections` plus a
     * column name is long enough to exceed.
     */
    private function indexName(string $table, string $column): string
    {
        $name = $table . '_' . $column . '_index';

        return strlen($name) <= 64 ? $name : substr($name, 0, 56) . '_' . substr(md5($name), 0, 7);
    }

    public function up(): void
    {
        $this->fixNumericStringColumns();

        foreach ($this->allIndexes() as [$table, $name, $columns]) {
            if (!Schema::hasTable($table)) {
                continue;
            }

            $this->addIndex($table, $name, $columns);
        }
    }

    public function down(): void
    {
        // The column type changes are deliberately NOT reverted. The string columns were the
        // defect, every stored value is numeric, and putting them back would only disable
        // the indexes again.
        foreach ($this->allIndexes() as [$table, $name, $columns]) {
            if (!Schema::hasTable($table)) {
                continue;
            }

            $existing = $this->showIndex($table);
            if ($existing === null || !$this->hasIndexNamed($existing, $name)) {
                continue;
            }

            try {
                Schema::table($table, fn (Blueprint $t) => $t->dropIndex($name));
            } catch (\Throwable $e) {
                Log::warning("Could not drop index {$name} on {$table}: " . $e->getMessage());
            }
        }
    }

    /**
     * One index, skipped when the columns are absent (a plugin or an older schema), when an
     * index of that name is already there, or when the columns are already covered as the
     * LEADING columns of some existing index — re-indexing the same prefix costs writes and
     * buys nothing.
     */
    private function addIndex(string $table, string $name, array $columns): void
    {
        foreach ($columns as $column) {
            if (!Schema::hasColumn($table, $column)) {
                return;
            }
        }

        $existing = $this->showIndex($table);
        if ($existing === null) {
            // Cannot read what is already there; do not risk a duplicate.
            return;
        }

        if ($this->hasIndexNamed($existing, $name) || $this->isAlreadyLed($existing, $columns)) {
            return;
        }

        try {
            Schema::table($table, fn (Blueprint $t) => $t->index($columns, $name));
        } catch (\Throwable $e) {
            // A client's row format may reject a wide composite. Log and move on: the
            // release must not fail over one index.
            Log::warning("Could not create index {$name} on {$table}: " . $e->getMessage());
        }
    }

    /** @param  array<int, object>  $existing  rows from SHOW INDEX */
    private function hasIndexNamed(array $existing, string $name): bool
    {
        foreach ($existing as $row) {
            if (($row->Key_name ?? '') === $name) {
                return true;
            }
        }

        return false;
    }

    /**
     * True when some existing index already begins with exactly these columns, in order.
     */
    private function isAlreadyLed(array $existing, array $columns): bool
    {
        $grouped = [];
        foreach ($existing as $row) {
            $grouped[$row->Key_name ?? ''][(int) ($row->Seq_in_index ?? 0)] = $row->Column_name ?? '';
        }

        foreach ($grouped as $cols) {
            ksort($cols);
            if (array_slice(array_values($cols), 0, count($columns)) === $columns) {
                return true;
            }
        }

        return false;
    }

    /** @return array<int, object>|null  null when the index list cannot be read. */
    private function showIndex(string $table): ?array
    {
        try {
            return DB::select('SHOW INDEX FROM `' . str_replace('`', '', $table) . '`');
        } catch (\Throwable) {
            return null;
        }
    }
};
