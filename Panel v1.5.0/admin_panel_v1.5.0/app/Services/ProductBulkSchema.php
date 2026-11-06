<?php

namespace App\Services;

use App\Helpers\ProductHelper;
use App\Models\Brand;
use App\Models\Category;
use App\Models\Language;
use App\Models\Branch;
use App\Models\TaxCategory;
use Illuminate\Support\Collection;

/**
 * Column schema for product bulk import/export.
 *
 * The sheet's columns are NOT fixed: they depend on the chosen category (which
 * decides the attribute + custom-field columns) and the chosen branches (which decide
 * the per-branch pricing column groups). Pricing lives in product_variant_branch_stocks
 * keyed (product_variant_id, branch_id) — there is no global price — so a branch
 * dimension is unavoidable.
 *
 * This class is the SINGLE source of truth for those columns. The sample writer, the
 * export writer and the import parser all build from it, so a column can never mean
 * one thing on the way out and another on the way in.
 *
 * Sheet shape: one row per VARIANT. Variants of the same product are grouped by the
 * `handle` column; product-level values are read from a group's first row.
 *
 * A column def is:
 *   key      machine key used by the parser
 *   label    header text shown in the sheet
 *   group    product|variant|attribute|custom|branch  (drives parsing)
 *   type     text|number|decimal|dropdown|date
 *   options  allowed values for dropdown columns (drives sheet data-validation)
 *   required whether a value must be present (create only)
 *   meta     group-specific payload (attribute_id, field_id, branch_id, field key, lang id)
 */
class ProductBulkSchema
{
    /** Product-level pick lists that are the same for every sheet. */
    public const PRODUCT_TYPES = [
        'none' => 0, 'veg' => 1, 'non_veg' => 2, 'chemical' => 3, 'eggetarian' => 4, 'medical' => 5,
    ];

    /** Translatable product fields the product form exposes per language. */
    public const TRANSLATABLE_PRODUCT_FIELDS = [
        'name', 'manufacturer', 'made_in', 'short_description', 'description',
        'meta_title', 'meta_keywords', 'meta_description',
    ];

    /** Translatable product fields the form keeps single-language (default only). */
    public const SINGLE_LANG_PRODUCT_FIELDS = ['tags', 'schema_markup'];

    /** Per-branch pricing/stock columns, in sheet order. */
    public const BRANCH_FIELDS = [
        'is_listed'        => ['label' => 'Listed',           'type' => 'dropdown'],
        'price'            => ['label' => 'Price',            'type' => 'decimal'],
        'discounted_price' => ['label' => 'Discounted Price', 'type' => 'decimal'],
        'purchase_price'   => ['label' => 'Purchase Price',   'type' => 'decimal'],
        'pricing_slabs'    => ['label' => 'Qty Slabs',        'type' => 'text'],
        'stock_status'     => ['label' => 'Stock Status',     'type' => 'dropdown'],
        'available'        => ['label' => 'Available Qty',    'type' => 'number'],
        'min_alert'        => ['label' => 'Min Alert',        'type' => 'number'],
        'is_unlimited_stock' => ['label' => 'Unlimited Stock', 'type' => 'dropdown'],
    ];

    public const ADDON_DIET_TYPES = [
        'none' => 0, 'veg' => 1, 'non_veg' => 2, 'eggetarian' => 4,
    ];

    /** Sheet token => stored enum, for an addon group's input_type. */
    public const ADDON_INPUT_TYPES = ['Radio' => 'radio', 'Checkbox' => 'checkbox'];

    /** Sheet token => stored enum, for where an option's price comes from. */
    public const ADDON_PRICE_SOURCES = ['Custom' => 'custom', 'Follow product' => 'product'];

    public const ADDON_BRANCH_FIELDS = [
        'is_available'     => ['label' => 'Addon Offered',     'type' => 'dropdown'],
        'price'            => ['label' => 'Addon Price',       'type' => 'decimal'],
        'discounted_price' => ['label' => 'Addon Offer Price', 'type' => 'decimal'],
    ];

    public Category $category;
    /** @var Collection<int,Branch> */
    public Collection $branches;
    /** @var Collection<int,Language> */
    public Collection $languages;
    public ?Language $defaultLanguage;
    public bool $forUpdate;

    public string $salesChannel;

