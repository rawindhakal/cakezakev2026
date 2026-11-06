<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\DeliveryArea;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class DeliveryAreaApiController extends Controller
{
    public function getDeliveryAreas(Request $request)
    {
        $query = DeliveryArea::with('city:id,name')->orderBy('name');

        if ($request->filled('delivery_city_id')) {
            $query->where('delivery_city_id', (int) $request->input('delivery_city_id'));
        }

        // Country-wise: areas inherit country via their city.
        if ($request->filled('country_id')) {
            $countryId = (int) $request->input('country_id');
            $query->whereHas('city', fn ($q) => $q->where('country_id', $countryId));
        }

        if ($request->filled('search')) {
            $term = $request->input('search');
            $query->where('name', 'like', "%{$term}%");
        }

        if ($request->filled('status')) {
            $query->where('status', (int) $request->input('status'));
        }

        $total = $query->count();

        if ($request->filled('limit')) {
            $areas = $query->skip((int) $request->input('offset', 0))
                ->take((int) $request->input('limit'))
                ->get();
        } else {
            $areas = $query->get();
        }

        return CommonHelper::responseWithData([
            'total' => $total,
            'areas' => $areas,
        ]);
    }

    public function save(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'delivery_city_id' => 'required|exists:delivery_cities,id',
            'name'             => 'required|string|max:255',
            'status'           => 'nullable|in:0,1',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $area = $request->filled('id') ? DeliveryArea::find($request->input('id')) : new DeliveryArea();

        if (!$area) {
            return CommonHelper::responseError('Delivery area not found');
        }

        $cityId = (int) $request->input('delivery_city_id');

        // Boundary polygon (map) is required. Must not overlap another area in the same city.
        $boundary = $request->input('boundary_points');
        if (is_string($boundary)) {
            $decoded = json_decode($boundary, true);
            $boundary = is_array($decoded) ? $decoded : null;
        }
        if (!is_array($boundary) || count($boundary) < 3) {
            return CommonHelper::responseError(__('please_draw_the_boundary_on_map'));
        }
        if (is_array($boundary) && !empty($boundary)) {
            $others = DeliveryArea::where('delivery_city_id', $cityId)
                ->whereNotNull('boundary_points')
                ->when($request->filled('id'), fn($q) => $q->where('id', '!=', $request->input('id')))
                ->get();
            foreach ($others as $other) {
                $poly = is_array($other->boundary_points) ? $other->boundary_points : json_decode($other->boundary_points, true);
                if (is_array($poly) && !empty($poly) && CommonHelper::polygonsOverlap($boundary, $poly)) {
                    return CommonHelper::responseError(__('area_boundary_overlaps_with') . ' ' . $other->name);
                }
            }
        }

        $area->delivery_city_id = $cityId;
        $area->name             = $request->input('name');
        $area->status           = (int) $request->input('status', 1);
        $area->boundary_points  = (is_array($boundary) && !empty($boundary)) ? $boundary : null;
        $area->latitude         = $request->filled('latitude') ? (float) $request->input('latitude') : null;
        $area->longitude        = $request->filled('longitude') ? (float) $request->input('longitude') : null;
        $area->save();

        return CommonHelper::responseWithData([
            'id'      => $area->id,
            'area'    => $area->load('city:id,name'),
            'message' => __('delivery_area_saved_successfully'),
        ]);
    }

    public function delete(Request $request)
    {
        if (!$request->filled('id')) {
            return CommonHelper::responseError('Delivery area id required');
        }

        $area = DeliveryArea::find($request->input('id'));
        if (!$area) {
            return CommonHelper::responseSuccess('delivery_area_already_deleted');
        }

        $area->delete();
        return CommonHelper::responseSuccess('delivery_area_deleted_successfully');
    }
}
