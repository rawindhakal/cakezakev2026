<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\ProductAddonGroup;
use App\Models\ProductAddonOption;
use App\Models\ProductAddonOptionBranch;
use App\Models\ProductVariant;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * A food product's own addon setup — the questions it asks and the answers it offers.
 *
 * The whole set is loaded and saved in one call, as the complete picture for that
 * product: a group or option the payload leaves out is removed. That is what lets the
 * form be a straightforward editor rather than a pile of per-row endpoints, and it is the
 * same contract the per-branch price rows already use.
 *
 * Groups belong to ONE product. There is no shared library to accidentally edit from
 * here; "copy from another product" duplicates rows rather than pointing at them, so
 * repricing one dish can never reprice another.
 */
class ProductAddonApiController extends Controller
{
    /** The product's groups, options, per-branch rows and translations, ready for the form. */
    public function index(Request $request)
    {
        $productId = (int) $request->input('product_id');
        if (!$productId) {
            return CommonHelper::responseError('product_not_found');
        }

        /* A branch user may read this form but never save it, and another branch's prices
           are none of their business — so hand back only their own branch's rows. */
        $scopeBranchId = (auth()->check() && isset(auth()->user()->branch->id))
            ? (int) auth()->user()->branch->id
            : null;

        $groups = ProductAddonGroup::with([
            'translations',
            'options.translations',
            'options.branchPrices' => fn ($q) => $scopeBranchId
                ? $q->where('branch_id', $scopeBranchId)
                : $q,
            'options.linkedVariant:id,product_id,name,image',
            'options.linkedVariant.product:id,image,product_type',
        ])->where('product_id', $productId)->orderBy('sort_order')->orderBy('id')->get();

        $groups->each(function ($g) {
            // The same derived line the customer reads, so the operator can see what
            // their rules actually say rather than guessing.
            $g->setAttribute('selection_text', $g->selectionText());
            // `image` is the stored path the form posts back; `image_url` is what to
            // show, which for a linked option is its product's own picture.
            $g->options->each(function ($o) {
                $o->setAttribute('image_url', $o->imageUrl());
                $o->setAttribute('resolved_product_type', $o->productType());
            });
        });

        return CommonHelper::responseWithData($groups);
    }

    /**
     * Variants that may be attached as an addon — "add a Coke".
     *
     * A product cannot offer its own variants as its addons: that would let a dish be an
     * ingredient of itself, and the stock arithmetic would double-count the same row.
     */
    public function linkable(Request $request)
    {
        $exclude = (int) $request->input('product_id');
        $search  = trim((string) $request->input('search', ''));

        $rows = ProductVariant::query()
            ->join('products as p', 'p.id', '=', 'product_variants.product_id')
            ->where('p.status', 1)
            ->where('p.is_draft', 0)
            ->when($exclude, fn ($q) => $q->where('p.id', '!=', $exclude))
            ->when($search !== '', fn ($q) => $q->where(function ($w) use ($search) {
                $w->where('p.name', 'like', "%{$search}%")
                    ->orWhere('product_variants.name', 'like', "%{$search}%");
            }))
            ->orderBy('p.name')->orderBy('product_variants.id')
            ->limit(50)
            ->get([
                'product_variants.id',
                'product_variants.name as variant_name',
                'product_variants.image as variant_image',
                'p.id as product_id',
                'p.name as product_name',
                'p.image as product_image',
                'p.tax_category_id',
                'p.is_addon_only',
                'p.product_type',
            ]);

        /* A linked option shows the product's own picture, so the picker carries it:
           resolved here rather than in the browser, which has no storage path. */
        $rows->transform(function ($r) {
            $path = $r->variant_image ?: $r->product_image;
            $r->image_url = $path ? asset('storage/' . $path) : null;
            unset($r->variant_image, $r->product_image);

            return $r;
        });

        return CommonHelper::responseWithData($rows);
    }

