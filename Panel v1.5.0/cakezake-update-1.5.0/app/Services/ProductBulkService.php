<?php

namespace App\Services;

use App\Helpers\ProductHelper;
use App\Http\Controllers\API\ProductAddonApiController;
use App\Http\Controllers\API\ProductApisController;
use App\Models\Product;
use App\Models\ProductAddonGroup;
use App\Models\ProductAddonOption;
use App\Models\ProductImages;
use App\Models\ProductVariant;
use App\Models\ProductVariantAttributeValue;
use App\Models\ProductVariantCustomValue;
use App\Models\ProductVariantBranchStock;
use App\Models\Branch;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use PhpOffice\PhpSpreadsheet\Cell\Coordinate;
use PhpOffice\PhpSpreadsheet\Cell\DataValidation;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

/**
 * Product bulk import/export.
 *
 * Two flows, deliberately asymmetric:
 *
 *  CREATE (upload) — builds the exact payload the product form posts and hands it to
 *  ProductApisController@save. The importer therefore inherits the real writer's
 *  behaviour (slug derivation, translation mirroring, PVSS sync, SKU checks) instead
 *  of duplicating it and drifting away from it — which is how the old importer ended
 *  up writing columns that no longer existed.
 *
 *  UPDATE — a targeted MERGE. It never calls the form's sync helpers, because those
 *  treat the payload as the complete truth and hard-delete any variant or branch price
 *  absent from it. A partial sheet ("re-price branch 3") must not destroy branch 5's
 *  pricing or the variants that weren't exported, so update only touches the cells
 *  actually present in the file.
 */
class ProductBulkService
{
    /** Hard cap so one file can't exhaust memory/execution time (imports are synchronous). */
    public const MAX_ROWS = 2000;

    /**
     * Hard cap for the Addons sheet.
     *
     * Its own, because its rows are per OPTION, not per variant: 300 dishes with four
     * groups of five options each is 6,000 rows, which the product cap would refuse
     * for no reason. An addon row carries no attribute or custom-field columns, so
     * 4,000 of them cost about what 2,000 product rows already do.
     */
    public const MAX_ADDON_ROWS = 4000;

    /** Each dish is one save() call in its own transaction: this is what bounds wall-clock. */
    public const MAX_ADDON_DISHES = 500;

    /** The second sheet, by name — the sample, the export and the reader all use this. */
    public const ADDONS_SHEET = 'Addons';

    /** The name on the grey example rows of both sheets. */
    private const SAMPLE_PRODUCT_NAME = 'Sample Product 1';

    /**
     * Headers that used to be called something else.
     *
     * A sheet downloaded before a column was renamed is still sitting in someone's
     * downloads folder, and matching is by label, so without this the file would come
     * back missing a required column.
     */
    private const HEADER_ALIASES = [
        'product handle' => 'handle',
        'dish handle'    => 'handle',
    ];

    /** Hidden sheet the dropdown ranges point at. */
    private const LISTS_SHEET = 'Lists';

    /** sku => variant id, for linked options resolved against the existing catalogue. */
    private array $linkedVariantMemo = [];

    /* ===================================================================== */
    /* Sample + export                                                        */
    /* ===================================================================== */

    /** Blank template whose columns match the chosen category + branches. */
    public function sample(ProductBulkSchema $schema): string
    {
        $columns = $schema->columns();
        $spreadsheet = new Spreadsheet();
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Products');

        $this->writeHeader($sheet, $columns);

        // The Addons sheet is created before any validation runs, so the book comes
        // out Products, Addons, Lists, Instructions — createSheet() appends.
        $addonColumns = $schema->addonColumns();
        $addonSheet = $spreadsheet->createSheet();
        $addonSheet->setTitle(self::ADDONS_SHEET);
        $this->writeHeader($addonSheet, $addonColumns);

        $used = $this->applyValidation($sheet, $columns, 2, 200);
        $this->applyValidation($addonSheet, $addonColumns, 2, 200, $used);

        // One worked example row so the grouping rule is self-evident: two variants
        // sharing a handle = one product with two variants.
        $this->writeExampleRows($sheet, $columns, $schema);
        $this->writeAddonExampleRows($addonSheet, $addonColumns, $schema);

        $this->addNotesSheet($spreadsheet, $schema);

        return $this->save($spreadsheet);
    }

    /** Existing products for the chosen category + branches, ready to edit and re-upload. */
    public function export(ProductBulkSchema $schema): string
    {
        $columns = $schema->columns();
        $spreadsheet = new Spreadsheet();
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Products');

        $this->writeHeader($sheet, $columns);

        $branchIds = $schema->branches->pluck('id')->all();
        $products = Product::where('category_id', $schema->category->id)
            ->with([
                'variants.branchStocks' => fn ($q) => $q->whereIn('branch_id', $branchIds),
                'variants.attributeValues',
                'variants.customValues',
                'variants.translations',
                'variants.images',
                'translations',
                'brand',
                'taxCategory',
            ])
            ->orderBy('id')
            ->get();

        $row = 2;
        foreach ($products as $product) {
            foreach ($product->variants as $variant) {
                $this->writeExportRow($sheet, $columns, $row, $product, $variant, $schema);
                $row++;
            }
        }

        $addonColumns = $schema->addonColumns();
        $addonSheet = $spreadsheet->createSheet();
        $addonSheet->setTitle(self::ADDONS_SHEET);
        $this->writeHeader($addonSheet, $addonColumns);
        $addonRow = $this->writeAddonExportRows($addonSheet, $addonColumns, $schema, $products);

        $used = $this->applyValidation($sheet, $columns, 2, max($row - 1, 2));
        // Unlike Products, this sheet is one the admin ADDS rows to — a new group, a
        // new option, a dish that had no menu — so the dropdowns run past the data.
        $this->applyValidation($addonSheet, $addonColumns, 2, max($addonRow - 1, 2) + 200, $used);

        $this->addNotesSheet($spreadsheet, $schema);

        return $this->save($spreadsheet);
    }

    private function writeHeader($sheet, array $columns): void
    {
        foreach ($columns as $i => $col) {
            $letter = Coordinate::stringFromColumnIndex($i + 1);
            $sheet->setCellValue($letter . '1', $col['label']);
            $sheet->getColumnDimension($letter)->setWidth(max(14, min(38, strlen($col['label']) + 4)));
        }
        $last = Coordinate::stringFromColumnIndex(count($columns));
        $style = $sheet->getStyle('A1:' . $last . '1');
        $style->getFont()->setBold(true);
        $style->getFill()->setFillType(Fill::FILL_SOLID)->getStartColor()->setRGB('E8EEF7');
        $style->getAlignment()->setVertical(Alignment::VERTICAL_CENTER)->setWrapText(true);
        $sheet->getRowDimension(1)->setRowHeight(30);
        $sheet->freezePane('A2');
    }

    /**
     * Range-based data validation. The old importer looped every cell of every
     * dropdown column for 999 rows, which was a real memory sink; one validation
     * object per column range does the same job.
     *
     * Every list is parked on a hidden sheet and referenced as a range, never written
     * inline. Excel caps an inline list at 255 characters, which quietly cost the
     * dropdown on exactly the columns that need one most — Color (63 values, 680
     * chars) and Pack Size (247 values, 1,716) came out as free text while Size and
     * Ring Size got their list. A range reference has no such cap, and it also keeps
     * values with a comma intact instead of rewriting them to a space, so what the
     * sheet offers is exactly what the importer will match.
     *
     * One workbook now holds two sheets with dropdowns, and both park their lists on
     * the SAME hidden sheet — so the column counter is carried in and handed back
     * rather than restarting. Restarting it would rewrite the first sheet's list
     * columns in place while its validations still point at those fixed ranges, which
     * turns every Products dropdown into whatever the Addons sheet happened to need.
     *
     * @return int the last hidden-sheet column used, to pass to the next call
     */
    private function applyValidation($sheet, array $columns, int $firstRow, int $lastRow, int $listColumn = 0): int
    {
        $lists = $this->listsSheet($sheet->getParent());

        foreach ($columns as $i => $col) {
            if ($col['type'] !== 'dropdown' || empty($col['options'])) {
                continue;
            }

            $options = array_values(array_filter(
                array_map(fn ($o) => trim((string) $o), $col['options']),
                fn ($o) => $o !== ''
            ));
            if (!$options) {
                continue;
            }

            // One column of the hidden sheet per dropdown, with its header for
            // whoever unhides it.
            $listColumn++;
            $listLetter = Coordinate::stringFromColumnIndex($listColumn);
            $lists->setCellValue($listLetter . '1', $col['label']);
            foreach ($options as $n => $option) {
                // setCellValueExplicit keeps "007" or "1-2" as typed, and stops Excel
                // reading a size like "5/8" as a date.
                $lists->setCellValueExplicit(
                    $listLetter . ($n + 2),
                    $option,
                    \PhpOffice\PhpSpreadsheet\Cell\DataType::TYPE_STRING
                );
            }
            $list = sprintf("'%s'!$%s$2:$%s$%d", $lists->getTitle(), $listLetter, $listLetter, count($options) + 1);

            $letter = Coordinate::stringFromColumnIndex($i + 1);
            $validation = $sheet->getCell($letter . $firstRow)->getDataValidation();
            $validation->setType(DataValidation::TYPE_LIST)
                ->setErrorStyle(DataValidation::STYLE_INFORMATION)
                ->setAllowBlank(true)
                ->setShowInputMessage(true)
                ->setShowErrorMessage(true)
                ->setShowDropDown(true)
                ->setErrorTitle(__('invalid_value'))
                ->setError(__('please_pick_a_value_from_the_list'))
                ->setFormula1($list);
            $sheet->setDataValidation($letter . $firstRow . ':' . $letter . $lastRow, clone $validation);
        }

        // Nothing to hide if no column had a list — and nothing an earlier sheet put
        // there either, which is what a non-zero carried-in counter would mean.
        if ($listColumn === 0) {
            $sheet->getParent()->removeSheetByIndex($sheet->getParent()->getIndex($lists));
        }

        return $listColumn;
    }

    /**
     * The hidden sheet holding every dropdown's values.
     *
     * Hidden rather than absent because Excel will not validate against a range it
     * cannot resolve, and hidden rather than visible because it is plumbing. The
     * reader only ever looks at sheet 0, so the extra sheet changes nothing on
     * re-upload.
     */
    private function listsSheet(Spreadsheet $spreadsheet): Worksheet
    {
        $existing = $spreadsheet->getSheetByName(self::LISTS_SHEET);
        if ($existing) {
            return $existing;
        }

        $lists = $spreadsheet->createSheet();
        $lists->setTitle(self::LISTS_SHEET);
        $lists->setSheetState(Worksheet::SHEETSTATE_HIDDEN);

        return $lists;
    }

