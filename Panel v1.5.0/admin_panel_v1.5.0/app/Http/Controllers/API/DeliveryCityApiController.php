<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\DeliveryCity;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class DeliveryCityApiController extends Controller
{
    public function getDeliveryCities(Request $request)
    {
        $query = DeliveryCity::orderBy('name');

        if ($request->filled('search')) {
            $term = $request->input('search');
            $query->where(function ($q) use ($term) {
                $q->where('name', 'like', "%{$term}%")
                    ->orWhere('state', 'like', "%{$term}%");
            });
        }

        if ($request->filled('status')) {
            $query->where('status', (int) $request->input('status'));
        }

        // Country-wise (header filter / cascade).
        if ($request->filled('country_id')) {
            $query->where('country_id', (int) $request->input('country_id'));
        }

        $total = $query->count();

        if ($request->filled('limit')) {
            $cities = $query->skip((int) $request->input('offset', 0))
                ->take((int) $request->input('limit'))
                ->get();
        } else {
            $cities = $query->get();
        }

        return CommonHelper::responseWithData([
            'total' => $total,
            'cities' => $cities,
        ]);
    }

    public function save(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name'       => 'required|string|max:255',
            'state'      => 'nullable|string|max:255',
            'country_id' => 'required|integer|exists:countries,id',
            'status'     => 'nullable|in:0,1',
        ], [
            'country_id.required' => __('country_is_required_for_the_zone'),
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $city = $request->filled('id') ? DeliveryCity::find($request->input('id')) : new DeliveryCity();

        if (!$city) {
            return CommonHelper::responseError('Delivery city not found');
        }

        // Boundary polygon (map) is required. Must not overlap another city's boundary.
        $boundary = $request->input('boundary_points');
        if (is_string($boundary)) {
            $decoded = json_decode($boundary, true);
            $boundary = is_array($decoded) ? $decoded : null;
        }
        if (!is_array($boundary) || count($boundary) < 3) {
            return CommonHelper::responseError(__('please_draw_the_boundary_on_map'));
        }
        if (is_array($boundary) && !empty($boundary)) {
            $others = DeliveryCity::whereNotNull('boundary_points')
                ->when($request->filled('id'), fn($q) => $q->where('id', '!=', $request->input('id')))
                ->get();
            foreach ($others as $other) {
                $poly = is_array($other->boundary_points) ? $other->boundary_points : json_decode($other->boundary_points, true);
                if (is_array($poly) && !empty($poly) && CommonHelper::polygonsOverlap($boundary, $poly)) {
                    return CommonHelper::responseError(__('city_boundary_overlaps_with') . ' ' . $other->name);
                }
            }
        }

        $city->name       = $request->input('name');
        $city->state      = $request->input('state');
        $city->country_id = (int) $request->input('country_id');
        $city->status     = (int) $request->input('status', 1);
        $city->boundary_points = (is_array($boundary) && !empty($boundary)) ? $boundary : null;
        $city->latitude  = $request->filled('latitude') ? (float) $request->input('latitude') : null;
        $city->longitude = $request->filled('longitude') ? (float) $request->input('longitude') : null;
        $city->save();

        return CommonHelper::responseWithData([
            'id'      => $city->id,
            'city'    => $city,
            'message' => __('delivery_city_saved_successfully'),
        ]);
    }

    public function delete(Request $request)
    {
        if (!$request->filled('id')) {
            return CommonHelper::responseError('Delivery city id required');
        }

        $city = DeliveryCity::find($request->input('id'));
        if (!$city) {
            return CommonHelper::responseSuccess('delivery_city_already_deleted');
        }

        $city->delete();
        return CommonHelper::responseSuccess('delivery_city_deleted_successfully');
    }
}