    /**
     * Food products that actually have an addon setup — the "copy from" list.
     *
     * Being food only means a product MAY ask questions; most of a menu has none yet.
     * Offering those as a source listed products that would copy nothing, so the operator
     * picked one, saw "copied", and found an empty form. Only products with at least one
     * group belong here.
     *
     * "Apply to other products" is the opposite direction and keeps the plain food list:
     * the whole point there is pushing a setup onto products that have none.
     */
    public function sources(Request $request)
    {
        $exclude = (int) $request->input('product_id');
        $search  = trim((string) $request->input('search', ''));

        $rows = Product::query()
            ->where('is_food', 1)
            ->whereHas('addonGroups')
            ->when($exclude, fn ($q) => $q->where('id', '!=', $exclude))
            ->when($search !== '', fn ($q) => $q->where('name', 'like', "%{$search}%"))
            ->orderBy('name')
            ->limit(50)
            ->get(['id', 'name']);

        return CommonHelper::responseWithData($rows);
    }

    /**
     * Branch one option's picture and hand back its path.
     *
     * Separate from `save` because the form posts its whole menu as JSON: nesting files
     * inside that would mean rebuilding the payload as multipart for the sake of an
     * optional thumbnail. The path returned here is what `save` then persists, and a
     * picture that is uploaded but never saved is cleaned up by the storage sweep.
     */
    public function uploadImage(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'image' => 'required|file|mimes:jpeg,jpg,png,gif,webp|max:2048',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $path = CommonHelper::uploadFile($request, 'image', 'products/addons');

        return CommonHelper::responseWithData([
            'path' => $path,
            'url'  => asset('storage/' . $path),
        ]);
    }

    /**
     * Replace a product's entire addon setup.
     *
     * Replace-not-merge is deliberate: the form always holds the whole picture, so a group
     * the operator deleted on screen has to disappear here too. Everything runs in one
     * transaction, because a half-saved menu would price carts wrongly.
     */
    public function save(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_id'                      => 'required|integer|exists:products,id',
            'groups'                          => 'nullable|array',
            'groups.*.name'                   => 'required|string|max:191',
            'groups.*.input_type'             => 'required|in:radio,checkbox',
            'groups.*.is_required'            => 'nullable|boolean',
            'groups.*.min_select'             => 'nullable|integer|min:0|max:50',
            'groups.*.max_select'             => 'nullable|integer|min:0|max:50',
            'groups.*.max_qty_per_option'     => 'nullable|integer|min:1|max:50',
            'groups.*.status'                 => 'nullable|integer|in:0,1',
            'groups.*.options'                => 'required|array|min:1',
            'groups.*.options.*.name'         => 'required|string|max:191',
            'groups.*.options.*.image'        => 'nullable|string|max:191',
            'groups.*.options.*.product_type' => 'nullable|integer|in:0,1,2,4',
            'groups.*.options.*.linked_variant_id' => 'nullable|integer|exists:product_variants,id',
            'groups.*.options.*.is_free'      => 'nullable|integer|in:0,1',
            'groups.*.options.*.price_source' => 'nullable|in:custom,product',
            'groups.*.options.*.branches'       => 'nullable|array',
            'groups.*.options.*.branches.*.branch_id' => 'required|integer|exists:branches,id',
            'groups.*.options.*.branches.*.price' => 'nullable|numeric|min:0',
            'groups.*.options.*.branches.*.discounted_price' => 'nullable|numeric|min:0',
        ], [
            'groups.*.options.required' => __('addon_group_needs_an_option'),
            'groups.*.options.min'      => __('addon_group_needs_an_option'),
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $product = Product::find($request->input('product_id'));
        $groups  = $request->input('groups', []) ?: [];

        // A product that is not food asks no questions: clearing the flag clears the setup
        // rather than leaving it to resurface if the flag is switched back on.
        if ((int) $product->is_food !== 1) {
            self::deleteGroups(ProductAddonGroup::where('product_id', $product->id));

            return CommonHelper::responseSuccess('addons_saved_successfully');
        }

        foreach ($groups as $group) {
            if ($error = $this->groupRuleError($product, $group)) {
                return CommonHelper::responseError($error);
            }
        }

        return DB::transaction(function () use ($product, $groups) {
            $keptGroups = [];

            foreach (array_values($groups) as $gi => $g) {
                $model = $this->upsertGroup($product, $g, $gi);
                $keptGroups[] = $model->id;
                $this->syncOptions($model, $g['options'] ?? []);
            }

            self::deleteGroups(
                ProductAddonGroup::where('product_id', $product->id)
                    ->when(!empty($keptGroups), fn ($q) => $q->whereNotIn('id', $keptGroups))
            );

            return CommonHelper::responseSuccess('addons_saved_successfully');
        });
    }