    private function writeExampleRows($sheet, array $columns, ProductBulkSchema $schema): void
    {
        $attrs = $schema->attributes();
        if ($attrs->isEmpty()) {
            return;
        }
        // Two rows sharing one handle => one product, two variants.
        for ($n = 0; $n < 2; $n++) {
            $rowNo = $n + 2;
            foreach ($columns as $i => $col) {
                $letter = Coordinate::stringFromColumnIndex($i + 1);
                $value = match (true) {
                    $col['key'] === 'handle' => self::SAMPLE_PRODUCT_NAME,
                    $col['key'] === 'sku' => 'SAMPLE-SKU-' . ($n + 1),
                    str_starts_with($col['key'], 'variant_name.') => 'Sample Variant ' . ($n + 1),
                    $col['group'] === 'attribute' => (string) ($col['options'][$n] ?? ($col['options'][0] ?? '')),
                    str_ends_with($col['key'], '.is_listed') => 'Yes',
                    str_ends_with($col['key'], '.price') => '100',
                    str_ends_with($col['key'], '.discounted_price') => '90',
                    str_ends_with($col['key'], '.purchase_price') => '70',
                    str_ends_with($col['key'], '.pricing_slabs') => '5-9:85 | 10+:80',
                    str_ends_with($col['key'], '.stock_status') => 'In Stock',
                    str_ends_with($col['key'], '.available') => '10',
                    default => '',
                };
                if ($value !== '') {
                    $sheet->setCellValueExplicit($letter . $rowNo, $value, \PhpOffice\PhpSpreadsheet\Cell\DataType::TYPE_STRING);
                }
            }
            $sheet->getStyle('A' . $rowNo . ':' . Coordinate::stringFromColumnIndex(count($columns)) . $rowNo)
                ->getFont()->getColor()->setRGB('9AA4B2');
        }
    }

    /** Human-readable rules, shipped inside the workbook instead of a separate .txt. */
    private function addNotesSheet(Spreadsheet $spreadsheet, ProductBulkSchema $schema): void
    {
        $notes = $spreadsheet->createSheet();
        $notes->setTitle('Instructions');
        $lines = [
            [__('product_bulk_instructions')],
            [''],
            ['1. ' . __('bulk_note_one_row_per_variant')],
            ['2. ' . __('bulk_note_handle_groups_variants')],
            ['3. ' . __('bulk_note_columns_match_selection')],
            ['4. ' . __('bulk_note_sku_unique')],
            ['5. ' . __('bulk_note_listed_needs_price')],
            ['6. ' . __('bulk_note_discount_lte_price')],
            ['7. ' . __('bulk_note_attributes_unique_combo')],
            ['8. ' . __('bulk_note_images_path_or_url')],
            ['9. ' . __('bulk_note_update_is_merge')],
            ['10. ' . __('bulk_note_qty_slabs_format')],
            ['11. ' . __('bulk_note_grey_rows_are_examples')],
            [''],
            // Row A15 — styled as a heading below.
            [__('addons_sheet')],
            [''],
            ['1. ' . __('bulk_note_addon_which_product')],
            ['2. ' . __('bulk_note_addon_one_row_per_option')],
            ['3. ' . __('bulk_note_addon_group_block_repeats')],
            ['4. ' . __('bulk_note_addon_rows_must_be_together')],
            ['5. ' . __('bulk_note_addon_replaces_whole_menu')],
            ['6. ' . __('bulk_note_addon_absent_dish_untouched')],
            ['7. ' . __('bulk_note_addon_clear_with_dash') . ': ' . ProductBulkSchema::ADDON_CLEAR],
            ['8. ' . __('bulk_note_addon_needs_food_item')],
            ['9. ' . __('bulk_note_addon_offered_meaning')],
            ['10. ' . __('bulk_note_addon_free_still_offered')],
            ['11. ' . __('bulk_note_addon_follow_product_ignores_prices')],
            ['12. ' . __('bulk_note_addon_linked_by_sku')],
            ['13. ' . __('bulk_note_addon_never_edit_ids')],
            ['14. ' . __('bulk_note_addon_dish_without_menu')],
            ['15. ' . __('bulk_note_addon_linked_tax')],
            [''],
            [__('category') . ': ' . $schema->category->name],
            [__('branches') . ': ' . $schema->branches->pluck('name')->implode(', ')],
            [__('max_rows') . ': ' . self::MAX_ROWS],
            [__('max_addon_rows') . ': ' . self::MAX_ADDON_ROWS],
        ];
        $notes->fromArray($lines, null, 'A1');
        $notes->getColumnDimension('A')->setWidth(110);
        $notes->getStyle('A1')->getFont()->setBold(true)->setSize(13);
        $notes->getStyle('A15')->getFont()->setBold(true)->setSize(13);
        $notes->getStyle('A1:A40')->getAlignment()->setWrapText(true);
    }

    private function writeExportRow($sheet, array $columns, int $row, Product $product, ProductVariant $variant, ProductBulkSchema $schema): void
    {
        $attrByAttrId = $variant->attributeValues->keyBy('attribute_id');
        $customByField = $variant->customValues->keyBy('category_custom_field_id');
        $stockByBranch = $variant->branchStocks->keyBy('branch_id');

        foreach ($columns as $i => $col) {
            $letter = Coordinate::stringFromColumnIndex($i + 1);
            $value = $this->exportValue($col, $product, $variant, $schema, $attrByAttrId, $customByField, $stockByBranch);
            if ($value === null || $value === '') {
                continue;
            }
            // Force text so SKUs/HSNs like "0012" keep their leading zeros.
            $sheet->setCellValueExplicit($letter . $row, (string) $value, \PhpOffice\PhpSpreadsheet\Cell\DataType::TYPE_STRING);
        }
    }

    private function exportValue(array $col, Product $product, ProductVariant $variant, ProductBulkSchema $schema, $attrByAttrId, $customByField, $stockByBranch)
    {
        $meta = $col['meta'];

        switch ($col['group']) {
            case 'key':
                return $col['key'] === 'product_id' ? $product->id : $variant->id;

            case 'variant':
                return match ($col['key']) {
                    'sku' => $variant->sku,
                    'hsn_code' => $variant->hsn_code,
                    'weight' => $variant->weight,
                    'length' => $variant->length,
                    'breadth' => $variant->breadth,
                    'height' => $variant->height,
                    'image' => $variant->getRawOriginal('image'),
                    // Gallery = the variant's product_images rows, comma-separated.
                    'gallery' => $variant->images->pluck('image')->filter()->implode(', '),
                    default => null,
                };

            case 'variant_translation':
                return $this->translatedField($variant, 'name', (int) $meta['language_id']);

            case 'attribute':
                $row = $attrByAttrId->get($meta['attribute_id']);
                return $row?->attributeValue?->value;

            case 'custom':
                $cv = $customByField->get($meta['field_id']);
                if (!$cv) {
                    return null;
                }
                return match ($meta['field_type']) {
                    'number' => $cv->value_number,
                    'date' => $cv->value_date ?: null,
                    'boolean' => $cv->value_text === null || $cv->value_text === '' ? null : ((int) $cv->value_text === 1 ? 'Yes' : 'No'),
                    'dropdown', 'checkbox' => is_array($cv->value_json) ? implode(', ', $cv->value_json) : $cv->value_text,
                    default => $cv->value_text,
                };

            case 'product':
                return $this->exportProductValue($col['key'], $product, $schema);

            case 'product_translation':
                return $this->translatedField($product, $meta['field'], (int) $meta['language_id']);

            case 'branch':
                $stock = $stockByBranch->get($meta['branch_id']);
                if (!$stock) {
                    return null;
                }
                return match ($meta['field']) {
                    'is_listed' => ((int) $stock->is_listed === 1 ? 'Yes' : 'No'),
                    'is_unlimited_stock' => ((int) $stock->is_unlimited_stock === 1 ? 'Yes' : 'No'),
                    'stock_status' => ((int) $stock->stock_status === 1 ? 'In Stock' : 'Out Of Stock'),
                    'price' => $stock->price,
                    'discounted_price' => $stock->discounted_price,
                    'purchase_price' => $stock->purchase_price,
                    'pricing_slabs' => ProductBulkSchema::encodeSlabs($stock->pricing_slabs),
                    'available' => $stock->available,
                    'min_alert' => $stock->min_alert,
                    default => null,
                };
        }

        return null;
    }

    /**
     * The exact stored translation for one language — no fallback.
     *
     * HasTranslations::getTranslationsAttribute() turns `$model->translations` into a
     * plain array, and getTranslatedAttribute() falls back to the default language.
     * Either would be wrong here: a fallback would print the default language's text
     * in another language's column, and re-uploading that sheet would persist it as a
     * real translation. An empty cell must stay empty.
     */
    private function translatedField($model, string $field, int $languageId)
    {
        if ($model->relationLoaded('translations')) {
            return $model->getRelation('translations')->firstWhere('language_id', $languageId)?->{$field};
        }
        return $model->translation($languageId)?->{$field};
    }

    private function exportProductValue(string $key, Product $product, ProductBulkSchema $schema)
    {
        switch ($key) {
            case 'brand':
                return $product->brand?->name;
            case 'tax':
                return $product->taxCategory?->name;
            case 'product_type':
                return array_search((int) $product->product_type, ProductBulkSchema::PRODUCT_TYPES, true) ?: null;
            case 'status':
                return (int) $product->status === 1 ? 'Active' : 'Inactive';
            case 'cod_allowed':
            case 'return_status':
            case 'cancelable_status':
                return (int) $product->{$key} === 1 ? 'Yes' : 'No';
            default:
                return $product->{$key};
        }
    }

    /* ===================================================================== */
    /* Addons sheet — writing                                                 */
    /* ===================================================================== */

    /**
     * Every exported product's addon setup, one row per option.
     *
     * Ordered product → sort_order → id so a group's options come out as one
     * contiguous run, which is exactly how the reader groups them again.
     *
     * @param  \Illuminate\Support\Collection<int,Product> $products
     * @return int the next free row
     */
    private function writeAddonExportRows($sheet, array $columns, ProductBulkSchema $schema, $products): int
    {
        $food = $products->filter(fn (Product $p) => (int) $p->is_food === 1);
        $foodIds = $food->pluck('id')->all();
        if (!$foodIds) {
            return 2;
        }
        // Raw, so the column reads the same whatever language the panel is in.
        $nameById = $food->mapWithKeys(fn (Product $p) => [(int) $p->id => (string) $p->getRawOriginal('name')])->all();

        $branchIds = $schema->branches->pluck('id')->all();
        $groups = ProductAddonGroup::whereIn('product_id', $foodIds)
            ->with([
                'translations',
                'options.translations',
                'options.branchPrices' => fn ($q) => $q->whereIn('branch_id', $branchIds),
                'options.linkedVariant:id,sku,product_id',
            ])
            ->orderBy('product_id')
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get();

        $row = 2;
        foreach ($groups as $group) {
            foreach ($group->options as $option) {
                $priceByBranch = $option->branchPrices->keyBy('branch_id');
                foreach ($columns as $i => $col) {
                    $value = $this->addonExportValue($col, $group, $option, $priceByBranch, $schema, $nameById);
                    if ($value === null || $value === '') {
                        continue;
                    }
                    $letter = Coordinate::stringFromColumnIndex($i + 1);
                    $sheet->setCellValueExplicit(
                        $letter . $row,
                        (string) $value,
                        \PhpOffice\PhpSpreadsheet\Cell\DataType::TYPE_STRING
                    );
                }
                $row++;
            }
        }

        return $row;
    }