    public function __construct(Category $category, Collection $branches, bool $forUpdate = false, ?string $salesChannel = null)
    {
        $this->category  = $category;
        $this->branches    = $branches;
        $this->forUpdate = $forUpdate;
        $this->salesChannel = in_array($salesChannel, ['quick', 'ecommerce', 'both'], true) ? $salesChannel : 'both';

        // Admin-panel languages drive the per-language column sets.
        $this->languages = Language::where('system_type', Language::$systemTypeAdminPanel)
            ->where('status', 1)
            ->leftJoin('supported_languages as sl', 'sl.id', '=', 'languages.supported_language_id')
            ->orderByDesc('languages.is_default')
            ->get(['languages.id', 'languages.is_default', 'sl.name as name']);

        $this->defaultLanguage = $this->languages->firstWhere('is_default', 1) ?? $this->languages->first();
    }

    public static function make(int $categoryId, array $branchIds, bool $forUpdate = false, ?string $salesChannel = null): self
    {
        $category = Category::findOrFail($categoryId);
        $branches = Branch::whereIn('id', $branchIds)->orderBy('name')->get(['id', 'name', 'fulfillment_type']);

        return new self($category, $branches, $forUpdate, $salesChannel);
    }

    /** Yes/No pick list used for every boolean column. */
    public static function boolOptions(): array
    {
        return ['Yes', 'No'];
    }

    /** The sentinel a sheet uses to say "remove the slabs this branch has". */
    public const SLABS_CLEAR = '-';

    /**
     * Quantity slabs as one cell: `5-9:56.05 | 10+:53.10`.
     */
    public static function encodeSlabs($slabs): string
    {
        $parts = [];
        foreach (ProductHelper::normalizeSlabs($slabs) as $slab) {
            $range = $slab['max_qty'] === null
                ? $slab['min_qty'] . '+'
                : $slab['min_qty'] . '-' . $slab['max_qty'];
            $parts[] = $range . ':' . rtrim(rtrim(number_format((float) $slab['price'], 2, '.', ''), '0'), '.');
        }

        return implode(' | ', $parts);
    }

    public static function parseSlabs($raw): array
    {
        $text = trim((string) ($raw ?? ''));
        if ($text === '') {
            return ['action' => 'skip', 'slabs' => [], 'error' => null];
        }
        if ($text === self::SLABS_CLEAR) {
            return ['action' => 'clear', 'slabs' => [], 'error' => null];
        }

        $slabs = [];
        foreach (preg_split('/[|,;]/', $text) as $piece) {
            $piece = trim($piece);
            if ($piece === '') {
                continue;
            }
            // `5-9:56.05` or the open-ended `10+:53.10`.
            if (!preg_match('/^(\d+)\s*(?:-\s*(\d+)|(\+))\s*:\s*(\d+(?:\.\d+)?)$/', $piece, $m)) {
                return ['action' => 'set', 'slabs' => [], 'error' => __('invalid_qty_slab') . ': ' . $piece];
            }
            $min = (int) $m[1];
            $max = ($m[3] ?? '') === '+' ? null : (int) $m[2];
            $price = (float) $m[4];

            if ($min < 1) {
                return ['action' => 'set', 'slabs' => [], 'error' => __('qty_slab_min_must_be_at_least_one') . ': ' . $piece];
            }
            if ($max !== null && $max < $min) {
                return ['action' => 'set', 'slabs' => [], 'error' => __('qty_slab_max_cannot_be_less_than_min') . ': ' . $piece];
            }
            if ($price <= 0) {
                return ['action' => 'set', 'slabs' => [], 'error' => __('qty_slab_price_must_be_greater_than_zero') . ': ' . $piece];
            }
            $slabs[] = ['min_qty' => $min, 'max_qty' => $max, 'price' => $price];
        }

        if ($slabs === []) {
            return ['action' => 'set', 'slabs' => [], 'error' => __('invalid_qty_slab') . ': ' . $text];
        }

        usort($slabs, fn ($a, $b) => $a['min_qty'] <=> $b['min_qty']);

        foreach ($slabs as $i => $slab) {
            if ($slab['max_qty'] === null && $i !== count($slabs) - 1) {
                return ['action' => 'set', 'slabs' => [], 'error' => __('only_the_highest_qty_slab_can_be_open_ended')];
            }
            $next = $slabs[$i + 1] ?? null;
            if ($next && $slab['max_qty'] !== null && $next['min_qty'] <= $slab['max_qty']) {
                return ['action' => 'set', 'slabs' => [], 'error' => __('qty_slabs_cannot_overlap') . ': ' . $slab['min_qty'] . '-' . $slab['max_qty']];
            }
        }

        return ['action' => 'set', 'slabs' => $slabs, 'error' => null];
    }

