<?php

namespace App\Http\Controllers\API;
use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Setting;
class SmsSettingsApiController extends Controller
{
    /** SMS gateway secret credentials blanked in demo mode (super admin exempt). */
    private array $confidentialSmsKeys = [
        'twilio_sid', 'twilio_auth_token', 'msg91_auth_key', 'fast2sms_api_key', 'twofactor_api_key',
    ];

    public function index()
    {
        $sms_settings = Setting::get();

        $mask = shouldDemoMask();
        $data=array();
        foreach ($sms_settings as $item){
            $value = $item->value;
            if ($mask && in_array($item->variable, $this->confidentialSmsKeys, true) && !empty($value)) {
                $value = '';
            }
            $data[$item->variable] = $value;
        }
        return CommonHelper::responseWithData($data);
    }
    public function save(Request $request)
    {
        foreach ($request->all() as $key => $item){

            $setting = Setting::where('variable', $key)->first();
            if ($setting) {
                $setting->variable = $key;
                $setting->value = $item ?? '';
                $setting->save();
            } else {
                $setting = new Setting();
                $setting->variable = $key;
                $setting->value = $item ?? '';
                $setting->save();
            }
        }

        return CommonHelper::responseSuccess('sms_settings_saved_successfully');
    }
}