    private function addonExportValue(array $col, ProductAddonGroup $group, ProductAddonOption $option, $priceByBranch, ProductBulkSchema $schema, array $nameById = [])
    {
        $meta = $col['meta'];

        switch ($col['group']) {
            case 'key':
                return match ($col['key']) {
                    'product_id'        => $group->product_id,
                    'product_name'      => $nameById[(int) $group->product_id] ?? null,
                    'addon_group_id'    => $group->id,
                    'addon_option_id'   => $option->id,
                    'linked_variant_id' => $option->linked_variant_id,
                    default             => null,
                };

            case 'addon_group_translation':
                return $this->addonName($group, (int) $meta['language_id'], $schema);

            case 'addon_option_translation':
                return $this->addonName($option, (int) $meta['language_id'], $schema);

            case 'addon_group':
                return match ($col['key']) {
                    'input_type' => array_search($group->input_type, ProductBulkSchema::ADDON_INPUT_TYPES, true) ?: 'Radio',
                    'is_required' => ((int) $group->is_required === 1 ? 'Yes' : 'No'),
                    'min_select' => (int) $group->min_select,
                    'max_select' => (int) $group->max_select,
                    'max_qty_per_option' => (int) $group->max_qty_per_option,
                    'group_status' => ((int) $group->status === 1 ? 'Active' : 'Inactive'),
                    default => null,
                };

            case 'addon_option':
                return $this->addonOptionExportValue($col['key'], $option);

            case 'addon_branch':
                $prices = $priceByBranch->get($meta['branch_id']);
                if (!$prices) {
                    // No row at all: this branch has never been offered the option.
                    return null;
                }
                return match ($meta['field']) {
                    'is_available' => ((int) $prices->is_available === 1 ? 'Yes' : 'No'),
                    'price' => $prices->price,
                    // 0 is the "no offer" marker, and a blank cell says the same thing.
                    'discounted_price' => (float) $prices->discounted_price > 0 ? $prices->discounted_price : null,
                    default => null,
                };
        }

        return null;
    }

    private function addonOptionExportValue(string $key, ProductAddonOption $option)
    {
        switch ($key) {
            case 'image':
                // Raw, not imagePath(): a linked option's picture is its product's and
                // is nulled on save, so resolving it here would export a value that
                // cannot come back.
                return $option->getRawOriginal('image');

            case 'diet_type':
                $raw = $option->getRawOriginal('product_type');
                if ($raw === null || $raw === '') {
                    return null;
                }
                return array_search((int) $raw, ProductBulkSchema::ADDON_DIET_TYPES, true) ?: null;

            case 'linked_sku':
                return $option->linkedVariant?->sku;

            case 'price_source':
                /* A linked variant is nullOnDelete while price_source stays 'product',
                   which leaves an option whose own validation rejects it. Export says
                   Custom in that case, so an untouched export re-uploads. */
                $source = $option->linked_variant_id ? $option->price_source : 'custom';
                return array_search($source, ProductBulkSchema::ADDON_PRICE_SOURCES, true) ?: 'Custom';

            case 'is_free':
                return (int) $option->is_free === 1 ? 'Yes' : 'No';

            case 'option_status':
                return (int) $option->status === 1 ? 'Active' : 'Inactive';
        }

        return null;
    }

    /**
     * A group's or option's name for one language column.
     *
     * The default language reads the BASE column, never a translation row: the admin
     * form posts the default name as the plain `name` and leaves it out of
     * `translations`, so a group built there has no default-language row at all. A
     * no-fallback lookup would export a blank cell, which then fails its own
     * required-name check on re-upload.
     */
    private function addonName($model, int $languageId, ProductBulkSchema $schema)
    {
        if ($languageId === (int) ($schema->defaultLanguage->id ?? 0)) {
            return $model->getRawOriginal('name');
        }

        return $this->translatedField($model, 'name', $languageId);
    }

    /** One group of two options, so the repeat-the-group-block rule is self-evident. */
    private function writeAddonExampleRows($sheet, array $columns, ProductBulkSchema $schema): void
    {
        $branch = $schema->branches->first();

        for ($n = 0; $n < 2; $n++) {
            $rowNo = $n + 2;
            foreach ($columns as $i => $col) {
                $letter = Coordinate::stringFromColumnIndex($i + 1);
                $value = match (true) {
                    $col['key'] === 'handle' => self::SAMPLE_PRODUCT_NAME,
                    str_starts_with($col['key'], 'group_name.') => 'Choose crust',
                    $col['key'] === 'input_type' => 'Radio',
                    $col['key'] === 'is_required' => 'Yes',
                    $col['key'] === 'min_select', $col['key'] === 'max_select',
                    $col['key'] === 'max_qty_per_option' => '1',
                    $col['key'] === 'group_status' => 'Active',
                    str_starts_with($col['key'], 'option_name.') => $n === 0 ? 'Thin crust' : 'Cheese burst',
                    $col['key'] === 'diet_type' => 'veg',
                    $col['key'] === 'price_source' => 'Custom',
                    $col['key'] === 'is_free' => $n === 0 ? 'Yes' : 'No',
                    $col['key'] === 'option_status' => 'Active',
                    // A free option still has to be OFFERED somewhere, or it can never
                    // be served; the example shows that.
                    $branch && $col['key'] === 'addon.' . $branch->id . '.is_available' => 'Yes',
                    $branch && $col['key'] === 'addon.' . $branch->id . '.price' => $n === 0 ? '0' : '25',
                    default => '',
                };
                if ($value !== '') {
                    $sheet->setCellValueExplicit($letter . $rowNo, $value, \PhpOffice\PhpSpreadsheet\Cell\DataType::TYPE_STRING);
                }
            }
            $sheet->getStyle('A' . $rowNo . ':' . Coordinate::stringFromColumnIndex(count($columns)) . $rowNo)
                ->getFont()->getColor()->setRGB('9AA4B2');
        }
    }

    /* ===================================================================== */
    /* Addons sheet — grouping, validating, writing                           */
    /* ===================================================================== */

    /**
     * Fold option rows into dishes and groups.
     *
     * A group is a CONTIGUOUS RUN of rows, not every row that happens to share a
     * name: sheet order is the only thing that can express the order the options
     * appear in the app, and it is what upsertGroup() branches as sort_order. A run ends
     * when the dish or the group identity changes, and a dish or group that comes back
     * after something else intervened is an error rather than a guess.
     *
     * @return array{dishes: array, errors: array}
     */
    public function groupAddonRows(array $rows, ProductBulkSchema $schema): array
    {
        $nameKey  = 'group_name.' . ($schema->defaultLanguage->id ?? 0);
        $dishes   = [];
        $errors   = [];
        $lastDish = null;
        $lastGroup = null;

        foreach ($rows as $row) {
            $r = (int) ($row['__row'] ?? 0);

            if ($schema->forUpdate) {
                $productId = (int) ($row['product_id'] ?? 0);
                $dishKey = 'p' . $productId;
                $valid = $productId > 0;
            } else {
                $handle = trim((string) ($row['handle'] ?? ''));
                $dishKey = 'h' . mb_strtolower($handle);
                $valid = $handle !== '';
            }

            if (!$valid) {
                $errors[] = $this->addonError($r, $schema->forUpdate ? __('product_id_is_required') : __('dish_handle_is_required'));
                continue;
            }

            if ($dishKey !== $lastDish && isset($dishes[$dishKey])) {
                $errors[] = $this->addonError($r, __('addon_rows_of_a_dish_must_be_together'));
                continue;
            }

            if (!isset($dishes[$dishKey])) {
                $dishes[$dishKey] = [
                    'handle'     => $schema->forUpdate ? null : trim((string) $row['handle']),
                    'product_id' => $schema->forUpdate ? (int) $row['product_id'] : null,
                    'first_row'  => $r,
                    'clear'      => false,
                    'runs'       => [],
                ];
            }

            $name = trim((string) ($row[$nameKey] ?? ''));

            // The sentinel row: this dish is to end up with no addons at all.
            if ($name === ProductBulkSchema::ADDON_CLEAR) {
                $dishes[$dishKey]['clear'] = true;
                $lastDish = $dishKey;
                $lastGroup = null;
                continue;
            }

            $groupId = (int) ($row['addon_group_id'] ?? 0);
            $groupKey = $groupId > 0 ? 'g' . $groupId : 'n' . mb_strtolower($name);

            if ($dishKey !== $lastDish || $groupKey !== $lastGroup) {
                $seen = false;
                foreach ($dishes[$dishKey]['runs'] as $run) {
                    if ($run['key'] === $groupKey) {
                        $seen = true;
                        break;
                    }
                }
                if ($seen) {
                    $errors[] = $this->addonError($r, __('addon_rows_of_a_group_must_be_together') . ($name !== '' ? ': ' . $name : ''));
                    continue;
                }
                $dishes[$dishKey]['runs'][] = ['key' => $groupKey, 'first' => $row, 'rows' => []];
            }

            $dishes[$dishKey]['runs'][count($dishes[$dishKey]['runs']) - 1]['rows'][] = $row;
            $lastDish = $dishKey;
            $lastGroup = $groupKey;
        }

        return ['dishes' => $dishes, 'errors' => $errors];
    }

