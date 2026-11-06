<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Setting;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class PopupApiController extends Controller
{
    public function index()
    {
        $popup_array = array(
            "popup_enabled" => 0,
            "popup_type" => "",
            "popup_type_id" => "",
            "popup_slug" => "",
            "popup_url" => "",
            "popup_image" => "",
            "popup_mode" => "lifetime",
            "popup_start_at" => "",
            "popup_end_at" => "",
        );
        $variables = array_keys($popup_array);
        $settings = Setting::whereIn('variable',$variables )->get();
        $imageArray = array("popup_image");
        $data = array();
        foreach ($settings as $setting){
            if(in_array($setting->variable,$imageArray)){
                $data[$setting->variable] = CommonHelper::getImage($setting->value);
            }else{
                $data[$setting->variable] = $setting->value;
            }
        }
        return CommonHelper::responseWithData($data);
    }

    public function save(Request $request)
    {
        $popup_image = Setting::get_value("popup_image");

        $validator = Validator::make($request->all(),[
            'popup_enabled' => 'required',
            'popup_type' => 'required',
            'popup_type_id' => 'required_if:popup_type,category,product,brand',
            'popup_url' => 'required_if:popup_type,==,popup_url',
            'popup_image' => ($popup_image == "null" || $popup_image == " " || $popup_image == "undefined")?'required|mimes:jpeg,jpg,png,gif':'',
            'popup_mode' => 'required|in:lifetime,scheduled',
            'popup_start_at' => 'nullable|date_format:Y-m-d H:i:s',
            'popup_end_at' => 'nullable|date_format:Y-m-d H:i:s',
        ],[
            'popup_type_id.required_if' => 'The '.$request->popup_type.' field is required when type is '.$request->popup_type.'.',
            'popup_url.required_if' => 'The link field is required when type is Popup Url.',
            'popup_url.url' => 'The link must be a valid URL.',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // Cross-field checks only matter in Scheduled mode — Lifetime clears both below anyway.
        if ($request->popup_mode === 'scheduled') {
            $startRaw = trim((string) $request->popup_start_at);
            $endRaw   = trim((string) $request->popup_end_at);
            try {
                $startAt = $startRaw !== '' ? \Carbon\Carbon::parse($startRaw, 'UTC') : null;
                $endAt   = $endRaw !== '' ? \Carbon\Carbon::parse($endRaw, 'UTC') : null;
            } catch (\Throwable $e) {
                return CommonHelper::responseError('invalid_schedule_date_time');
            }
            if ($startAt && $endAt && $endAt->lessThanOrEqualTo($startAt)) {
                return CommonHelper::responseError('turn_off_time_must_be_after_turn_on_time');
            }
            if ($endAt && !$startAt && $endAt->lessThanOrEqualTo(\Carbon\Carbon::now('UTC'))) {
                return CommonHelper::responseError('turn_off_time_must_be_in_the_future');
            }
        }

        if($request->hasFile('popup_image'))
        {
            $popupImage = CommonHelper::uploadFile($request, 'popup_image', 'offers');
        }
        // Determine which fields should be cleared based on the selected type.
        $type = $request->popup_type;
        $clearKeys = [];
        if (in_array($type, ['default', 'popup_url'])) {
            $clearKeys[] = 'popup_type_id'; // no category/product/brand needed
        }
        if (in_array($type, ['default', 'category', 'product', 'brand'])) {
            $clearKeys[] = 'popup_url'; // no URL needed
        }
        if ($request->popup_mode !== 'scheduled') {
            $clearKeys[] = 'popup_start_at'; // Lifetime is on/off by hand only — no window to keep
            $clearKeys[] = 'popup_end_at';
        }

        foreach ($request->all() as $key => $value) {
            // Force stale type-specific keys to empty — ignore whatever the request sent
            if (in_array($key, $clearKeys)) {
                $value = '';
            } else {
                $value = $value ?? '';
            }

            $setting = Setting::where('variable', $key)->first();
            if ($setting) {
                if ($key == 'popup_image' && $request->hasFile('popup_image') && isset($popupImage)
                    && $setting->value != '' && $setting->value != 'null' && $setting->value != 'undefined') {
                    CommonHelper::deleteFile($setting->value);
                } elseif ($key == 'popup_image') {
                    $value = $popup_image;
                }
                $setting->variable = $key;
                $setting->value = ($key == 'popup_image' && isset($popupImage)) ? $popupImage : $value;
                $setting->save();
            } else {
                $setting = new Setting();
                $setting->variable = $key;
                $setting->value = ($key == 'popup_image' && isset($popupImage)) ? $popupImage : $value;
                $setting->save();
            }
        }
        return CommonHelper::responseSuccess('popup_image_saved_successfully');
    }
}
