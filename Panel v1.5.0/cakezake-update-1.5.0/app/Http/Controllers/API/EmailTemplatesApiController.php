<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\EmailTemplate;
use App\Models\EmailTemplateTranslation;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class EmailTemplatesApiController extends Controller
{
    /** Paged template list with translations — used by the Settings > Email Templates page. */
    public function list(Request $request)
    {
        $limit = (int) ($request->input('limit', 10));
        $offset = ((int) ($request->input('offset', 1)) - 1) * $limit;
        $filter = $request->input('filter', '');

        $query = EmailTemplate::with('translations')->orderBy('id', 'ASC');
        if ($filter !== '') {
            $matched = EmailTemplate::pluck('type')
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

    /** Save one language's subject/body for a template (mirrors notification templates). */
    public function updateTranslation(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email_template_id' => 'required|exists:email_templates,id',
            'language_id' => 'required|exists:languages,id',
            'title' => 'required|string',
            'message' => 'nullable|string',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        EmailTemplateTranslation::updateOrCreate(
            [
                'email_template_id' => $request->email_template_id,
                'language_id' => $request->language_id,
            ],
            [
                'title' => $request->title,
                'message' => $request->message ?? '',
            ]
        );

        // Keep the base row in sync with the default language for fallbacks.
        if ((int) $request->language_id === CommonHelper::getDefaultLanguageId()) {
            EmailTemplate::where('id', $request->email_template_id)->update([
                'title' => $request->title,
                'message' => $request->message ?? '',
            ]);
        }

        return CommonHelper::responseSuccess('email_template_updated_successfully');
    }

}