    /**
     * Validate the whole Addons sheet before a single row is written.
     *
     * The controller this importer writes through validates too, but it answers with
     * ONE message for the whole payload and no row number — useless to someone
     * holding a 4,000-row sheet. So its rules are reproduced here, per row, and its
     * own pass stays as the second line of defence.
     *
     * @return array<int,array{sheet:string,row:int,error:string}>
     */
    public function validateAddons(array $addonRows, array $productRows, ProductBulkSchema $schema): array
    {
        if ($addonRows === []) {
            return [];
        }

        $grouped = $this->groupAddonRows($addonRows, $schema);
        $errors  = $grouped['errors'];
        $dishes  = $grouped['dishes'];

        if (count($dishes) > self::MAX_ADDON_DISHES) {
            $errors[] = $this->addonError(0, __('too_many_addon_dishes_max') . ': ' . self::MAX_ADDON_DISHES);

            return $errors;
        }

        $ctx       = $this->addonContext($productRows);
        $owners    = $this->addonOwners($addonRows);
        $links     = $this->addonLinkTargets($addonRows);
        $nameKey   = 'group_name.' . ($schema->defaultLanguage->id ?? 0);
        $optKey    = 'option_name.' . ($schema->defaultLanguage->id ?? 0);

        foreach ($dishes as $dish) {
            $firstRow = $dish['first_row'];

            /* ---- the dish itself ---- */
            if ($schema->forUpdate) {
                $product = Product::find($dish['product_id']);
                if (!$product) {
                    $errors[] = $this->addonError($firstRow, __('product_not_found') . ': ' . $dish['product_id']);
                    continue;
                }
                if ((int) $product->category_id !== (int) $schema->category->id) {
                    $errors[] = $this->addonError($firstRow, __('product_is_not_in_the_selected_category') . ': ' . $dish['product_id']);
                    continue;
                }
                $isFood = $ctx['food_by_id'][$dish['product_id']] ?? (int) $product->is_food;
                $ownProductId = (int) $product->id;
            } else {
                $handle = mb_strtolower((string) $dish['handle']);
                if (!isset($ctx['handles'][$handle])) {
                    // `handle` exists only inside the sheet, so there is nothing else
                    // to resolve it against. An existing dish is update mode's job.
                    $errors[] = $this->addonError($firstRow, __('addon_dish_handle_not_on_products_sheet') . ': ' . $dish['handle']);
                    continue;
                }
                $isFood = $ctx['handles'][$handle]['is_food'] ?? 0;
                $ownProductId = null;
            }

            /* The guard that matters most: save() WIPES a non-food product's groups
               and answers "success", so without this an update that flips Food Item to
               No would quietly delete a live menu and report an import. */
            if ((int) $isFood !== 1) {
                $errors[] = $this->addonError($firstRow, __('addons_only_for_food_products'));
                continue;
            }

            if ($dish['clear']) {
                if ($dish['runs'] !== []) {
                    $errors[] = $this->addonError($firstRow, __('addon_dish_cannot_clear_and_define_at_once'));
                }
                continue;
            }

            /* ---- each group ---- */
            foreach ($dish['runs'] as $run) {
                $first = $run['first'];
                $gr    = (int) $first['__row'];
                $name  = trim((string) ($first[$nameKey] ?? ''));

                if ($name === '') {
                    $errors[] = $this->addonError($gr, __('addon_group_name_is_required'));
                }

                $groupId = (int) ($first['addon_group_id'] ?? 0);
                if ($groupId > 0) {
                    $owner = $owners['groups'][$groupId] ?? null;
                    if ($owner === null) {
                        $errors[] = $this->addonError($gr, __('addon_group_not_found') . ': ' . $groupId);
                    } elseif ($ownProductId !== null && (int) $owner !== $ownProductId) {
                        $errors[] = $this->addonError($gr, __('addon_group_belongs_to_another_product') . ': ' . $groupId);
                    }
                }

                $inputType = $this->addonTokenCell($first['input_type'] ?? null, 'radio', fn ($v) => ProductBulkSchema::addonInputType($v));
                if ($inputType === null) {
                    $errors[] = $this->addonError($gr, __('invalid_value_for') . ' Selection Type: ' . $first['input_type']);
                    $inputType = 'radio';
                }
                if ($this->boolCell($first['is_required'] ?? null, 0) === null) {
                    $errors[] = $this->addonError($gr, __('invalid_value_for') . ' Required: ' . $first['is_required']);
                }
                if (ProductBulkSchema::addonStatus($first['group_status'] ?? null) === null) {
                    $errors[] = $this->addonError($gr, __('invalid_value_for') . ' Group Status: ' . $first['group_status']);
                }

                $min = $this->intCell($first['min_select'] ?? null, 0);
                $max = $this->intCell($first['max_select'] ?? null, 0);
                $qty = $this->intCell($first['max_qty_per_option'] ?? null, 1);
                foreach (['Min Select' => [$min, 0, 50], 'Max Select' => [$max, 0, 50], 'Max Qty Per Option' => [$qty, 1, 50]] as $label => [$val, $lo, $hi]) {
                    if ($val === null || $val < $lo || $val > $hi) {
                        $errors[] = $this->addonError($gr, __('invalid_value_for') . ' ' . $label . ' (' . $lo . '-' . $hi . ')');
                    }
                }

                // A later row quietly losing its edit is worse than being told.
                $errors = array_merge($errors, $this->addonRunConflicts($run, $schema));

                /* Radio groups are normalised by the writer (one selection, one of
                   each), so these two only apply to checkboxes — exactly as
                   groupRuleError() does, or the sheet would refuse what the form
                   accepts. */
                if ($inputType === 'checkbox' && $min !== null && $max !== null) {
                    if ($max > 0 && $min > $max) {
                        $errors[] = $this->addonError($gr, __('min_select_cannot_exceed_max_select'));
                    }
                    if ($min > count($run['rows'])) {
                        $errors[] = $this->addonError($gr, __('min_select_cannot_exceed_option_count'));
                    }
                }

                /* ---- each option ---- */
                foreach ($run['rows'] as $o) {
                    $errors = array_merge($errors, $this->validateAddonOption($o, $schema, [
                        'group_id'   => $groupId,
                        'own_id'     => $ownProductId,
                        'handle'     => $dish['handle'],
                        'option_key' => $optKey,
                        'owners'     => $owners,
                        'links'      => $links,
                        'ctx'        => $ctx,
                    ]));
                }
            }
        }

        return $errors;
    }

    /** One option row: identity, picture, diet mark, link, price source, branch cells. */
    private function validateAddonOption(array $o, ProductBulkSchema $schema, array $c): array
    {
        $errors = [];
        $r = (int) $o['__row'];

        if (trim((string) ($o[$c['option_key']] ?? '')) === '') {
            $errors[] = $this->addonError($r, __('addon_option_name_is_required'));
        }

        $optionId = (int) ($o['addon_option_id'] ?? 0);
        if ($optionId > 0) {
            $group = $c['owners']['options'][$optionId] ?? null;
            if ($group === null) {
                $errors[] = $this->addonError($r, __('addon_option_not_found') . ': ' . $optionId);
            } elseif ($c['group_id'] > 0 && (int) $group !== $c['group_id']) {
                $errors[] = $this->addonError($r, __('addon_option_belongs_to_another_group') . ': ' . $optionId);
            }
        }

        // The column is keyed `image` so this check needs no addon-specific copy.
        foreach ($this->validateImages($o, $r) as $e) {
            $errors[] = $this->addonError($r, $e['error']);
        }

        if ($this->addonTokenCell($o['diet_type'] ?? null, 0, fn ($v) => ProductBulkSchema::addonDietType($v)) === null) {
            $errors[] = $this->addonError($r, __('invalid_value_for') . ' Diet Type: ' . $o['diet_type']);
        }
        if (ProductBulkSchema::addonStatus($o['option_status'] ?? null) === null) {
            $errors[] = $this->addonError($r, __('invalid_value_for') . ' Option Status: ' . $o['option_status']);
        }

        $free = $this->boolCell($o['is_free'] ?? null, 0);
        if ($free === null) {
            $errors[] = $this->addonError($r, __('invalid_value_for') . ' Free: ' . $o['is_free']);
            $free = 0;
        }

        /* ---- the link ---- */
        $variantId = (int) ($o['linked_variant_id'] ?? 0);
        $sku = trim((string) ($o['linked_sku'] ?? ''));
        $skuKey = mb_strtolower($sku);
        $target = null;
        $hasLink = false;

        if ($variantId > 0) {
            $target = $c['links']['by_id'][$variantId] ?? null;
            $hasLink = true;
            if (!$target) {
                $errors[] = $this->addonError($r, __('addon_option_not_available') . ': ' . $variantId);
            }
        } elseif ($sku !== '') {
            $target = $c['links']['by_sku'][$skuKey] ?? null;
            if ($target) {
                $hasLink = true;
            } elseif (isset($c['ctx']['skus'][$skuKey])) {
                // Created by the Products sheet in this same file — it cannot be
                // resolved until phase 2, but it is a real link.
                $hasLink = true;
                if (!$schema->forUpdate && $c['ctx']['skus'][$skuKey] === mb_strtolower((string) $c['handle'])) {
                    $errors[] = $this->addonError($r, __('addon_cannot_link_the_same_product'));
                }
            } else {
                $errors[] = $this->addonError($r, __('addon_linked_sku_not_found') . ': ' . $sku);
            }
        }

        if ($target) {
            if ($c['own_id'] !== null && (int) $target->product_id === (int) $c['own_id']) {
                $errors[] = $this->addonError($r, __('addon_cannot_link_the_same_product'));
            }
            // Parity with the form's picker, which only ever offers live products.
            if ((int) $target->product_status !== 1 || (int) $target->product_is_draft === 1) {
                $errors[] = $this->addonError($r, __('addon_linked_product_is_not_active') . ': ' . ($sku !== '' ? $sku : $variantId));
            }
        }

        $source = $this->addonTokenCell($o['price_source'] ?? null, 'custom', fn ($v) => ProductBulkSchema::addonPriceSource($v));
        if ($source === null) {
            $errors[] = $this->addonError($r, __('invalid_value_for') . ' Price From: ' . $o['price_source']);
            $source = 'custom';
        }
        if ($source === 'product' && !$hasLink && $free !== 1) {
            $errors[] = $this->addonError($r, __('addon_price_from_product_needs_a_link'));
        }
        // A free option is priced by nobody, so it follows nothing — the form does the
        // same normalisation when the Free box is ticked.
        $effective = $free === 1 ? 'custom' : $source;

        /* ---- branch cells ---- */
        $offered = 0;
        $touchedAny = false;
        foreach ($schema->branches as $branch) {
            $p = 'addon.' . $branch->id . '.';
            $av = $o[$p . 'is_available'] ?? null;
            $price = $o[$p . 'price'] ?? null;
            $disc = $o[$p . 'discounted_price'] ?? null;
            if (!$this->filled($av) && !$this->filled($price) && !$this->filled($disc)) {
                continue;
            }
            $touchedAny = true;
            $prefix = '[' . $branch->name . '] ';

            $available = $this->boolCell($av, 0);
            if ($available === null) {
                $errors[] = $this->addonError($r, $prefix . __('invalid_value_for') . ' Addon Offered: ' . $av);
                continue;
            }
            if ($available === 1) {
                $offered++;
            }
            foreach (['Addon Price' => $price, 'Addon Offer Price' => $disc] as $label => $v) {
                if ($this->filled($v) && (!is_numeric($v) || (float) $v < 0)) {
                    $errors[] = $this->addonError($r, $prefix . __('invalid_value_for') . ' ' . $label . ': ' . $v);
                }
            }
            if (is_numeric($price) && is_numeric($disc) && (float) $disc > (float) $price) {
                $errors[] = $this->addonError($r, $prefix . __('discounted_price_cannot_be_greater_than_price'));
            }
        }

        if ($effective === 'product') {
            // syncBranchPrices() deletes every row for a catalogue-priced option, so a
            // typed price would disappear without a word.
            if ($touchedAny) {
                $errors[] = $this->addonError($r, __('addon_price_from_product_ignores_branch_prices'));
            }
        } elseif ($offered === 0) {
            /* True for a FREE option too: AddonHelper::isOptionSellable() wants an own
               available row for anything that does not follow the catalogue, so an
               option offered nowhere would save and then never be servable. The
               controller lets that through; a sheet has nowhere to show a warning. */
            $errors[] = $this->addonError($r, __('addon_option_needs_an_offered_branch'));
        }

        return $errors;
    }

    /**
     * Group-block cells that disagree with the run's first row.
     *
     * The Products sheet reads product-level values from a group's first row and gets
     * away with it because an export repeats identical values on every row. Here an
     * admin editing Min Select on the third option of a group would otherwise watch
     * the edit vanish.
     */
    private function addonRunConflicts(array $run, ProductBulkSchema $schema): array
    {
        $errors = [];
        $keys = ['input_type' => 'Selection Type', 'is_required' => 'Required', 'min_select' => 'Min Select',
            'max_select' => 'Max Select', 'max_qty_per_option' => 'Max Qty Per Option', 'group_status' => 'Group Status'];
        foreach ($schema->languages as $lang) {
            $keys['group_name.' . $lang->id] = 'Group Name (' . $lang->name . ')';
        }

        $first = $run['first'];
        foreach ($run['rows'] as $row) {
            if ((int) $row['__row'] === (int) $first['__row']) {
                continue;
            }
            foreach ($keys as $key => $label) {
                $mine = trim((string) ($row[$key] ?? ''));
                if ($mine === '') {
                    continue;
                }
                $theirs = trim((string) ($first[$key] ?? ''));
                if (mb_strtolower($mine) !== mb_strtolower($theirs)) {
                    $errors[] = $this->addonError(
                        (int) $row['__row'],
                        __('addon_group_value_conflicts_with_first_row') . ': ' . $label
                    );
                }
            }
        }

        return $errors;
    }

