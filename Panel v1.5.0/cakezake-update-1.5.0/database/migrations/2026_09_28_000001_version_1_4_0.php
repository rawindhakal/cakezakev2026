<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Release 1.4.0.
 *
 * Two things:
 *
 * 1. The plugin platform — paid plugins are installed from a zip with their own purchase
 *    code, each owning its migrations, settings and licence state.
 * 3. Two-factor authentication for panel logins — the password earns a short-lived
 *    challenge, and a code emailed to the admin's own address exchanges it for an access
 *    token. The challenge lives in columns on `admins` rather than the session, because
 *    the panel is a token-authenticated SPA with no session to hang it on; one admin can
 *    only be mid-login once, so a row per challenge would buy nothing. Delivery boys are
 *    left out on purpose: the rider app is compiled against the one-step response and
 *    would read a tokenless reply as a failed login.
 * 2. Groundwork for courier shipping (the Shiprocket plugin is the first consumer, but
 *    none of this depends on it): variants carry a dead weight and a box size (nothing
 *    is copied onto the order line — weight is an input, recomputed at checkout and
 *    recorded on the shipment), stores carry a pickup pincode, and a zone may price
 *    ecommerce delivery from a courier quote instead of its own rule.
 */
return new class extends Migration
{
    public function up(): void
    {
        $this->pluginsTable();
        $this->pluginWebhookEventsTable();
        $this->syncPermissions();
        $this->variantShippingColumns();
        $this->orderItemCourierColumns();
        $this->storePostalColumns();
        $this->zoneCourierPricingStrategy();
        $this->zoneCourierMargin();
        $this->orderItemCourierException();
        $this->orderDeliveryPincode();
        $this->returnRequestCourierColumns();
        $this->twoFactorColumns();
        $this->twoFactorSettings();
        $this->twoFactorEmailTemplate();
        $this->deliveryBoyLookupIndexes();
        $this->productBulkImportChannel();
        $this->pluginPaymentIntentsTable();
        $this->shippingConfigurationsTable();
    }

    public function down(): void
    {
        $this->dropColumns('admins', [
            'two_factor_token', 'two_factor_code', 'two_factor_attempts',
            'two_factor_sends', 'two_factor_sent_at', 'two_factor_expires_at',
        ]);
        DB::table('settings')->whereIn('variable', [
            'panel_two_factor', 'panel_two_factor_store_users', 'panel_two_factor_expiry',
        ])->delete();
        $this->dropEmailTemplate('two_factor_code_admin');
        Schema::dropIfExists('plugin_webhook_events');
        Schema::dropIfExists('plugins');
        $this->dropPermissions(['manage_plugins']);
        $this->dropColumns('product_variants', ['weight', 'length', 'breadth', 'height']);
        $this->dropColumns('order_items', ['courier_provider', 'courier_shipment_id', 'courier_order_id', 'courier_label_url', 'courier_exception']);
        $this->dropColumns('orders', ['delivery_pincode']);
        $this->dropColumns('return_requests', [
            'courier_agency', 'tracking_id', 'tracking_url',
            'courier_provider', 'courier_shipment_id', 'courier_order_id', 'courier_exception', 'pickup_pincode',
        ]);
        $this->dropColumns('zones', ['courier_markup_type', 'courier_markup_value', 'courier_round_to', 'courier_min_charge', 'ecommerce_delivery_methods']);
        $this->dropColumns('stores', ['pincode']);
        $this->dropColumns('product_bulk_imports', ['sales_channel']);
        Schema::dropIfExists('plugin_payment_intents');
        Schema::dropIfExists('shipping_configurations');

        // Any zone already priced from a courier quote falls back to its flat rule, else
        // the enum change below would reject the stored value.
        if (Schema::hasTable('zones') && Schema::hasColumn('zones', 'pricing_strategy')) {
            DB::table('zones')->where('pricing_strategy', 'courier')->update(['pricing_strategy' => 'flat']);
            DB::statement("ALTER TABLE `zones` MODIFY `pricing_strategy` ENUM('flat','slab','city','area') NOT NULL DEFAULT 'flat'");
        }
    }

    /**
     * One row per installed plugin.
     *
     * The manifest is stored alongside the row so the panel can still describe a
     * plugin whose folder was deleted by hand, and the purchase code is encrypted by
     * the model rather than living in a cache file.
     *
     * The row holds only what cannot be derived from the plugin itself. Its namespace,
     * its working class and its settings all come from `module.json`, so columns for
     * them would be a second copy that drifts the moment a plugin is updated.
     */
    private function pluginsTable(): void
    {
        if (Schema::hasTable('plugins')) {
            return;
        }

        Schema::create('plugins', function (Blueprint $t) {
            $t->id();
            // Also the folder name under app/Modules and the licence identity.
            $t->string('slug', 64)->unique();
            $t->string('name', 191);
            $t->string('version', 20);
            $t->string('type', 32)->nullable()->index();          // payment|shipping
            $t->json('manifest')->nullable();
            $t->string('status', 16)->default('installed');       // installed|active|disabled|uninstalled|broken
            $t->boolean('enabled')->default(0);

            // Licence. The code itself is encrypted; only the last 4 are ever shown.
            $t->text('purchase_code')->nullable();
            $t->string('purchase_code_last4', 8)->nullable();
            $t->string('verify_url', 255)->nullable();
            $t->string('licence_state', 16)->default('unverified'); // valid|invalid|unverified
            $t->timestamp('licence_verified_at')->nullable();
            $t->string('licence_message', 255)->nullable();
            $t->json('lang_keys')->nullable();

            $t->unsignedBigInteger('installed_by')->nullable();
            $t->timestamp('installed_at')->nullable();
            $t->text('last_error')->nullable();
            $t->timestamps();

            $t->index(['enabled', 'status']);
            $t->index(['type', 'enabled']);
            $t->index('licence_state');
        });
    }

    /**
     * Inbound webhook deliveries, keyed so a retry can never be processed twice —
     * couriers and payment gateways both redeliver.
     */
    private function pluginWebhookEventsTable(): void
    {
        if (Schema::hasTable('plugin_webhook_events')) {
            return;
        }

        Schema::create('plugin_webhook_events', function (Blueprint $t) {
            $t->id();
            $t->string('slug', 64)->index();
            $t->string('action', 40);
            $t->char('event_key', 64)->unique();
            $t->string('reference', 191)->nullable()->index();
            $t->string('external_id', 191)->nullable()->index();   // AWB / gateway txn id
            $t->string('outcome', 24)->nullable();
            $t->unsignedSmallInteger('http_code')->nullable();
            $t->string('message', 255)->nullable();
            $t->text('payload_excerpt')->nullable();
            $t->string('ip', 45)->nullable();
            $t->timestamp('created_at')->nullable();
        });
    }

    /**
     * Managing plugins is its own permission, mirrored onto whoever already manages
     * general settings. A fresh install is left to the seeder.
     */
    private function syncPermissions(): void
    {
        if (!Schema::hasTable('permissions') || !Schema::hasTable('permission_categories') || !Schema::hasTable('roles')) {
            return;
        }
        if (!DB::table('permission_categories')->exists()) {
            return; // fresh install — the seeder owns this
        }

        $mirrored = ['manage_plugins' => 'manage_general_settings'];

        $categoryId = DB::table('permission_categories')->where('name', 'settings')->value('id')
            ?: DB::table('permission_categories')->insertGetId(['name' => 'settings', 'guard_name' => 'web']);

        foreach ($mirrored as $name => $mirror) {
            $id = DB::table('permissions')->where('name', $name)->value('id');
            if (!$id) {
                $id = DB::table('permissions')->insertGetId([
                    'name'        => $name,
                    'guard_name'  => 'web',
                    'category_id' => $categoryId,
                    'created_at'  => now(),
                    'updated_at'  => now(),
                ]);
            }

            $sourceId = DB::table('permissions')->where('name', $mirror)->value('id');
            $roleIds = $sourceId
                ? DB::table('role_has_permissions')->where('permission_id', $sourceId)->pluck('role_id')
                : DB::table('roles')->whereIn('name', ['Super Admin', 'Admin'])->pluck('id');

            foreach ($roleIds as $rid) {
                DB::table('role_has_permissions')->updateOrInsert(
                    ['permission_id' => $id, 'role_id' => $rid],
                    ['permission_id' => $id, 'role_id' => $rid]
                );
            }
        }
    }

    private function dropPermissions(array $names): void
    {
        if (!Schema::hasTable('permissions')) {
            return;
        }
        $ids = DB::table('permissions')->whereIn('name', $names)->pluck('id');
        if ($ids->isEmpty()) {
            return;
        }
        foreach (['role_has_permissions', 'model_has_permissions'] as $pivot) {
            if (Schema::hasTable($pivot)) {
                DB::table($pivot)->whereIn('permission_id', $ids)->delete();
            }
        }
        DB::table('permissions')->whereIn('id', $ids)->delete();
    }

    /**
     * What a courier needs to quote and label a parcel. Per variant, because a 500 g
     * pack and a 1 kg pack of the same product are different variants.
     *
     * Nullable throughout: an existing catalogue has none of this, and a shipping plugin
     * falls back to its own default box until the admin fills it in.
     */
    private function variantShippingColumns(): void
    {
        $this->addColumns('product_variants', [
            'weight'  => fn (Blueprint $t) => $t->decimal('weight', 10, 3)->nullable()->after('hsn_code')
                ->comment('Dead weight in kg'),
            'length'  => fn (Blueprint $t) => $t->decimal('length', 8, 2)->nullable()->after('weight')->comment('cm'),
            'breadth' => fn (Blueprint $t) => $t->decimal('breadth', 8, 2)->nullable()->after('length')->comment('cm'),
            'height'  => fn (Blueprint $t) => $t->decimal('height', 8, 2)->nullable()->after('breadth')->comment('cm'),
        ]);
    }

    /**
     * Which courier a line was handed to, and under what identity.
     *
     * Not a snapshot of anything — weight and box size stay inputs, recomputed at
     * checkout. These three are identity: the shipment has to be cancellable, its label
     * re-printable and its webhooks attributable even after the plugin is disabled, and
     * the existing `courier_agency` / `tracking_id` / `tracking_url` columns hold only
     * what a human types.
     */
    private function orderItemCourierColumns(): void
    {
        $this->addColumns('order_items', [
            'courier_provider'    => fn (Blueprint $t) => $t->string('courier_provider', 32)->nullable()->after('tracking_url')
                ->comment('Plugin slug that booked this shipment'),
            'courier_shipment_id' => fn (Blueprint $t) => $t->string('courier_shipment_id', 64)->nullable()->after('courier_provider'),
            /* A carrier gives a booking two handles and they are not interchangeable:
               Shiprocket cancels by ORDER id and refuses a shipment id. Both are kept. */
            'courier_order_id'    => fn (Blueprint $t) => $t->string('courier_order_id', 64)->nullable()
                ->after('courier_shipment_id')->index(),
            'courier_label_url'   => fn (Blueprint $t) => $t->string('courier_label_url', 500)->nullable()->after('courier_order_id'),
        ]);
    }

    /**
     * A courier pickup address is postal, not a map pin, and the pincode is the one part
     * the store has no home for. City and state come from the store's zone, the contact
     * from `contact_number`, the country from the zone's country — so only this is new.
     */
    private function storePostalColumns(): void
    {
        $this->addColumns('stores', [
            'pincode' => fn (Blueprint $t) => $t->string('pincode', 16)->nullable()->after('formatted_address'),
        ]);
    }

    /**
     * Ecommerce delivery pricing gains a 'courier' strategy. With no shipping plugin
     * installed the value simply never resolves and the zone keeps its own rule, so the
     * enum widening is safe on its own.
     */
    private function zoneCourierPricingStrategy(): void
    {
        if (!Schema::hasTable('zones') || !Schema::hasColumn('zones', 'pricing_strategy')) {
            return;
        }

        DB::statement("ALTER TABLE `zones` MODIFY `pricing_strategy` ENUM('flat','slab','city','area','courier') NOT NULL DEFAULT 'flat'");
    }

    /**
     * What a zone adds on top of a courier's quote.
     *
     * A courier's rate is what the *store* pays; what the customer pays is a business
     * decision. Without these a client's margin moves every time a carrier reprices,
     * which is not something they can watch daily.
     */
    private function zoneCourierMargin(): void
    {
        $this->addColumns('zones', [
            'courier_markup_type'  => fn (Blueprint $t) => $t->enum('courier_markup_type', ['none', 'percent', 'fixed'])
                ->default('none')->after('pricing_strategy'),
            'courier_markup_value' => fn (Blueprint $t) => $t->decimal('courier_markup_value', 8, 2)->default(0)
                ->after('courier_markup_type'),
            // Rounds the final charge up to a multiple: 5 turns 43.20 into 45.
            'courier_round_to'     => fn (Blueprint $t) => $t->decimal('courier_round_to', 5, 2)->default(0)
                ->after('courier_markup_value'),
            'courier_min_charge'   => fn (Blueprint $t) => $t->decimal('courier_min_charge', 8, 2)->default(0)
                ->after('courier_round_to'),
            'ecommerce_delivery_methods' => fn (Blueprint $t) => $t->json('ecommerce_delivery_methods')
                ->nullable()->after('courier_min_charge'),
        ]);
    }

    /**
     * A carrier's exception on an order line — "undelivered, customer not available".
     *
     * Kept on the item rather than only in the plugin's table because the panel has to
     * show it beside the line it affects, and it has to survive the plugin being
     * disabled: an unresolved failed delivery is the customer's problem either way.
     */
    private function orderItemCourierException(): void
    {
        $this->addColumns('order_items', [
            'courier_exception' => fn (Blueprint $t) => $t->string('courier_exception', 191)->nullable()
                ->after('courier_label_url'),
        ]);
    }

    private function orderDeliveryPincode(): void
    {
        $this->addColumns('orders', [
            'delivery_pincode' => fn (Blueprint $t) => $t->string('delivery_pincode', 16)->nullable()
                ->after('address_id'),
        ]);

        if (!Schema::hasColumn('orders', 'delivery_pincode')) {
            return;
        }

        DB::table('orders')->whereNull('delivery_pincode')
            ->select('id', 'address_id', 'address')->chunkById(500, function ($orders) {
                foreach ($orders as $order) {
                    $snapshot = json_decode((string) $order->address, true);
                    $pincode = trim((string) ($snapshot['pincode'] ?? ''));

                    if ($pincode === '' && $order->address_id) {
                        $pincode = trim((string) DB::table('user_addresses')
                            ->where('id', $order->address_id)->value('pincode'));
                    }
                    if ($pincode !== '') {
                        DB::table('orders')->where('id', $order->id)
                            ->update(['delivery_pincode' => mb_substr($pincode, 0, 16)]);
                    }
                }
            });
    }

    /**
     * A return can travel back by courier, not only by the shop's own rider.
     *
     * Same column names as `order_items` on purpose: `courier_agency` / `tracking_id` /
     * `tracking_url` for a courier someone tracks by hand, and `courier_provider` /
     * `courier_shipment_id` for a reverse parcel a plugin booked. One vocabulary means the
     * panel and the status writer read a return exactly as they read a forward parcel.
     *
     * No label column: a reverse pickup needs no label — the courier's own rider brings the
     * paperwork to the customer's door, and the shop has no box to stick anything on.
     */
    private function returnRequestCourierColumns(): void
    {
        $this->addColumns('return_requests', [
            'courier_agency'      => fn (Blueprint $t) => $t->string('courier_agency', 191)->nullable()
                ->after('delivery_boy_id'),
            'tracking_id'         => fn (Blueprint $t) => $t->string('tracking_id', 191)->nullable()
                ->after('courier_agency'),
            'tracking_url'        => fn (Blueprint $t) => $t->string('tracking_url', 500)->nullable()
                ->after('tracking_id'),
            'courier_provider'    => fn (Blueprint $t) => $t->string('courier_provider', 64)->nullable()
                ->after('tracking_url'),
            'courier_shipment_id' => fn (Blueprint $t) => $t->string('courier_shipment_id', 64)->nullable()
                ->after('courier_provider'),
            'courier_order_id'    => fn (Blueprint $t) => $t->string('courier_order_id', 64)->nullable()
                ->after('courier_shipment_id')->index(),
            'courier_exception'   => fn (Blueprint $t) => $t->string('courier_exception', 191)->nullable()
                ->after('courier_order_id'),
            'pickup_pincode'      => fn (Blueprint $t) => $t->string('pickup_pincode', 16)->nullable()
                ->after('address_id'),
        ]);

        if (!Schema::hasColumn('return_requests', 'pickup_pincode')) {
            return;
        }

        DB::table('return_requests')->whereNull('pickup_pincode')
            ->select('id', 'order_id', 'address_id', 'address')
            ->chunkById(500, function ($requests) {
                foreach ($requests as $request) {
                    $snapshot = json_decode((string) $request->address, true);
                    $pincode = trim((string) ($snapshot['pincode'] ?? ''));

                    if ($pincode === '') {
                        $pincode = trim((string) DB::table('orders')
                            ->where('id', $request->order_id)->value('delivery_pincode'));
                    }
                    if ($pincode === '' && $request->address_id) {
                        $pincode = trim((string) DB::table('user_addresses')
                            ->where('id', $request->address_id)->value('pincode'));
                    }
                    if ($pincode !== '') {
                        DB::table('return_requests')->where('id', $request->id)
                            ->update(['pickup_pincode' => mb_substr($pincode, 0, 16)]);
                    }
                }
            });
    }

    /** Add only the columns that are missing, so the release can be re-applied. */
    private function deliveryBoyLookupIndexes(): void
    {
        $wanted = [
            'order_items'                   => ['delivery_boy_id'],
            'delivery_boy_cash_collections' => ['delivery_boy_id'],
            'delivery_boy_settlements'      => ['delivery_boy_id'],
            'return_requests'               => ['delivery_boy_id'],
            // Withdrawals are keyed by an owner type plus its id, so the pair is the key.
            'withdrawal_requests'           => ['type', 'type_id'],
        ];

        foreach ($wanted as $table => $columns) {
            if (!Schema::hasTable($table)) {
                continue;
            }

            foreach ($columns as $column) {
                if (!Schema::hasColumn($table, $column)) {
                    continue 2;
                }
            }

            // Re-running the release must not fail on an index that is already there.
            if ($this->hasIndex($table, $columns[0])) {
                continue;
            }

            Schema::table($table, function (Blueprint $t) use ($columns) {
                $t->index($columns);
            });
        }
    }

    private function pluginPaymentIntentsTable(): void
    {
        if (Schema::hasTable('plugin_payment_intents')) {
            return;
        }

        Schema::create('plugin_payment_intents', function (Blueprint $t) {
            $t->id();
            $t->string('plugin_slug', 64);
            // Our own identifier: order-{id}-{user} or wallet-{stamp}-{user}-c{country}.
            $t->string('reference', 191)->unique();
            // Theirs. Nullable because the row is written before the gateway answers.
            $t->string('gateway_payment_id', 191)->nullable();
            $t->decimal('amount', 20, 6)->default(0);
            $t->string('currency', 8)->nullable();
            $t->unsignedBigInteger('user_id')->nullable();
            $t->unsignedBigInteger('country_id')->nullable();
            $t->string('purpose', 16)->default('order');
            $t->string('status', 16)->default('pending');
            $t->timestamps();

            $t->index(['plugin_slug', 'status']);
            $t->index('gateway_payment_id');
        });
    }

    /**
     * The channel the admin picked on the bulk upload screen.
     *
     * It used to live only in the browser: the picker narrowed the store list and was
     * then thrown away, so the import derived a product's sales_channel purely from the
     * selected stores' fulfillment_type. Where every store serves both channels that
     * always resolved to 'both', and an admin uploading a Quick-only catalogue silently
     * got products listed on ecommerce too. The pick has to survive to the queue worker,
     * so it is parked on the import row next to the other choices it belongs with.
     */

    /**
     * A shipping plugin's credentials.
     *
     * Payment plugins read theirs from the country they are charging in, because a shop
     * selling through two countries uses two merchant accounts. A courier account is not
     * like that — it is one contract with one carrier — so these are global, and stored
     * in the same generic columns the shared plugin format defines for payment. A plugin
     * written for another CakeZake product therefore reads `$config->secret_key` here and
     * there alike, which is the whole point of the format.
     */
    private function shippingConfigurationsTable(): void
    {
        if (Schema::hasTable('shipping_configurations')) {
            return;
        }

        Schema::create('shipping_configurations', function (Blueprint $t) {
            $t->id();
            // The plugin slug, so a row is found without knowing the carrier.
            $t->string('provider', 64)->unique();
            $t->text('api_key')->nullable();
            $t->text('secret_key')->nullable();
            $t->text('webhook_secret_key')->nullable();
            $t->string('additional_data_1', 191)->nullable();
            $t->string('additional_data_2', 191)->nullable();
            $t->string('payment_mode', 32)->nullable();   // sandbox | live
            $t->string('username', 191)->nullable();
            $t->text('password')->nullable();
            $t->string('currency_code', 8)->nullable();
            $t->boolean('status')->default(0);
            $t->json('extra')->nullable();                // settings the format has no column for
            $t->timestamps();
        });
    }

    private function productBulkImportChannel(): void
    {
        $this->addColumns('product_bulk_imports', [
            'sales_channel' => fn (Blueprint $t) => $t->string('sales_channel', 20)->nullable()->after('store_ids'),
        ]);
    }

    /** Whether any index on the table leads with this column. */
    private function hasIndex(string $table, string $column): bool
    {
        try {
            foreach (DB::select('SHOW INDEX FROM `' . str_replace('`', '', $table) . '`') as $row) {
                if ((int) ($row->Seq_in_index ?? 1) === 1 && ($row->Column_name ?? '') === $column) {
                    return true;
                }
            }
        } catch (\Throwable) {
            // Cannot tell: leave the index alone rather than risk a duplicate.
            return true;
        }

        return false;
    }

    private function addColumns(string $table, array $map): void
    {
        if (!Schema::hasTable($table)) {
            return;
        }
        $missing = array_filter($map, fn ($_, $name) => !Schema::hasColumn($table, $name), ARRAY_FILTER_USE_BOTH);
        if (empty($missing)) {
            return;
        }
        Schema::table($table, function (Blueprint $t) use ($missing) {
            foreach ($missing as $definition) {
                $definition($t);
            }
        });
    }

    /** Drop only the columns that are actually present, so down() re-runs cleanly. */
    private function dropColumns(string $table, array $columns): void
    {
        if (!Schema::hasTable($table)) {
            return;
        }
        $present = array_values(array_filter($columns, fn ($c) => Schema::hasColumn($table, $c)));
        if ($present) {
            Schema::table($table, fn (Blueprint $t) => $t->dropColumn($present));
        }
    }

    /**
     * The half-finished login, parked on the admin's own row.
     *
     * An admin can only be mid-login once — a second attempt replaces the first, or the
     * older code would still open the door — so the challenge is state of the user, not
     * a collection. Keeping it here also means deleting an admin disposes of it.
     */
    private function twoFactorColumns(): void
    {
        if (!Schema::hasTable('admins') || Schema::hasColumn('admins', 'two_factor_token')) {
            return;
        }

        Schema::table('admins', function (Blueprint $t) {
            // Grouped after `status` so the login columns sit with the rest of the
            // account's own state rather than trailing the timestamps.
            $t->after('status', function (Blueprint $t) {
                /* The ticket handed to the browser, stored as a sha256: a leaked database
                   must not hand anyone a half-finished login. */
                $t->string('two_factor_token', 64)->nullable()->unique();

                // Hashed the same way a password is, so the 6 digits are never readable.
                $t->string('two_factor_code')->nullable();

                $t->unsignedTinyInteger('two_factor_attempts')->default(0);
                $t->unsignedTinyInteger('two_factor_sends')->default(0);
                $t->timestamp('two_factor_sent_at')->nullable();
                $t->timestamp('two_factor_expires_at')->nullable();
            });
        });
    }

    private function twoFactorSettings(): void
    {
        $defaults = [
            'panel_two_factor' => '0',
            'panel_two_factor_store_users' => '1',
            'panel_two_factor_expiry' => '10',
        ];

        foreach ($defaults as $variable => $value) {
            if (!DB::table('settings')->where('variable', $variable)->exists()) {
                DB::table('settings')->insert(['variable' => $variable, 'value' => $value]);
            }
        }
    }

    private function twoFactorEmailTemplate(): void
    {
        $template = [
            'type' => 'two_factor_code_admin',
            'title' => '{{app_name}} - Your login code',
            'message' => "Hi {{username}},\n\nYour login verification code is: {{code}}\n\n"
                . "It expires in {{expiry_minutes}} minutes and can be used once.\n\n"
                . "If you did not try to sign in, change your password — someone else knows it.\n\n{{app_name}}",
            'placeholders' => json_encode(['username', 'code', 'expiry_minutes', 'app_name']),
        ];

        DB::table('email_templates')->updateOrInsert(
            ['type' => $template['type']],
            [
                'title' => $template['title'],
                'message' => $template['message'],
                'placeholders' => $template['placeholders'],
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );

        $templateId = DB::table('email_templates')->where('type', $template['type'])->value('id');
        $defaultLangId = DB::table('languages')->where('is_default', 1)->value('id')
            ?: DB::table('languages')->orderBy('id')->value('id');

        if ($templateId && $defaultLangId) {
            DB::table('email_template_translations')->updateOrInsert(
                ['email_template_id' => $templateId, 'language_id' => $defaultLangId],
                [
                    'title' => $template['title'],
                    'message' => $template['message'],
                    'created_at' => now(),
                    'updated_at' => now(),
                ]
            );
        }
    }

    private function dropEmailTemplate(string $type): void
    {
        if (!Schema::hasTable('email_templates')) {
            return;
        }

        $id = DB::table('email_templates')->where('type', $type)->value('id');
        if (!$id) {
            return;
        }

        if (Schema::hasTable('email_template_translations')) {
            DB::table('email_template_translations')->where('email_template_id', $id)->delete();
        }
        DB::table('email_templates')->where('id', $id)->delete();
    }

};
