<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\NotificationTemplate;
use App\Models\NotificationTemplateTranslation;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class NotificationTemplatesApiController extends Controller
{

    public function index()
    {
        $request = request();
        $limit = (int) ($request->input('limit', 10));
        $offset = ((int) ($request->input('offset', 1)) - 1) * $limit;
        $filter = $request->input('filter', '');

        $query = NotificationTemplate::with('translations')->orderBy('id', 'ASC');
        if ($filter !== '') {
            $matched = NotificationTemplate::pluck('type')
                ->filter(fn ($t) => stripos($t, $filter) !== false
                    || stripos(NotificationService::templateLabel($t), $filter) !== false)
                ->values();
            $query->whereIn('type', $matched);
        }
        $total = $query->count();
        $templates = $query->skip($offset)->take($limit)->get();
        $templates->each(fn ($t) => $t->label = NotificationService::templateLabel($t->type));

        return CommonHelper::responseWithData($templates, $total);
    }

    public function update(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'notification_template_id' => 'required|exists:notification_templates,id',
            'language_id' => 'required|exists:languages,id',
            'title' => 'required|string',
            'message' => 'nullable|string',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        NotificationTemplateTranslation::updateOrCreate(
            [
                'notification_template_id' => $request->notification_template_id,
                'language_id' => $request->language_id,
            ],
            [
                'title' => $request->title,
                'message' => $request->message ?? '',
            ]
        );

        return CommonHelper::responseSuccess('notification_template_updated_successfully');
    }
}
