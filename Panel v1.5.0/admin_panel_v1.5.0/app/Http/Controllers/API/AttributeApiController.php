<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Attribute;
use App\Models\AttributeValue;
use App\Models\Category;
use App\Services\LanguageService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class AttributeApiController extends Controller
{
    protected $languageService;

    public function __construct(LanguageService $languageService)
    {
        $this->languageService = $languageService;
    }

    public function usage(Request $request)
    {
        $attributeId = (int) $request->input('id', $request->input('attribute_id', 0));
        if (!$attributeId) {
            return CommonHelper::responseWithData(['product_count' => 0, 'variant_count' => 0, 'values' => []]);
        }

        $base = DB::table('product_variant_attribute_values as pvav')
            ->join('product_variants as pv', 'pv.id', '=', 'pvav.product_variant_id')
            ->where('pvav.attribute_id', $attributeId);

        $productCount = (clone $base)->distinct()->count('pv.product_id');
        $variantCount = (clone $base)->distinct()->count('pvav.product_variant_id');

        $perValue = (clone $base)
            ->select('pvav.attribute_value_id', DB::raw('COUNT(DISTINCT pv.product_id) as c'))
            ->groupBy('pvav.attribute_value_id')
            ->pluck('c', 'pvav.attribute_value_id');

        return CommonHelper::responseWithData([
            'product_count' => (int) $productCount,
            'variant_count' => (int) $variantCount,
            'values'        => $perValue,
        ]);
    }

    public function list(Request $request)
    {
        if ($request->filled('id')) {
            $attribute = Attribute::withAllTranslations()
                ->with(['values' => function ($q) {
                    $q->withAllTranslations();
                }])
                ->where('id', $request->id)
                ->first();

            return CommonHelper::responseWithData($attribute);
        }

        $limit = (int) $request->input('per_page', 10);
        $page = max((int) $request->input('page', 1), 1);
        $offset = ($page - 1) * $limit;
        $filter = $request->input('filter', '');

        $query = Attribute::withAllTranslations()
            ->with(['values' => function ($q) {
                $q->withAllTranslations();
            }])
            ->orderBy('id', 'DESC');

        if ($filter) {
            $like = "%{$filter}%";
            $query->where(function ($q) use ($like) {
                $q->where('id', 'like', $like)
                    ->orWhere('name', 'like', $like)
                    ->orWhere('slug', 'like', $like)
                    ->orWhereHas('translations', fn ($t) => $t->where('name', 'like', $like))
                    ->orWhereHas('values', function ($v) use ($like) {
                        $v->where('value', 'like', $like)
                            ->orWhereHas('translations', fn ($t) => $t->where('value', 'like', $like));
                    });
            });
        }

        $total = $query->count();
        $rows = $query->skip($offset)->take($limit)->get();

        return CommonHelper::responseWithData($rows, $total);
    }

    /**
     * Lightweight list for selectors (category form).
     */
    public function dropdown(Request $request)
    {
        $query = Attribute::withAllTranslations()
            ->with(['activeValues' => function ($q) {
                $q->withAllTranslations();
            }])
            ->where('status', 1)
            ->orderBy('id');

        $categoryId = (int) $request->input('category_id', 0);
        if ($categoryId > 0) {
            $query->whereIn('id', self::categoryScopedAttributeIds($categoryId));
        }

        return CommonHelper::responseWithData($query->get());
    }

    /**
     * Attributes reachable from one category: its own effective set (own +
     * inherited from ancestors, minus the ones it has switched off) plus
     * everything attached to its descendants — a parent listing shows its
     * children's products, which carry child-only attributes.
     *
     * A pivot row flagged `is_overridden_off` is a suppression marker on that one
     * category, not an attachment, so it never pulls an attribute in by itself.
     *
     * @return int[]
     */
    private static function categoryScopedAttributeIds(int $categoryId): array
    {
        $category = Category::find($categoryId);
        if (!$category) {
            return [];
        }

        // The chain is the model's job: it already resolves inheritance and the
        // child-level switch-offs the category editor writes.
        $ids = $category->effectiveAttributes()->pluck('id')->map(fn ($id) => (int) $id)->all();

        $childrenOf = [];
        foreach (DB::table('categories')->select('id', 'parent_id')->get() as $row) {
            $childrenOf[(int) $row->parent_id][] = (int) $row->id;
        }

        $descendants = [];
        $stack = [$categoryId];
        while ($stack) {
            $id = array_pop($stack);
            foreach ($childrenOf[$id] ?? [] as $child) {
                if (!isset($descendants[$child])) {
                    $descendants[$child] = true;
                    $stack[] = $child;
                }
            }
        }

        if (!empty($descendants)) {
            $ids = array_merge($ids, DB::table('category_attribute')
                ->whereIn('category_id', array_keys($descendants))
                ->where(function ($q) {
                    $q->where('is_overridden_off', 0)->orWhereNull('is_overridden_off');
                })
                ->distinct()
                ->pluck('attribute_id')
                ->map(fn ($id) => (int) $id)
                ->all());
        }

        return array_values(array_unique($ids));
    }

    public function save(Request $request)
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $isDefaultLang = $request->language_id == $defaultLanguage->id;

        $validator = Validator::make($request->all(), [
            'name' => 'required|string',
            'language_id' => 'required|exists:languages,id',
            'values' => 'required|array|min:1',
            'values.*.value' => 'required|string',
        ], [
            'values.required' => __('at_least_one_value_required'),
            'values.min' => __('at_least_one_value_required'),
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        if (!$isDefaultLang) {
            return CommonHelper::responseError('default_language_required');
        }

        return DB::transaction(function () use ($request) {
            $slug = $request->input('slug') ?: Str::slug($request->name);
            // ensure uniqueness
            $base = $slug;
            $i = 1;
            while (Attribute::where('slug', $slug)->exists()) {
                $i++;
                $slug = $base . '-' . $i;
            }

            $attribute = Attribute::create([
                'name' => $request->name,
                'slug' => $slug,
                'status' => $request->input('status', 1),
            ]);

            $attribute->saveTranslation($request->language_id, ['name' => $request->name]);

            $this->syncValues($attribute, $request->input('values', []), $request->language_id);

            return CommonHelper::responseWithData([
                'id' => $attribute->id,
                'message' => __('attribute_saved_successfully'),
            ]);
        });
    }

    public function update(Request $request)
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $isDefaultLang = $request->language_id == $defaultLanguage->id;

        $rules = [
            'id' => 'required|exists:attributes,id',
            'language_id' => 'required|exists:languages,id',
        ];
        if ($isDefaultLang) {
            $rules['name'] = 'required|string';
            $rules['values'] = 'required|array|min:1';
            $rules['values.*.value'] = 'required|string';
        } else {
            $rules['name'] = 'nullable|string';
            $rules['values'] = 'sometimes|array';
        }

        $validator = Validator::make($request->all(), $rules, [
            'values.required' => __('at_least_one_value_required'),
            'values.min' => __('at_least_one_value_required'),
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $attribute = Attribute::find($request->id);
        if (!$attribute) {
            return CommonHelper::responseError('attribute_not_found');
        }

        // a dropped id would otherwise be deleted and stripped from existing variants).
        if ($isDefaultLang) {
            $incomingIds = collect($request->input('values', []))
                ->pluck('id')->filter()->map(fn ($i) => (int) $i)->all();
            $existingIds = AttributeValue::where('attribute_id', $attribute->id)->pluck('id')->all();
            $removedIds = array_values(array_diff($existingIds, $incomingIds));
            if ($removedIds) {
                $usedIds = DB::table('product_variant_attribute_values')
                    ->whereIn('attribute_value_id', $removedIds)
                    ->distinct()->pluck('attribute_value_id')->all();
                if ($usedIds) {
                    $names = AttributeValue::whereIn('id', $usedIds)->pluck('value')->implode(', ');
                    return CommonHelper::responseError(
                        __('attribute_value_in_use_cannot_remove', ['values' => $names])
                    );
                }
            }
        }

        return DB::transaction(function () use ($request, $attribute, $isDefaultLang) {
            if ($isDefaultLang) {
                $attribute->name = $request->name;
                $attribute->status = $request->status ?? $attribute->status;
                if ($request->filled('slug') && $request->slug !== $attribute->slug) {
                    $newSlug = $request->slug;
                    if (!Attribute::where('slug', $newSlug)->where('id', '!=', $attribute->id)->exists()) {
                        $attribute->slug = $newSlug;
                    }
                }
                $attribute->save();
            }

            $attribute->saveTranslation($request->language_id, ['name' => $request->name]);

            if ($request->has('values')) {
                $this->syncValues($attribute, $request->input('values', []), $request->language_id);
            }

            return CommonHelper::responseSuccess('attribute_updated_successfully');
        });
    }

    public function delete(Request $request)
    {
        $attribute = Attribute::find($request->id);
        if (!$attribute) {
            return CommonHelper::responseError('attribute_not_found');
        }
        // Block deleting an attribute that's used by any product variant.
        $inUse = DB::table('product_variant_attribute_values')
            ->where('attribute_id', $attribute->id)->exists();
        if ($inUse) {
            return CommonHelper::responseError(__('attribute_in_use_cannot_delete'));
        }
        $attribute->delete();
        return CommonHelper::responseSuccess('attribute_deleted_successfully');
    }

    /**
     * Sync child values: incoming list = full set for default language.
     * Items with `id` are updated; items without are created; missing ids deleted.
     * For non-default language, only updates translation rows.
     */
    protected function syncValues(Attribute $attribute, array $values, int $languageId): void
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $isDefaultLang = $languageId == $defaultLanguage->id;

        $incomingIds = [];

        foreach ($values as $row) {
            $id = $row['id'] ?? null;
            $value = $row['value'] ?? '';

            if ($id) {
                $av = AttributeValue::where('attribute_id', $attribute->id)->find($id);
                if (!$av) {
                    continue;
                }
                if ($isDefaultLang) {
                    $av->value = $value;
                    $av->save();
                }

                $av->saveTranslation($languageId, ['value' => $value]);
                $incomingIds[] = $av->id;
            } else if ($isDefaultLang) {
                $av = AttributeValue::create([
                    'attribute_id' => $attribute->id,
                    'value' => $value,
                ]);
                $av->saveTranslation($languageId, ['value' => $value]);
                $incomingIds[] = $av->id;
            }
        }

        // Only delete missing on default language sync
        if ($isDefaultLang && !empty($incomingIds)) {
            AttributeValue::where('attribute_id', $attribute->id)
                ->whereNotIn('id', $incomingIds)
                ->delete();
        } elseif ($isDefaultLang && empty($values)) {
            AttributeValue::where('attribute_id', $attribute->id)->delete();
        }
    }
}
