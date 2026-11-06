<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Language;
use App\Models\SupportedLanguage;
use App\Services\LanguageFileService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;
class LanguageApiController extends Controller
{
    public function index(){

        $sql = Language::leftJoin("supported_languages", "supported_languages.id", "languages.supported_language_id", "languages.display_name");
       
        $languages = $sql->orderBy('languages.id','DESC')->get(['languages.id','supported_language_id','languages.slug','name','code','type','system_type','is_default','status','display_name']);

        foreach ($languages as $lang) {
            $lang->has_json_file = LanguageFileService::exists((int) $lang->system_type, (string) $lang->code);
        }

        return CommonHelper::responseWithData($languages);
    }

    public function getSupportedLanguages(){
        $data["system_types"] = Language::get_system_types();
        $data["supported_languages"] = SupportedLanguage::orderBy('name','ASC')->get();
        return CommonHelper::responseWithData($data);
    }

    public function getSystemLanguages(Request $request){ 

        $validator = Validator::make($request->all(),[
            'system_type' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $query = Language::where('system_type', $request->system_type)->where('status', 1)->leftJoin("supported_languages", "supported_languages.id", "languages.supported_language_id");

        if((isset($request->id) && $request->id != 0) || (isset($request->is_default) && $request->is_default != 0)){
            if(isset($request->id) && $request->id != 0){
                $query = $query->where('languages.id',$request->id);
            }else if(isset($request->is_default) && $request->is_default != 0){
                $query = $query->where('is_default', $request->is_default);
            }

            // Include supported_language_id to find admin lang for FCM
            $language = $query->first(['languages.id','languages.supported_language_id','languages.slug','name','code','type','system_type','is_default','display_name']);
            if($language){
                $language->json_data = (object) LanguageFileService::readArray(
                    (int) $language->system_type,
                    (string) $language->code
                );
                
                // Add admin_lang_id_for_fcm: language ID of system_type=4 with same supported_language_id
                // This is used to store the correct admin panel language ID for FCM notifications
                $language->admin_lang_id_for_fcm = $this->getAdminLangIdForFcm($language->supported_language_id);
                unset($language->supported_language_id);

                $total = $language->count();
                return CommonHelper::responseWithData($language, $total);
            }else{
                return CommonHelper::responseSuccess('language_not_found');
            }
        }

        // Include supported_language_id to find admin lang for FCM
        $languages = $query->orderBy('id','ASC')->get(['languages.id','languages.supported_language_id','languages.slug','name','code','type','system_type','is_default','display_name']);
        if(count($languages) == 0){
            return CommonHelper::responseSuccess('language_not_found');
        }
        
        foreach($languages as $lang){
            $lang->admin_lang_id_for_fcm = $this->getAdminLangIdForFcm($lang->supported_language_id);
            unset($lang->supported_language_id);
        }
        
        return CommonHelper::responseWithData($languages, $languages->count());
    }
    
    public function getJson(Request $request)
    {
        $language = Language::find((int) $request->input('id'));
        if (!$language) {
            return CommonHelper::responseError('language_not_found');
        }

        $code = LanguageFileService::codeFor($language);
        if (!$code) {
            return CommonHelper::responseError('language_code_not_found');
        }

        return CommonHelper::responseWithData([
            'id' => (int) $language->id,
            'system_type' => (int) $language->system_type,
            'code' => $code,
            'exists' => LanguageFileService::exists((int) $language->system_type, $code),
            'file_path' => str_replace(base_path() . '/', '', (string) LanguageFileService::path((int) $language->system_type, $code)),
            'json_data' => (object) LanguageFileService::readArray((int) $language->system_type, $code),
        ]);
    }

    private function getAdminLangIdForFcm($supportedLanguageId): ?int
    {
        if (empty($supportedLanguageId)) {
            return null;
        }
        
        // Find language with system_type=4 (admin panel) that has the same supported_language_id
        return Language::where('system_type', 4)
            ->where('supported_language_id', $supportedLanguageId)
            ->where('status', 1)
            ->value('id');
    }

    private function decodeJsonPayload($val)
    {
        if (is_string($val) && str_starts_with($val, 'b64:')) {
            $decoded = base64_decode(substr($val, 4), true);
            if ($decoded !== false) {
                return $decoded;
            }
        }
        return $val;
    }

    public function save(Request $request){

        // Get all system types dynamically
        $systemTypesArray = Language::get_system_types();
        $systemTypes = array_column($systemTypesArray, 'id');
        
        $validationRules = [
            'supported_language' => 'required',
        ];
        
        foreach ($systemTypes as $systemTypeId) {
            $validationRules['json_data_' . $systemTypeId] = 'required';
        }
        
        $validator = Validator::make($request->all(), $validationRules);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $is_default = $request->is_default ?? 0;
        $requestStatus = $request->status ?? 1;
     
        // Validate: Default language must always have status = 1
        if ($is_default == 1 && $requestStatus == 0) {
            return CommonHelper::responseError('default_language_must_be_active_cannot_set_inactive_language_as_default');
        }
     
        if (isset($request->is_default) && $request->is_default == 1) {
            Language::where('is_default', 1)->update(['is_default' => 0]);
        }

        // Restrict duplicate: same supported_language_id + system_type cannot exist multiple times
        $exists = Language::where('supported_language_id', $request->supported_language)
            ->whereIn('system_type', $systemTypes)
            ->exists();
        if ($exists) {
            return CommonHelper::responseError('language_already_exists');
        }
       
        try{
            $supportedLanguage = SupportedLanguage::find($request->supported_language);
            $code = $supportedLanguage ? $supportedLanguage->code : null;

            foreach ($systemTypes as $systemType) {
                $jsonDataKey = 'json_data_' . $systemType;
                $jsonData = $this->decodeJsonPayload($request->input($jsonDataKey));

                if (empty($jsonData)) {
                    continue;
                }
                
                if (!$code) {
                    return CommonHelper::responseError('language_code_not_found');
                }

                LanguageFileService::write($systemType, $code, $jsonData);

                $language = new Language();
                $language->system_type = $systemType;
                $language->supported_language_id = $request->supported_language;
                $language->display_name = $request->display_name;
                $language->is_default = $is_default;
                $language->status = ($is_default == 1) ? 1 : $requestStatus;

                $language->save();
            }
            
            return CommonHelper::responseSuccess('language_saved_successfully');
        }catch ( \Exception $e){
            return CommonHelper::responseError($e->getMessage() ?: __('error_saving_language'));
        }
    }

    /** Row settings only (display name, default, status). Bundles go through updateJson. */
    public function update(Request $request){
        $validator = Validator::make($request->all(), [
            'system_type' => 'required',
            'supported_language' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        if(isset($request->id)){

            $language = Language::find($request->id);
            
            if (!$language) {
                return CommonHelper::responseError('language_not_found');
            }

            $requestStatus = $request->status ?? $language->status;
            $requestIsDefault = isset($request->is_default) ? $request->is_default : $language->is_default;
            
            if ($requestStatus == 0 && ($requestIsDefault == 1 || $language->is_default == 1)) {
                return CommonHelper::responseError('default_language_must_be_active_cannot_deactivate_default_language');
            }
            
            if ($requestStatus == 0) {
                $activeLanguagesCount = Language::where('system_type', $request->system_type)
                    ->where('status', 1)
                    ->where('id', '!=', $request->id)
                    ->count();
                
                if ($activeLanguagesCount == 0) {
                    return CommonHelper::responseError('at_least_one_language_must_be_active_for_this_system_type');
                }
            }

            if (isset($request->is_default) && $request->is_default == 1) {
                if ($requestStatus == 0) {
                    return CommonHelper::responseError('default_language_must_be_active_cannot_set_inactive_language_as_default');
                }
            }

            if (isset($request->is_default) && $request->is_default == 0) {
                $supportedLanguageId = $request->supported_language;
                
                $defaultLanguagesCount = Language::where('system_type', $request->system_type)
                    ->where('is_default', 1)
                    ->where('supported_language_id', '!=', $supportedLanguageId)
                    ->count();
                
                if ($defaultLanguagesCount == 0) {
                    return CommonHelper::responseError('at_least_one_language_must_be_default_for_this_system_type');
                }
            }

            if(isset($request->is_default) && $request->is_default == 1){
                Language::where('is_default', 1)->update(['is_default' => 0]);
                
                $supportedLanguageId = $request->supported_language;
                Language::where('supported_language_id', $supportedLanguageId)
                    ->update(['is_default' => 1, 'status' => 1]);
                
                $requestStatus = 1;
            } else {
                $supportedLanguageId = $request->supported_language;
                Language::where('supported_language_id', $supportedLanguageId)
                    ->update(['is_default' => 0]);
            }

            $language->system_type = $request->system_type;
            $language->supported_language_id = $request->supported_language;
            $language->display_name = $request->display_name;
            $language->is_default = isset($request->is_default) ? $request->is_default : $language->is_default;
            $finalIsDefault = isset($request->is_default) ? $request->is_default : $language->is_default;
            $language->status = ($finalIsDefault == 1) ? 1 : $requestStatus;
            $language->save();
            
            $supportedLanguageId = $request->supported_language;
            Language::where('supported_language_id', $supportedLanguageId)
                ->update(['display_name' => $request->display_name]);
        }
        
        return CommonHelper::responseSuccess('language_updated_successfully');
    }

    public function updateJson(Request $request){
        $validator = Validator::make($request->all(), [
            'system_type' => 'required',
            'supported_language' => 'required',
            'json_data' => 'required'
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        try {
            $supportedLanguage = SupportedLanguage::find($request->supported_language);
            $code = $supportedLanguage ? $supportedLanguage->code : null;

            if(isset($request->id) && $request->id){
                // Update existing record
                $language = Language::find($request->id);
                if (!$language) {
                    return CommonHelper::responseError("Language not found!");
                }
                
                if ($language->is_default == 1 && isset($request->status) && $request->status == 0) {
                    return CommonHelper::responseError('default_language_must_be_active_cannot_deactivate_default_language');
                }
                
                    if ($language->is_default == 1) {
                    $language->status = 1;
                } else if (isset($request->status)) {
                    $language->status = $request->status;
                }
                $language->save();
            } else {
                $is_default = $request->is_default ?? 0;
                $requestStatus = $request->status ?? 1;
                
                if ($is_default == 1 && $requestStatus == 0) {
                    return CommonHelper::responseError('default_language_must_be_active_cannot_set_inactive_language_as_default');
                }
                
                $language = new Language();
                $language->system_type = $request->system_type;
                $language->supported_language_id = $request->supported_language;
                    $language->display_name = $request->display_name ?? '';
                $language->is_default = $is_default;
                $language->status = ($is_default == 1) ? 1 : $requestStatus;
                $language->save();
            }

            if (!$code) {
                return CommonHelper::responseError('language_code_not_found');
            }
            // Every platform writes its own file now — not just the admin panel.
            LanguageFileService::write((int) $request->system_type, $code, $this->decodeJsonPayload($request->json_data));

            return CommonHelper::responseSuccess('language_updated_successfully');
        } catch (\Exception $e) {
            return CommonHelper::responseError($e->getMessage());
        }
    }
    
    public function delete(Request $request){
        if(isset($request->id)){
            $language = Language::find($request->id);
    
            if ($language) {
                try {
                    $supportedLanguageId = $language->supported_language_id;

                    // Block deletion if this language is the default
                    $isDefault = Language::where('supported_language_id', $supportedLanguageId)
                                        ->where('is_default', 1)
                                        ->exists();
                    if ($isDefault) {
                        return CommonHelper::responseError(__('cannot_delete_default_language_set_other_language_as_default_and_fill_data_for_it'));
                    }

                    $totalLanguagesCount = Language::count();
                    
                    $languagesToDeleteCount = Language::where('supported_language_id', $supportedLanguageId)->count();
                    
                    if ($totalLanguagesCount <= $languagesToDeleteCount) {
                        return CommonHelper::responseError('cannot_delete_last_language_at_least_one_language_must_exist');
                    }
                    
                    $supportedLanguage = SupportedLanguage::find($supportedLanguageId);
                    $code = $supportedLanguage ? $supportedLanguage->code : null;
                    
                    Language::where('supported_language_id', $supportedLanguageId)->delete();
                    
                    if ($code) {
                        LanguageFileService::deleteAll($code);
                    }
                    
                    return CommonHelper::responseSuccess('language_deleted_successfully');
                } catch (\Exception $e) {
                    return CommonHelper::responseError('error_deleting_language' . ": " . $e->getMessage());
                }
            } else {
                return CommonHelper::responseError('language_not_found');
            }
        }
        return CommonHelper::responseError('language_id_is_required');
    }

    public function getActiveLanguages(Request $request)
    {
        $languages = DB::table('languages as l')
            ->select(
                'l.id',
                'l.is_default',
                'l.slug',
                's.name',
                's.code'
            )
            ->join('supported_languages as s', 'l.supported_language_id', '=', 's.id')
            ->where('l.system_type', '=', 4)
            ->where('l.status', '=', 1)
            ->orderByRaw('l.is_default DESC, s.name ASC')
            ->get();

        if ($languages->isEmpty()) {
            return CommonHelper::responseError('no_languages_found');
        }

        $languages = $languages->map(function ($lang) {
            $lang->is_default = (int) $lang->is_default;
            return $lang;
        });

        return CommonHelper::responseWithData($languages);
    }

}