    /**
     * Copy another product's addon setup onto this one, as fresh rows.
     *
     * Rows, not references: the two menus are independent from the moment they are
     * copied, which is the whole reason groups belong to a product in the first place.
     */
    public function copy(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_id' => 'required|integer|exists:products,id',
            'source_id'  => 'required|integer|exists:products,id|different:product_id',
            'replace'    => 'nullable|boolean',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $target = Product::find($request->input('product_id'));
        if ((int) $target->is_food !== 1) {
            return CommonHelper::responseError('addons_only_for_food_products');
        }

        $copied = DB::transaction(function () use ($request, $target) {
            if ($request->boolean('replace')) {
                self::deleteGroups(ProductAddonGroup::where('product_id', $target->id));
            }

            return $this->duplicateGroups((int) $request->input('source_id'), $target);
        });

        return CommonHelper::responseWithData([
            'copied'  => $copied,
            'message' => __('addons_copied_successfully'),
        ]);
    }

    /** Push this product's setup onto several others at once — a menu section in one go. */
    public function apply(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_id'    => 'required|integer|exists:products,id',
            'target_ids'    => 'required|array|min:1',
            'target_ids.*'  => 'integer|exists:products,id',
            'replace'       => 'nullable|boolean',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $sourceId = (int) $request->input('product_id');
        $targets  = array_values(array_unique(array_map('intval', $request->input('target_ids'))));
        $applied  = 0;
        $skipped  = [];

        DB::transaction(function () use ($sourceId, $targets, $request, &$applied, &$skipped) {
            foreach ($targets as $id) {
                if ($id === $sourceId) {
                    continue;
                }
                $target = Product::find($id);
                // Silently making a product food would change how it sells; say so instead.
                if (!$target || (int) $target->is_food !== 1) {
                    $skipped[] = $target->name ?? $id;
                    continue;
                }
                if ($request->boolean('replace')) {
                    self::deleteGroups(ProductAddonGroup::where('product_id', $target->id));
                }
                $this->duplicateGroups($sourceId, $target);
                $applied++;
            }
        });

        return CommonHelper::responseWithData([
            'applied' => $applied,
            'skipped' => $skipped,
            'message' => __('addons_applied_to_count_products', ['count' => $applied]),
        ]);
    }

