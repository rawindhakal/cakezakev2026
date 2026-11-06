<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\CategoryCustomField;
use App\Models\CategoryCustomSection;
use App\Models\Product;
use App\Services\LanguageService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class CategoryApiController extends Controller
{
    protected $languageService;

    public function __construct(LanguageService $languageService)
    {
        $this->languageService = $languageService;
    }

    public function getCategories(Request $request)
    {
        try {

            $useContentLanguage = $request->header('Content-Language') !== null
                && trim((string) $request->header('Content-Language')) !== '';

            $limit = $request->input('limit');
            $offset = (($request->input('offset')) - 1) * $limit;
            $filter = $request->input('filter', '');
            $categoryId = $request->input('id');
            $statusFilter = $request->input('status');
            $parentFilter = $request->input('parent_id');

            $categoriesQuery = Category::query();

            if (!is_null($statusFilter)) {
                $categoriesQuery = $categoriesQuery->where('status', $statusFilter);
            }

            if ($categoryId) {
                $categoriesQuery = $categoriesQuery->where('id', $categoryId);
            }

            if (!is_null($parentFilter) && $parentFilter !== '') {
                $categoriesQuery = $categoriesQuery->where('parent_id', (int) $parentFilter);
            }

            if ($filter) {
                $categoriesQuery = $categoriesQuery->where(function ($query) use ($filter) {
                    $query->where('name', 'like', "%{$filter}%");
                });
            }
            $total = $categoriesQuery->count();
            if (!$useContentLanguage) {
                $categoriesQuery = $categoriesQuery->with('translations');
            }

            // Per-category counts + the names behind them: the card/tree views show the
            // totals and reveal the actual values on hover, so both travel together.
            $categoriesQuery = $categoriesQuery
                ->withCount(['categoryAttributes', 'customSections', 'childs', 'products'])
                ->with([
                    'categoryAttributes:id,name',
                    'customSections:id,category_id,name',
                    'childs:id,parent_id,name',
                ]);
            if (isset($limit) && !is_null($limit)) {
                $categories = $categoriesQuery->orderBy('id', 'desc')->skip($offset)->take($limit)->get();
            } else {
                $categories = $categoriesQuery->orderBy('id', 'desc')->get();
            }

            if ($categories->isEmpty()) {
                return CommonHelper::responseWithData([], 0);
            }

            $categories->makeHidden(['has_child', 'has_active_child']);

            return CommonHelper::responseWithData($categories, $total);
        } catch (\Exception $e) {
            return CommonHelper::responseError($e->getMessage());
        }
    }

    public function getMainCategories(Request $request)
    {
        $categories = CommonHelper::getMainCategories($request);
        $total = $categories->count();
        if (empty($categories)) {
            return CommonHelper::responseError('category_not_found');
        }
        return CommonHelper::responseWithData($categories, $total);
    }

    public function getCategoryChain(Request $request)
    {
        // Only ACTIVE categories are offered as options, EXCEPT the currently-selected
        $siblings = fn ($parentId, $includeId = null) => Category::where('parent_id', $parentId)
            ->where(function ($q) use ($includeId) {
                $q->where('status', 1);
                if ($includeId) {
                    $q->orWhere('id', $includeId);
                }
            })
            ->with('translations')
            ->orderBy('row_order', 'ASC')
            ->get()
            ->makeHidden(['has_child', 'has_active_child']);

        $leafId = (int) $request->input('id', 0);

        // No leaf → just the main (top) level.
        if (!$leafId) {
            return CommonHelper::responseWithData([
                ['parentId' => 0, 'items' => $siblings(0), 'selectedId' => null],
            ]);
        }

        // Walk root → leaf (guarded against a bad cyclic parent chain).
        $chain = [];
        $cur = Category::find($leafId);
        $guard = 0;
        while ($cur && $guard++ < 25) {
            array_unshift($chain, $cur);
            $cur = $cur->parent_id ? Category::find($cur->parent_id) : null;
        }

        if (empty($chain)) {
            return CommonHelper::responseWithData([
                ['parentId' => 0, 'items' => $siblings(0), 'selectedId' => null],
            ]);
        }

        $levels = [];
        $parentId = 0;
        foreach ($chain as $cat) {
            $levels[] = [
                'parentId'   => $parentId,
                'items'      => $siblings($parentId, $cat->id),
                'selectedId' => $cat->id,
            ];
            $parentId = $cat->id;
        }

        // Trailing level = the leaf's children (nothing selected), if it has any.
        $leafChildren = $siblings($leafId);
        if ($leafChildren->count() > 0) {
            $levels[] = ['parentId' => $leafId, 'items' => $leafChildren, 'selectedId' => null];
        }

        return CommonHelper::responseWithData($levels);
    }

    public function getCategoriesByRowOrder()
    {
        $categories = Category::
            where('status', 1)
            ->with('translations')
            ->orderBy('row_order', 'ASC')
            ->get();
        $categories->makeHidden(['has_child', 'has_active_child']);
        return CommonHelper::responseWithData($categories);
    }
    public function save(Request $request)
    {
        // Get default language to check if this is default language save
        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $isDefaultLanguage = ($request->language_id == $defaultLanguage->id);

        $rules = [
            'name' => 'required',
            'language_id' => 'required|exists:languages,id'
        ];
        if ($isDefaultLanguage) {
            $rules['name'] = 'required';
            $rules['image'] = 'required|mimes:jpeg,jpg,png,gif,webp,svg';
        } else {
            $rules['name'] = 'nullable';
            $rules['image'] = 'nullable|mimes:jpeg,jpg,png,gif,webp,svg';
        }

        $validator = Validator::make($request->all(), $rules);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // Products may only live on LEAF categories. A parent that still holds
        // products is allowed only when the admin confirmed moving them into this
        // new child (move_parent_products=1); otherwise they must clear it first.
        $parentId = (int) ($request->parent_id ?? 0);
        $moveParentProducts = (int) $request->input('move_parent_products', 0) === 1;
        if ($parentId > 0 && !$moveParentProducts && Product::where('category_id', $parentId)->exists()) {
            return CommonHelper::responseError('parent_category_has_products_cannot_have_subcategory');
        }

        if ($request->has('slug') && !empty($request->slug)) {
            $slug = $request->slug;
        } else {
            // Generate slug from name
            $slug = preg_replace('/\s+/', '-', trim(
                preg_replace('/[^A-Za-z0-9 ]/', '', $request->name)
            ));

            // Ensure slug uniqueness
            $count = Category::where('slug', $slug)->count();
            if ($count > 0) {
                $slug .= '-' . ($count + 1);
            }
        }

        $category = Category::where('slug', $slug)->first();

        if (!$category) {
            $category = new Category();
            $category->slug = $slug;
            $category->status = 1;
            $category->parent_id = $request->parent_id ?? 0;

            $category->image = CommonHelper::uploadFile($request, 'image', 'categories') ?? '';

            $category->name = $request->name;
            $category->meta_title = $request->meta_title ?? "";
            $category->meta_keywords = $request->meta_keywords ?? "";
            $category->schema_markup = $request->schema_markup ?? "";
            $category->meta_description = $request->meta_description ?? "";

            $category->save();
        }

        // Confirmed hand-over: the parent's products move into this new child, so
        // the parent becomes a pure container and products stay on a leaf.
        if ($moveParentProducts && $parentId > 0 && $category->parent_id == $parentId) {
            Product::where('category_id', $parentId)->update(['category_id' => $category->id]);
        }

        $translationData = [
            'name' => $request->name,
            'meta_title' => $request->meta_title ?? "",
            'meta_keywords' => $request->meta_keywords ?? "",
            'schema_markup' => $request->schema_markup ?? "",
            'meta_description' => $request->meta_description ?? "",
        ];

        $category->saveTranslation($request->language_id, $translationData);

        $isDefaultLanguage = ($request->language_id == $this->languageService->getDefaultLanguage()->id);
        if ($isDefaultLanguage) {
            $this->syncCategoryAttributes(
                $category,
                $this->decodeJsonInput($request->input('attributes', [])),
                $this->decodeJsonInput($request->input('inherited_off_attribute_ids', []))
            );
        }
        $this->syncCategoryCustomSections(
            $category,
            $this->decodeJsonInput($request->input('custom_sections', [])),
            $this->decodeJsonInput($request->input('inherited_off_section_names', [])),
            (int) $request->language_id,
            $isDefaultLanguage
        );

        return CommonHelper::responseWithData([
            'id' => $category->id,
            'message' => __('category_saved_successfully')
        ]);
    }
    public function update(Request $request)
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $isDefaultLanguage = ($request->language_id == $defaultLanguage->id);

        $rules = [
            'id' => 'required|exists:categories,id',
            'language_id' => 'required|exists:languages,id'
        ];
        if ($isDefaultLanguage) {
            $rules['name'] = 'required';
        } else {
            $rules['name'] = 'nullable';
        }

        $validator = Validator::make($request->all(), $rules);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $category = Category::find($request->id);
        if (!$category) {
            return CommonHelper::responseError('category_not_found');
        }

        if ($isDefaultLanguage && $request->has('slug')) {
            $category->slug = $request->slug;
        }

        if ($isDefaultLanguage) {
            $category->status = $request->status ?? $category->status;

            // Products may only live on LEAF categories: a parent still holding
            // products needs the admin's confirmation to move them into this one.
            $parentId = (int) ($request->parent_id ?? $category->parent_id);
            $moveParentProducts = (int) $request->input('move_parent_products', 0) === 1;
            if ($parentId > 0 && $parentId !== (int) $category->id
                && !$moveParentProducts && Product::where('category_id', $parentId)->exists()) {
                return CommonHelper::responseError('parent_category_has_products_cannot_have_subcategory');
            }

            $category->parent_id = $request->parent_id ?? $category->parent_id;

            if ($moveParentProducts && $parentId > 0 && $parentId !== (int) $category->id) {
                Product::where('category_id', $parentId)->update(['category_id' => $category->id]);
            }
        }

        $category->image = CommonHelper::uploadFile($request, 'image', 'categories', $category->image);

        if ($isDefaultLanguage) {
            $category->name = $request->name;
            $category->meta_title = $request->meta_title ?? "";
            $category->meta_keywords = $request->meta_keywords ?? "";
            $category->schema_markup = $request->schema_markup ?? "";
            $category->meta_description = $request->meta_description ?? "";
        }

        $category->save();

        // Save/update translation for the specified language
        $translationData = [
            'name' => $request->name,
            'meta_title' => $request->meta_title ?? "",
            'meta_keywords' => $request->meta_keywords ?? "",
            'schema_markup' => $request->schema_markup ?? "",
            'meta_description' => $request->meta_description ?? "",
        ];

        $category->saveTranslation($request->language_id, $translationData);

        if ($isDefaultLanguage) {
            $this->syncCategoryAttributes(
                $category,
                $this->decodeJsonInput($request->input('attributes', [])),
                $this->decodeJsonInput($request->input('inherited_off_attribute_ids', []))
            );
        }
        $this->syncCategoryCustomSections(
            $category,
            $this->decodeJsonInput($request->input('custom_sections', [])),
            $this->decodeJsonInput($request->input('inherited_off_section_names', [])),
            (int) $request->language_id,
            $isDefaultLanguage
        );

        return CommonHelper::responseSuccess('category_updated_successfully');
    }

    public function delete(Request $request)
    {
        if (!$request->filled('id')) {
            return CommonHelper::responseError('category_id_is_required');
        }

        $category = Category::find($request->id);
        if (!$category) {
            return CommonHelper::responseSuccess('category_already_deleted');
        }

        // Child categories first: deleting a parent is what strands a whole subtree.
        $childCount = Category::where('parent_id', $category->id)->count();
        if ($childCount > 0) {
            return CommonHelper::responseError(
                __('category_has_sub_categories_move_or_delete_them_first', ['count' => $childCount])
            );
        }

        // Products anywhere in this category's subtree — a parent with no products of
        // its own can still have children that do.
        $subtreeIds = $this->descendantCategoryIds($category->id);
        $productCount = Product::whereIn('category_id', $subtreeIds)->count();
        if ($productCount > 0) {
            return CommonHelper::responseError(
                __('category_in_use_by_products_deactivate_instead', ['count' => $productCount])
            );
        }

        CommonHelper::deleteFile($category->image);
        $category->delete();
        return CommonHelper::responseSuccess('category_deleted_successfully');
    }

    /** A category id plus every descendant id (breadth-first, one query per level). */
    private function descendantCategoryIds(int $rootId): array
    {
        $ids = [$rootId];
        $frontier = [$rootId];
        $guard = 0;
        while (!empty($frontier) && $guard++ < 50) {
            $children = Category::whereIn('parent_id', $frontier)->pluck('id')->map('intval')->all();
            $children = array_values(array_diff($children, $ids));
            if (empty($children)) {
                break;
            }
            $ids = array_merge($ids, $children);
            $frontier = $children;
        }
        return $ids;
    }

    /**
     * Flat active-category list for the AppSelect tree parent picker. Returns the flat
     * active-category list (id, name, parent_id, translations); the excluded category and
     * all its descendants are removed so a category can't become its own ancestor (cycle).
     */
    public function getOptionsData(Request $request)
    {
        $excludeId = (int) $request->input('exclude_id', 0);

        $categories = Category::where('status', 1)
            ->select('id', 'name', 'parent_id')
            ->with(['translations:id,category_id,language_id,name'])
            ->orderBy('name')
            ->get();

        // Collect the excluded subtree (the category + every descendant).
        $excluded = [];
        if ($excludeId) {
            $byParent = [];
            foreach ($categories as $c) {
                $byParent[(int) ($c->parent_id ?? 0)][] = (int) $c->id;
            }
            $stack = [$excludeId];
            while ($stack) {
                $id = array_pop($stack);
                $excluded[$id] = true;
                foreach ($byParent[$id] ?? [] as $childId) {
                    if (!isset($excluded[$childId])) {
                        $stack[] = $childId;
                    }
                }
            }
        }

        $data = $categories
            ->reject(fn (Category $c) => isset($excluded[(int) $c->id]))
            ->map(fn (Category $c) => [
                'id'           => (int) $c->id,
                'name'         => $c->name,
                'parent_id'    => (int) ($c->parent_id ?? 0),
                'translations' => $c->relationLoaded('translations')
                    ? $c->getRelation('translations')->map(fn ($t) => [
                        'language_id' => $t->language_id,
                        'name'        => $t->name,
                    ])->values()->toArray()
                    : [],
            ])->values();

        return CommonHelper::responseWithData($data);
    }

    /**
     * Parent-selection check for the category form: does this candidate parent hold
     * products, and how many? Drives the "move its products here?" confirmation.
     */
    public function parentCheck(Request $request)
    {
        $id = (int) $request->input('id', 0);
        $category = Category::find($id);
        if (!$category) {
            return CommonHelper::responseError('category_not_found');
        }

        return CommonHelper::responseWithData([
            'id' => (int) $category->id,
            'name' => $category->name,
            'product_count' => Product::where('category_id', $id)->count(),
        ]);
    }

    public function getActiveCategories()
    {
        $categories = Category::where('status', 1)
            ->with('translations')
            ->orderBy('id', 'ASC')
            ->get();
        $categories->makeHidden(['has_child', 'has_active_child']);

        return CommonHelper::responseWithData($categories);
    }

    public function updateCategoriesOrder(Request $request)
    {
        $categories = $request->all();
        foreach ($categories as $category) {
            $data = Category::find($category["id"]);
            $data->row_order = $category["row_order"];
            $data->save();
        }
        return CommonHelper::responseSuccess('category_order_updated_successfully');
    }

    public function checkSlug($slug)
    {
        try {
            // Query the database to count the documents that match the slug pattern
            $existingDocumentCount = Category::where('slug', 'like', $slug . '%')->count();

            // Construct the response data
            $responseData = [
                'unique' => $existingDocumentCount === 0,
                'count' => $existingDocumentCount
            ];

            return response()->json($responseData);
        } catch (\Exception $e) {
            return response()->json(['error' => __('an_error_occurred_while_checking_slug_uniqueness')], 500);
        }
    }

    /**
     * Resolve effective attributes + custom fields for a category, walking the parent chain.
     * If only parent_id supplied (creating a new category), returns inherited schema preview.
     */
    public function getSchema(Request $request)
    {
        $categoryId = (int) $request->input('id', 0);
        $parentId = (int) $request->input('parent_id', 0);

        $attributes = collect();
        $customSections = collect();
        $own = [
            'attribute_ids' => [],
            'overridden_off_attribute_ids' => [],
            'custom_section_ids' => [],
            'overridden_off_section_names' => [],
        ];

        if ($categoryId > 0) {
            $category = Category::with(['categoryAttributes' => function ($q) {
                $q->withPivot(['is_overridden_off'])
                    ->withAllTranslations()
                    ->with(['values' => function ($vq) {
                        $vq->withAllTranslations();
                    }]);
            }, 'customSections' => function ($q) {
                $q->withAllTranslations()->with(['fields' => function ($fq) {
                    $fq->withAllTranslations();
                }]);
            }])->find($categoryId);

            if (!$category) {
                return CommonHelper::responseError('category_not_found');
            }

            foreach ($category->categoryAttributes as $attr) {
                $own['attribute_ids'][] = (int) $attr->id;
                if ($attr->pivot->is_overridden_off) {
                    $own['overridden_off_attribute_ids'][] = (int) $attr->id;
                }
            }
            foreach ($category->customSections as $section) {
                $own['custom_section_ids'][] = (int) $section->id;
                if ($section->is_overridden_off) {
                    $own['overridden_off_section_names'][] = $section->name;
                }
            }

            $attributes = $category->effectiveAttributes();
            $customSections = $category->effectiveCustomSections();
            $parentId = $category->parent_id;
        } else if ($parentId > 0) {
            $parent = Category::find($parentId);
            if ($parent) {
                $attributes = $parent->effectiveAttributes();
                $customSections = $parent->effectiveCustomSections();
            }
        }

        return CommonHelper::responseWithData([
            'parent_id' => $parentId,
            'attributes' => $attributes,
            'custom_sections' => $customSections,
            'own' => $own,
        ]);
    }

    protected function decodeJsonInput($input): array
    {
        if (is_array($input)) {
            return $input;
        }
        if (is_string($input) && $input !== '') {
            $decoded = json_decode($input, true);
            return is_array($decoded) ? $decoded : [];
        }
        return [];
    }

    public function attachAttribute(Request $request)
    {
        $categoryId  = (int) $request->input('category_id', 0);
        $attributeId = (int) $request->input('attribute_id', 0);
        if (!$categoryId || !$attributeId) {
            return CommonHelper::responseError('category_and_attribute_are_required');
        }
        $category = Category::find($categoryId);
        if (!$category) {
            return CommonHelper::responseError('category_not_found');
        }
        $category->categoryAttributes()->syncWithoutDetaching([$attributeId => ['is_overridden_off' => 0]]);

        return CommonHelper::responseSuccess('attribute_added_to_category');
    }

    /**
     * Sync many-to-many category_attribute pivot.
     * $payload rows: ['attribute_id']
     * $offIds: attribute ids inherited from parent the user toggled off for this category.
     */
    protected function syncCategoryAttributes(Category $category, array $payload, array $offIds): void
    {
        $sync = [];
        foreach ($payload as $row) {
            $attrId = (int) ($row['attribute_id'] ?? 0);
            if ($attrId <= 0) {
                continue;
            }
            $sync[$attrId] = ['is_overridden_off' => 0];
        }
        // Inherited-off entries are stored as pivot rows so child can suppress parent attribute
        foreach ($offIds as $attrId) {
            $attrId = (int) $attrId;
            if ($attrId <= 0) {
                continue;
            }
            $sync[$attrId] = ['is_overridden_off' => 1];
        }

        $category->categoryAttributes()->sync($sync);
    }

    /**
     * Sync category custom sections (with nested fields).
     * $payload rows: ['id'?, 'name', 'sort_order', 'fields' => [
     *                  ['id'?, 'field_label', 'field_type', 'options', 'is_required', 'sort_order']
     *                ]]
     * $offNames: section names from parent toggled off here (suppression rows).
     */
    protected function syncCategoryCustomSections(Category $category, array $payload, array $offNames, int $languageId, bool $isDefaultLanguage): void
    {
        $incomingSectionIds = [];

        foreach ($payload as $sIdx => $row) {
            $sectionId = $row['id'] ?? null;
            $name = $row['name'] ?? '';
            $fields = $row['fields'] ?? [];
            if (is_string($fields)) {
                $decoded = json_decode($fields, true);
                $fields = is_array($decoded) ? $decoded : [];
            }

            if ($sectionId) {
                $section = CategoryCustomSection::where('category_id', $category->id)->find($sectionId);
                if (!$section) {
                    continue;
                }
                if ($isDefaultLanguage) {
                    $section->name = $name;
                    $section->is_overridden_off = 0;
                    $section->sort_order = (int) ($row['sort_order'] ?? $sIdx);
                    $section->save();
                }
                $section->saveTranslation($languageId, ['name' => $name]);
            } else if ($isDefaultLanguage && $name !== '') {
                $section = CategoryCustomSection::create([
                    'category_id' => $category->id,
                    'name' => $name,
                    'is_overridden_off' => 0,
                    'sort_order' => (int) ($row['sort_order'] ?? $sIdx),
                ]);
                $section->saveTranslation($languageId, ['name' => $name]);
            } else {
                continue;
            }

            $incomingSectionIds[] = $section->id;
            $this->syncSectionFields($section, $fields, $languageId, $isDefaultLanguage);
        }

        if ($isDefaultLanguage) {
            foreach ($offNames as $idx => $rawName) {
                $rawName = (string) $rawName;
                if ($rawName === '') {
                    continue;
                }
                $section = CategoryCustomSection::where('category_id', $category->id)
                    ->where('name', $rawName)->first();
                if (!$section) {
                    $section = CategoryCustomSection::create([
                        'category_id' => $category->id,
                        'name' => $rawName,
                        'is_overridden_off' => 1,
                        'sort_order' => 9999 + $idx,
                    ]);
                } else {
                    $section->is_overridden_off = 1;
                    $section->save();
                }
                $incomingSectionIds[] = $section->id;
            }

            CategoryCustomSection::where('category_id', $category->id)
                ->whereNotIn('id', $incomingSectionIds)
                ->delete();
        }
    }

    /**
     * Sync fields under a section.
     */
    protected function syncSectionFields(CategoryCustomSection $section, array $fields, int $languageId, bool $isDefaultLanguage): void
    {
        $incomingFieldIds = [];

        foreach ($fields as $fIdx => $row) {
            $id = $row['id'] ?? null;
            $label = $row['field_label'] ?? '';
            $type = $row['field_type'] ?? 'text';
            $options = $row['options'] ?? null;
            if (is_string($options)) {
                $decoded = json_decode($options, true);
                $options = is_array($decoded) ? $decoded : null;
            }

            if ($id) {
                $field = CategoryCustomField::where('category_custom_section_id', $section->id)->find($id);
                if (!$field) {
                    continue;
                }
                if ($isDefaultLanguage) {
                    $field->field_label = $label;
                    $field->field_type = $type;
                    $field->options = $options;
                    $field->is_required = !empty($row['is_required']) ? 1 : 0;
                    $field->sort_order = (int) ($row['sort_order'] ?? $fIdx);
                    $field->save();
                }
                $field->saveTranslation($languageId, [
                    'field_label' => $label,
                    'options' => $options,
                ]);
                $incomingFieldIds[] = $field->id;
            } else if ($isDefaultLanguage) {
                $field = CategoryCustomField::create([
                    'category_custom_section_id' => $section->id,
                    'field_label' => $label,
                    'field_type' => $type,
                    'options' => $options,
                    'is_required' => !empty($row['is_required']) ? 1 : 0,
                    'sort_order' => (int) ($row['sort_order'] ?? $fIdx),
                ]);
                $field->saveTranslation($languageId, [
                    'field_label' => $label,
                    'options' => $options,
                ]);
                $incomingFieldIds[] = $field->id;
            }
        }

        if ($isDefaultLanguage) {
            CategoryCustomField::where('category_custom_section_id', $section->id)
                ->whereNotIn('id', $incomingFieldIds)
                ->delete();
        }
    }
}
