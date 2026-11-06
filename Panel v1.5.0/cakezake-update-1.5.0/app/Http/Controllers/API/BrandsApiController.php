<?php

namespace App\Http\Controllers\API;

use App\Services\LanguageService;
use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Brand;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class BrandsApiController extends Controller
{

    protected $languageService;

    public function __construct(LanguageService $languageService)
    {
        $this->languageService = $languageService;
    }

    public function list(Request $request)
    {
        if ($request->filled('id')) {
            $brand = Brand::withAllTranslations()
                ->where('id', $request->id)
                ->first();

            return CommonHelper::responseWithData($brand);
        }

        $limit = $request->input('per_page', 10);
        $page = max((int) $request->input('page', 1), 1);
        $offset = ($page - 1) * $limit;
        $filter = $request->input('filter', '');
        $status = $request->input('status');

        $query = Brand::withAllTranslations()->withCount('products')->orderBy('id', 'DESC');

        if ($status !== null && $status !== '') {
            $query->where('status', (int) $status);
        }

        if ($filter) {
            $query->where(function ($q) use ($filter) {
                $q->where('id', 'like', "%{$filter}%")
                  ->orWhere('name', 'like', "%{$filter}%")
                  ->orWhereHas('translations', fn ($t) => $t->where('name', 'like', "%{$filter}%"));

                $lowerFilter = strtolower($filter);
                if (str_contains($lowerFilter, 'deac') || str_contains($lowerFilter, 'inac') || $filter === '0') {
                    $q->orWhere('status', 0);
                } elseif (str_contains($lowerFilter, 'act') || $filter === '1') {
                    $q->orWhere('status', 1);
                }
            });
        }

        $total = $query->count();
        $brands = $query->skip($offset)->take($limit)->get();

        return CommonHelper::responseWithData($brands, $total);
    }

    public function save(Request $request)
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $isDefaultLang = $request->language_id == $defaultLanguage->id;

        $validator = Validator::make($request->all(), [
            'name' => 'required|string',
            'language_id' => 'required|exists:languages,id',
            'image' => 'nullable|image',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        if (!$isDefaultLang) {
            return CommonHelper::responseError('default_language_required');
        }

        $brand = new Brand();
        $brand->name = $request->name;
        $brand->status = 1;


        $brand->image = CommonHelper::uploadFile($request, 'image', 'brand');
        $brand->save();

        $brand->saveTranslation($request->language_id, [
            'name' => $request->name,
        ]);
        return CommonHelper::responseWithData([
            'id' => $brand->id,
            'message' => __('brand_saved_successfully'),
        ]);
    }

    public function update(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'id' => 'required|exists:brands,id',
            'name' => 'required|string',
            'language_id' => 'required|exists:languages,id',
            'image' => 'nullable|image',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $brand = Brand::find($request->id);
        if (!$brand) {
            return CommonHelper::responseError('brand_not_found');
        }

        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $isDefaultLang = $request->language_id == $defaultLanguage->id;

        /* UPDATE MAIN TABLE ONLY FOR DEFAULT LANGUAGE */
        if ($isDefaultLang) {
            $brand->name = $request->name;
            $brand->status = $request->status ?? $brand->status;

            $brand->image = CommonHelper::uploadFile($request, 'image', 'brand', $brand->image);

            $brand->save();
        }

        /* SAVE / UPDATE TRANSLATION */
        $brand->saveTranslation($request->language_id, [
            'name' => $request->name,
        ]);

        return CommonHelper::responseSuccess('brand_updated_successfully');
    }

    public function delete(Request $request)
    {
        $brand = Brand::find($request->id);

        if (!$brand) {
            return CommonHelper::responseError('brand_not_found');
        }

        CommonHelper::deleteFile($brand->image);

        $brand->delete();

        return CommonHelper::responseSuccess('brand_deleted_successfully');
    }

    /**
     * Products under one brand — loaded lazily when a brand is expanded in the tree
     * view, so the list page never has to ship the whole catalogue up front.
     */
    public function brandProducts(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'brand_id' => 'required|integer|exists:brands,id',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $products = Product::where('brand_id', (int) $request->brand_id)
            ->with(['translations:id,product_id,language_id,name', 'variants:id,product_id,image'])
            ->orderBy('id', 'DESC')
            ->get(['id', 'name', 'status', 'is_draft', 'brand_id'])
            ->map(function ($p) {
                // The list card shows the first variant's image, same as the products page.
                $img = optional($p->variants->first())->image;
                return [
                    'id'           => $p->id,
                    'name'         => $p->getAttributes()['name'] ?? '',
                    'image_url'    => $img ? asset('storage/' . $img) : '',
                    'status'       => (int) $p->status,
                    'is_draft'     => (int) $p->is_draft,
                    'translations' => $p->translations,
                ];
            })
            ->values();

        return CommonHelper::responseWithData($products, $products->count());
    }

    public function getBrands(Request $request)
    {
        $limit = $request->get('limit');
        $offset = $request->get('offset');

        $contentLanguage = $request->header('Content-Language');
        $useContentLanguage = $contentLanguage !== null && trim((string) $contentLanguage) !== '';

        $query = $useContentLanguage
            ? Brand::where('status', 1)->orderBy('id', 'ASC')
            : Brand::withAllTranslations()->where('status', 1)->orderBy('id', 'ASC');

        $total = $query->count();

        if ($limit > 0) {
            $query->skip($offset)->take($limit);
        }

        return CommonHelper::responseWithData($query->get(), $total);
    }
}