    /** Deep-copy every group, option, translation and branch row from one product to another. */
    private function duplicateGroups(int $sourceId, Product $target): int
    {
        $source = ProductAddonGroup::with(['translations', 'options.translations', 'options.branchPrices'])
            ->where('product_id', $sourceId)->orderBy('sort_order')->orderBy('id')->get();

        foreach ($source as $g) {
            $new = ProductAddonGroup::create([
                'product_id'         => $target->id,
                'name'               => $g->name,
                'input_type'         => $g->input_type,
                'is_required'        => $g->is_required,
                'min_select'         => $g->min_select,
                'max_select'         => $g->max_select,
                'max_qty_per_option' => $g->max_qty_per_option,
                'sort_order'         => $g->sort_order,
                'status'             => $g->status,
            ]);

            foreach (self::translationRows('product_addon_group_translations', 'addon_group_id', $g->id) as $t) {
                $new->saveTranslation((int) $t->language_id, ['name' => $t->name]);
            }

            foreach ($g->options as $o) {
                $newOption = ProductAddonOption::create([
                    'addon_group_id'    => $new->id,
                    'name'              => $o->name,
                    // The path, not a second copy of the file. discardImage() checks for
                    // other holders before deleting, so the two never tread on each other.
                    'image'             => $o->image,
                    'product_type'      => $o->product_type,
                    'linked_variant_id' => $o->linked_variant_id,
                    'is_free'           => $o->is_free,
                    'price_source'      => $o->price_source,
                    'sort_order'        => $o->sort_order,
                    'status'            => $o->status,
                ]);

                foreach (self::translationRows('product_addon_option_translations', 'addon_option_id', $o->id) as $t) {
                    $newOption->saveTranslation((int) $t->language_id, ['name' => $t->name]);
                }

                foreach ($o->branchPrices as $sp) {
                    ProductAddonOptionBranch::create([
                        'addon_option_id'  => $newOption->id,
                        'branch_id'         => $sp->branch_id,
                        'is_available'     => $sp->is_available,
                        'price'            => $sp->price,
                        'discounted_price' => $sp->discounted_price,
                    ]);
                }
            }
        }

        return $source->count();
    }

    /**
     * Translations straight from the table.
     *
     * The models append `translations` as a plain array for the API payload, which
     * shadows the relation — reading it as objects here silently copied nothing.
     */
    private static function translationRows(string $table, string $foreignKey, $ownerId)
    {
        return DB::table($table)->where($foreignKey, $ownerId)->get();
    }

    /**
     * Reject a setup the customer could never satisfy, rather than letting it reach the
     * cart and fail there.
     */
    private function groupRuleError(Product $product, array $group): ?string
    {
        $options = $group['options'] ?? [];
        $count   = count($options);
        $radio   = ($group['input_type'] ?? 'radio') === 'radio';
        $min     = (int) ($group['min_select'] ?? 0);
        $max     = (int) ($group['max_select'] ?? 0);   // 0 = no limit

        /* Only the combinations a customer could never satisfy are refused.
           A maximum or a free allowance above the option count is harmless — nobody can
           pick more options than exist — and refusing it would block an operator who
           sets the ceiling before adding the rest of the list, or who deletes an option
           later and suddenly cannot save the group at all. A minimum above the count is
           different: that group can never be answered. */
        if (!$radio) {
            if ($max > 0 && $min > $max) {
                return __('min_select_cannot_exceed_max_select');
            }
            if ($min > $count) {
                return __('min_select_cannot_exceed_option_count');
            }
        }

        foreach ($options as $o) {
            $linkedId = (int) ($o['linked_variant_id'] ?? 0);
            $source   = $o['price_source'] ?? 'custom';
            $isFree   = (int) ($o['is_free'] ?? 0) === 1;
            $branches   = is_array($o['branches'] ?? null) ? $o['branches'] : [];

            if ($linkedId) {
                $variant = ProductVariant::find($linkedId);
                if (!$variant) {
                    return __('addon_option_not_available');
                }
                // A dish cannot be an ingredient of itself.
                if ((int) $variant->product_id === (int) $product->id) {
                    return __('addon_cannot_link_the_same_product');
                }
            } elseif ($source === 'product' && !$isFree) {
                return __('addon_price_from_product_needs_a_link');
            }

            if ($source !== 'product') {
                $offered = array_filter(
                    $branches,
                    fn ($s) => !empty($s['branch_id']) && (!array_key_exists('is_available', $s) || (int) $s['is_available'] === 1)
                );
                if (empty($offered)) {
                    return __('addon_option_needs_a_branch_price');
                }
            }

            // A free option has no price left to check.
            if ($isFree) {
                continue;
            }

            $seen = [];
            foreach ($branches as $s) {
                $branchId = (int) ($s['branch_id'] ?? 0);
                if (isset($seen[$branchId])) {
                    return __('addon_option_branch_listed_twice');
                }
                $seen[$branchId] = true;

                // Same rule products use: equal is allowed and simply means "no offer".
                if (round((float) ($s['discounted_price'] ?? 0), 2) > round((float) ($s['price'] ?? 0), 2)) {
                    return __('discounted_price_cannot_be_greater_than_price');
                }
            }
        }

        return null;
    }