    public static function parseBool($value, ?int $default = null): ?int
    {
        if ($value === null || $value === '') {
            return $default;
        }
        $v = strtolower(trim((string) $value));
        if (in_array($v, ['yes', 'y', '1', 'true', 'in stock', 'listed', 'active'], true)) {
            return 1;
        }
        if (in_array($v, ['no', 'n', '0', 'false', 'out of stock', 'not listed', 'inactive'], true)) {
            return 0;
        }
        return $default;
    }

    /**
     * The full ordered column list for this (category, branches, languages) selection.
     *
     * @return array<int,array>
     */
    public function columns(): array
    {
        $cols = [];

        // --- identity -------------------------------------------------------
        if ($this->forUpdate) {
            // Export/update keys. product_id + variant_id are what we match on; they
            // are never edited, so the sheet carries them read-only.
            $cols[] = $this->col('product_id', 'Product ID', 'key', 'number', [], true);
            $cols[] = $this->col('variant_id', 'Variant ID', 'key', 'number', [], true);
        } else {
            /* Groups variant rows into one product. It is the product's NAME: that is
               what the operator already has in front of them, it is what the Addons
               sheet points back at, and nothing in the database carries it, so any
               stable text would do. Two different products must not share it. */
            $cols[] = $this->col('handle', 'Product Name*', 'key', 'text', [], true);
        }

        // --- variant identity ----------------------------------------------
        foreach ($this->languages as $lang) {
            $required = !$this->forUpdate && (int) $lang->is_default === 1;
            $cols[] = $this->col(
                'variant_name.' . $lang->id,
                'Variant Name (' . $lang->name . ')' . ($required ? '*' : ''),
                'variant_translation',
                'text',
                [],
                $required,
                ['field' => 'name', 'language_id' => (int) $lang->id]
            );
        }
        $cols[] = $this->col('sku', 'SKU*', 'variant', 'text', [], !$this->forUpdate);
        $cols[] = $this->col('hsn_code', 'HSN Code', 'variant', 'text');
        // Courier shipping data. Blank leaves the variant without it, which a shipping
        // integration handles by falling back to its own default box.
        $cols[] = $this->col('weight', 'Weight (kg)', 'variant', 'number');
        $cols[] = $this->col('length', 'Length (cm)', 'variant', 'number');
        $cols[] = $this->col('breadth', 'Breadth (cm)', 'variant', 'number');
        $cols[] = $this->col('height', 'Height (cm)', 'variant', 'number');

        /* --- attributes: one column per category attribute -------------------
         *
         * A variant is exactly one point in the attribute space (unique
         * (product_variant_id, attribute_id)), so one column each is a faithful
         * mapping.
         *
         * None of them is marked required, because a category's attribute list is a
         * menu, not a checklist: a shirt category may offer Colour, Size, Fabric and
         * Sleeve while a particular shirt only varies by size. That is exactly what
         * the product form already does — it builds variants from the attributes the
         * operator ticked and ignores the rest. The rule is one of the set, not all
         * of it, which no per-column asterisk can express; validateForCreate()
         * enforces it per row instead. */
        foreach ($this->attributes() as $attr) {
            $cols[] = $this->col(
                'attr.' . $attr->id,
                $attr->name,
                'attribute',
                'dropdown',
                $attr->values->pluck('value')->filter()->values()->all(),
                false,
                ['attribute_id' => (int) $attr->id]
            );
        }

        // --- images ---------------------------------------------------------
        // Variant image is required on create; the gallery is always optional.
        $imageRequired = !$this->forUpdate;
        $cols[] = $this->col('image', 'Variant Image (path or URL)' . ($imageRequired ? '*' : ''), 'variant', 'text', [], $imageRequired);
        $cols[] = $this->col('gallery', 'Gallery Images (comma separated)', 'variant', 'text');

        // --- product-level ---------------------------------------------------
        $cols[] = $this->col('brand', 'Brand', 'product', 'dropdown', $this->brandOptions());
        $cols[] = $this->col('tax', 'Tax Category', 'product', 'dropdown', $this->taxOptions());
        $cols[] = $this->col('product_type', 'Product Type', 'product', 'dropdown', array_keys(self::PRODUCT_TYPES));
        // Food products are the ones that can carry addon groups.
        $cols[] = $this->col('is_food', 'Food Item', 'product', 'dropdown', self::boolOptions());
        $cols[] = $this->col('is_addon_only', 'Sold Only As Addon', 'product', 'dropdown', self::boolOptions());
        $cols[] = $this->col('status', 'Status', 'product', 'dropdown', ['Active', 'Inactive']);
        $cols[] = $this->col('total_allowed_quantity', 'Max Qty Per Order', 'product', 'number');
        $cols[] = $this->col('cod_allowed', 'COD Allowed', 'product', 'dropdown', self::boolOptions());
        $cols[] = $this->col('return_status', 'Returnable', 'product', 'dropdown', self::boolOptions());
        $cols[] = $this->col('return_days', 'Return Days', 'product', 'number');
        $cols[] = $this->col('cancelable_status', 'Cancellable', 'product', 'dropdown', self::boolOptions());
        $cols[] = $this->col('till_status_quick', 'Cancellable Till (Quick)', 'product', 'text');
        $cols[] = $this->col('till_status_ecommerce', 'Cancellable Till (Ecommerce)', 'product', 'text');
        $cols[] = $this->col('is_prescription_required', 'Prescription Required', 'product', 'dropdown', ['0', '1']);

        // Single-language product fields (the form does not translate these).
        foreach (self::SINGLE_LANG_PRODUCT_FIELDS as $field) {
            $cols[] = $this->col(
                'ptrans.' . $field . '.' . ($this->defaultLanguage->id ?? 0),
                ucwords(str_replace('_', ' ', $field)),
                'product_translation',
                'text',
                [],
                false,
                ['field' => $field, 'language_id' => (int) ($this->defaultLanguage->id ?? 0)]
            );
        }

        // Per-language product fields.
        foreach (self::TRANSLATABLE_PRODUCT_FIELDS as $field) {
            foreach ($this->languages as $lang) {
                $cols[] = $this->col(
                    'ptrans.' . $field . '.' . $lang->id,
                    ucwords(str_replace('_', ' ', $field)) . ' (' . $lang->name . ')',
                    'product_translation',
                    'text',
                    [],
                    false,
                    ['field' => $field, 'language_id' => (int) $lang->id]
                );
            }
        }

        // --- custom fields (per variant, from the category's sections) --------
        foreach ($this->customFields() as $field) {
            $cols[] = $this->col(
                'custom.' . $field->id,
                $field->field_label,
                'custom',
                $this->customFieldType($field),
                $this->customFieldOptions($field),
                false,
                ['field_id' => (int) $field->id, 'field_type' => $field->field_type]
            );
        }

        // --- per-branch pricing groups ----------------------------------------
        foreach ($this->branches as $branch) {
            foreach (self::BRANCH_FIELDS as $key => $def) {
                $options = [];
                if ($key === 'is_listed' || $key === 'is_unlimited_stock') {
                    $options = self::boolOptions();
                } elseif ($key === 'stock_status') {
                    $options = ['In Stock', 'Out Of Stock'];
                }
                $cols[] = $this->col(
                    'branch.' . $branch->id . '.' . $key,
                    '[' . $this->branchLabel($branch) . '] ' . $def['label'],
                    'branch',
                    $def['type'],
                    $options,
                    false,
                    ['branch_id' => (int) $branch->id, 'field' => $key]
                );
            }
        }

        return $cols;
    }