    /** What the Products sheet says about the dishes an addon row can point at. */
    private function addonContext(array $productRows): array
    {
        $handles = [];
        $skus = [];
        $foodById = [];

        foreach ($productRows as $row) {
            $food = ProductBulkSchema::parseBool($row['is_food'] ?? null, null);

            $handle = mb_strtolower(trim((string) ($row['handle'] ?? '')));
            if ($handle !== '') {
                if (!isset($handles[$handle])) {
                    $handles[$handle] = ['row' => $row['__row'] ?? 0, 'is_food' => null];
                }
                if ($food !== null) {
                    $handles[$handle]['is_food'] = $food;
                }
            }

            $sku = mb_strtolower(trim((string) ($row['sku'] ?? '')));
            if ($sku !== '') {
                $skus[$sku] = $handle;
            }

            $productId = (int) ($row['product_id'] ?? 0);
            if ($productId > 0 && $food !== null) {
                $foodById[$productId] = $food;
            }
        }

        return ['handles' => $handles, 'skus' => $skus, 'food_by_id' => $foodById];
    }

    /** Who owns the group/option ids the sheet carries, in two queries. */
    private function addonOwners(array $rows): array
    {
        $groupIds = [];
        $optionIds = [];
        foreach ($rows as $row) {
            $g = (int) ($row['addon_group_id'] ?? 0);
            $o = (int) ($row['addon_option_id'] ?? 0);
            if ($g > 0) {
                $groupIds[$g] = true;
            }
            if ($o > 0) {
                $optionIds[$o] = true;
            }
        }

        return [
            'groups' => $groupIds
                ? ProductAddonGroup::whereIn('id', array_keys($groupIds))->pluck('product_id', 'id')->all()
                : [],
            'options' => $optionIds
                ? ProductAddonOption::whereIn('id', array_keys($optionIds))->pluck('addon_group_id', 'id')->all()
                : [],
        ];
    }

    /**
     * The variants an addon row wants to link, by id and by SKU.
     *
     * The lookup is catalogue-wide on purpose, unlike every other column on these
     * sheets: a Coke offered with a pizza lives in Beverages, not in Pizzas.
     */
    private function addonLinkTargets(array $rows): array
    {
        $ids = [];
        $skus = [];
        foreach ($rows as $row) {
            $id = (int) ($row['linked_variant_id'] ?? 0);
            if ($id > 0) {
                $ids[$id] = true;
            }
            $sku = trim((string) ($row['linked_sku'] ?? ''));
            if ($sku !== '') {
                $skus[mb_strtolower($sku)] = $sku;
            }
        }

        $select = [
            'product_variants.id', 'product_variants.sku', 'product_variants.product_id',
            'p.status as product_status', 'p.is_draft as product_is_draft',
        ];

        $byId = [];
        if ($ids) {
            $byId = ProductVariant::join('products as p', 'p.id', '=', 'product_variants.product_id')
                ->whereIn('product_variants.id', array_keys($ids))
                ->get($select)->keyBy('id')->all();
        }

        $bySku = [];
        if ($skus) {
            foreach (ProductVariant::join('products as p', 'p.id', '=', 'product_variants.product_id')
                ->whereIn('product_variants.sku', array_values($skus))
                ->get($select) as $variant) {
                $bySku[mb_strtolower((string) $variant->sku)] = $variant;
            }
        }

        return ['by_id' => $byId, 'by_sku' => $bySku];
    }

    /**
     * Replace one dish's whole addon setup with what the sheet says, through the real
     * writer.
     *
     * The same bridge createProduct() uses for products: the controller owns the
     * replace semantics, the id matching, the translation mirroring and the branch-row
     * pruning, so the importer cannot drift away from what the admin form does. An
     * empty `groups` is the wipe.
     */
    public function saveAddonsForDish(int $productId, array $dish, ProductBulkSchema $schema, array $skuToVariantId = []): ?string
    {
        $groups = [];
        if (!$dish['clear']) {
            foreach ($dish['runs'] as $run) {
                $groups[] = $this->addonGroupPayload($run, $schema, $skuToVariantId);
            }
        }

        $request = new Request();
        // Nested arrays, not a JSON string: the controller's rule is `groups => array`
        // and it reads them straight back with $request->input('groups').
        $request->merge(['product_id' => $productId, 'groups' => $groups]);

        $response = app(ProductAddonApiController::class)->save($request);
        $body = json_decode($response->getContent(), true);

        return ($body['status'] ?? 0) ? null : ($body['message'] ?? __('something_went_wrong'));
    }

    private function addonGroupPayload(array $run, ProductBulkSchema $schema, array $skuToVariantId): array
    {
        $first = $run['first'];
        $defaultId = (int) ($schema->defaultLanguage->id ?? 0);

        $options = [];
        foreach ($run['rows'] as $row) {
            $options[] = $this->addonOptionPayload($row, $schema, $skuToVariantId);
        }

        return [
            'id'                 => (int) ($first['addon_group_id'] ?? 0) ?: null,
            'name'               => trim((string) ($first['group_name.' . $defaultId] ?? '')),
            'input_type'         => ProductBulkSchema::addonInputType($first['input_type'] ?? null) ?? 'radio',
            'is_required'        => $this->boolCell($first['is_required'] ?? null, 0) ?? 0,
            'min_select'         => $this->intCell($first['min_select'] ?? null, 0) ?? 0,
            'max_select'         => $this->intCell($first['max_select'] ?? null, 0) ?? 0,
            'max_qty_per_option' => $this->intCell($first['max_qty_per_option'] ?? null, 1) ?? 1,
            'status'             => ProductBulkSchema::addonStatus($first['group_status'] ?? null) ?? 1,
            'translations'       => $this->addonTranslations($first, 'group_name.', $schema),
            'options'            => $options,
        ];
    }

    private function addonOptionPayload(array $row, ProductBulkSchema $schema, array $skuToVariantId): array
    {
        $defaultId = (int) ($schema->defaultLanguage->id ?? 0);
        $linkedId = $this->resolveLinkedVariantId($row, $skuToVariantId);
        $free = $this->boolCell($row['is_free'] ?? null, 0) ?? 0;
        $source = ProductBulkSchema::addonPriceSource($row['price_source'] ?? null) ?? 'custom';

        $image = trim((string) ($row['image'] ?? ''));

        $branches = [];
        foreach ($schema->branches as $branch) {
            $p = 'addon.' . $branch->id . '.';
            $av = $row[$p . 'is_available'] ?? null;
            $price = $row[$p . 'price'] ?? null;
            $disc = $row[$p . 'discounted_price'] ?? null;
            if (!$this->filled($av) && !$this->filled($price) && !$this->filled($disc)) {
                // Untouched: the branch keeps no row, which is how an option is never
                // offered there.
                continue;
            }
            $branches[] = [
                'branch_id'         => (int) $branch->id,
                // Kept even when 0, so a withdrawn branch does not lose its price.
                'is_available'     => $this->boolCell($av, 0) ?? 0,
                'price'            => $this->num($price) ?? 0,
                'discounted_price' => $this->num($disc) ?? 0,
            ];
        }

        return [
            'id'                => (int) ($row['addon_option_id'] ?? 0) ?: null,
            'name'              => trim((string) ($row['option_name.' . $defaultId] ?? '')),
            // A linked option wears its product's picture and diet mark; the writer
            // nulls both, so sending them would only invite a disagreement.
            'image'             => $linkedId ? null : ($image !== '' ? $this->resolveImage($image, 'products/addons') : null),
            'product_type'      => $linkedId ? null : (ProductBulkSchema::addonDietType($row['diet_type'] ?? null) ?? 0),
            'linked_variant_id' => $linkedId ?: null,
            'is_free'           => $free,
            'price_source'      => ($linkedId && $free !== 1) ? $source : 'custom',
            'status'            => ProductBulkSchema::addonStatus($row['option_status'] ?? null) ?? 1,
            'translations'       => $this->addonTranslations($row, 'option_name.', $schema),
            'branches'            => $branches,
        ];
    }

    /** Exported id wins; else the SKU, resolved against this run's new variants first. */
    private function resolveLinkedVariantId(array $row, array $skuToVariantId): int
    {
        $id = (int) ($row['linked_variant_id'] ?? 0);
        if ($id > 0) {
            return $id;
        }

        $sku = trim((string) ($row['linked_sku'] ?? ''));
        if ($sku === '') {
            return 0;
        }

        $key = mb_strtolower($sku);
        foreach ($skuToVariantId as $created => $variantId) {
            if (mb_strtolower((string) $created) === $key) {
                return (int) $variantId;
            }
        }

        if (!array_key_exists($key, $this->linkedVariantMemo)) {
            $this->linkedVariantMemo[$key] = (int) (ProductVariant::where('sku', $sku)->value('id') ?? 0);
        }

        return $this->linkedVariantMemo[$key];
    }

    /**
     * Non-default languages only, keyed by language id.
     *
     * The default language's name travels as the plain `name`, exactly as the admin
     * form posts it — HasTranslations mirrors it onto the base column from there.
     */
    private function addonTranslations(array $row, string $prefix, ProductBulkSchema $schema): array
    {
        $out = [];
        foreach ($schema->languages as $lang) {
            if ((int) $lang->id === (int) ($schema->defaultLanguage->id ?? 0)) {
                continue;
            }
            $v = trim((string) ($row[$prefix . $lang->id] ?? ''));
            if ($v !== '') {
                $out[(string) $lang->id] = ['name' => $v];
            }
        }

        return $out;
    }

    private function addonError(int $row, string $message): array
    {
        return ['sheet' => self::ADDONS_SHEET, 'row' => $row, 'error' => $message];
    }

    private function filled($value): bool
    {
        return $value !== null && trim((string) $value) !== '';
    }

    /** Blank => default; a token we know => its value; anything else => null. */
    private function boolCell($value, int $default): ?int
    {
        if (!$this->filled($value)) {
            return $default;
        }

        return ProductBulkSchema::parseBool($value, null);
    }

    private function intCell($value, int $default): ?int
    {
        if (!$this->filled($value)) {
            return $default;
        }

        return is_numeric($value) ? (int) $value : null;
    }

    /** Same contract as boolCell, for the enum cells. */
    private function addonTokenCell($value, $default, callable $parse)
    {
        if (!$this->filled($value)) {
            return $default;
        }

        return $parse($value);
    }

    private function save(Spreadsheet $spreadsheet): string
    {
        $spreadsheet->setActiveSheetIndex(0);
        $tmp = tempnam(sys_get_temp_dir(), 'products_bulk_');
        (new Xlsx($spreadsheet))->save($tmp);
        $spreadsheet->disconnectWorksheets();

        return $tmp;
    }

    /* ===================================================================== */
    /* Reading                                                                */
    /* ===================================================================== */

    /**
     * Both sheets of one upload, from one load of the workbook.
     *
     * Matching is by header LABEL, not position, so a reordered sheet still imports.
     *
     * The Products sheet stays sheet 0 by POSITION, deliberately: a hand-built file
     * whose first tab is called something else imports today and must keep doing so.
     * The Addons sheet is found by NAME, and its absence is not an error — every file
     * downloaded before addons existed has no such tab.
     *
     * @return array{products: array{rows: array, errors: array}, addons: array{rows: array, errors: array}}
     */
    public function readAll(string $path, array $productColumns, array $addonColumns): array
    {
        $none = ['rows' => [], 'errors' => []];

        try {
            $book = IOFactory::load($path);
        } catch (\Throwable $e) {
            Log::warning('[Bulk] could not read the uploaded sheet: ' . $e->getMessage());

            return [
                'products' => ['rows' => [], 'errors' => [__('the_file_could_not_be_read_please_upload_the_sample_sheet')]],
                'addons'   => $none,
            ];
        }

        $products = $this->parseSheet(
            $book->getSheet(0),
            $productColumns,
            self::MAX_ROWS,
            __('too_many_rows_max') . ': ' . self::MAX_ROWS,
            fn (array $a) => $this->isSampleName($a['handle'] ?? null)
                && str_starts_with((string) ($a['sku'] ?? ''), 'SAMPLE-SKU-'),
            true
        );

        $addonSheet = $addonColumns === [] ? null : $book->getSheetByName(self::ADDONS_SHEET);
        $addons = $addonSheet === null ? $none : $this->parseSheet(
            $addonSheet,
            $addonColumns,
            self::MAX_ADDON_ROWS,
            __('too_many_addon_rows_max') . ': ' . self::MAX_ADDON_ROWS,
            // An addon row has no SKU, so the Products sentinel would never fire and
            // the grey example rows would import as a dish nobody asked for.
            fn (array $a) => $this->isSampleName($a['handle'] ?? null),
            false
        );

        return ['products' => $products, 'addons' => $addons];
    }