    /** Create or update one group, pinning a radio group to exactly one pick. */
    private function upsertGroup(Product $product, array $g, int $position): ProductAddonGroup
    {
        $radio = ($g['input_type'] ?? 'radio') === 'radio';
        $required = (bool) ($g['is_required'] ?? false);

        $attributes = [
            'product_id'  => $product->id,
            'name'        => $g['name'],
            'input_type'  => $radio ? 'radio' : 'checkbox',
            'is_required' => $required,
            // A radio group is exactly one pick by definition; the rest would be noise,
            // and a stepper on a single choice makes no sense.
            'min_select'  => $radio ? ($required ? 1 : 0) : max((int) ($g['min_select'] ?? 0), $required ? 1 : 0),
            'max_select'  => $radio ? 1 : (int) ($g['max_select'] ?? 0),
            'max_qty_per_option' => $radio ? 1 : max(1, (int) ($g['max_qty_per_option'] ?? 1)),
            'sort_order'  => $position,
            'status'      => (int) ($g['status'] ?? 1),
        ];

        $model = !empty($g['id'])
            ? ProductAddonGroup::where('product_id', $product->id)->find($g['id'])
            : null;

        if ($model) {
            $model->fill($attributes)->save();
        } else {
            $model = ProductAddonGroup::create($attributes);
        }

        foreach (($g['translations'] ?? []) as $languageId => $t) {
            $model->saveTranslation((int) $languageId, ['name' => $t['name'] ?? null]);
        }

        return $model;
    }

    /** Sync a group's options; the payload is the complete set, so the rest are removed. */
    private function syncOptions(ProductAddonGroup $group, array $options): void
    {
        $kept = [];

        $orphaned = [];

        foreach (array_values($options) as $i => $o) {
            $linkedId = !empty($o['linked_variant_id']) ? (int) $o['linked_variant_id'] : null;
            // A linked option draws its picture from its product, so it stores none —
            // which also means switching an option to linked releases the old upload.
            $image = $linkedId ? null : (is_string($o['image'] ?? null) && $o['image'] !== '' ? $o['image'] : null);
            $productType = $linkedId ? null : (int) ($o['product_type'] ?? 0);

            $linkedName = $linkedId ? self::linkedOptionName($linkedId) : null;

            $attributes = [
                'addon_group_id'    => $group->id,
                'name'              => $linkedName ?: $o['name'],
                'image'             => $image,
                'product_type'      => $productType,
                'linked_variant_id' => $linkedId,
                'is_free'           => (int) ($o['is_free'] ?? 0) === 1 ? 1 : 0,
                'price_source'      => ($o['price_source'] ?? 'custom') === 'product' ? 'product' : 'custom',
                'sort_order'        => $i,
                'status'            => (int) ($o['status'] ?? 1),
            ];

            $model = !empty($o['id'])
                ? ProductAddonOption::where('addon_group_id', $group->id)->find($o['id'])
                : null;

            $previousImage = $model ? $model->image : null;

            if ($model) {
                $model->fill($attributes)->save();
            } else {
                $model = ProductAddonOption::create($attributes);
            }
            $kept[] = $model->id;

            if ($previousImage && $previousImage !== $model->image) {
                $orphaned[] = $previousImage;
            }

            foreach (($o['translations'] ?? []) as $languageId => $t) {
                $model->saveTranslation((int) $languageId, ['name' => $t['name'] ?? null]);
            }

            $this->syncBranchPrices($model, is_array($o['branches'] ?? null) ? $o['branches'] : []);
        }

        $dropped = ProductAddonOption::where('addon_group_id', $group->id)
            ->when(!empty($kept), fn ($q) => $q->whereNotIn('id', $kept))
            ->get(['id', 'image']);

        ProductAddonOption::whereIn('id', $dropped->pluck('id'))->forceDelete();

        // After the rows are gone, so the "is anyone else using it" check is honest.
        foreach (array_merge($orphaned, $dropped->pluck('image')->all()) as $path) {
            self::discardImage($path);
        }
    }