    /**
     * The Addons sheet's columns — one row per OPTION.
     *
     * A group spans the rows of its options, so the group block repeats on each of
     * them and is read from the run's first row, the same way the Products sheet
     * reads product-level values from a handle group's first row. Order inside a dish
     * is sheet order, which is what ProductAddonApiController::upsertGroup() branches as
     * sort_order.
     *
     * Update mode carries `Group ID` / `Option ID`. They are not decoration: a cart
     * line stores its addons BY OPTION ID and signs them with a sha1 of those ids, so
     * a sheet that could not send ids back would recreate every option on every
     * upload and break every live cart holding that dish.
     *
     * @return array<int,array>
     */
    public function addonColumns(): array
    {
        $cols = [];

        // --- identity -------------------------------------------------------
        if ($this->forUpdate) {
            $cols[] = $this->col('product_id', 'Product ID', 'key', 'number', [], true);
            /* Read-only, and ignored on the way back in — the id is what identifies the
               product. It is here so a row can be read by a human: nobody knows which
               dish 1089 is. */
            $cols[] = $this->col('product_name', 'Product Name', 'key', 'text');
            // Blank on a row the admin added by hand: that becomes a new group/option.
            $cols[] = $this->col('addon_group_id', 'Group ID', 'key', 'number');
            $cols[] = $this->col('addon_option_id', 'Option ID', 'key', 'number');
        } else {
            // The same Product Name typed on the Products sheet. A new product has no
            // id yet, so its name is the only thing the two sheets can share.
            $cols[] = $this->col('handle', 'Product Name*', 'key', 'text', [], true);
        }

        // --- group block (repeated per option row; the run's first row wins) ---
        foreach ($this->languages as $lang) {
            $required = (int) $lang->is_default === 1;
            $cols[] = $this->col(
                'group_name.' . $lang->id,
                'Group Name (' . $lang->name . ')' . ($required ? '*' : ''),
                'addon_group_translation',
                'text',
                [],
                $required,
                ['field' => 'name', 'language_id' => (int) $lang->id]
            );
        }
        $cols[] = $this->col('input_type', 'Selection Type', 'addon_group', 'dropdown', array_keys(self::ADDON_INPUT_TYPES));
        $cols[] = $this->col('is_required', 'Required', 'addon_group', 'dropdown', self::boolOptions());
        $cols[] = $this->col('min_select', 'Min Select', 'addon_group', 'number');
        $cols[] = $this->col('max_select', 'Max Select', 'addon_group', 'number');
        $cols[] = $this->col('max_qty_per_option', 'Max Qty Per Option', 'addon_group', 'number');
        $cols[] = $this->col('group_status', 'Group Status', 'addon_group', 'dropdown', ['Active', 'Inactive']);

        // --- option block ----------------------------------------------------
        foreach ($this->languages as $lang) {
            $required = (int) $lang->is_default === 1;
            $cols[] = $this->col(
                'option_name.' . $lang->id,
                'Option Name (' . $lang->name . ')' . ($required ? '*' : ''),
                'addon_option_translation',
                'text',
                [],
                $required,
                ['field' => 'name', 'language_id' => (int) $lang->id]
            );
        }
        // Keyed `image` on purpose: that is what lets the importer's existing
        // validateImages() check this cell without a second copy of the same rules.
        $cols[] = $this->col('image', 'Option Image (path or URL)', 'addon_option', 'text');
        $cols[] = $this->col('diet_type', 'Diet Type', 'addon_option', 'dropdown', array_keys(self::ADDON_DIET_TYPES));
        // A linked option IS a catalogue item. SKU is how the sheet names a variant
        // everywhere else, so it is the primary key here too.
        $cols[] = $this->col('linked_sku', 'Linked Product SKU', 'addon_option', 'text');
        if ($this->forUpdate) {
            // Exported beside the SKU and wins when filled, because product_variants.sku
            // is nullable: a variant without one could not otherwise round-trip.
            $cols[] = $this->col('linked_variant_id', 'Linked Variant ID', 'key', 'number');
        }
        $cols[] = $this->col('price_source', 'Price From', 'addon_option', 'dropdown', array_keys(self::ADDON_PRICE_SOURCES));
        $cols[] = $this->col('is_free', 'Free', 'addon_option', 'dropdown', self::boolOptions());
        $cols[] = $this->col('option_status', 'Option Status', 'addon_option', 'dropdown', ['Active', 'Inactive']);

        // --- per-branch addon pricing -----------------------------------------
        foreach ($this->branches as $branch) {
            foreach (self::ADDON_BRANCH_FIELDS as $key => $def) {
                $cols[] = $this->col(
                    'addon.' . $branch->id . '.' . $key,
                    '[' . $this->branchLabel($branch) . '] ' . $def['label'],
                    'addon_branch',
                    $def['type'],
                    $key === 'is_available' ? self::boolOptions() : [],
                    false,
                    ['branch_id' => (int) $branch->id, 'field' => $key]
                );
            }
        }

        return $cols;
    }