    /**
     * One sheet into assoc rows.
     *
     * @param  callable|null $isExampleRow  tells the shipped grey rows from real data
     * @param  bool          $required      false for an optional sheet: blank, header-only
     *                                      and header-deleted all mean "no rows", not an error
     * @return array{rows: array, errors: array}
     */
    private function parseSheet(
        $sheet,
        array $columns,
        int $maxRows,
        string $tooManyMessage,
        ?callable $isExampleRow,
        bool $required
    ): array {
        $raw = $sheet->toArray(null, true, false, false);

        if (empty($raw)) {
            return ['rows' => [], 'errors' => $required ? [__('the_file_is_empty')] : []];
        }

        $header = array_map(fn ($h) => $this->normalizeHeader($h), array_shift($raw));
        $byLabel = [];
        foreach ($columns as $col) {
            $byLabel[$this->normalizeHeader($col['label'])] = $col['key'];
        }

        // Map each sheet column index -> our column key.
        $keys = array_flip(array_column($columns, 'key'));
        $indexToKey = [];
        foreach ($header as $idx => $label) {
            if ($label === '') {
                continue;
            }
            if (isset($byLabel[$label])) {
                $indexToKey[$idx] = $byLabel[$label];
                continue;
            }
            // An older download, whose header still uses the previous wording.
            $alias = self::HEADER_ALIASES[$label] ?? null;
            if ($alias !== null && isset($keys[$alias]) && !in_array($alias, $indexToKey, true)) {
                $indexToKey[$idx] = $alias;
            }
        }

        // An optional sheet the admin emptied out entirely — headers and all — is a
        // sheet with nothing to say, not a broken file.
        if (!$required && $indexToKey === []) {
            return ['rows' => [], 'errors' => []];
        }

        $errors = [];
        // Only required columns must be present; optional ones may be dropped.
        foreach ($columns as $col) {
            if ($col['required'] && !in_array($col['key'], $indexToKey, true)) {
                $errors[] = __('missing_required_column') . ': ' . $col['label'];
            }
        }
        if ($errors) {
            return ['rows' => [], 'errors' => $errors];
        }

        $rows = [];
        foreach ($raw as $n => $line) {
            $assoc = [];
            foreach ($indexToKey as $idx => $key) {
                $v = $line[$idx] ?? null;
                $assoc[$key] = is_string($v) ? trim($v) : $v;
            }
            // Skip fully blank lines and the greyed example rows we ship in the sample.
            if (!array_filter($assoc, fn ($v) => $v !== null && $v !== '')) {
                continue;
            }
            if ($isExampleRow !== null && $isExampleRow($assoc)) {
                continue;
            }
            $assoc['__row'] = $n + 2; // human-facing sheet row number
            $rows[] = $assoc;
        }

        if (count($rows) > $maxRows) {
            return ['rows' => [], 'errors' => [$tooManyMessage]];
        }

        return ['rows' => $rows, 'errors' => []];
    }

    /** The grey example rows, under either the current name or the old slug. */
    private function isSampleName($value): bool
    {
        return in_array(strtolower(trim((string) $value)), ['sample product 1', 'sample-product-1'], true);
    }

    private function normalizeHeader($h): string
    {
        $h = strtolower(trim(preg_replace('/\s+/', ' ', (string) $h)));

        // The trailing asterisk is only our "required" marker, so a sheet downloaded
        // before a column's requirement changed still maps onto the same column.
        return rtrim($h, " *");
    }

    /* ===================================================================== */
    /* Create                                                                 */
    /* ===================================================================== */

    /**
     * Validate every row up front, then write. Nothing is written unless the whole
     * file is clean, so a user never ends up with half a catalogue imported.
     *
     * @return array{errors: array, created: int}
     */
    public function validateForCreate(array $rows, ProductBulkSchema $schema): array
    {
        $errors = [];
        $seenSku = [];
        $seenCombo = [];
        /** @var array<int,array{handle:string,attributes:int[]}> which attributes each row answered */
        $answeredByRow = [];
        $attributes = $schema->attributes();

        foreach ($rows as $row) {
            $r = $row['__row'];
            $handle = $row['handle'] ?? '';
            $sku = $row['sku'] ?? '';

            if ($handle === '') {
                $errors[] = ['row' => $r, 'error' => __('product_handle_is_required')];
            }
            if ($sku === '') {
                $errors[] = ['row' => $r, 'error' => __('sku_is_required')];
            } else {
                $k = mb_strtolower($sku);
                if (isset($seenSku[$k])) {
                    $errors[] = ['row' => $r, 'error' => __('duplicate_sku_in_file') . ': ' . $sku . ' (' . __('row') . ' ' . $seenSku[$k] . ')'];
                } else {
                    $seenSku[$k] = $r;
                    if (ProductVariant::where('sku', $sku)->exists()) {
                        $errors[] = ['row' => $r, 'error' => __('sku_already_used') . ': ' . $sku];
                    }
                }
            }

            // Default-language variant name is what the product's slug is derived from.
            $nameKey = 'variant_name.' . ($schema->defaultLanguage->id ?? 0);
            if (empty($row[$nameKey])) {
                $errors[] = ['row' => $r, 'error' => __('variant_name_required_in_default_language')];
            }

            // On create every variant needs its own image; the gallery stays optional.
            if (trim((string) ($row['image'] ?? '')) === '') {
                $errors[] = ['row' => $r, 'error' => __('variant_image_is_required')];
            }

            /* A variant must answer AT LEAST ONE attribute, not all of them.
             *
             * The category's attributes are what it may vary by, not what every
             * product does vary by: a category offering Colour, Size and Fabric still
             * sells shirts that come in one fabric and vary only by size. Leaving the
             * others blank is the correct way to say that, and the writers already
             * skip a blank cell. What is never valid is a variant with no attribute at
             * all — nothing would tell two of them apart.
             *
             * The combination must also be unique inside the product; that is what
             * makes a variant addressable. */
            $combo = [];
            $answered = [];
            foreach ($attributes as $attr) {
                $val = $row['attr.' . $attr->id] ?? '';
                if ($val === '' || $val === null) {
                    continue;
                }
                $match = $attr->values->first(fn ($v) => mb_strtolower((string) $v->value) === mb_strtolower((string) $val));
                if (!$match) {
                    $errors[] = ['row' => $r, 'error' => __('invalid_value_for') . ' ' . $attr->name . ': ' . $val];
                    continue;
                }
                $combo[] = $attr->id . ':' . $match->id;
                $answered[] = (int) $attr->id;
            }
            if (!$answered && $attributes->isNotEmpty()) {
                $errors[] = ['row' => $r, 'error' => __('at_least_one_attribute_value_is_required')];
            }
            $answeredByRow[$r] = ['handle' => $handle, 'attributes' => $answered];
            if ($combo && $handle !== '') {
                sort($combo);
                $ck = $handle . '|' . implode(',', $combo);
                if (isset($seenCombo[$ck])) {
                    $errors[] = ['row' => $r, 'error' => __('duplicate_variant_combination_for_handle') . ' (' . __('row') . ' ' . $seenCombo[$ck] . ')'];
                } else {
                    $seenCombo[$ck] = $r;
                }
            }

            $errors = array_merge($errors, $this->validateBranchCells($row, $schema, $r));
            $errors = array_merge($errors, $this->validateImages($row, $r));
        }

        /* Every variant of ONE product must answer the SAME attributes.
         *
         * "Red" and "Large" are not two variants of the same thing — the app's variant
         * picker has to ask one consistent set of questions, and the product form can
         * only ever produce such a set. A sheet is the one place a mixed product could
         * be described, so it is caught here rather than written. */
        $byHandleAttributes = [];
        foreach ($answeredByRow as $r => $info) {
            if ($info['handle'] === '' || !$info['attributes']) {
                continue;
            }
            $set = $info['attributes'];
            sort($set);
            $key = implode(',', $set);
            $first = $byHandleAttributes[$info['handle']] ?? null;
            if ($first === null) {
                $byHandleAttributes[$info['handle']] = ['key' => $key, 'row' => $r];
                continue;
            }
            if ($first['key'] !== $key) {
                $errors[] = [
                    'row'   => $r,
                    'error' => __('variants_of_a_product_must_use_the_same_attributes')
                        . ' (' . __('row') . ' ' . $first['row'] . ')',
                ];
            }
        }

        // A product must be listed somewhere, or it is invisible to every customer.
        foreach ($this->groupByHandle($rows) as $handle => $group) {
            $anyListed = false;
            foreach ($group as $row) {
                foreach ($schema->branches as $branch) {
                    if (ProductBulkSchema::parseBool($row['branch.' . $branch->id . '.is_listed'] ?? null, 0) === 1) {
                        $anyListed = true;
                        break 2;
                    }
                }
            }
            if (!$anyListed) {
                $errors[] = ['row' => $group[0]['__row'], 'error' => __('at_least_one_branch_must_be_listed_for') . ': ' . $handle];
            }
        }

        return $errors;
    }

    /** Price rules per branch cell group. */
    private function validateBranchCells(array $row, ProductBulkSchema $schema, int $r, ?ProductVariant $variant = null): array
    {
        $errors = [];
        foreach ($schema->branches as $branch) {
            $p = 'branch.' . $branch->id . '.';

            $slabCell = ProductBulkSchema::parseSlabs($row[$p . 'pricing_slabs'] ?? null);
            if ($slabCell['error'] !== null) {
                $errors[] = ['row' => $r, 'error' => '[' . $branch->name . '] ' . $slabCell['error']];
            } elseif ($slabCell['slabs'] !== []) {
                $base = $this->effectiveBasePrice($row, $p, (int) $branch->id, $variant);
                foreach ($slabCell['slabs'] as $slab) {
                    if ($base !== null && $slab['price'] >= $base) {
                        $errors[] = ['row' => $r, 'error' => '[' . $branch->name . '] '
                            . __('qty_slab_price_must_be_below_the_selling_price') . ': ' . $slab['min_qty']];
                        break;
                    }
                }
            }
            // Unlike the form's API, an omitted "Listed" here means NOT listed. The old
            // default (listed) turned a blank cell into a hard failure on missing price.
            $listed = ProductBulkSchema::parseBool($row[$p . 'is_listed'] ?? null, 0);
            if ($listed !== 1) {
                continue;
            }
            $price = $row[$p . 'price'] ?? null;
            $disc  = $row[$p . 'discounted_price'] ?? null;

            if ($price === null || $price === '' || !is_numeric($price) || (float) $price <= 0) {
                if ($this->effectiveBasePrice($row, $p, (int) $branch->id, $variant) === null) {
                    $errors[] = ['row' => $r, 'error' => '[' . $branch->name . '] ' . __('price_is_required_for_a_listed_branch')];
                }
                continue;
            }
            if ($disc !== null && $disc !== '') {
                if (!is_numeric($disc)) {
                    $errors[] = ['row' => $r, 'error' => '[' . $branch->name . '] ' . __('discounted_price_must_be_a_number')];
                } elseif ((float) $disc > (float) $price) {
                    $errors[] = ['row' => $r, 'error' => '[' . $branch->name . '] ' . __('discounted_price_cannot_be_greater_than_price')];
                }
            }
            foreach (['purchase_price', 'available', 'min_alert'] as $f) {
                $v = $row[$p . $f] ?? null;
                if ($v !== null && $v !== '' && (!is_numeric($v) || (float) $v < 0)) {
                    $errors[] = ['row' => $r, 'error' => '[' . $branch->name . '] ' . __('invalid_value_for') . ' ' . $f];
                }
            }
        }
        return $errors;
    }

