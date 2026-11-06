<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Release 1.5.0 — food products and their addons.
 *
 * A product can be marked as food, and a food product carries its own addon groups:
 * "Choose crust", "Add toppings", "Add a drink". The groups belong to THE PRODUCT, not to
 * a shared library — a chain's twenty pizzas each own their toppings list, so repricing
 * one cannot silently reprice the other nineteen. Copy-from-another-product in the admin
 * is what keeps that from meaning twenty rounds of typing.
 *
 * `products.product_type` is deliberately untouched: veg / non-veg / eggetarian is a diet
 * marking that belongs on groceries too, a food item is *also* veg or non-veg so the two
 * can never share one column, and the customer apps already draw their badge from that
 * column's existing values.
 *
 * Money is per BRANCH, in `product_addon_option_branches`, exactly as a product's own price
 * lives in `product_variant_branch_stocks` and never on the variant. That is not tidiness:
 * a branch sits in a zone, a zone in a country, and each country prices in its own currency
 * with no conversion anywhere in the stack. A single global price would be read as 30
 * rupees in India and 30 dollars in New York. A branch with no row does not offer the
 * option at all, rather than offering it at another country's number.
 *
 * An option can also BE a product — "add a Coke" — through `linked_variant_id` plus
 * one unit per selection. It then draws on that variant's real stock at the same branch, and is shown
 * nested under the dish rather than as its own cart line.
 *
 * Two columns carry the choice through checkout:
 *
 *   carts.addon_signature  — sha1 of the sorted option id:qty pairs, '' when none. This is
 *                            what finally gives a cart line an identity: one pizza with
 *                            cheese and one without are two rows of the same variant. An
 *                            old app build sends no addons, gets '', and behaves as today.
 *   order_items.addons     — a resolved snapshot (group and option NAMES, quantities, and
 *                            any linked variant), so renaming or deleting an option cannot
 *                            rewrite history, and a return can still find the stock to put
 *                            back.
 *
 * The snapshot is a JSON column on `order_items` rather than a child table on purpose:
 * ConditionalResponse::riderStamp() fingerprints `order_items.updated_at`, and a child
 * table would not move that stamp, so the rider app could serve a stale 304.
 *
 * The addon amount is NOT a side column anywhere money is summed — it is folded into the
 * per-unit price, because `qty * unit_price == sub_total` is assumed by both invoices, the
 * delivery receipt, order emails, refunds, report net sales, dashboard revenue, the
 * ecommerce per-item charge splits and the courier declared value. `addon_total` exists
 * for display and reporting only; nothing does arithmetic with it.
 */