    /**
     * The branch's name as a column label.
     *
     * Raw, not translated. `branches.name` is translatable, so `$branch->name` resolves
     * against the CURRENT request language — and a queue worker has no request
     * language. The header the admin downloaded would then not match the header the
     * job builds, and because branch columns are optional they would be dropped in
     * silence: products imported with no price, addon options with no branch row.
     */
    private function branchLabel(Branch $branch): string
    {
        return (string) ($branch->getRawOriginal('name') ?: ('Branch #' . $branch->id));
    }

    /** The sentinel an Addons row uses to say "this dish has no addons at all". */
    public const ADDON_CLEAR = '-';

    /**
     * Resolve one addon dropdown cell. Null means "not a value we offer" — callers
     * must treat a blank cell as "not set" BEFORE asking, so that an unknown token can
     * be reported against its own cell instead of silently defaulting.
     */
    public static function addonDietType($value): ?int
    {
        $v = strtolower(trim((string) $value));
        $v = str_replace([' ', '-'], '_', $v);

        return self::ADDON_DIET_TYPES[$v] ?? null;
    }

    public static function addonInputType($value): ?string
    {
        $v = strtolower(trim((string) $value));
        foreach (self::ADDON_INPUT_TYPES as $label => $stored) {
            if ($v === strtolower($label) || $v === $stored) {
                return $stored;
            }
        }
        return null;
    }