    private function effectiveBasePrice(array $row, string $p, int $branchId, ?ProductVariant $variant): ?float
    {
        $price = $row[$p . 'price'] ?? null;
        $disc  = $row[$p . 'discounted_price'] ?? null;

        if (($price === null || $price === '' || !is_numeric($price)) && $variant) {
            $stock = ProductVariantBranchStock::where('product_variant_id', $variant->id)
                ->where('branch_id', $branchId)->first();
            if ($stock) {
                $price = $stock->price;
                if ($disc === null || $disc === '') {
                    $disc = $stock->discounted_price;
                }
            }
        }

        if ($price === null || $price === '' || !is_numeric($price) || (float) $price <= 0) {
            return null;
        }

        return (is_numeric($disc) && (float) $disc > 0) ? (float) $disc : (float) $price;
    }

    private function validateImages(array $row, int $r, array $knownPaths = []): array
    {
        $errors = [];
        foreach (['image' => false, 'gallery' => true] as $key => $multi) {
            $raw = $row[$key] ?? '';
            if ($raw === '' || $raw === null) {
                continue;
            }
            $items = $multi ? array_filter(array_map('trim', explode(',', (string) $raw))) : [(string) $raw];
            foreach ($items as $item) {
                if (filter_var($item, FILTER_VALIDATE_URL)) {
                    continue;
                }
                if (in_array($item, $knownPaths, true)) {
                    continue;
                }
                if (!Storage::disk('public')->exists($item)) {

                    $looksLikeFragment = $multi && pathinfo($item, PATHINFO_EXTENSION) === '';
                    $errors[] = [
                        'row' => $r,
                        'error' => __('image_not_found') . ': ' . $item
                            . ($looksLikeFragment ? ' — ' . __('image_path_contains_comma_hint') : ''),
                    ];
                }
            }
        }
        return $errors;
    }

    /** @return array<string,array> */
    public function groupByHandle(array $rows): array
    {
        $groups = [];
        foreach ($rows as $row) {
            $groups[(string) ($row['handle'] ?? '')][] = $row;
        }
        return $groups;
    }

    /**
     * Build the product-form payload for one handle group and hand it to the real
     * writer.
     *
     * Returns what the writer wrote, because the addon phase needs it: a dish's own id
     * to hang its groups off, and the sku => variant id map so an option can link a
     * variant created in this same file.
     *
     * @return array{error: ?string, product_id: ?int, variants: array<string,int>}
     */
    public function createProduct(string $handle, array $group, ProductBulkSchema $schema): array
    {
        $first = $group[0];

        $payload = [
            'category_id' => $schema->category->id,
            'is_draft'    => 0,
            'sales_channel' => $this->channelForBranches($schema),
            'brand_id'    => $schema->brandId($first['brand'] ?? null),
            'tax_category_id' => $schema->taxCategoryId($first['tax'] ?? null),
            'product_type' => ProductBulkSchema::PRODUCT_TYPES[strtolower((string) ($first['product_type'] ?? 'none'))] ?? 0,
            'status'      => strtolower((string) ($first['status'] ?? 'active')) === 'inactive' ? 0 : 1,
            'total_allowed_quantity' => (int) ($first['total_allowed_quantity'] ?? 0),
            'cod_allowed' => ProductBulkSchema::parseBool($first['cod_allowed'] ?? null, 0),
            'return_status' => ProductBulkSchema::parseBool($first['return_status'] ?? null, 0),
            'return_days' => (int) ($first['return_days'] ?? 0),
            'cancelable_status' => ProductBulkSchema::parseBool($first['cancelable_status'] ?? null, 0),
            'till_status_quick' => $first['till_status_quick'] ?? '',
            'till_status_ecommerce' => $first['till_status_ecommerce'] ?? '',
            'is_prescription_required' => (int) ($first['is_prescription_required'] ?? 0),
            'is_food' => ProductBulkSchema::parseBool($first['is_food'] ?? null, 0),
            'is_addon_only' => ProductBulkSchema::parseBool($first['is_addon_only'] ?? null, 0),
            'translations' => json_encode($this->productTranslations($first, $schema)),
            'variants' => json_encode($this->variantPayloads($group, $schema)),
        ];

        $request = new Request();
        $request->merge($payload);

        $response = app(ProductApisController::class)->save($request);
        $body = json_decode($response->getContent(), true);

        if (!($body['status'] ?? 0)) {
            return ['error' => $body['message'] ?? __('something_went_wrong'), 'product_id' => null, 'variants' => []];
        }

        // Gallery images are referenced by path, which the form's file-upload path
        // does not cover — attach them once the variants exist.
        $this->attachGalleries($group, $schema);

        $variantIds = [];
        foreach (($body['data']['variants'] ?? []) as $v) {
            if (!empty($v['sku'])) {
                $variantIds[(string) $v['sku']] = (int) $v['id'];
            }
        }

        return [
            'error'      => null,
            'product_id' => (int) ($body['data']['id'] ?? 0) ?: null,
            'variants'   => $variantIds,
        ];
    }

    private function channelForBranches(ProductBulkSchema $schema): string
    {
        $types = Branch::whereIn('id', $schema->branches->pluck('id'))
            ->pluck('fulfillment_type')->unique()->values()->all();

        $capable = [];
        foreach ($types as $type) {
            if ($type === 'quick' || $type === 'both') {
                $capable['quick'] = true;
            }
            if ($type === 'ecommerce' || $type === 'both') {
                $capable['ecommerce'] = true;
            }
        }
        $capable = array_keys($capable);

        $asked = $schema->salesChannel === 'both' ? ['quick', 'ecommerce'] : [$schema->salesChannel];

        $effective = array_values(array_intersect($asked, $capable));
        if (empty($effective)) {
            $effective = $capable;
        }

        if (count($effective) === 1) {
            return $effective[0];
        }
        return 'both';
    }

    private function productTranslations(array $first, ProductBulkSchema $schema): array
    {
        $out = [];
        foreach ($schema->languages as $lang) {
            $data = [];
            foreach (ProductBulkSchema::TRANSLATABLE_PRODUCT_FIELDS as $field) {
                $v = $first['ptrans.' . $field . '.' . $lang->id] ?? null;
                if ($v !== null && $v !== '') {
                    $data[$field] = $v;
                }
            }
            if ((int) $lang->is_default === 1) {
                foreach (ProductBulkSchema::SINGLE_LANG_PRODUCT_FIELDS as $field) {
                    $v = $first['ptrans.' . $field . '.' . $lang->id] ?? null;
                    if ($v !== null && $v !== '') {
                        $data[$field] = $v;
                    }
                }
            }
            if ($data) {
                $out[(string) $lang->id] = $data;
            }
        }
        return $out;
    }

    private function variantPayloads(array $group, ProductBulkSchema $schema): array
    {
        $attributes = $schema->attributes();
        $variants = [];

        foreach ($group as $row) {
            $attrValues = [];
            foreach ($attributes as $attr) {
                $val = $row['attr.' . $attr->id] ?? '';
                $match = $attr->values->first(fn ($v) => mb_strtolower((string) $v->value) === mb_strtolower((string) $val));
                if ($match) {
                    $attrValues[] = ['attribute_id' => (int) $attr->id, 'value_id' => (int) $match->id];
                }
            }

            $translations = [];
            foreach ($schema->languages as $lang) {
                $n = $row['variant_name.' . $lang->id] ?? null;
                if ($n !== null && $n !== '') {
                    $translations[(string) $lang->id] = ['name' => $n];
                }
            }

            $variants[] = [
                'name' => $row['variant_name.' . ($schema->defaultLanguage->id ?? 0)] ?? '',
                'sku' => $row['sku'] ?? '',
                'hsn_code' => $row['hsn_code'] ?? '',
                'image_path' => $this->resolveImage($row['image'] ?? ''),
                'attribute_values' => $attrValues,
                'translations' => $translations,
                'custom_values' => $this->customValuePayloads($row, $schema),
                'branch_stocks' => $this->branchStockPayloads($row, $schema),
            ];
        }

        return $variants;
    }

    private function customValuePayloads(array $row, ProductBulkSchema $schema): array
    {
        $out = [];
        foreach ($schema->customFields() as $field) {
            $v = $row['custom.' . $field->id] ?? null;
            if ($v === null || $v === '') {
                continue;
            }
            $entry = ['field_id' => (int) $field->id, 'value_text' => null, 'value_number' => null, 'value_date' => null, 'value_json' => null, 'translations' => []];

            switch ($field->field_type) {
                case 'number':
                    if (!is_numeric($v)) {
                        continue 2;
                    }
                    $entry['value_number'] = (float) $v;
                    break;
                case 'date':
                    $ts = strtotime((string) $v);
                    if ($ts === false) {
                        continue 2;
                    }
                    $entry['value_date'] = date('Y-m-d', $ts);
                    break;
                case 'boolean':
                    $entry['value_text'] = (string) (ProductBulkSchema::parseBool($v, 0));
                    break;
                case 'multiselect':
                case 'checkbox':
                    $entry['value_json'] = array_values(array_filter(array_map('trim', explode(',', (string) $v))));
                    break;
                default:
                    $entry['value_text'] = (string) $v;
            }
            $out[] = $entry;
        }
        return $out;
    }

    private function branchStockPayloads(array $row, ProductBulkSchema $schema): array
    {
        $out = [];
        foreach ($schema->branches as $branch) {
            $p = 'branch.' . $branch->id . '.';
            $listed = ProductBulkSchema::parseBool($row[$p . 'is_listed'] ?? null, 0);
            // Unlimited stock is a per-branch column now — it arrives in the branch group.
            $unlimited = ProductBulkSchema::parseBool($row[$p . 'is_unlimited_stock'] ?? null, 0);
            $out[] = [
                'branch_id' => (int) $branch->id,
                'is_listed' => $listed,
                'is_unlimited_stock' => $unlimited,
                'stock_status' => ProductBulkSchema::parseBool($row[$p . 'stock_status'] ?? null, 1),
                // Counts are kept as submitted even when unlimited, so flipping a branch
                // back to Limited preserves them (matches the product form).
                'available' => (int) ($row[$p . 'available'] ?? 0),
                'min_alert' => (int) ($row[$p . 'min_alert'] ?? 0),
                'price' => $this->num($row[$p . 'price'] ?? null),
                'discounted_price' => $this->num($row[$p . 'discounted_price'] ?? null),
                'purchase_price' => $this->num($row[$p . 'purchase_price'] ?? null),
                'pricing_slabs' => ProductBulkSchema::parseSlabs($row[$p . 'pricing_slabs'] ?? null)['slabs'],
            ];
        }
        return $out;
    }

