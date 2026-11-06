<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\HomeLayoutTemplate;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class HomeLayoutTemplateApiController extends Controller
{
    public function index()
    {
        $rows = HomeLayoutTemplate::orderBy('id', 'desc')->get();
        return CommonHelper::responseWithData($rows);
    }

    public function save(Request $request)
    {
        // FormData posts section_json as a JSON-encoded string; decode first.
        $sectionJson = $request->input('section_json');
        if (is_string($sectionJson)) {
            $decoded = json_decode($sectionJson, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                $sectionJson = $decoded;
                $request->merge(['section_json' => $decoded]);
            }
        }

        $validator = Validator::make($request->all(), [
            'name'         => 'required|string|max:191',
            'section_type' => 'required|string|max:64',
            'section_json' => 'required|array',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $row = HomeLayoutTemplate::create([
            'name'         => $request->input('name'),
            'description'  => $request->input('description'),
            'icon'         => $request->input('icon'),
            'section_type' => $request->input('section_type'),
            'section_json' => $sectionJson,
            'created_by'   => auth()->id(),
        ]);

        return CommonHelper::responseWithData($row);
    }

    public function delete(Request $request)
    {
        $id = (int) $request->input('id');
        $row = HomeLayoutTemplate::find($id);
        if (!$row) {
            return CommonHelper::responseError(__('not_found'));
        }
        $row->delete();
        return CommonHelper::responseSuccess(__('deleted_successfully'));
    }
}
