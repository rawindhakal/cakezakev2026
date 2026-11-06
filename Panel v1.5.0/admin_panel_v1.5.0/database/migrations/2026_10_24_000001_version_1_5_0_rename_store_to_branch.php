<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Release 1.5.0 — "Store" becomes "Branch", everywhere.
 *
 * Second migration of the 1.5.0 release, after the food-addon tables; it runs last so the
 * tables that release adds are renamed too.
 *
 * CakeZake is a single-vendor product: every outlet belongs to the one business running
 * the panel. Calling them stores made clients read the system as a marketplace and ask
 * which vendor owned what, so the word is retired — in the schema, not only on screen,
 * because a `store_id` in a report or a plugin would keep the old idea alive.
 *
 * The same goes for "seller": the snapshot columns on `order_items` describe the branch
 * that sold the line, not a third party, so they are renamed in step with it.
 *
 * Every step is guarded on the current name, so the migration is safe to re-run and does
 * nothing on a database that is already renamed. Index and constraint names are rebuilt
 * too — a `pvss_store_fk` left behind would be the only place the old word survives.
 *
 * Deliberately NOT renamed, because they are not branches:
 *   - `settings.store_map_url` — the map link that sits beside the business address
 *   - the app-store rows (`play_store_logo`, `appstore_url`, …)
 *   - branch names themselves (`branches.name`), which are the client's own data
 */