    private function num($v): ?float
    {
        return ($v === null || $v === '' || !is_numeric($v)) ? null : (float) $v;
    }

    /**
     * Only local storage paths are usable as-is; URLs are fetched and stored.
     *
     * The directory is a parameter because an addon option's picture belongs beside
     * the ones its own upload endpoint writes, not under products/variants.
     */
    private function resolveImage(string $value, string $dir = 'products/variants'): string
    {
        $value = trim($value);
        if ($value === '') {
            return '';
        }
        if (!filter_var($value, FILTER_VALIDATE_URL)) {
            return $value;
        }
        try {
            $contents = @file_get_contents($value);
            if ($contents === false) {
                return '';
            }
            $ext = pathinfo(parse_url($value, PHP_URL_PATH), PATHINFO_EXTENSION) ?: 'jpg';
            $path = rtrim($dir, '/') . '/' . uniqid('bulk_', true) . '.' . $ext;
            Storage::disk('public')->put($path, $contents);
            return $path;
        } catch (\Throwable $e) {
            return '';
        }
    }

    private function attachGalleries(array $group, ProductBulkSchema $schema): void
    {
        foreach ($group as $row) {
            $raw = trim((string) ($row['gallery'] ?? ''));
            if ($raw === '') {
                continue;
            }
            $variant = ProductVariant::where('sku', $row['sku'] ?? '')->first();
            if ($variant) {
                $this->mergeGalleryPaths($variant, $raw);
            }
        }
    }

    private function mergeGalleryPaths(ProductVariant $variant, string $raw): void
    {
        $existing = ProductImages::where('product_variant_id', $variant->id)
            ->pluck('image')->all();

        foreach (array_filter(array_map('trim', explode(',', $raw))) as $item) {
            $path = $this->resolveImage($item);
            if ($path === '' || in_array($path, $existing, true)) {
                continue;
            }
            ProductImages::create([
                'product_id' => $variant->product_id,
                'product_variant_id' => $variant->id,
                'image' => $path,
            ]);
            $existing[] = $path;
        }
    }


    /**
     * Validate an update sheet. Rows are matched on variant_id; anything the sheet
     * does not mention is left alone.
     */
    public function validateForUpdate(array $rows, ProductBulkSchema $schema): array
    {
        $errors = [];
        foreach ($rows as $row) {
            $r = $row['__row'];
            $variantId = (int) ($row['variant_id'] ?? 0);
            $productId = (int) ($row['product_id'] ?? 0);

            if ($variantId <= 0 || $productId <= 0) {
                $errors[] = ['row' => $r, 'error' => __('product_id_and_variant_id_are_required')];
                continue;
            }
            $variant = ProductVariant::where('id', $variantId)->where('product_id', $productId)->first();
            if (!$variant) {
                $errors[] = ['row' => $r, 'error' => __('variant_not_found_for_this_product') . ': ' . $variantId];
                continue;
            }
            $sku = $row['sku'] ?? '';
            if ($sku !== '' && ProductVariant::where('sku', $sku)->where('id', '!=', $variantId)->exists()) {
                $errors[] = ['row' => $r, 'error' => __('sku_already_used') . ': ' . $sku];
            }
            $errors = array_merge($errors, $this->validateBranchCells($row, $schema, $r, $variant));

            // Paths the variant already carries are accepted as-is: an unchanged
            // export must re-upload cleanly even if a referenced file went missing.
            $knownPaths = ProductImages::where('product_variant_id', $variant->id)
                ->pluck('image')->push((string) $variant->getRawOriginal('image'))
                ->filter()->all();
            $errors = array_merge($errors, $this->validateImages($row, $r, $knownPaths));
        }
        return $errors;
    }

    /**
     * Merge one row into an existing variant. Only columns present in the sheet are
     * written; variants and branches that were not exported keep their data.
     */
    public function updateRow(array $row, ProductBulkSchema $schema): void
    {
        $variant = ProductVariant::find((int) $row['variant_id']);
        if (!$variant) {
            return;
        }
        $product = Product::find((int) $row['product_id']);

        /* ---- variant fields ---- */
        if (array_key_exists('sku', $row) && $row['sku'] !== '' && $row['sku'] !== null) {
            $variant->sku = $row['sku'];
        }
        if (array_key_exists('hsn_code', $row) && $row['hsn_code'] !== null && $row['hsn_code'] !== '') {
            $variant->hsn_code = $row['hsn_code'];
        }
        foreach (['weight', 'length', 'breadth', 'height'] as $dim) {
            if (array_key_exists($dim, $row) && $row[$dim] !== null && $row[$dim] !== '') {
                $variant->{$dim} = (float) $row[$dim];
            }
        }
        if (!empty($row['image'])) {
            $path = $this->resolveImage((string) $row['image']);
            if ($path !== '') {
                $variant->image = $path;
            }
        }
        $variant->save();

        // Gallery column: add any listed paths the variant doesn't have yet.
        if (!empty($row['gallery'])) {
            $this->mergeGalleryPaths($variant, (string) $row['gallery']);
        }

        foreach ($schema->languages as $lang) {
            $n = $row['variant_name.' . $lang->id] ?? null;
            if ($n !== null && $n !== '') {
                $variant->saveTranslation((int) $lang->id, ['name' => $n]);
            }
        }

        /* ---- product fields (last row of a product wins; sheets repeat them) ---- */
        if ($product) {
            $this->mergeProductFields($product, $row, $schema);
        }

        /* ---- custom values ---- */
        foreach ($this->customValuePayloads($row, $schema) as $cv) {
            $model = ProductVariantCustomValue::firstOrNew([
                'product_variant_id' => $variant->id,
                'category_custom_field_id' => $cv['field_id'],
            ]);
            $model->value_text = $cv['value_text'];
            $model->value_number = $cv['value_number'];
            $model->value_date = $cv['value_date'];
            $model->value_json = $cv['value_json'];
            $model->save();
        }

        /* ---- attributes ---- */
        foreach ($schema->attributes() as $attr) {
            $val = $row['attr.' . $attr->id] ?? null;
            if ($val === null || $val === '') {
                continue;
            }
            $match = $attr->values->first(fn ($v) => mb_strtolower((string) $v->value) === mb_strtolower((string) $val));
            if (!$match) {
                continue;
            }
            ProductVariantAttributeValue::updateOrCreate(
                ['product_variant_id' => $variant->id, 'attribute_id' => (int) $attr->id],
                ['attribute_value_id' => (int) $match->id]
            );
        }

        /* ---- pricing: targeted upsert on the PVSS natural key ---- */
        foreach ($schema->branches as $branch) {
            $p = 'branch.' . $branch->id . '.';
            // A branch group left entirely blank means "don't touch this branch".
            $touched = false;
            foreach (array_keys(ProductBulkSchema::BRANCH_FIELDS) as $f) {
                if (array_key_exists($p . $f, $row) && $row[$p . $f] !== null && $row[$p . $f] !== '') {
                    $touched = true;
                    break;
                }
            }
            if (!$touched) {
                continue;
            }

            $stock = ProductVariantBranchStock::firstOrNew([
                'product_variant_id' => $variant->id,
                'branch_id' => (int) $branch->id,
            ]);

            $listed = ProductBulkSchema::parseBool($row[$p . 'is_listed'] ?? null, null);
            if ($listed !== null) {
                $stock->is_listed = $listed;
            }
            $ss = ProductBulkSchema::parseBool($row[$p . 'stock_status'] ?? null, null);
            if ($ss !== null) {
                $stock->stock_status = $ss;
            }
            foreach (['price', 'discounted_price', 'purchase_price'] as $f) {
                $v = $row[$p . $f] ?? null;
                if ($v !== null && $v !== '' && is_numeric($v)) {
                    $stock->{$f} = (float) $v;
                }
            }
            // Unlimited stock is per branch now. Counts are still stored as submitted so
            // switching a branch back to Limited preserves them (mirrors the product form).
            $unlimited = ProductBulkSchema::parseBool($row[$p . 'is_unlimited_stock'] ?? null, null);
            if ($unlimited !== null) {
                $stock->is_unlimited_stock = $unlimited;
            }
            foreach (['available', 'min_alert'] as $f) {
                $v = $row[$p . $f] ?? null;
                if ($v !== null && $v !== '' && is_numeric($v)) {
                    $stock->{$f} = (int) $v;
                }
            }
            $slabCell = ProductBulkSchema::parseSlabs($row[$p . 'pricing_slabs'] ?? null);
            if ($slabCell['action'] === 'clear') {
                $stock->pricing_slabs = null;
            } elseif ($slabCell['action'] === 'set' && $slabCell['slabs'] !== []) {
                $stock->pricing_slabs = $slabCell['slabs'];
            }
            $stock->save();
            ProductHelper::notifyBackInStock($variant->id, (int) $branch->id);
        }
    }

    private function mergeProductFields(Product $product, array $row, ProductBulkSchema $schema): void
    {
        $map = [
            'brand' => fn ($v) => ['brand_id' => $schema->brandId($v)],
            'tax' => fn ($v) => ['tax_category_id' => $schema->taxCategoryId($v)],
            'product_type' => fn ($v) => ['product_type' => ProductBulkSchema::PRODUCT_TYPES[strtolower((string) $v)] ?? 0],
            'status' => fn ($v) => ['status' => strtolower((string) $v) === 'inactive' ? 0 : 1],
            'cod_allowed' => fn ($v) => ['cod_allowed' => ProductBulkSchema::parseBool($v, 0)],
            'return_status' => fn ($v) => ['return_status' => ProductBulkSchema::parseBool($v, 0)],
            'cancelable_status' => fn ($v) => ['cancelable_status' => ProductBulkSchema::parseBool($v, 0)],
            'return_days' => fn ($v) => ['return_days' => (int) $v],
            'total_allowed_quantity' => fn ($v) => ['total_allowed_quantity' => (int) $v],
            'till_status_quick' => fn ($v) => ['till_status_quick' => $v],
            'till_status_ecommerce' => fn ($v) => ['till_status_ecommerce' => $v],
            'is_prescription_required' => fn ($v) => ['is_prescription_required' => (int) $v],
            'is_food' => fn ($v) => ['is_food' => ProductBulkSchema::parseBool($v, 0)],
            'is_addon_only' => fn ($v) => ['is_addon_only' => ProductBulkSchema::parseBool($v, 0)],
        ];

        foreach ($map as $key => $fn) {
            if (array_key_exists($key, $row) && $row[$key] !== null && $row[$key] !== '') {
                foreach ($fn($row[$key]) as $col => $val) {
                    $product->{$col} = $val;
                }
            }
        }
        $product->save();

        foreach ($schema->languages as $lang) {
            $data = [];
            $fields = ProductBulkSchema::TRANSLATABLE_PRODUCT_FIELDS;
            if ((int) $lang->is_default === 1) {
                $fields = array_merge($fields, ProductBulkSchema::SINGLE_LANG_PRODUCT_FIELDS);
            }
            foreach ($fields as $field) {
                $v = $row['ptrans.' . $field . '.' . $lang->id] ?? null;
                if ($v !== null && $v !== '') {
                    $data[$field] = $v;
                }
            }
            if ($data) {
                $product->saveTranslation((int) $lang->id, $data);
            }
        }
    }
}
