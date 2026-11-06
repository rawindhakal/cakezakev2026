<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

/**
 * Release 1.3.0 — Spin Wheel rewards + Page Builder.
 *
 * A campaign owns wheel segments; a segment's money differs per country, so amounts live
 * in a child table keyed by (segment, country). A win either credits the wallet or issues
 * a promo code generated for that one customer, which is why `promo_codes` gains a
 * `source` marker — the coupon screen hides machine-issued codes behind a toggle.
 *
 * Every step is guarded so a half-finished run can be repeated safely.
 */
return new class extends Migration
{
    public function up(): void
    {
        $this->spinWheelTables();
        $this->campaignScheduleColumn();
        $this->faqSortOrderColumn();
        $this->promoCodeSourceColumns();
        $this->promoCodeIndexes();
        $this->pageLayoutsTable();
        $this->splitAppVersionSettings();
        $this->stockAlertsTable();
        $this->seedBackInStockNotification();
        $this->orderDeliveryTypeColumn();
        $this->storePickupColumns();
        $this->zoneAdditionalChargeAppliesTo();
        $this->addStorePlaceholdersToOrderTemplates();
        $this->syncPermissions();
    }

    private function syncPermissions(): void
    {
        if (!Schema::hasTable('permissions') || !Schema::hasTable('permission_categories') || !Schema::hasTable('roles')) {
            return;
        }
        if (!DB::table('permission_categories')->exists()) {
            return; // fresh install — the seeder owns this
        }

        $admin = ['Super Admin', 'Admin'];
        $groups = [
            ['category' => 'spin_wheel',   'roles' => $admin, 'names' => ['spin_wheel_list', 'spin_wheel_create', 'spin_wheel_update', 'spin_wheel_delete']],
            ['category' => 'page_builder', 'roles' => $admin, 'names' => ['page_builder_list', 'page_builder_create', 'page_builder_update', 'page_builder_delete', 'page_builder_publish']],
            // Pickup orders never reach riders, so the Delivery Boy role is left out.
            ['category' => 'order',        'except' => ['Delivery Boy'], 'names' => [
                'self_pickup_order_list'   => 'order_list',
                'self_pickup_order_update' => 'order_update',
                'self_pickup_order_delete' => 'order_delete',
            ]],
            // Whoever may see customers' wishlists may see what they are waiting to buy.
            ['category' => 'customer',     'names' => ['manage_stock_alerts' => 'manage_wishlists']],
        ];

        $roleId = fn (array $names) => DB::table('roles')->whereIn('name', $names)->pluck('id');

        foreach ($groups as $group) {
            $categoryId = DB::table('permission_categories')->where('name', $group['category'])->value('id');
            if (!$categoryId) {
                $categoryId = DB::table('permission_categories')->insertGetId([
                    'name'       => $group['category'],
                    'guard_name' => 'web',
                ]);
            }
            $excluded = $roleId($group['except'] ?? [])->map(fn ($id) => (int) $id)->all();

            foreach ($group['names'] as $key => $value) {
                // list form: value is the name; map form: key is the name, value the permission to mirror
                [$name, $mirror] = is_int($key) ? [$value, null] : [$key, $value];

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

                $sourceId = $mirror ? DB::table('permissions')->where('name', $mirror)->value('id') : null;
                $roleIds = $sourceId
                    ? DB::table('role_has_permissions')->where('permission_id', $sourceId)->pluck('role_id')
                    : $roleId($group['roles'] ?? $admin);

                foreach ($roleIds as $rid) {
                    if (in_array((int) $rid, $excluded, true)) {
                        continue;
                    }
                    DB::table('role_has_permissions')->updateOrInsert(
                        ['permission_id' => $id, 'role_id' => $rid],
                        ['permission_id' => $id, 'role_id' => $rid]
                    );
                }
            }
        }
    }

    // -------------------------------------------------------------- self pickup

    /**
     * How the order reaches the customer: delivered to them, or collected at the store.
     *
     * Every existing order is a delivery, so the default is the whole backfill. Indexed
     * with the status because the "Self Pickup" page lists by both.
     */
    private function orderDeliveryTypeColumn(): void
    {
        $this->addColumns('orders', [
            'delivery_type' => fn (Blueprint $t) => $t->enum('delivery_type', ['delivery', 'pickup'])
                ->default('delivery')->after('channel')->comment('delivery | pickup'),
        ]);

        if (Schema::hasTable('orders') && !$this->hasIndex('orders', 'orders_delivery_type_status_index')) {
            Schema::table('orders', fn (Blueprint $t) => $t->index(['delivery_type', 'active_status'], 'orders_delivery_type_status_index'));
        }
    }

    /**
     * What a store offers: home delivery, self pickup, or both — and, for a store serving
     * both sales channels, on which of them pickup is available. Defaults reproduce
     * today's behaviour (delivery only).
     */
    private function storePickupColumns(): void
    {
        $this->addColumns('stores', [
            'service_modes'   => fn (Blueprint $t) => $t->enum('service_modes', ['delivery', 'pickup', 'both'])
                ->default('delivery')->after('fulfillment_type')->comment('delivery | pickup | both'),
            'pickup_channels' => fn (Blueprint $t) => $t->enum('pickup_channels', ['quick', 'ecommerce', 'both'])
                ->default('both')->after('service_modes')->comment('channels on which self pickup is offered'),
        ]);
    }

    /**
     * Each zone additional charge now says whether it applies to delivery, pickup or both.
     *
     * Existing rows are made explicit as `delivery` — a bag fee or handling charge set up
     * for deliveries must not start appearing on pickup orders by surprise. Code treats a
     * missing key the same way, so this is only about what the panel shows.
     */
    private function zoneAdditionalChargeAppliesTo(): void
    {
        if (!Schema::hasTable('zones')) {
            return;
        }

        foreach (['additional_charges_quick', 'additional_charges_ecommerce'] as $column) {
            if (!Schema::hasColumn('zones', $column)) {
                continue;
            }
            DB::table('zones')->select('id', $column)->whereNotNull($column)->orderBy('id')
                ->chunk(200, function ($zones) use ($column) {
                    foreach ($zones as $zone) {
                        $rows = json_decode($zone->{$column}, true);
                        if (!is_array($rows) || empty($rows)) {
                            continue;
                        }
                        $changed = false;
                        foreach ($rows as &$row) {
                            if (is_array($row) && !array_key_exists('applies_to', $row)) {
                                $row['applies_to'] = 'delivery';
                                $changed = true;
                            }
                        }
                        unset($row);
                        if ($changed) {
                            DB::table('zones')->where('id', $zone->id)->update([$column => json_encode($rows)]);
                        }
                    }
                });
        }
    }

    /**
     * Customer order-status templates can now mention the store — the one thing a pickup
     * notification has to say. The panel lists a template's own placeholders, so the
     * stored rows are extended, not just the catalog.
     */
    private function addStorePlaceholdersToOrderTemplates(): void
    {
        foreach (['notification_templates', 'email_templates', 'sms_templates'] as $table) {
            if (!Schema::hasTable($table) || !Schema::hasColumn($table, 'placeholders')) {
                continue;
            }
            $rows = DB::table($table)->select('id', 'placeholders')
                ->where('type', 'like', 'order_status_%_customer')
                ->get();
            foreach ($rows as $row) {
                $list = json_decode($row->placeholders ?? '[]', true);
                if (!is_array($list)) {
                    $list = [];
                }
                $before = count($list);
                foreach (['store_name', 'store_address'] as $key) {
                    if (!in_array($key, $list, true)) {
                        $list[] = $key;
                    }
                }
                if (count($list) !== $before) {
                    DB::table($table)->where('id', $row->id)->update(['placeholders' => json_encode(array_values($list))]);
                }
            }
        }
    }

    // ------------------------------------------------------------ back in stock

    private const BACK_IN_STOCK_EVENT = 'back_in_stock';
    private const BACK_IN_STOCK_TYPE = 'back_in_stock_customer';
    private const BACK_IN_STOCK_PLACEHOLDERS = [
        'app_name', 'customer_name', 'product_name', 'variant_name', 'price', 'currency',
    ];

    private function stockAlertsTable(): void
    {
        if (Schema::hasTable('product_stock_alerts')) {
            return;
        }

        Schema::create('product_stock_alerts', function (Blueprint $t) {
            $t->id();
            $t->unsignedBigInteger('user_id')->index();
            $t->unsignedBigInteger('product_id')->index();
            $t->unsignedBigInteger('product_variant_id');
            $t->unsignedBigInteger('country_id')->nullable();
            $t->unsignedBigInteger('zone_id')->nullable()->index();
            $t->tinyInteger('status')->default(1)->comment('1-waiting, 2-notified, 0-cancelled');
            $t->timestamp('notified_at')->nullable();
            $t->timestamps();
            $t->unique(['user_id', 'product_variant_id'], 'psa_user_variant_unique');
            $t->index(['product_variant_id', 'status'], 'psa_variant_status_index');
        });
    }

    private function seedBackInStockNotification(): void
    {
        $ph = json_encode(self::BACK_IN_STOCK_PLACEHOLDERS);
        $now = now();

        $rows = [
            'notification_templates' => [
                'title'   => '{{product_name}} is back in stock!',
                'message' => '{{product_name}} ({{variant_name}}) is available again at {{currency}}{{price}}. Grab it before it sells out.',
            ],
            'email_templates' => [
                'title'   => '{{product_name}} is back in stock',
                'message' => "Hi {{customer_name}},\n\nGood news — {{product_name}} ({{variant_name}}) you asked us about is back in stock at {{currency}}{{price}}.\n\nOrder now before it sells out again.\n\n{{app_name}}",
            ],
            'sms_templates' => [
                'message' => '{{product_name}} ({{variant_name}}) is back in stock at {{currency}}{{price}}. Order now! - {{app_name}}',
            ],
        ];

        foreach ($rows as $table => $copy) {
            if (!Schema::hasTable($table)) {
                continue;
            }
            if (DB::table($table)->where('type', self::BACK_IN_STOCK_TYPE)->exists()) {
                continue;
            }
            DB::table($table)->insert(array_merge($copy, [
                'type'         => self::BACK_IN_STOCK_TYPE,
                'audience'     => 'customer',
                'category'     => 'Products',
                'placeholders' => $ph,
                'created_at'   => $now,
                'updated_at'   => $now,
            ]));
        }

        if (Schema::hasTable('notification_admin_settings')) {
            foreach (['mail' => 1, 'push' => 1, 'sms' => 0] as $channel => $enabled) {
                $exists = DB::table('notification_admin_settings')
                    ->where('event_key', self::BACK_IN_STOCK_EVENT)
                    ->where('audience', 'customer')
                    ->where('channel', $channel)
                    ->exists();
                if (!$exists) {
                    DB::table('notification_admin_settings')->insert([
                        'event_key'  => self::BACK_IN_STOCK_EVENT,
                        'audience'   => 'customer',
                        'channel'    => $channel,
                        'is_enabled' => $enabled,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                }
            }
        }
    }

    // ------------------------------------------------------------------ tables

    private function spinWheelTables(): void
    {
        if (!Schema::hasTable('spin_wheel_campaigns')) {
            Schema::create('spin_wheel_campaigns', function (Blueprint $t) {
                $t->id();
                // Default-language copies; every language lives in the translations table.
                $t->string('name')->nullable();
                // Prefix of the generated coupon, e.g. DIWALI -> DIWALI7K2QD9AB.
                $t->string('code_prefix', 16)->default('SPIN');
                // Off by default: a half-built wheel must never be live.
                $t->tinyInteger('status')->default(0)->comment('1-active, 0-inactive');
                // Schedule the campaign instead of switching it on by hand: at its start time
                // the scheduler activates it and switches off whatever was running.
                $t->tinyInteger('is_scheduled')->default(0)->comment('1-activate on start_date');
                // Datetime, not date: a campaign is scheduled to the minute.
                $t->dateTime('start_date')->nullable();
                $t->dateTime('end_date')->nullable();
                $t->unsignedInteger('spins_per_day')->default(1);
                $t->unsignedInteger('max_spins_per_user')->default(0)->comment('0 = unlimited');
                $t->unsignedInteger('min_delivered_orders')->default(0)->comment('0 = anyone may spin');
                // {use_brand_theme, wheel_bg, pointer_color, text_color, border_color}
                $t->json('theme')->nullable();
                $t->timestamps();
            });
        }

        if (!Schema::hasTable('spin_wheel_campaign_translations')) {
            Schema::create('spin_wheel_campaign_translations', function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger('spin_wheel_campaign_id')->index();
                $t->unsignedBigInteger('language_id')->index();
                $t->string('name')->nullable();
                $t->timestamps();
                $t->unique(['spin_wheel_campaign_id', 'language_id'], 'swct_campaign_language_unique');
            });
        }

        if (!Schema::hasTable('spin_wheel_segments')) {
            Schema::create('spin_wheel_segments', function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger('spin_wheel_campaign_id')->index();
                $t->string('label')->nullable();
                $t->enum('type', ['promo_code', 'wallet', 'free_delivery', 'no_luck']);
                // Odds. Every segment of a campaign must add up to exactly 100.
                $t->decimal('win_chance', 5, 2)->default(0);
                $t->unsignedInteger('winner_limit')->default(0)->comment('0 = unlimited');
                $t->unsignedInteger('wins_count')->default(0);
                $t->string('color', 32)->nullable();
                $t->string('text_color', 32)->nullable();
                $t->string('icon')->nullable();
                $t->enum('display_mode', ['name', 'icon', 'both'])->default('both');
                $t->integer('sort_order')->default(0);
                // Reward config. Flat money is per country (see spin_wheel_segment_amounts);
                // a percentage is the same number everywhere, so it sits here.
                $t->enum('discount_type', ['percentage', 'flat'])->nullable();
                // instant = off the bill now; wallet = cashback credited after delivery.
                $t->enum('discount_apply_type', ['instant', 'wallet'])->default('instant');
                $t->decimal('discount_value', 10, 2)->default(0);
                $t->unsignedInteger('validity_days')->default(7);
                $t->enum('applicability', ['all', 'categories', 'products', 'brands'])->default('all');
                $t->json('applicability_ids')->nullable();
                $t->tinyInteger('status')->default(1);
                $t->timestamps();
            });
        }

        if (!Schema::hasTable('spin_wheel_segment_translations')) {
            Schema::create('spin_wheel_segment_translations', function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger('spin_wheel_segment_id')->index();
                $t->unsignedBigInteger('language_id')->index();
                $t->string('label')->nullable();
                $t->timestamps();
                $t->unique(['spin_wheel_segment_id', 'language_id'], 'swst_segment_language_unique');
            });
        }

        if (!Schema::hasTable('spin_wheel_segment_amounts')) {
            Schema::create('spin_wheel_segment_amounts', function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger('spin_wheel_segment_id')->index();
                $t->unsignedBigInteger('country_id')->index();
                // Wallet credit, or the flat discount value.
                $t->decimal('amount', 14, 2)->default(0);
                $t->decimal('max_discount_amount', 14, 2)->default(0);
                $t->decimal('minimum_order_amount', 14, 2)->default(0);
                $t->timestamps();
                // No row for a country = that segment is not offered there.
                $t->unique(['spin_wheel_segment_id', 'country_id'], 'swsa_segment_country_unique');
            });
        }

        if (!Schema::hasTable('spin_wheel_spins')) {
            Schema::create('spin_wheel_spins', function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger('spin_wheel_campaign_id')->index();
                $t->unsignedBigInteger('spin_wheel_segment_id')->nullable()->index();
                $t->unsignedBigInteger('user_id')->index();
                // Stamped so the admin report answers to the panel's country filter.
                $t->unsignedBigInteger('country_id')->nullable()->index();
                $t->unsignedBigInteger('zone_id')->nullable();
                $t->enum('result', ['win', 'no_luck'])->default('no_luck');
                $t->enum('reward_type', ['promo_code', 'wallet', 'free_delivery', 'no_luck'])->default('no_luck');
                $t->decimal('amount', 14, 2)->default(0);
                $t->string('currency')->nullable();
                $t->string('currency_code')->nullable();
                $t->unsignedBigInteger('promo_code_id')->nullable()->index();
                $t->unsignedBigInteger('wallet_transaction_id')->nullable();
                // Client-supplied per-gesture id: a retried request returns the first
                // result instead of handing out a second prize.
                $t->string('request_token', 64)->nullable();
                $t->dateTime('spun_at')->useCurrent();
                $t->timestamps();
                $t->index(['user_id', 'spun_at'], 'sws_user_spun_index');
                $t->index(['spin_wheel_campaign_id', 'spun_at'], 'sws_campaign_spun_index');
                $t->unique(['spin_wheel_campaign_id', 'user_id', 'request_token'], 'sws_campaign_user_token_unique');
            });
        }
    }

    // ------------------------------------------------------------ promo codes

    private function campaignScheduleColumn(): void
    {
        $this->addColumns('spin_wheel_campaigns', [
            'is_scheduled' => fn (Blueprint $t) => $t->tinyInteger('is_scheduled')
                ->default(0)->after('status')->comment('1-activate on start_date'),
        ]);
        // Same for installs that created the segments table before this column existed.12
        $this->addColumns('spin_wheel_segments', [
            'discount_apply_type' => fn (Blueprint $t) => $t->enum('discount_apply_type', ['instant', 'wallet'])
                ->default('instant')->after('discount_type'),
        ]);
    }

    /** FAQs are shown in the order the admin drags them into; existing rows keep their id order. */
    private function faqSortOrderColumn(): void
    {
        if (!Schema::hasTable('faqs') || Schema::hasColumn('faqs', 'sort_order')) {
            return;
        }
        $this->addColumns('faqs', [
            'sort_order' => fn (Blueprint $t) => $t->unsignedInteger('sort_order')->default(0)->after('answer'),
        ]);
        DB::statement('UPDATE faqs SET sort_order = id');
    }

    private function promoCodeSourceColumns(): void
    {
        $this->addColumns('promo_codes', [
            // Where the coupon came from. Spin-issued ones are hidden from the coupon
            // list by default — one row per win would otherwise bury the real coupons.
            'source' => fn (Blueprint $t) => $t->enum('source', ['manual', 'spin_wheel'])
                ->default('manual')->after('status'),
            'source_id' => fn (Blueprint $t) => $t->unsignedBigInteger('source_id')
                ->nullable()->after('source')->comment('spin_wheel_segments.id'),
        ]);

        // Rows that existed before this release are all hand-made.
        if (Schema::hasColumn('promo_codes', 'source')) {
            DB::table('promo_codes')->whereNull('source')->update(['source' => 'manual']);
        }
    }

    private function promoCodeIndexes(): void
    {
        if (!Schema::hasTable('promo_codes')) {
            return;
        }

        if (!$this->hasIndex('promo_codes', 'promo_codes_source_index')) {
            Schema::table('promo_codes', fn (Blueprint $t) => $t->index(['source', 'source_id'], 'promo_codes_source_index'));
        }

        // getCartPromoNudge() and the customer coupon list both scan on exactly these.
        if (!$this->hasIndex('promo_codes', 'promo_codes_listing_index')) {
            Schema::table('promo_codes', fn (Blueprint $t) => $t->index(['status', 'visibility', 'end_date'], 'promo_codes_listing_index'));
        }

        // The code was never unique, and every lookup takes the FIRST match — so a
        // generated code colliding with an existing one would resolve to the wrong row.
        // Existing duplicates would fail the index, so leave them be and say so.
        if (!$this->hasIndex('promo_codes', 'promo_codes_promo_code_unique')) {
            $duplicates = DB::table('promo_codes')
                ->select('promo_code')
                ->groupBy('promo_code')
                ->havingRaw('COUNT(*) > 1')
                ->pluck('promo_code');

            if ($duplicates->isNotEmpty()) {
                Log::warning('1.3.0: promo_code left non-unique, duplicates present: ' . $duplicates->implode(', '));
            } else {
                Schema::table('promo_codes', fn (Blueprint $t) => $t->unique('promo_code', 'promo_codes_promo_code_unique'));
            }
        }
    }

    // ----------------------------------------------------------- page builder

    /**
     * Standalone pages built with the Home Builder's section system. A page is global
     * (no zone / channel); product blocks resolve against the customer's zone when the
     * page is served. Home Builder banners redirect to a page by id.
     */
    private function pageLayoutsTable(): void
    {
        if (Schema::hasTable('page_layouts')) {
            return;
        }
        Schema::create('page_layouts', function (Blueprint $t) {
            $t->id();
            // Admin label — shown in the list and the redirect picker.
            $t->string('name', 191);
            // URL handle the web app opens the page by (/page/{slug}).
            $t->string('slug', 191)->unique();
            // {langId: text} — the title the app shows above the page.
            $t->json('title')->nullable();
            // NULL = admin page; a store user's pages belong to its store.
            $t->unsignedBigInteger('store_id')->nullable()->index();
            $t->enum('status', ['draft', 'published'])->default('draft');
            $t->boolean('is_active')->default(1);
            // {sections: [...]} — same shape as home_layouts.draft_json.
            $t->json('draft_json')->nullable();
            $t->json('published_json')->nullable();
            $t->timestamp('published_at')->nullable();
            $t->timestamps();
            $t->index(['status', 'is_active'], 'page_layouts_resolution_idx');
        });
    }


    /**
     * App version control used to be one set of settings shared by the customer and
     * delivery boy apps. Each app now has its own (`_customer` / `_delivery_boy`),
     * seeded from the shared values so nothing changes until an admin edits them.
     */
    private function splitAppVersionSettings(): void
    {
        if (!Schema::hasTable('settings')) {
            return;
        }
        $shared = ['is_version_system_on', 'required_force_update', 'current_version',
                   'ios_is_version_system_on', 'ios_required_force_update', 'ios_current_version'];
        $old = DB::table('settings')->whereIn('variable', $shared)->pluck('value', 'variable');
        foreach ($shared as $key) {
            foreach (['customer', 'delivery_boy'] as $app) {
                $new = $key . '_' . $app;
                if (DB::table('settings')->where('variable', $new)->exists()) {
                    continue;
                }
                DB::table('settings')->insert([
                    'variable' => $new,
                    'value'    => $old[$key] ?? (str_contains($key, 'current_version') ? '1.0.0' : '0'),
                ]);
            }
        }
        DB::table('settings')->whereIn('variable', $shared)->delete();
    }

    // ---------------------------------------------------------------- helpers

    /**
     * Add only the columns that are still missing, so the migration re-runs cleanly
     * even after an interrupted run. $map is column name => closure(Blueprint).
     */
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

    private function hasIndex(string $table, string $index): bool
    {
        try {
            return collect(DB::select("SHOW INDEX FROM `{$table}`"))
                ->contains(fn ($i) => $i->Key_name === $index);
        } catch (\Throwable) {
            return false;
        }
    }

    /**
     * Roll the release back.
     *
     * Issued coupons and credited wallet transactions are deliberately left alone — they
     * are money a customer already holds, not part of this schema.
     */
    public function down(): void
    {
        if (Schema::hasTable('permissions')) {
            $ids = DB::table('permissions')
                ->whereIn('name', [
                    'spin_wheel_list', 'spin_wheel_create', 'spin_wheel_update', 'spin_wheel_delete',
                    'page_builder_list', 'page_builder_create', 'page_builder_update', 'page_builder_delete', 'page_builder_publish',
                    'self_pickup_order_list', 'self_pickup_order_update', 'self_pickup_order_delete',
                    'manage_stock_alerts',
                ])
                ->pluck('id');
            if ($ids->isNotEmpty()) {
                foreach (['role_has_permissions', 'model_has_permissions'] as $pivot) {
                    if (Schema::hasTable($pivot)) {
                        DB::table($pivot)->whereIn('permission_id', $ids)->delete();
                    }
                }
                DB::table('permissions')->whereIn('id', $ids)->delete();
            }
            if (Schema::hasTable('permission_categories')) {
                DB::table('permission_categories')->whereIn('name', ['spin_wheel', 'page_builder'])->delete();
            }
        }

        foreach (['promo_codes_source_index', 'promo_codes_listing_index', 'promo_codes_promo_code_unique'] as $index) {
            if ($this->hasIndex('promo_codes', $index)) {
                Schema::table('promo_codes', fn (Blueprint $t) => $t->dropIndex($index));
            }
        }
        $this->dropColumns('promo_codes', ['source', 'source_id']);

        if (Schema::hasTable('orders') && $this->hasIndex('orders', 'orders_delivery_type_status_index')) {
            Schema::table('orders', fn (Blueprint $t) => $t->dropIndex('orders_delivery_type_status_index'));
        }
        $this->dropColumns('orders', ['delivery_type']);
        $this->dropColumns('stores', ['service_modes', 'pickup_channels']);

        // Children first.
        foreach ([
            'spin_wheel_segment_amounts',
            'spin_wheel_segment_translations',
            'spin_wheel_segments',
            'spin_wheel_spins',
            'spin_wheel_campaign_translations',
            'spin_wheel_campaigns',
            'page_layouts',
            'product_stock_alerts',
        ] as $table) {
            Schema::dropIfExists($table);
        }

        foreach (['notification_templates', 'email_templates', 'sms_templates'] as $table) {
            if (Schema::hasTable($table)) {
                DB::table($table)->where('type', self::BACK_IN_STOCK_TYPE)->delete();
            }
        }
        if (Schema::hasTable('notification_admin_settings')) {
            DB::table('notification_admin_settings')->where('event_key', self::BACK_IN_STOCK_EVENT)->delete();
        }
    }
};
