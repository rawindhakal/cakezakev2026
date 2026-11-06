<?php

namespace App\Http\Controllers\API\Customer;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Region;
use App\Models\UserAddress;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class AddressApiController extends Controller
{
    public function getAddress(Request $request){

        $offset = $request->get('offset', 0);
        $limit = $request->get('limit', 10);

        $addresses = UserAddress::with('region:id,name,code,tax_code')
            ->where('user_id',auth()->user()->id);

        if(isset($request->is_default) && $request->is_default == 1 ){
            $address = $addresses->where("is_default", 1)->get();

            if (count($address) > 0) {
                return CommonHelper::responseWithData($address);
            }else{
                $addresses = UserAddress::with('region:id,name,code,tax_code')
                    ->where('user_id',auth()->user()->id)->get();
                if (count($addresses) > 0) {
                    $address[0] = $addresses[0];
                    return CommonHelper::responseWithData($address);
                }
                
                return CommonHelper::responseWithData([], 0);
            }
        }
        $total = $addresses->count();
        $addresses = $addresses->orderBy("is_default","DESC")->offset($offset)->limit($limit)->get();

        $addresses->each(fn ($a) => $a->region_name = optional($a->region)->name);

        return CommonHelper::responseWithData($addresses, $total);
    }

    public function regions(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'country_id' => 'required|exists:countries,id',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $useContentLanguage = trim((string) $request->header('Content-Language')) !== '';

        $query = ($useContentLanguage ? Region::query() : Region::with('translations'))
            ->where('country_id', (int) $request->country_id)
            ->where('status', 1);

        if ($request->filled('search')) {
            $search = trim((string) $request->input('search'));
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('code', 'like', "%{$search}%");
            });
        }

        $total = (clone $query)->count();

        $limit = (int) $request->get('limit', 0);
        if ($limit > 0) {
            $query->skip((int) $request->get('offset', 0))->take($limit);
        }

        $rows = $query->orderBy('name')->get()
            ->makeHidden(['type', 'tax_code', 'code', 'status', 'created_at', 'updated_at']);

        return CommonHelper::responseWithData($rows, $total);
    }

    public function save(Request $request){
        $input = $request->all();
        $validator = Validator::make($request->all(),[
            'name' => 'required',
            'mobile' => 'required',
            'country_code' => 'required_with:mobile',
            'alternate_country_code' => 'required_with:alternate_mobile',
            'type' => 'required',
            'address' => 'required',
            'landmark' => 'required',
            'area' => 'required',
            'latitude' => 'required',
            'longitude' => 'required',
            'pincode' => 'required',
            'city' => 'required',
            'state' => 'required',
            'country' => 'required',
            'region_id' => 'nullable|exists:regions,id',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $channel = strtolower(trim((string) $request->header('channel'))) ?: null;
        $city = CommonHelper::getDeliverableCity($request->latitude, $request->longitude, $channel);

        $regionError = $this->validateRegion($request, $city);
        if ($regionError) {
            return CommonHelper::responseError($regionError);
        }

        $user_id = auth()->user()->id;
        $count = UserAddress::where('user_id',$user_id)->count();
        if($count == 0){
            $input['is_default'] = 1;
        }

        if(isset($request->is_default) && $request->is_default == 1 && $count > 0){
            UserAddress::where('user_id', '=', $user_id)->update(['is_default' => 0]);
        }

        $input['user_id'] = $user_id;
        $input['zone_id'] = $city->id ?? 0;
        $address = UserAddress::create($input);

        $address->is_default = ($address->is_default == "0") ? 0 : 1; // this for type casting
        return CommonHelper::responseWithData($address);
    }

    public function update(Request $request){

        $input = $request->all();
        $validator = Validator::make($request->all(),[
            'id' => 'required',
            'name' => 'required',
            'mobile' => 'required',
            'country_code' => 'required_with:mobile',
            'alternate_country_code' => 'required_with:alternate_mobile',
            'type' => 'required',
            'address' => 'required',
            'landmark' => 'required',
            'area' => 'required',
            'pincode' => 'required',
            'city' => 'required',
            'state' => 'required',
            'country' => 'required',
            'region_id' => 'nullable|exists:regions,id',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $channel = strtolower(trim((string) $request->header('channel'))) ?: null;
        $city = CommonHelper::getDeliverableCity($request->latitude, $request->longitude, $channel);

        $regionZone = $city;
        if (!$regionZone) {
            $storedZoneId = UserAddress::where('id', $request->id)
                ->where('user_id', auth()->user()->id)->value('zone_id');
            $regionZone = $storedZoneId
                ? DB::table('zones')->where('id', $storedZoneId)->first(['id', 'country_id'])
                : null;
        }
        $regionError = $this->validateRegion($request, $regionZone);
        if ($regionError) {
            return CommonHelper::responseError($regionError);
        }

        if(isset($request->is_default) && $request->is_default == 1 ){
            $user_id = auth()->user()->id;
            UserAddress::where('user_id', '=', $user_id)->update(['is_default' => 0]);
        }

        $address = UserAddress::where('id',$request->id)->first();
        if(!$address){
            return CommonHelper::responseError('address_not_found');
        }

        $input['zone_id'] = $city->id ?? 0;
        $address->update($input);

        $address->is_default = ($address->is_default == "0")?0:1; // this for type casting
        return CommonHelper::responseWithData($address);
    }

    public function delete(Request $reequest){
        $id = $reequest->id;
        $address = UserAddress::find($id);
        if(!$address){
            return CommonHelper::responseError('address_not_found');
        }
        $address->delete();
        return CommonHelper::responseSuccess('address_deleted_successfully');
    }

    private function validateRegion(Request $request, $zone): ?string
    {
        $countryId = $zone->country_id ?? null;
        if (!$countryId) {
            return null;
        }
        $hasRegions = Region::where('country_id', $countryId)->where('status', 1)->exists();
        if (!$hasRegions) {
            return null;
        }

        $countryName = DB::table('countries')->where('id', $countryId)->value('name') ?: '';

        if (!$request->filled('region_id')) {
            return __('region_required_for_this_country', ['country' => $countryName]);
        }

        $region = Region::where('id', (int) $request->region_id)->where('status', 1)
            ->first(['id', 'name', 'country_id']);

        if (!$region) {
            return __('region_not_available');
        }
        if ((int) $region->country_id === (int) $countryId) {
            return null;
        }

        $regionCountry = DB::table('countries')->where('id', $region->country_id)->value('name') ?: '';

        return __('region_does_not_belong_to_country', [
            'region'         => $region->name,
            'region_country' => $regionCountry,
            'country'        => $countryName,
        ]);
    }
}
