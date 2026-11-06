<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

/**
 * Release 1.2.0.
 */
return new class extends Migration
{
    /** table => [columns] */
    private array $columns = [
        'delivery_boys'                 => ['balance', 'cash_received'],
        'delivery_boy_settlements'      => ['amount', 'opening_balance', 'closing_balance'],
        'delivery_boy_cash_collections' => ['amount'],
        'withdrawal_requests'           => ['amount'],
    ];

    public function up(): void
    {
        $this->moneyColumnsToDecimal();
        $this->geographyTables();
        $this->taxConfigTables();
        $this->orderSnapshotColumns();
        $this->zoneChargeColumns();
        $this->seedRegions();
        $this->backfillRegionLinks();
        $this->backfillTaxConfig();
        $this->backfillOrderSnapshots();
        $this->dropLegacyTaxSystem();
    }

    private function dropLegacyTaxSystem(): void
    {
        // Never drop the old system unless the new one actually holds data, or a
        // half-finished migration would leave every product untaxed.
        if (!Schema::hasTable('tax_categories') || DB::table('tax_categories')->doesntExist()) {
            Log::warning('version_1_2_0: legacy tax tables kept — no tax categories were created.');
            return;
        }

        if (Schema::hasColumn('products', 'tax_id')) {
            Schema::table('products', fn (Blueprint $t) => $t->dropColumn('tax_id'));
        }
        Schema::dropIfExists('tax_translations');
        Schema::dropIfExists('taxes');
    }

    // ---------------------------------------------------------------- money

    private function moneyColumnsToDecimal(): void
    {
        foreach ($this->columns as $table => $columns) {
            if (!Schema::hasTable($table)) {
                continue;
            }

            foreach ($columns as $column) {
                if (!Schema::hasColumn($table, $column)) {
                    continue;
                }
                DB::table($table)->whereNotNull($column)->update([
                    $column => DB::raw("ROUND(`{$column}`, 2)"),
                ]);
            }

            Schema::table($table, function (Blueprint $t) use ($table, $columns) {
                foreach ($columns as $column) {
                    if (Schema::hasColumn($table, $column)) {
                        $t->decimal($column, 14, 2)->default(0)->change();
                    }
                }
            });
        }
    }

    // ------------------------------------------------------------ geography

    private function geographyTables(): void
    {
        if (!Schema::hasTable('regions')) {
            Schema::create('regions', function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger('country_id')->index();
                $t->string('name');
                // ISO-3166-2 subdivision code ('IN-MH', 'AE-DU') — stable, universal.
                $t->string('code', 12)->nullable();
                // Jurisdiction tax code. India GST state code ('27'). Blank where the
                // concept doesn't exist. Data only — no code branches on it.
                $t->string('tax_code', 8)->nullable();
                $t->string('type', 24)->default('state');
                $t->tinyInteger('status')->default(1);
                $t->timestamps();
                $t->unique(['country_id', 'code']);
            });
        }

        if (!Schema::hasTable('region_translations')) {
            Schema::create('region_translations', function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger('region_id')->index();
                $t->unsignedBigInteger('language_id')->index();
                $t->string('name')->nullable();
                $t->timestamps();
                $t->unique(['region_id', 'language_id']);
            });
        }

        $this->addColumns('zones', [
            'region_id' => fn (Blueprint $t) => $t->unsignedBigInteger('region_id')->nullable()->index()->after('state'),
        ]);

        /* A store's region is simply its zone's region — one zone serves one store, so a
           separate store-level region was a second place for the same fact to live (and
           to drift). Tax identity moves onto the store row itself: one number per store,
           which needs no table of its own. */
        $this->addColumns('stores', [
            'tax_number'            => fn (Blueprint $t) => $t->string('tax_number', 32)->nullable()->after('email'),
            'tax_registration_type' => fn (Blueprint $t) => $t->string('tax_registration_type', 24)->nullable()->after('tax_number'),
        ]);

        $this->addColumns('user_addresses', [
            'region_id' => fn (Blueprint $t) => $t->unsignedBigInteger('region_id')->nullable()->index()->after('state'),
        ]);

        /* Whether a stored price already contains its tax. It lives beside the PRICE,
           not on the tax rule: prices are per variant per store, so one store can quote
           tax-inclusive while another quotes net for the same product. */
        $this->addColumns('product_variant_store_stocks', [
            'is_tax_inclusive' => fn (Blueprint $t) => $t->boolean('is_tax_inclusive')->default(0)->after('discounted_price'),
        ]);

        // `code` must be unique for the ISO lookups the tax engine relies on. Only add
        // the index when the data is already clean — never delete a referenced country.
        if (Schema::hasTable('countries') && !$this->hasIndex('countries', 'countries_code_unique')) {
            $dupes = DB::table('countries')
                ->selectRaw('UPPER(code) as c, COUNT(*) as n')
                ->groupBy('c')->havingRaw('COUNT(*) > 1')->pluck('c');
            if ($dupes->isEmpty()) {
                Schema::table('countries', fn (Blueprint $t) => $t->unique('code'));
            } else {
                Log::warning('version_1_2_0: countries.code unique index skipped, duplicates: ' . $dupes->implode(','));
            }
        }
    }

    // ----------------------------------------------------------- tax config

    private function taxConfigTables(): void
    {
        if (!Schema::hasTable('tax_categories')) {
            Schema::create('tax_categories', function (Blueprint $t) {
                $t->id();
                $t->string('name');
                $t->string('code', 32)->unique();
                $t->string('description')->nullable();
                $t->tinyInteger('status')->default(1);
                $t->timestamps();
            });
        }

        if (!Schema::hasTable('tax_rules')) {
            Schema::create('tax_rules', function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger('country_id')->index();
                // NULL = whole country. A region always refers to the STORE's location:
                // every jurisdiction this engine serves is origin-based.
                $t->unsignedBigInteger('region_id')->nullable()->index();
                $t->unsignedBigInteger('tax_category_id')->nullable()->index(); // NULL = all categories
                // any  = jurisdiction has no intra/inter distinction
                // intra/inter = store region vs customer region
                $t->enum('place_of_supply', ['any', 'intra', 'inter'])->default('any');
                $t->tinyInteger('status')->default(1);
                $t->timestamps();
                $t->index(['country_id', 'tax_category_id', 'status'], 'tax_rules_lookup_idx');
            });
        }

        if (!Schema::hasTable('tax_rule_components')) {
            Schema::create('tax_rule_components', function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger('tax_rule_id')->index();
                $t->string('name', 64); // CGST | SGST | UTGST | IGST | VAT | County Tax ...
                $t->decimal('rate', 8, 3)->default(0);
                $t->integer('sort_order')->default(0);
            });
        }

        $this->addColumns('products', [
            'tax_category_id' => fn (Blueprint $t) => $t->unsignedBigInteger('tax_category_id')->nullable()->index()->after('tax_id'),
        ]);

        // Dead flag: only ever echoed as a literal in the product payload, never read.
        // Tax inclusivity now lives on the PRICE row (pvss.is_tax_inclusive).
        if (Schema::hasColumn('products', 'tax_included_in_price')) {
            Schema::table('products', fn (Blueprint $t) => $t->dropColumn('tax_included_in_price'));
        }
    }

    // ------------------------------------------------------- order snapshot

    private function orderSnapshotColumns(): void
    {
        $this->addColumns('orders', [
            'buyer_region_id' => fn (Blueprint $t) => $t->unsignedBigInteger('buyer_region_id')->nullable()->index()->after('zone_id'),
            'place_of_supply' => fn (Blueprint $t) => $t->string('place_of_supply', 64)->nullable()->after('buyer_region_id'),
            'taxable_value'   => fn (Blueprint $t) => $t->decimal('taxable_value', 14, 2)->default(0)->after('tax_percentage'),
        ]);

        // `tax_total` is the LINE-TOTAL tax. `tax_amount` stays PER-UNIT — getOrderDetails()
        // and buildReturnItem() both depend on that meaning, so it is not repurposed.
        $this->addColumns('order_items', [
            'tax_total'         => fn (Blueprint $t) => $t->decimal('tax_total', 14, 2)->nullable()->after('tax_percentage'),
            'taxable_value'     => fn (Blueprint $t) => $t->decimal('taxable_value', 14, 2)->nullable()->after('tax_total'),
            'seller_region_id'  => fn (Blueprint $t) => $t->unsignedBigInteger('seller_region_id')->nullable()->after('store_id'),
            'seller_tax_number' => fn (Blueprint $t) => $t->string('seller_tax_number', 32)->nullable()->after('store_id'),
            'supply_type'       => fn (Blueprint $t) => $t->enum('supply_type', ['intra', 'inter', 'none'])->nullable()->after('store_id'),
            'refund_tax_amount' => fn (Blueprint $t) => $t->decimal('refund_tax_amount', 14, 2)->default(0)->after('refund_amount'),
            // Whether the stored `price` already contained its tax. Without this, the
            // order-history screens can't tell a gross price from a net one and would
            // re-add tax that is already inside it.
            'is_tax_inclusive'  => fn (Blueprint $t) => $t->boolean('is_tax_inclusive')->default(0)->after('tax_percentage'),
        ]);

        if (!Schema::hasTable('order_item_taxes')) {
            Schema::create('order_item_taxes', function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger('order_id')->index();
                // NULL = an order-level charge tax (quick-channel surge/additional/delivery)
                $t->unsignedBigInteger('order_item_id')->nullable()->index();
                $t->unsignedBigInteger('tax_rule_id')->nullable();
                $t->string('component_name', 64);
                $t->decimal('rate', 8, 3)->default(0);
                $t->decimal('taxable_value', 14, 2)->default(0);
                $t->decimal('amount', 14, 2)->default(0);
                $t->enum('source', ['item', 'delivery', 'surge', 'additional'])->default('item');
                $t->string('source_ref', 191)->nullable();
                $t->string('hsn_code', 16)->nullable();
                $t->boolean('is_reversal')->default(0);
                $t->timestamp('created_at')->nullable();
            });
        }
    }

    // --------------------------------------------------------- zone charges

    private function zoneChargeColumns(): void
    {
        // Surge slots / additional charges carry their own is_taxable + is_tax_included +
        // tax_category_id keys INSIDE the existing JSON columns — no schema needed there.
        // The base delivery charge has no JSON row of its own, so it gets columns.
        $this->addColumns('zones', [
            'delivery_charge_is_taxable'      => fn (Blueprint $t) => $t->boolean('delivery_charge_is_taxable')->default(0)->after('base_delivery_charge'),
            'delivery_charge_tax_included'    => fn (Blueprint $t) => $t->boolean('delivery_charge_tax_included')->default(0)->after('base_delivery_charge'),
            'delivery_charge_tax_category_id' => fn (Blueprint $t) => $t->unsignedBigInteger('delivery_charge_tax_category_id')->nullable()->after('base_delivery_charge'),
        ]);
    }

    // -------------------------------------------------------------- helpers

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

    // ------------------------------------------------------------- backfill

    /**
     * Import the shipped subdivision list for every country already in the table.
     * Same dataset the admin import screen uses (config/states.json), so an
     * existing install comes up with working dropdowns instead of empty ones.
     */
    private function seedRegions(): void
    {
        if (!Schema::hasTable('regions') || !Schema::hasTable('countries')) {
            return;
        }
        $defaultLanguageId = Schema::hasTable('languages')
            ? DB::table('languages')->where('is_default', 1)->value('id')
            : null;
        foreach (DB::table('countries')->get(['id', 'code']) as $country) {
            // Same code path the country-import screen uses, so there is exactly one
            // implementation of "pull a country's subdivisions from the shipped dataset".
            \App\Models\Region::importFromDataset(
                (int) $country->id,
                (string) $country->code,
                null,
                $defaultLanguageId
            );
        }
    }

    /**
     * Point existing zones and addresses at a region using their free-text `state`.
     * Three passes, cheapest first: exact normalised name, ISO subdivision suffix
     * ("Mh" -> IN-MH), then a 1-2 character typo tolerance ("gujrat" -> Gujarat).
     * Anything still unmatched stays NULL, which the engine reads as
     * "place of supply unknown" rather than guessing.
     */
    private function backfillRegionLinks(): void
    {
        if (!Schema::hasTable('regions')) {
            return;
        }
        $regions = DB::table('regions')->get(['id', 'country_id', 'name', 'code']);
        if ($regions->isEmpty()) {
            return;
        }
        $byCountry = $regions->groupBy('country_id');

        if (Schema::hasTable('zones') && Schema::hasColumn('zones', 'region_id')) {
            foreach (DB::table('zones')->whereNull('region_id')->get(['id', 'state', 'country_id']) as $zone) {
                $match = $this->matchRegion($byCountry->get($zone->country_id), $zone->state);
                if ($match) {
                    DB::table('zones')->where('id', $zone->id)->update(['region_id' => $match]);
                }
            }
        }

        if (Schema::hasTable('user_addresses') && Schema::hasColumn('user_addresses', 'region_id')) {
            // An address has no country_id of its own — resolve it through its zone.
            DB::table('user_addresses')
                ->whereNull('region_id')
                ->orderBy('id')
                ->chunkById(500, function ($addresses) use ($byCountry) {
                    $zoneCountry = DB::table('zones')->pluck('country_id', 'id');
                    foreach ($addresses as $address) {
                        $countryId = $zoneCountry[$address->zone_id] ?? null;
                        $match = $this->matchRegion($countryId ? $byCountry->get($countryId) : null, $address->state);
                        if ($match) {
                            DB::table('user_addresses')->where('id', $address->id)->update(['region_id' => $match]);
                        }
                    }
                });
        }
    }

    private function matchRegion($regions, ?string $state): ?int
    {
        $needle = preg_replace('/[^a-z0-9]/', '', strtolower(trim((string) $state)));
        if ($needle === '' || !$regions) {
            return null;
        }
        foreach ($regions as $region) {
            if (preg_replace('/[^a-z0-9]/', '', strtolower($region->name)) === $needle) {
                return (int) $region->id;
            }
        }
        foreach ($regions as $region) {
            $suffix = strtolower((string) strstr((string) $region->code, '-'));
            if ($suffix !== '' && ltrim($suffix, '-') === $needle) {
                return (int) $region->id;
            }
        }
        foreach ($regions as $region) {
            $name = preg_replace('/[^a-z0-9]/', '', strtolower($region->name));
            if (strlen($needle) >= 5 && levenshtein($needle, $name) <= 2) {
                return (int) $region->id;
            }
        }
        return null;
    }

    /**
     * Turn each legacy `taxes` row into a tax category plus the rules that charge it.
     *
     * Behaviour is preserved exactly: every existing country gets a rule at the old
     * percentage, so a store that charged 18% still charges 18%. India additionally
     * gets the intra/inter pair (CGST+SGST vs IGST) that splits that same total —
     * seeded DATA, matching how the country list itself is seeded.
     */
    private function backfillTaxConfig(): void
    {
        if (!Schema::hasTable('taxes') || !Schema::hasTable('tax_categories') || !Schema::hasTable('tax_rules')) {
            return;
        }
        $now = now();
        $defaultLanguageId = Schema::hasTable('languages')
            ? DB::table('languages')->where('is_default', 1)->value('id')
            : null;

        $categoryByTaxId = [];
        foreach (DB::table('taxes')->orderBy('id')->get() as $tax) {
            $code = $this->categoryCode($tax->title, (float) $tax->percentage);
            $existing = DB::table('tax_categories')->where('code', $code)->first();
            if ($existing) {
                // Category already built by an earlier run. Do NOT skip the rule loop:
                // a country imported since then would otherwise have no rule for this
                // category, and the engine would silently resolve it to 0% tax.
                $categoryByTaxId[$tax->id] = $existing->id;
                $this->seedRulesForCategory((int) $existing->id, $tax, $now);
                continue;
            }
            $categoryId = DB::table('tax_categories')->insertGetId([
                'name'        => $tax->title,
                'code'        => $code,
                'description' => 'Migrated from legacy tax #' . $tax->id,
                'status'      => (int) ($tax->status ?? 1),
                'created_at'  => $now,
                'updated_at'  => $now,
            ]);
            $categoryByTaxId[$tax->id] = $categoryId;

            $this->seedRulesForCategory($categoryId, $tax, $now);
        }

        if (Schema::hasColumn('products', 'tax_category_id')) {
            foreach ($categoryByTaxId as $taxId => $categoryId) {
                DB::table('products')->where('tax_id', $taxId)->whereNull('tax_category_id')
                    ->update(['tax_category_id' => $categoryId]);
            }
        }
    }

    /**
     * One rule per country for a category, at the legacy flat percentage, so behaviour
     * is preserved exactly: a store that charged 18% still charges 18%. India gets the
     * intra/inter pair that splits that same total. Countries that already have a rule
     * for this category are left alone — the admin may have edited it.
     */
    private function seedRulesForCategory(int $categoryId, $tax, $now): void
    {
        $rate = round((float) $tax->percentage, 3);
        $head = $this->componentHead($tax->title);

        foreach (DB::table('countries')->get(['id', 'code']) as $country) {
            if (DB::table('tax_rules')->where('country_id', $country->id)->where('tax_category_id', $categoryId)->exists()) {
                continue;
            }
            $isIndia = strtoupper((string) $country->code) === 'IN';
            $plans = $isIndia
                ? [
                    ['intra', [['C' . $head, round($rate / 2, 3)], ['S' . $head, round($rate / 2, 3)]]],
                    ['inter', [['I' . $head, $rate]]],
                ]
                : [['any', [[$head, $rate]]]];

            foreach ($plans as [$placeOfSupply, $components]) {
                $ruleId = DB::table('tax_rules')->insertGetId([
                    'country_id'         => $country->id,
                    'region_id'          => null,
                    'tax_category_id'    => $categoryId,
                    'place_of_supply'    => $placeOfSupply,
                    'status'             => 1,
                    'created_at'         => $now,
                    'updated_at'         => $now,
                ]);
                foreach ($components as $i => [$name, $componentRate]) {
                    DB::table('tax_rule_components')->insert([
                        'tax_rule_id' => $ruleId,
                        'name'        => $name,
                        'rate'        => $componentRate,
                        'sort_order'  => $i,
                    ]);
                }
            }
        }
    }

    /** "GST 5%" -> GST_5 ; "Reduced rate" -> REDUCED_RATE. Kept unique per rate. */
    private function categoryCode(string $title, float $percentage): string
    {
        $slug = strtoupper(preg_replace('/[^A-Za-z0-9]+/', '_', trim($title)));
        $slug = trim($slug, '_');
        return $slug !== '' ? substr($slug, 0, 32) : 'TAX_' . str_replace('.', '_', (string) $percentage);
    }

    /** Leading word of the tax title is the head name: "GST 18%" -> GST. */
    private function componentHead(string $title): string
    {
        preg_match('/[A-Za-z]+/', $title, $m);
        return strtoupper($m[0] ?? 'TAX');
    }

    /**
     * Historical orders: derive the line-total tax from the per-unit snapshot and
     * write one generic tax line per item. No CGST/SGST split is invented for orders
     * placed before the engine existed — the split was never captured, so the snapshot
     * shows a single "Tax" head and the invoice falls back to its legacy layout.
     */
    private function backfillOrderSnapshots(): void
    {
        if (!Schema::hasTable('order_items') || !Schema::hasColumn('order_items', 'tax_total')) {
            return;
        }

        DB::table('order_items')->whereNull('tax_total')->update([
            'tax_total'     => DB::raw('ROUND(COALESCE(tax_amount, 0) * COALESCE(quantity, 1), 2)'),
            'supply_type'   => 'none',
        ]);
        DB::table('order_items')->whereNull('taxable_value')->update([
            'taxable_value' => DB::raw('ROUND(COALESCE(sub_total, 0) - COALESCE(tax_total, 0), 2)'),
        ]);

        if (Schema::hasTable('order_item_taxes') && DB::table('order_item_taxes')->doesntExist()) {
            DB::table('order_items')
                ->where('tax_total', '>', 0)
                ->orderBy('id')
                ->chunkById(500, function ($items) {
                    $rows = [];
                    foreach ($items as $item) {
                        $rows[] = [
                            'order_id'       => $item->order_id,
                            'order_item_id'  => $item->id,
                            'tax_rule_id'    => null,
                            'component_name' => 'Tax',
                            'rate'           => round((float) $item->tax_percentage, 3),
                            'taxable_value'  => round((float) $item->taxable_value, 2),
                            'amount'         => round((float) $item->tax_total, 2),
                            'source'         => 'item',
                            'source_ref'     => null,
                            'hsn_code'       => $item->hsn_code ?? null,
                            'is_reversal'    => 0,
                            'created_at'     => $item->created_at,
                        ];
                    }
                    DB::table('order_item_taxes')->insert($rows);
                });
        }

        // orders.tax_amount is LEFT ALONE. Verified against production data: the header
        // already holds the correct line-total tax (it was built from sub_total, not from
        // the per-unit column), so rewriting it would only churn historical records. The
        // per-unit bug lives in the REPORTS that sum order_items.tax_amount — those move
        // to tax_total in code, not here. Only the new taxable_value column is filled.
        if (Schema::hasColumn('orders', 'taxable_value')) {
            DB::statement('
                UPDATE orders o
                JOIN (
                    SELECT order_id, ROUND(SUM(COALESCE(taxable_value, 0)), 2) AS taxable_sum
                    FROM order_items
                    WHERE deleted_at IS NULL
                    GROUP BY order_id
                ) i ON i.order_id = o.id
                SET o.taxable_value = i.taxable_sum
                WHERE o.taxable_value = 0
            ');
        }

        $this->syncReportPermissions();
        $this->addDeliveryEstimates();
    }

    /**
     * Delivery-time estimates: how long a store takes to prepare a quick order, how
     * many days a parcel takes to reach a zone, and the promised date frozen onto each
     * ecommerce order item — plus the notification sent when that date is revised.
     *
     * Folded in from the standalone 2026_08_30_000001_delivery_estimates migration so
     * the release ships as one file. Both are guarded, so an install that already ran
     * the standalone one finds everything present and does nothing.
     */
    private function addDeliveryEstimates(): void
    {
        if (!Schema::hasColumn('stores', 'preparation_time')) {
            Schema::table('stores', function (Blueprint $table) {
                // Minutes. 0 = not configured, which keeps today's travel-only ETA.
                $table->unsignedInteger('preparation_time')->default(0)->after('operating_hours');
            });
        }

        if (!Schema::hasColumn('zones', 'ecommerce_delivery_days')) {
            Schema::table('zones', function (Blueprint $table) {
                // Whole days. 0 = no estimate shown, as before.
                $table->unsignedSmallInteger('ecommerce_delivery_days')->default(0)->after('area_pricing');
            });
        }

        if (!Schema::hasColumn('order_items', 'estimated_delivery_date')) {
            Schema::table('order_items', function (Blueprint $table) {
                $table->date('estimated_delivery_date')->nullable()->after('delivery_charge');
            });
        }

        $this->seedDeliveryEstimateNotification();
    }

    /** The notification this feature sends, and the placeholders it fills. */
    private const NOTIF_TYPE = 'order_item_delivery_estimate_customer';
    private const NOTIF_EVENT = 'order_item_delivery_estimate';
    private const NOTIF_PLACEHOLDERS = [
        'app_name', 'customer_name', 'order_id', 'order_item_id', 'product_name',
        'quantity', 'estimated_delivery_date', 'previous_delivery_date', 'currency', 'final_total',
    ];

    /**
     * Give an EXISTING install the "delivery date changed" templates.
     *
     * Fresh installs get these from the three template seeders; an upgrade never runs
     * those again, so the rows are created here too. Only missing rows are written —
     * copy a client has already edited is left exactly as they wrote it.
     */
    private function seedDeliveryEstimateNotification(): void
    {
        $ph = json_encode(self::NOTIF_PLACEHOLDERS);
        $now = now();

        $rows = [
            'notification_templates' => [
                'title'   => 'New delivery date for {{product_name}}',
                'message' => '{{product_name}} in order #{{order_id}} is now expected by {{estimated_delivery_date}}. Sorry for the delay.',
            ],
            'email_templates' => [
                'title'   => 'Updated delivery date for your order #{{order_id}}',
                'message' => "Hi {{customer_name}},\n\nThe delivery date for {{product_name}} (qty {{quantity}}) in your order #{{order_id}} has changed from {{previous_delivery_date}} to {{estimated_delivery_date}}.\n\nWe are sorry for the delay and are working to get it to you as soon as possible.\n\n{{app_name}}",
            ],
            'sms_templates' => [
                'message' => '{{product_name}} in order #{{order_id}} is now expected by {{estimated_delivery_date}}. - {{app_name}}',
            ],
        ];

        foreach ($rows as $table => $copy) {
            if (!Schema::hasTable($table)) {
                continue;
            }
            if (DB::table($table)->where('type', self::NOTIF_TYPE)->exists()) {
                continue;
            }
            DB::table($table)->insert(array_merge($copy, [
                'type'         => self::NOTIF_TYPE,
                'audience'     => 'customer',
                'category'     => 'Order Items',
                'placeholders' => $ph,
                'created_at'   => $now,
                'updated_at'   => $now,
            ]));
        }

        /* Admin toggles per channel. Without these the event is invisible in the
           notification settings screen, so nobody could turn it off.

           SMS defaults OFF, matching every other customer event in the catalog
           (NotificationService's $recipientCh): texts cost money per message, so an
           upgrade must not start spending on a client's behalf. They can switch it on.

           Only ever INSERTED — a re-run must not flip a toggle an admin has set. */
        if (Schema::hasTable('notification_admin_settings')) {
            foreach (['mail' => 1, 'push' => 1, 'sms' => 0] as $channel => $enabled) {
                $exists = DB::table('notification_admin_settings')
                    ->where('event_key', self::NOTIF_EVENT)
                    ->where('audience', 'customer')
                    ->where('channel', $channel)
                    ->exists();
                if (!$exists) {
                    DB::table('notification_admin_settings')->insert([
                        'event_key'  => self::NOTIF_EVENT,
                        'audience'   => 'customer',
                        'channel'    => $channel,
                        'is_enabled' => $enabled,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                }
            }
        }

        /* Customer preferences need no backfill: NotificationService treats a missing
           row as enabled, so every customer receives this until they opt out. */
    }


    private function syncReportPermissions(): void
    {
        if (!Schema::hasTable('permissions')) {
            return;
        }

        $categoryId = Schema::hasTable('permission_categories')
            ? DB::table('permission_categories')->where('name', 'report')->value('id')
            : null;

        // Grant them to whoever already holds the sales report — the same audience.
        $salesId = DB::table('permissions')->where('name', 'report_sales')->value('id');
        $roleIds = $salesId && Schema::hasTable('role_has_permissions')
            ? DB::table('role_has_permissions')->where('permission_id', $salesId)->pluck('role_id')
            : collect();

        foreach (['report_tax', 'report_tax_orders'] as $name) {
            $id = DB::table('permissions')->where('name', $name)->value('id');
            if (!$id && !$categoryId) {
                continue;
            }
            if (!$id) {
                $id = DB::table('permissions')->insertGetId([
                    'name'        => $name,
                    'guard_name'  => 'web',
                    'category_id' => $categoryId,
                    'created_at'  => now(),
                    'updated_at'  => now(),
                ]);
            }
            foreach ($roleIds as $roleId) {
                DB::table('role_has_permissions')->updateOrInsert(
                    ['permission_id' => $id, 'role_id' => $roleId],
                    ['permission_id' => $id, 'role_id' => $roleId]
                );
            }
        }

        // Retired permission: drop its grants first, then the row itself.
        $deadId = DB::table('permissions')->where('name', 'manage_system_registration')->value('id');
        if ($deadId) {
            if (Schema::hasTable('role_has_permissions')) {
                DB::table('role_has_permissions')->where('permission_id', $deadId)->delete();
            }
            if (Schema::hasTable('model_has_permissions')) {
                DB::table('model_has_permissions')->where('permission_id', $deadId)->delete();
            }
            DB::table('permissions')->where('id', $deadId)->delete();
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
     * Reverses in the opposite order to up(): rebuild the flat tax system first (while
     * the categories and rules are still there to rebuild it FROM), then drop the new
     * schema, then put the money columns back to double.
     *
     * What cannot be recovered: the per-line tax breakdown in `order_item_taxes` and the
     * region links on zones/addresses. Those are new facts this release captured, and
     * the old schema has nowhere to hold them.
     */
    public function down(): void
    {
        $this->revertDeliveryEstimates();
        $this->revertReportPermissions();
        $this->restoreLegacyTaxSystem();
        $this->dropTaxEngineSchema();
        $this->moneyColumnsToDouble();
    }
    
    /** Undo addDeliveryEstimates(): the three columns and the notification it added. */
    private function revertDeliveryEstimates(): void
    {
        if (Schema::hasColumn('stores', 'preparation_time')) {
            Schema::table('stores', fn (Blueprint $t) => $t->dropColumn('preparation_time'));
        }
        if (Schema::hasColumn('zones', 'ecommerce_delivery_days')) {
            Schema::table('zones', fn (Blueprint $t) => $t->dropColumn('ecommerce_delivery_days'));
        }
        if (Schema::hasColumn('order_items', 'estimated_delivery_date')) {
            Schema::table('order_items', fn (Blueprint $t) => $t->dropColumn('estimated_delivery_date'));
        }

        foreach (['notification_templates', 'email_templates', 'sms_templates'] as $table) {
            if (!Schema::hasTable($table)) {
                continue;
            }
            $ids = DB::table($table)->where('type', self::NOTIF_TYPE)->pluck('id');
            $tr = rtrim($table, 's') . '_translations';
            $fk = rtrim($table, 's') . '_id';
            if ($ids->isNotEmpty() && Schema::hasTable($tr)) {
                DB::table($tr)->whereIn($fk, $ids)->delete();
            }
            DB::table($table)->whereIn('id', $ids)->delete();
        }

        foreach (['notification_admin_settings', 'notification_preferences'] as $table) {
            if (Schema::hasTable($table)) {
                DB::table($table)->where('event_key', self::NOTIF_EVENT)->delete();
            }
        }
    }

    private function revertReportPermissions(): void
    {
        if (!Schema::hasTable('permissions')) {
            return;
        }

        $ids = DB::table('permissions')->whereIn('name', ['report_tax', 'report_tax_orders'])->pluck('id');
        if ($ids->isNotEmpty()) {
            if (Schema::hasTable('role_has_permissions')) {
                DB::table('role_has_permissions')->whereIn('permission_id', $ids)->delete();
            }
            if (Schema::hasTable('model_has_permissions')) {
                DB::table('model_has_permissions')->whereIn('permission_id', $ids)->delete();
            }
            DB::table('permissions')->whereIn('id', $ids)->delete();
        }

        $settingsCategoryId = Schema::hasTable('permission_categories')
            ? DB::table('permission_categories')->where('name', 'settings')->value('id')
            : null;
        $exists = DB::table('permissions')->where('name', 'manage_system_registration')->exists();
        // Same NOT NULL constraint as above: without the category there is no row to write.
        if (!$exists && $settingsCategoryId) {
            DB::table('permissions')->insert([
                'name'        => 'manage_system_registration',
                'guard_name'  => 'web',
                'category_id' => $settingsCategoryId,
                'created_at'  => now(),
                'updated_at'  => now(),
            ]);
        }
    }

    /**
     * Rebuild `taxes` / `products.tax_id` from the categories and rules that replaced
     * them, so a rolled-back install still charges tax instead of nothing.
     *
     * Each category's percentage is taken from a rule in the DEFAULT country, preferring
     * one that is not `inter` (an intra rule and an inter rule total the same, so either
     * gives the right figure). A category no rule prices becomes 0%.
     */
    private function restoreLegacyTaxSystem(): void
    {
        if (!Schema::hasTable('tax_categories')) {
            return;
        }

        if (!Schema::hasTable('taxes')) {
            Schema::create('taxes', function (Blueprint $t) {
                $t->increments('id');
                $t->string('title');
                $t->double('percentage')->default(0);
                $t->tinyInteger('status')->default(1);
            });
        }
        if (!Schema::hasTable('tax_translations')) {
            Schema::create('tax_translations', function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger('tax_id');
                $t->unsignedBigInteger('language_id');
                $t->string('title')->nullable();
                $t->timestamps();
                $t->unique(['tax_id', 'language_id']);
            });
        }
        $this->addColumns('products', [
            'tax_id'                => fn (Blueprint $t) => $t->unsignedBigInteger('tax_id')->nullable()->default(0),
            'tax_included_in_price' => fn (Blueprint $t) => $t->boolean('tax_included_in_price')->default(0),
        ]);

        $defaultCountryId = Schema::hasTable('countries')
            ? DB::table('countries')->where('is_default', 1)->value('id')
            : null;

        foreach (DB::table('tax_categories')->get() as $category) {
            $rule = DB::table('tax_rules')
                ->where('tax_category_id', $category->id)->where('status', 1)
                ->when($defaultCountryId, fn ($q) => $q->orderByRaw('country_id = ? DESC', [$defaultCountryId]))
                ->orderByRaw("place_of_supply = 'inter' ASC")
                ->first(['id']);

            $percentage = $rule
                ? (float) DB::table('tax_rule_components')->where('tax_rule_id', $rule->id)->sum('rate')
                : 0.0;

            $taxId = DB::table('taxes')->where('title', $category->name)->value('id')
                ?: DB::table('taxes')->insertGetId([
                    'title'      => $category->name,
                    'percentage' => round($percentage, 2),
                    'status'     => (int) $category->status,
                ]);

            DB::table('products')->where('tax_category_id', $category->id)->update(['tax_id' => $taxId]);
        }
    }

    /** Drop everything the tax engine added, children before parents. */
    private function dropTaxEngineSchema(): void
    {
        Schema::dropIfExists('order_item_taxes');
        Schema::dropIfExists('tax_rule_components');
        Schema::dropIfExists('tax_rules');
        Schema::dropIfExists('tax_categories');
        Schema::dropIfExists('region_translations');
        Schema::dropIfExists('regions');

        $this->dropColumns('products', ['tax_category_id']);
        $this->dropColumns('orders', ['buyer_region_id', 'place_of_supply', 'taxable_value']);
        $this->dropColumns('order_items', [
            'tax_total', 'taxable_value', 'seller_region_id', 'seller_tax_number',
            'supply_type', 'refund_tax_amount', 'is_tax_inclusive',
        ]);
        $this->dropColumns('stores', ['tax_number', 'tax_registration_type']);
        $this->dropColumns('product_variant_store_stocks', ['is_tax_inclusive']);
        $this->dropColumns('user_addresses', ['region_id']);
        $this->dropColumns('zones', [
            'region_id', 'delivery_charge_is_taxable',
            'delivery_charge_tax_included', 'delivery_charge_tax_category_id',
        ]);

        // The unique index on countries.code was added by up(); leave the column alone.
        if (Schema::hasTable('countries') && $this->hasIndex('countries', 'countries_code_unique')) {
            Schema::table('countries', fn (Blueprint $t) => $t->dropUnique('countries_code_unique'));
        }
    }

    /** Money columns back to double — the shape they had before this release. */
    private function moneyColumnsToDouble(): void
    {
        foreach ($this->columns as $table => $columns) {
            if (!Schema::hasTable($table)) {
                continue;
            }
            Schema::table($table, function (Blueprint $t) use ($columns) {
                foreach ($columns as $column) {
                    if (Schema::hasColumn($t->getTable(), $column)) {
                        $t->double($column)->default(0)->change();
                    }
                }
            });
        }
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
};