    public static function addonPriceSource($value): ?string
    {
        $v = strtolower(trim((string) $value));
        foreach (self::ADDON_PRICE_SOURCES as $label => $stored) {
            if ($v === strtolower($label) || $v === $stored) {
                return $stored;
            }
        }
        // The form calls it "Follow the product"; accept what it says on screen.
        if (in_array($v, ['follow the product', 'from product', 'product price'], true)) {
            return 'product';
        }
        return null;
    }

    /** Active/Inactive cell => 1/0, or null when the token is not one of those. */
    public static function addonStatus($value, int $default = 1): ?int
    {
        $v = strtolower(trim((string) $value));
        if ($v === '') {
            return $default;
        }
        if (in_array($v, ['active', 'yes', '1', 'enabled'], true)) {
            return 1;
        }
        if (in_array($v, ['inactive', 'no', '0', 'disabled'], true)) {
            return 0;
        }
        return null;
    }

    /** @return Collection */
    public function attributes(): Collection
    {
        return $this->category->effectiveAttributes();
    }

    /** Flattened custom fields across the category's effective sections. */
    public function customFields(): Collection
    {
        $fields = collect();
        foreach ($this->category->effectiveCustomSections() as $section) {
            foreach ($section->fields as $field) {
                $fields->push($field);
            }
        }
        return $fields;
    }

    private function customFieldType($field): string
    {
        return match ($field->field_type) {
            'number'   => 'number',
            'date'     => 'date',
            'dropdown', 'checkbox', 'boolean' => 'dropdown',
            default    => 'text',
        };
    }

    private function customFieldOptions($field): array
    {
        if ($field->field_type === 'boolean') {
            return self::boolOptions();
        }
        if (in_array($field->field_type, ['dropdown', 'checkbox'], true)) {
            $opts = $field->options;
            if (is_string($opts)) {
                $opts = json_decode($opts, true);
            }
            return is_array($opts) ? array_values(array_filter(array_map('strval', $opts))) : [];
        }
        return [];
    }

    public function brandOptions(): array
    {
        return Brand::where('status', 1)->orderBy('name')->pluck('name')->filter()->values()->all();
    }

    public function taxOptions(): array
    {
        return TaxCategory::where('status', 1)->orderBy('name')->pluck('name')->values()->all();
    }

    /** Resolve a Brand name back to its id. */
    public function brandId(?string $name): int
    {
        if (!$name) {
            return 0;
        }
        return (int) (Brand::where('name', trim($name))->value('id') ?? 0);
    }

    public function taxCategoryId(?string $label): ?int
    {
        if (!$label) {
            return null;
        }
        $name = trim(preg_replace('/\s*\([^)]*%\)\s*$/', '', $label));
        $id = TaxCategory::where('name', $name)->value('id')
            ?? TaxCategory::where('code', strtoupper(preg_replace('/[^A-Za-z0-9]+/', '_', $name)))->value('id');

        return $id ? (int) $id : null;
    }

    private function col(
        string $key,
        string $label,
        string $group,
        string $type = 'text',
        array $options = [],
        bool $required = false,
        array $meta = []
    ): array {
        return compact('key', 'label', 'group', 'type', 'options', 'required', 'meta');
    }
}