    private static function linkedOptionName(int $variantId): ?string
    {
        $row = DB::table('product_variants as v')
            ->join('products as p', 'p.id', '=', 'v.product_id')
            ->where('v.id', $variantId)
            ->first(['v.name as variant_name', 'p.name as product_name']);

        $product = trim((string) ($row->product_name ?? ''));
        if ($product === '') {
            return null;
        }

        $variant = trim((string) ($row->variant_name ?? ''));

        return mb_substr(self::linkedLabel($product, $variant), 0, 191);
    }

    private static function linkedLabel(string $product, string $variant): string
    {
        if ($variant === '') {
            return $product;
        }

        return mb_stripos($variant, $product) === 0 ? $variant : $product . ' — ' . $variant;
    }

    /**
     * Delete groups along with the option pictures they leave behind.
     *
     * The database cascades the option rows; nothing cascades the files, so the paths
     * are collected before the rows disappear and swept afterwards.
     */
    private static function deleteGroups($query): void
    {
        $groupIds = $query->pluck('id');
        if ($groupIds->isEmpty()) {
            return;
        }

        $images = ProductAddonOption::whereIn('addon_group_id', $groupIds)
            ->whereNotNull('image')->pluck('image')->unique()->all();

        ProductAddonGroup::whereIn('id', $groupIds)->forceDelete();

        foreach ($images as $path) {
            self::discardImage($path);
        }
    }

    /**
     * Drop an option picture once nothing points at it any more.
     *
     * Copy-from-product duplicates the path rather than the file, so two dishes can share
     * one photo — deleting it blindly would blank the other dish's menu.
     */
    private static function discardImage(?string $path): void
    {
        if (!$path) {
            return;
        }

        $stillUsed = ProductAddonOption::withTrashed()->where('image', $path)->exists();
        if (!$stillUsed) {
            CommonHelper::deleteFile($path);
        }
    }

    /**
     * Replace an option's per-branch rows with exactly what was sent.
     *
     * Dropping the branches left out is the point: that is how an operator withdraws a
     * topping from one country without touching the others. An option that follows the
     * linked product's catalogue price keeps no rows of its own at all.
     */
    private function syncBranchPrices(ProductAddonOption $option, array $branches): void
    {
        if ($option->price_source === 'product') {
            ProductAddonOptionBranch::where('addon_option_id', $option->id)->delete();

            return;
        }

        $kept = [];
        foreach ($branches as $row) {
            $branchId = (int) ($row['branch_id'] ?? 0);
            if (!$branchId) {
                continue;
            }

            $price = round((float) ($row['price'] ?? 0), 2);
            $offer = round((float) ($row['discounted_price'] ?? 0), 2);
            if ($offer >= $price) {
                $offer = 0.0;   // 0 is the "no offer" marker
            }

            ProductAddonOptionBranch::updateOrCreate(
                ['addon_option_id' => $option->id, 'branch_id' => $branchId],
                [
                    'is_available'     => (bool) ($row['is_available'] ?? true),
                    'price'            => $price,
                    'discounted_price' => $offer,
                ]
            );
            $kept[] = $branchId;
        }

        ProductAddonOptionBranch::where('addon_option_id', $option->id)
            ->when(!empty($kept), fn ($q) => $q->whereNotIn('branch_id', $kept))
            ->delete();
    }
}
