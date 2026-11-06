<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\SocialMedia;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class SocialMediaApiController extends Controller
{
    public function index(){
        $socialMedia = SocialMedia::orderBy('id','DESC')->get();
        return CommonHelper::responseWithData($socialMedia);
    }

    public function save(Request $request){

        $validator = Validator::make($request->all(),[
            'icon' => 'required|file|mimes:jpeg,jpg,png,gif,webp,svg',
            'link' => 'required'
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $socialMedia = new SocialMedia();
        $socialMedia->icon = CommonHelper::uploadFile($request, 'icon', 'social_media');
        $socialMedia->link = $request->link;
        $socialMedia->save();
        return CommonHelper::responseSuccess(__('social_media_saved_successfully'));
    }

    public function update(Request $request){

        if (isset($request->id)) {
            $socialMedia = SocialMedia::find($request->id);
            if (!$socialMedia) {
                return CommonHelper::responseError(__('social_media_record_not_found'));
            }
    
            $validator = Validator::make($request->all(), [
                'icon' => 'nullable|file|mimes:jpeg,jpg,png,gif,webp,svg',
                'link' => 'required'
            ]);

            if ($validator->fails()) {
                return CommonHelper::responseError($validator->errors()->first());
            }

            // Keep the existing icon when no new file is uploaded.
            if ($request->hasFile('icon')) {
                $socialMedia->icon = CommonHelper::uploadFile($request, 'icon', 'social_media', $socialMedia->icon);
            }
            $socialMedia->link = $request->link;
            $socialMedia->save();
    
            return CommonHelper::responseSuccess(__('social_media_updated_successfully'));
        }
    
        return CommonHelper::responseError("ID is required for updating Social Media!");
    }

    public function delete(Request $request){
        if(isset($request->id)){
            $socialMedia = SocialMedia::find($request->id);
            if($socialMedia){
                CommonHelper::deleteFile($socialMedia->icon);
                $socialMedia->delete();
                return CommonHelper::responseSuccess(__('social_media_deleted_successfully'));
            }else{
                return CommonHelper::responseSuccess("Social Media Already Deleted!");
            }
        }
    }
}