return new class extends Migration
{
    public function up(): void
    {
        $this->addonGroupsTable();
        $this->addonGroupTranslationsTable();
        $this->addonOptionsTable();
        $this->addonOptionTranslationsTable();
        $this->addonOptionBranchesTable();
        $this->productFlags();
        $this->cartAddonColumns();
        $this->cartIndexes();
        $this->orderItemAddonColumns();
        $this->appVersionUpdateNotification();
        $this->brokenImageSetting();
        $this->buyerTaxIdentity();
        $this->pageHeaderColors();
    }

    public function down(): void
    {
        $this->dropColumns('page_layouts', ['title_color', 'header_color']);
        $this->dropColumns('orders', ['buyer_tax_number', 'buyer_tax_label', 'buyer_business_name']);
        $this->dropColumns('countries', ['buyer_tax_enabled', 'buyer_tax_label', 'buyer_tax_regex']);
        $this->dropColumns('order_items', ['addons', 'addon_total']);
        $this->dropCartIndexes();
        $this->dropColumns('carts', ['addons', 'addon_signature']);
        $this->dropColumns('products', ['is_food', 'is_addon_only']);

        Schema::dropIfExists('product_addon_option_stores');
        Schema::dropIfExists('product_addon_option_branches');
        Schema::dropIfExists('product_addon_option_translations');
        Schema::dropIfExists('product_addon_options');
        Schema::dropIfExists('product_addon_group_translations');
        Schema::dropIfExists('product_addon_groups');
    }

    /**
     * One question a product puts to the customer: "Choose crust", "Add toppings".
     *
     * `input_type` is the picker contract the apps render from — radio or checkbox, said
     * outright rather than inferred from some other field.
     *
     * There is deliberately no subtitle column. The helper line the customer reads —
     * "Required • Select any 1 option" — is DERIVED from these rules and translated on
     * the way out, so it can never drift from what the group actually enforces and no
     * operator has to retype it in every language.
     *
     * `max_select` of 0 means no limit. `max_qty_per_option` above 1 turns a checkbox
     * into a stepper, which is how "2 x extra cheese" is expressed.
     *
     * There is deliberately no "first N free" allowance. An option that costs nothing is
     * said so on the OPTION, through its Paid/Free setting, which is one rule the
     * customer can read off the option itself rather than an arithmetic over the group.
     */
    private function addonGroupsTable(): void
    {
        if (Schema::hasTable('product_addon_groups')) {
            return;
        }

        Schema::create('product_addon_groups', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('product_id');
            $table->string('name');
            $table->enum('input_type', ['radio', 'checkbox'])->default('radio')
                ->comment('What the app renders: radio = exactly one, checkbox = several');
            $table->boolean('is_required')->default(0);
            $table->tinyInteger('min_select')->default(0);
            $table->tinyInteger('max_select')->default(0)
                ->comment('Largest number of options the customer may pick; 0 = no limit');
            $table->tinyInteger('max_qty_per_option')->default(1)
                ->comment('How many of ONE option may be taken; above 1 the app shows a stepper');
            $table->integer('sort_order')->default(0);
            $table->tinyInteger('status')->default(1);
            $table->timestamps();
            $table->softDeletes();

            $table->foreign('product_id', 'pa_grp_product_fk')
                ->references('id')->on('products')->onDelete('cascade');
            $table->index(['product_id', 'status'], 'pa_grp_product_status_idx');
        });
    }

    private function addonGroupTranslationsTable(): void
    {
        if (Schema::hasTable('product_addon_group_translations')) {
            return;
        }

        Schema::create('product_addon_group_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('addon_group_id');
            $table->unsignedBigInteger('language_id');
            $table->string('name')->nullable();
            $table->timestamps();

            $table->foreign('addon_group_id', 'pa_grp_trans_grp_fk')
                ->references('id')->on('product_addon_groups')->onDelete('cascade');
            $table->foreign('language_id', 'pa_grp_trans_lang_fk')
                ->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['addon_group_id', 'language_id'], 'pa_grp_trans_unique');
        });
    }

    /**
     * One answer to that question.
     *
     * A CUSTOM option is just a name, priced per branch below. A LINKED option points at a
     * real catalogue variant — "add a Coke" — and one selection is one unit of it. A
     * linked option draws on that variant's actual stock, which is the whole point of
     * linking rather than retyping it as a custom option. A bundle of several units is
     * modelled as a variant that IS the bundle, not as a multiplier here.
     *
     * `price_source = product` follows the linked variant's own branch price, keeping the
     * catalogue as the single source of truth; `custom` lets this dish charge its own
     * number. When following the catalogue it is the variant's BASE branch price, never its
     * quantity slabs — a slab is a tier on how many of that product you buy, and it must
     * not be reached by ordering more of the dish it hangs off.
     *
     * `image` is optional, and only a custom option carries one: a linked option already
     * IS a product with a picture, so uploading the same photo a second time would only
     * create something that can disagree with the catalogue.
     */
    private function addonOptionsTable(): void
    {
        if (!Schema::hasTable('product_addon_options')) {
            Schema::create('product_addon_options', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('addon_group_id');
                $table->string('name');
                $table->string('image')->nullable()
                    ->comment('Optional picture; a LINKED option wears its product\'s own image and keeps this null');
                $table->tinyInteger('product_type')->nullable()
                    ->comment('Diet mark, same scale as products.product_type: 0 none | 1 veg | 2 non-veg | 4 eggetarian. A LINKED option reads its product\'s and keeps this null');
                $table->unsignedBigInteger('linked_variant_id')->nullable()
                    ->comment('Set when this option IS a catalogue product; null for a plain named option');
                $table->boolean('is_free')->default(0)
                    ->comment('1 = given away: costs nothing wherever it is offered');
                $table->enum('price_source', ['custom', 'product'])->default('custom')
                    ->comment("product = follow the linked variant's base branch price");
                $table->integer('sort_order')->default(0);
                $table->tinyInteger('status')->default(1);
                $table->timestamps();
                $table->softDeletes();

                $table->foreign('addon_group_id', 'pa_opt_grp_fk')
                    ->references('id')->on('product_addon_groups')->onDelete('cascade');
                // Deleting the linked product leaves the option standing but unsellable,
                // rather than silently deleting part of a dish's menu.
                $table->foreign('linked_variant_id', 'pa_opt_variant_fk')
                    ->references('id')->on('product_variants')->nullOnDelete();
                $table->index('addon_group_id', 'pa_opt_grp_idx');
            });
        }

        /* 1.5.0 is unreleased, so `image` is simply part of the table above. The guarded
           add is for a database that already ran an earlier build of this same migration,
           where the create block is skipped outright. */
        $this->addColumns('product_addon_options', [
            'image' => fn (Blueprint $t) => $t->string('image')->nullable()->after('name')
                ->comment("Optional picture; a LINKED option wears its product's own image and keeps this null"),
            'product_type' => fn (Blueprint $t) => $t->tinyInteger('product_type')->nullable()->after('image')
                ->comment("Diet mark, same scale as products.product_type: 0 none | 1 veg | 2 non-veg | 4 eggetarian. A LINKED option reads its product's and keeps this null"),
        ]);
    }

    private function addonOptionTranslationsTable(): void
    {
        if (Schema::hasTable('product_addon_option_translations')) {
            return;
        }

        Schema::create('product_addon_option_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('addon_option_id');
            $table->unsignedBigInteger('language_id');
            $table->string('name')->nullable();
            $table->timestamps();

            $table->foreign('addon_option_id', 'pa_opt_trans_opt_fk')
                ->references('id')->on('product_addon_options')->onDelete('cascade');
            $table->foreign('language_id', 'pa_opt_trans_lang_fk')
                ->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['addon_option_id', 'language_id'], 'pa_opt_trans_unique');
        });
    }

    /**
     * What one option costs at one branch, per unit of the dish it hangs off: two burgers
     * with extra cheese are charged for two portions of cheese.
     *
     * A missing row means the option is simply NOT offered at that branch — the same rule
     * `product_variant_branch_stocks.is_listed` already applies to the product itself.
     * `is_available` lets a branch withdraw an option for the day without losing its price.
     *
     * `discounted_price` follows the product convention exactly: 0 means "no offer", so the
     * charged amount is `discounted_price > 0 && discounted_price < price ? discounted_price
     * : price`.
     */
    private function addonOptionBranchesTable(): void
    {
        /* 1.5.0 is unreleased, so this ships under its final name and the store-to-branch
           migration has nothing to rename here. The old name is still checked, because a
           development database built from an earlier 1.5.0 build holds it — that one is
           renamed by the later migration, and creating a second table here would strand
           its rows. */
        if (Schema::hasTable('product_addon_option_branches') || Schema::hasTable('product_addon_option_stores')) {
            return;
        }

        $branchTable = Schema::hasTable('branches') ? 'branches' : 'stores';

        Schema::create('product_addon_option_branches', function (Blueprint $table) use ($branchTable) {
            $table->id();
            $table->unsignedBigInteger('addon_option_id');
            $table->unsignedBigInteger('branch_id');
            $table->boolean('is_available')->default(1);
            $table->decimal('price', 14, 2)->default(0);
            $table->decimal('discounted_price', 14, 2)->default(0)
                ->comment('0 = no offer, charge `price`');
            $table->timestamps();

            $table->foreign('addon_option_id', 'pa_opt_branch_opt_fk')
                ->references('id')->on('product_addon_options')->onDelete('cascade');
            $table->foreign('branch_id', 'pa_opt_branch_branch_fk')
                ->references('id')->on($branchTable)->onDelete('cascade');
            $table->unique(['addon_option_id', 'branch_id'], 'pa_opt_branch_unique');
        });
    }

    /**
     * `is_food` unlocks the addon setup on a product and tells the apps to ask before
     * adding it to the cart. It is NOT a sixth `product_type`: that column is a single
     * mutually-exclusive diet marking, and a food item is also veg or non-veg.
     *
     * It lives on the product and nowhere else — no category flag. Addons are configured
     * per product anyway, so a category tick would save no clicks while adding a second
     * source of truth; and since a product gets re-filed eventually, inheritance would mean
     * a dish silently stops being food the day someone moves it between categories.
     *
     * `is_addon_only` is for an item that exists purely to ride along — a 50ml dip, a
     * second portion of curry. It stays attachable but is excluded from every
     * customer-facing listing, search and home section.
     */
    private function productFlags(): void
    {
        $this->addColumns('products', [
            'is_food' => fn (Blueprint $t) => $t->tinyInteger('is_food')->default(0)->after('product_type')
                ->comment('1 = food item; unlocks addon setup on the product form'),
            'is_addon_only' => fn (Blueprint $t) => $t->tinyInteger('is_addon_only')->default(0)->after('is_food')
                ->comment('1 = sold only as an addon; hidden from listings, search and home sections'),
        ]);
    }

    private function cartAddonColumns(): void
    {
        $this->addColumns('carts', [
            'addons' => fn (Blueprint $t) => $t->json('addons')->nullable()->after('qty')
                ->comment('Chosen options as [{id, qty}]. IDs only — prices resolve live, so a menu change reaches carts already holding the item'),
            'addon_signature' => fn (Blueprint $t) => $t->string('addon_signature', 64)->default('')->after('addons')
                ->comment("sha1 of the sorted id:qty pairs, '' when none — the cart line's identity"),
        ]);
    }

    /**
     * `carts` ships with no index at all beyond its primary key, and every cart call
     * filters on the same two shapes. The signature joins the lookup key so two addon
     * variations of one variant stop colliding.
     */
    private function cartIndexes(): void
    {
        if (!Schema::hasTable('carts') || !Schema::hasColumn('carts', 'addon_signature')) {
            return;
        }

        if (!$this->hasIndexNamed('carts', 'carts_user_variant_addon_idx')) {
            Schema::table('carts', function (Blueprint $t) {
                $t->index(['user_id', 'product_variant_id', 'addon_signature'], 'carts_user_variant_addon_idx');
            });
        }
        if (!$this->hasIndexNamed('carts', 'carts_user_channel_idx')) {
            Schema::table('carts', function (Blueprint $t) {
                $t->index(['user_id', 'channel'], 'carts_user_channel_idx');
            });
        }
    }

    private function dropCartIndexes(): void
    {
        if (!Schema::hasTable('carts')) {
            return;
        }
        foreach (['carts_user_variant_addon_idx', 'carts_user_channel_idx'] as $name) {
            if ($this->hasIndexNamed('carts', $name)) {
                Schema::table('carts', fn (Blueprint $t) => $t->dropIndex($name));
            }
        }
    }

    /**
     * The order-time snapshot. `addons` holds resolved names, quantities and any linked
     * variant alongside the ids, so the invoice still reads correctly after an option is
     * renamed and a return can still find the linked stock to put back. `addon_total` is
     * the line's addon money (per-unit amount * quantity) for display and reporting only —
     * the amount itself is already inside `price` / `discounted_price` / `sub_total`.
     */
    private function orderItemAddonColumns(): void
    {
        $this->addColumns('order_items', [
            'addons' => fn (Blueprint $t) => $t->json('addons')->nullable()->after('variant_attributes')
                ->comment('Snapshot: [{group_id, group_name, option_id, option_name, qty, price, is_free, linked_variant_id}]'),
            'addon_total' => fn (Blueprint $t) => $t->decimal('addon_total', 14, 2)->default(0)
                ->after('addons')
                ->comment('Display/reporting only — already included in price, discounted_price and sub_total'),
        ]);
    }

    private function hasIndexNamed(string $table, string $name): bool
    {
        try {
            foreach (\Illuminate\Support\Facades\DB::select('SHOW INDEX FROM `' . str_replace('`', '', $table) . '`') as $row) {
                if (($row->Key_name ?? '') === $name) {
                    return true;
                }
            }
        } catch (\Throwable) {
            // Cannot tell: leave the index alone rather than risk a duplicate.
            return true;
        }

        return false;
    }

    private function brokenImageSetting(): void
    {
        if (!Schema::hasTable('settings') || DB::table('settings')->where('variable', 'broken_image')->exists()) {
            return;
        }

        DB::table('settings')->insert(['variable' => 'broken_image', 'value' => '']);
    }

    // ------------------------------------------------- app version notification

    private const VERSION_EVENT = 'app_version_update';

    /**
     * A version bump can now announce itself to that app's users.
     *
     * Three template rows per audience (push / mail / SMS) plus the admin master
     * switches, seeded exactly as every other catalog event is. SMS starts OFF: a release
     * announcement to the whole user base is the most expensive message a business can send,
     * so it is opted into, not out of.
     *
     * The two `notify_version_update_*` settings are the per-card tick box. They default
     * to 0, so upgrading to 1.5.0 cannot make an existing install start mailing anyone.
     */
    private function appVersionUpdateNotification(): void
    {
        $now = now();

        $copy = [
            'customer' => [
                'notification_templates' => [
                    'title'   => 'Update {{app_name}} to {{version}}',
                    'message' => 'A new {{platform}} version of {{app_name}} ({{version}}) is available. Update now for the latest features and fixes.',
                ],
                'email_templates' => [
                    'title'   => '{{app_name}} {{version}} is now available',
                    'message' => "Hi {{customer_name}},\n\nA new {{platform}} version of {{app_name}} ({{version}}) is now available.\n\nUpdate here: {{store_url}}\n\n{{app_name}}",
                ],
                'sms_templates' => [
                    'message' => '{{app_name}} {{version}} is now available on {{platform}}. Update now: {{store_url}}',
                ],
            ],
            'delivery_boy' => [
                'notification_templates' => [
                    'title'   => 'Update {{app_name}} to {{version}}',
                    'message' => 'A new {{platform}} version of {{app_name}} ({{version}}) is available. Update now to keep taking orders.',
                ],
                'email_templates' => [
                    'title'   => '{{app_name}} {{version}} is now available',
                    'message' => "Hi {{delivery_boy_name}},\n\nA new {{platform}} version of {{app_name}} ({{version}}) is now available. Please update to keep taking orders.\n\nUpdate here: {{store_url}}\n\n{{app_name}}",
                ],
                'sms_templates' => [
                    'message' => '{{app_name}} {{version}} is now available on {{platform}}. Please update: {{store_url}}',
                ],
            ],
        ];

        foreach ($copy as $audience => $tables) {
            $type = self::VERSION_EVENT . '_' . $audience;
            $nameKey = $audience === 'delivery_boy' ? 'delivery_boy_name' : 'customer_name';
            $placeholders = json_encode(['app_name', $nameKey, 'version', 'platform', 'store_url']);

            foreach ($tables as $table => $row) {
                if (!Schema::hasTable($table) || DB::table($table)->where('type', $type)->exists()) {
                    continue;
                }
                DB::table($table)->insert(array_merge($row, [
                    'type'         => $type,
                    'audience'     => $audience,
                    'category'     => 'App',
                    'placeholders' => $placeholders,
                    'created_at'   => $now,
                    'updated_at'   => $now,
                ]));
            }

            if (Schema::hasTable('notification_admin_settings')) {
                foreach (['mail' => 1, 'push' => 1, 'sms' => 0] as $channel => $enabled) {
                    $exists = DB::table('notification_admin_settings')
                        ->where('event_key', self::VERSION_EVENT)
                        ->where('audience', $audience)
                        ->where('channel', $channel)
                        ->exists();
                    if (!$exists) {
                        DB::table('notification_admin_settings')->insert([
                            'event_key'  => self::VERSION_EVENT,
                            'audience'   => $audience,
                            'channel'    => $channel,
                            'is_enabled' => $enabled,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ]);
                    }
                }
            }
        }

        if (Schema::hasTable('settings')) {
            foreach (['notify_version_update_customer', 'notify_version_update_delivery_boy'] as $variable) {
                if (!DB::table('settings')->where('variable', $variable)->exists()) {
                    DB::table('settings')->insert(['variable' => $variable, 'value' => '0']);
                }
            }
        }
    }

    // ------------------------------------------------------ buyer tax identity

    /**
     * A business buyer can now put its own tax registration number on the order — GSTIN
     * in India, VAT number in the EU, TRN in the UAE, ABN in Australia. Without it the
     * invoice the buyer receives is not one it can claim credit against.
     *
     * The field is OPTIONAL everywhere. Most buyers are consumers with no number at all,
     * so making it mandatory would block the ordinary checkout to serve the rare case.
     *
     * The wording and the format rule sit on the COUNTRY, because the scheme follows the
     * buyer's country, not the branch's: a UAE buyer ordering from an Indian branch holds a
     * TRN, not a GSTIN. `App\Services\BuyerTaxIdentity::seedFor()` supplies the starting
     * values per ISO code; an admin editing the country overrides them, and a country with
     * no known scheme starts switched OFF so an upgrade never adds a box to a checkout
     * nobody asked for.
     *
     * The order keeps its own copy of number, label and business name. Reading them live
     * off the address would mean editing an address silently rewrote past invoices — the
     * same reason `order_items.branch_tax_number` exists on the branch side.
     */
    private function buyerTaxIdentity(): void
    {
        $this->addColumns('countries', [
            'buyer_tax_enabled' => fn (Blueprint $t) => $t->tinyInteger('buyer_tax_enabled')->default(0)
                ->comment('Ask the buyer for a tax registration number at checkout'),
            'buyer_tax_label'   => fn (Blueprint $t) => $t->string('buyer_tax_label', 48)->nullable()
                ->comment('What this country calls it: GSTIN, VAT Number, TRN, ABN'),
            'buyer_tax_regex'   => fn (Blueprint $t) => $t->string('buyer_tax_regex', 191)->nullable()
                ->comment('Format check only; blank means accept anything non-empty'),
        ]);

        $this->addColumns('orders', [
            'buyer_tax_number'    => fn (Blueprint $t) => $t->string('buyer_tax_number', 64)->nullable()->after('buyer_region_id'),
            'buyer_tax_label'     => fn (Blueprint $t) => $t->string('buyer_tax_label', 48)->nullable()->after('buyer_tax_number'),
            'buyer_business_name' => fn (Blueprint $t) => $t->string('buyer_business_name', 191)->nullable()->after('buyer_tax_label'),
        ]);

        // Seed the wording per country, leaving any row an admin has already filled alone.
        if (!Schema::hasTable('countries') || !Schema::hasColumn('countries', 'buyer_tax_label')) {
            return;
        }

        $rows = DB::table('countries')->whereNull('buyer_tax_label')->get(['id', 'code']);
        foreach ($rows as $row) {
            [$label, $regex, $enabled] = \App\Services\BuyerTaxIdentity::seedFor($row->code);
            DB::table('countries')->where('id', $row->id)->update([
                'buyer_tax_label'   => $label,
                'buyer_tax_regex'   => $regex,
                'buyer_tax_enabled' => $enabled,
            ]);
        }
    }

    // ------------------------------------------------------- page header colours

    /**
     * A Page Builder page carries its own header colours.
     *
     * A campaign page is built to match the campaign's artwork, and a white bar with dark
     * text fights a dark banner. Both sit beside `title` as page meta rather than inside
     * `draft_json`/`published_json`, because that is where the title itself lives: the
     * chrome around the sections is not one of the sections.
     *
     * The bar is white unless the admin says otherwise, which is what every existing page
     * already shows. The title colour stays null — the apps own the text default, and
     * they are the only ones who know what reads on their own type.
     */
    private function pageHeaderColors(): void
    {
        $this->addColumns('page_layouts', [
            // 9 characters: '#' plus 8 hex digits, so a colour with alpha still fits.
            'header_color' => fn (Blueprint $t) => $t->string('header_color', 9)->default('#FFFFFF')->after('title'),
            'title_color'  => fn (Blueprint $t) => $t->string('title_color', 9)->nullable()->after('header_color'),
        ]);

        /* The column is NOT NULL with a default, so MySQL already wrote white into every
           page built before this release. This only catches a row left holding an empty
           string by an earlier hand-edit, which would render as no colour at all. */
        if (Schema::hasTable('page_layouts') && Schema::hasColumn('page_layouts', 'header_color')) {
            DB::table('page_layouts')->where('header_color', '')->update(['header_color' => '#FFFFFF']);
        }
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
};