return new class extends Migration
{
    /** Tables: old name => new name. */
    private const TABLES = [
        'stores'                       => 'branches',
        'store_translations'           => 'branch_translations',
        'product_variant_store_stocks' => 'product_variant_branch_stocks',
        'product_addon_option_stores'  => 'product_addon_option_branches',
    ];

    /** Columns, keyed by the table they now live in: old name => new name. */
    private const COLUMNS = [
        'admins'                        => ['store_id' => 'branch_id', 'is_store_owner' => 'is_branch_owner'],
        'carts'                         => ['store_id' => 'branch_id'],
        'faqs'                          => ['store_id' => 'branch_id'],
        'media'                         => ['store_id' => 'branch_id'],
        'order_items'                   => [
            'store_id'          => 'branch_id',
            'seller_region_id'  => 'branch_region_id',
            'seller_tax_number' => 'branch_tax_number',
        ],
        'page_layouts'                  => ['store_id' => 'branch_id'],
        'roles'                         => ['store_id' => 'branch_id'],
        'branch_translations'           => ['store_id' => 'branch_id'],
        'product_variant_branch_stocks' => ['store_id' => 'branch_id'],
        'product_addon_option_branches' => ['store_id' => 'branch_id'],
        'product_bulk_imports'          => ['store_ids' => 'branch_ids'],
    ];

    /** Plain indexes: table => [old index name => [new name, columns]]. */
    private const INDEXES = [
        'branches'                      => ['stores_zone_id_index' => ['branches_zone_id_index', ['zone_id']]],
        // The language foreign key's own index keeps the old table's name after a rename.
        'branch_translations'           => [
            'store_translations_language_id_foreign' => ['branch_translations_language_id_index', ['language_id']],
        ],
        'admins'                        => ['admins_store_id_index' => ['admins_branch_id_index', ['branch_id']]],
        'order_items'                   => ['order_items_store_id_index' => ['order_items_branch_id_index', ['branch_id']]],
        'page_layouts'                  => ['page_layouts_store_id_index' => ['page_layouts_branch_id_index', ['branch_id']]],
        'roles'                         => ['roles_store_id_index' => ['roles_branch_id_index', ['branch_id']]],
        'product_variant_branch_stocks' => [
            'product_variant_store_stocks_store_id_index' => ['product_variant_branch_stocks_branch_id_index', ['branch_id']],
        ],
    ];

    /** Unique indexes: table => [old name => [new name, columns]]. */
    private const UNIQUES = [
        'branch_translations' => [
            'store_translations_store_id_language_id_unique' => ['branch_translations_branch_id_language_id_unique', ['branch_id', 'language_id']],
        ],
        'product_variant_branch_stocks' => [
            'pvss_variant_store_unique' => ['pvbs_variant_branch_unique', ['product_variant_id', 'branch_id']],
        ],
        'product_addon_option_branches' => [
            'pa_opt_store_unique' => ['pa_opt_branch_unique', ['addon_option_id', 'branch_id']],
        ],
    ];

    /**
     * Foreign keys: table => [old constraint => [new constraint, column, referenced table]].
     * Dropped and re-created, since a constraint cannot be renamed in place.
     */
    private const FOREIGN_KEYS = [
        'branch_translations' => [
            'store_translations_store_id_foreign'     => ['branch_translations_branch_id_foreign', 'branch_id', 'branches'],
            'store_translations_language_id_foreign'  => ['branch_translations_language_id_foreign', 'language_id', 'languages'],
        ],
        'product_variant_branch_stocks' => [
            'pvss_store_fk' => ['pvbs_branch_fk', 'branch_id', 'branches'],
        ],
        'product_addon_option_branches' => [
            'pa_opt_store_store_fk' => ['pa_opt_branch_branch_fk', 'branch_id', 'branches'],
            'pa_opt_store_opt_fk'   => ['pa_opt_branch_opt_fk', 'addon_option_id', 'product_addon_options'],
        ],
    ];

    public function up(): void
    {
        foreach (self::TABLES as $old => $new) {
            if (Schema::hasTable($old) && !Schema::hasTable($new)) {
                Schema::rename($old, $new);
            }
        }

        foreach (self::COLUMNS as $table => $map) {
            foreach ($map as $old => $new) {
                if (Schema::hasTable($table) && Schema::hasColumn($table, $old) && !Schema::hasColumn($table, $new)) {
                    Schema::table($table, fn (Blueprint $t) => $t->renameColumn($old, $new));
                }
            }
        }

        // Constraints before their indexes: an index backing a foreign key cannot be dropped.
        // Renaming a table makes MySQL rewrite the constraints whose names began with the
        // old table name, so some of these are already carrying the new name by now.
        foreach (self::FOREIGN_KEYS as $table => $map) {
            foreach ($map as $old => [$new, $column, $references]) {
                if (!$this->foreignKeyExists($table, $old) || $this->foreignKeyExists($table, $new)) {
                    continue;
                }
                Schema::table($table, function (Blueprint $t) use ($old, $new, $column, $references) {
                    $t->dropForeign($old);
                    $t->foreign($column, $new)->references('id')->on($references)->cascadeOnDelete();
                });
            }
        }

        // New index first, old one after: a foreign key is backed by the index whose
        // leading column it uses, and MySQL refuses to drop the only one that fits.
        foreach (self::UNIQUES as $table => $map) {
            foreach ($map as $old => [$new, $columns]) {
                if (!$this->indexExists($table, $new)) {
                    Schema::table($table, fn (Blueprint $t) => $t->unique($columns, $new));
                }
                if ($this->indexExists($table, $old)) {
                    Schema::table($table, fn (Blueprint $t) => $t->dropUnique($old));
                }
            }
        }

        foreach (self::INDEXES as $table => $map) {
            foreach ($map as $old => [$new, $columns]) {
                if (!$this->indexExists($table, $new)) {
                    Schema::table($table, fn (Blueprint $t) => $t->index($columns, $new));
                }
                if ($this->indexExists($table, $old)) {
                    Schema::table($table, fn (Blueprint $t) => $t->dropIndex($old));
                }
            }
        }

        $this->renameStoredNames();
    }

    /**
     * The word also lives in rows: permission and role names the panel checks by string,
     * the token type a branch login is issued under, one settings key, and the template
     * keys for the "returned to branch" status.
     */
    private function renameStoredNames(): void
    {
        $permissions = [
            'store_list'        => 'branch_list',
            'store_create'      => 'branch_create',
            'store_update'      => 'branch_update',
            'store_delete'      => 'branch_delete',
            'store_user_manage' => 'branch_user_manage',
            'store_role_manage' => 'branch_role_manage',
        ];
        if (Schema::hasTable('permissions')) {
            foreach ($permissions as $old => $new) {
                DB::table('permissions')->where('name', $old)->update(['name' => $new]);
            }
        }

        if (Schema::hasTable('permission_categories')) {
            DB::table('permission_categories')->where('name', 'store')->update(['name' => 'branch']);
            DB::table('permission_categories')->where('name', 'store_panel')->update(['name' => 'branch_panel']);
        }

        // Branch roles are named "<slug><branch id>:<role>", e.g. store4:__owner__.
        if (Schema::hasTable('roles')) {
            DB::table('roles')->where('name', 'Store')->update(['name' => 'Branch']);
            DB::table('roles')->where('name', 'like', 'store%:%')
                ->update(['name' => DB::raw("CONCAT('branch', SUBSTRING(name, 6))")]);
        }

        if (Schema::hasTable('admin_tokens')) {
            DB::table('admin_tokens')->where('type', 'Store')->update(['type' => 'Branch']);
        }

        if (Schema::hasTable('settings')) {
            DB::table('settings')->where('variable', 'panel_two_factor_store_users')
                ->update(['variable' => 'panel_two_factor_branch_users']);
        }

        foreach (['email_templates', 'notification_templates', 'sms_templates'] as $table) {
            if (!Schema::hasTable($table)) {
                continue;
            }
            DB::table($table)->where('type', 'like', '%return_to_store%')->update([
                'type' => DB::raw("REPLACE(type, 'return_to_store', 'return_to_branch')"),
            ]);

            /* The placeholder catalogue a client clicks in the template editor, and any
               wording they already pasted it into. {store_url} is the app store's download
               link and stays as it is. */
            foreach (['placeholders', 'message', 'title', 'subject'] as $column) {
                if (!Schema::hasColumn($table, $column)) {
                    continue;
                }
                foreach (['store_name' => 'branch_name', 'store_address' => 'branch_address'] as $old => $new) {
                    DB::table($table)->where($column, 'like', "%$old%")->update([
                        $column => DB::raw("REPLACE(`$column`, '$old', '$new')"),
                    ]);
                }
            }

            /* Default wording that named the destination. Matched on the whole phrase so a
               client's own rewrite, and anything about the app store, is left alone. */
            if (Schema::hasColumn($table, 'message')) {
                DB::table($table)->where('message', 'like', '%reached the store%')->update([
                    'message' => DB::raw("REPLACE(message, 'reached the store', 'reached the branch')"),
                ]);
            }
        }

        /* The business address is a settings row, and the panel now posts it under the new
           name: left behind, the field would load blank and save a second row. */
        if (Schema::hasTable('settings')) {
            DB::table('settings')->where('variable', 'store_address')
                ->update(['variable' => 'branch_address']);
        }

        /* Notification switches are keyed by event name, and one event is named after the
           status: a row still saying return_to_store would silently stop matching, so an
           admin's muted mail or a customer's opt-out would come back on. */
        foreach (['notification_admin_settings', 'notification_preferences'] as $table) {
            if (Schema::hasTable($table) && Schema::hasColumn($table, 'event_key')) {
                DB::table($table)->where('event_key', 'like', '%return_to_store%')->update([
                    'event_key' => DB::raw("REPLACE(event_key, 'return_to_store', 'return_to_branch')"),
                ]);
            }
        }
    }

    private function foreignKeyExists(string $table, string $constraint): bool
    {
        if (!Schema::hasTable($table)) {
            return false;
        }

        return (bool) DB::selectOne(
            'select 1 as found from information_schema.table_constraints where table_schema = ? and table_name = ? and constraint_name = ? and constraint_type = ? limit 1',
            [DB::getDatabaseName(), $table, $constraint, 'FOREIGN KEY']
        );
    }

    private function indexExists(string $table, string $index): bool
    {
        if (!Schema::hasTable($table)) {
            return false;
        }

        return (bool) DB::selectOne(
            'select 1 as found from information_schema.statistics where table_schema = ? and table_name = ? and index_name = ? limit 1',
            [DB::getDatabaseName(), $table, $index]
        );
    }

    public function down(): void
    {
        // Names only; nothing here loses data, so the reverse is the same work backwards.
        foreach (['notification_admin_settings', 'notification_preferences'] as $table) {
            if (Schema::hasTable($table) && Schema::hasColumn($table, 'event_key')) {
                DB::table($table)->where('event_key', 'like', '%return_to_branch%')->update([
                    'event_key' => DB::raw("REPLACE(event_key, 'return_to_branch', 'return_to_store')"),
                ]);
            }
        }

        if (Schema::hasTable('settings')) {
            DB::table('settings')->where('variable', 'branch_address')
                ->update(['variable' => 'store_address']);
        }

        foreach (['email_templates', 'notification_templates', 'sms_templates'] as $table) {
            if (!Schema::hasTable($table)) {
                continue;
            }
            DB::table($table)->where('type', 'like', '%return_to_branch%')->update([
                'type' => DB::raw("REPLACE(type, 'return_to_branch', 'return_to_store')"),
            ]);

            foreach (['placeholders', 'message', 'title', 'subject'] as $column) {
                if (!Schema::hasColumn($table, $column)) {
                    continue;
                }
                foreach (['branch_name' => 'store_name', 'branch_address' => 'store_address'] as $old => $new) {
                    DB::table($table)->where($column, 'like', "%$old%")->update([
                        $column => DB::raw("REPLACE(`$column`, '$old', '$new')"),
                    ]);
                }
            }

            if (Schema::hasColumn($table, 'message')) {
                DB::table($table)->where('message', 'like', '%reached the branch%')->update([
                    'message' => DB::raw("REPLACE(message, 'reached the branch', 'reached the store')"),
                ]);
            }
        }

        if (Schema::hasTable('settings')) {
            DB::table('settings')->where('variable', 'panel_two_factor_branch_users')
                ->update(['variable' => 'panel_two_factor_store_users']);
        }

        if (Schema::hasTable('admin_tokens')) {
            DB::table('admin_tokens')->where('type', 'Branch')->update(['type' => 'Store']);
        }

        if (Schema::hasTable('roles')) {
            DB::table('roles')->where('name', 'Branch')->update(['name' => 'Store']);
            DB::table('roles')->where('name', 'like', 'branch%:%')
                ->update(['name' => DB::raw("CONCAT('store', SUBSTRING(name, 7))")]);
        }

        if (Schema::hasTable('permission_categories')) {
            DB::table('permission_categories')->where('name', 'branch')->update(['name' => 'store']);
            DB::table('permission_categories')->where('name', 'branch_panel')->update(['name' => 'store_panel']);
        }

        if (Schema::hasTable('permissions')) {
            foreach (['branch_list' => 'store_list', 'branch_create' => 'store_create', 'branch_update' => 'store_update',
                      'branch_delete' => 'store_delete', 'branch_user_manage' => 'store_user_manage',
                      'branch_role_manage' => 'store_role_manage'] as $new => $old) {
                DB::table('permissions')->where('name', $new)->update(['name' => $old]);
            }
        }

        foreach (self::FOREIGN_KEYS as $table => $map) {
            foreach ($map as $old => [$new, $column, $references]) {
                if (!$this->foreignKeyExists($table, $new) || $this->foreignKeyExists($table, $old)) {
                    continue;
                }
                Schema::table($table, function (Blueprint $t) use ($old, $new, $column, $references) {
                    $t->dropForeign($new);
                    $t->foreign($column, $old)->references('id')->on($references)->cascadeOnDelete();
                });
            }
        }

        foreach (self::UNIQUES as $table => $map) {
            foreach ($map as $old => [$new, $columns]) {
                if (!$this->indexExists($table, $old)) {
                    Schema::table($table, fn (Blueprint $t) => $t->unique($columns, $old));
                }
                if ($this->indexExists($table, $new)) {
                    Schema::table($table, fn (Blueprint $t) => $t->dropUnique($new));
                }
            }
        }

        foreach (self::INDEXES as $table => $map) {
            foreach ($map as $old => [$new, $columns]) {
                if (!$this->indexExists($table, $old)) {
                    Schema::table($table, fn (Blueprint $t) => $t->index($columns, $old));
                }
                if ($this->indexExists($table, $new)) {
                    Schema::table($table, fn (Blueprint $t) => $t->dropIndex($new));
                }
            }
        }

        foreach (self::COLUMNS as $table => $map) {
            foreach ($map as $old => $new) {
                if (Schema::hasTable($table) && Schema::hasColumn($table, $new) && !Schema::hasColumn($table, $old)) {
                    Schema::table($table, fn (Blueprint $t) => $t->renameColumn($new, $old));
                }
            }
        }

        foreach (array_reverse(self::TABLES, true) as $old => $new) {
            if (Schema::hasTable($new) && !Schema::hasTable($old)) {
                Schema::rename($new, $old);
            }
        }
    }
};
