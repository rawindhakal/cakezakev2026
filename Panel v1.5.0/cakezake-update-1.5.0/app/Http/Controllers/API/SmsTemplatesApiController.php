<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Models\SmsTemplate;
use App\Models\SmsTemplateTranslation;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller as BaseController;
use Illuminate\Support\Facades\Validator;

class SmsTemplatesApiController extends BaseController
{
    public function index(Request $request)
    {
        $limit  = (int) $request->input('limit', 10);
        $offset = (((int) $request->input('offset', 0)) - 1) * $limit;
        $filter = trim((string) $request->input('filter', ''));

        $query = SmsTemplate::orderBy('id', 'ASC');
        if ($filter !== '') {
            $matched = SmsTemplate::pluck('type')
                ->filter(fn ($t) => stripos($t, $filter) !== false
                    || stripos(NotificationService::templateLabel($t), $filter) !== false)
                ->values();
            $query->where(function ($q) use ($filter, $matched) {
                $q->whereIn('type', $matched)
                    ->orWhere('message', 'like', "%{$filter}%");
            });
        }

        $total = (clone $query)->count();
        if ($limit > 0) {
            $query->skip($offset < 0 ? 0 : $offset)->take($limit);
        }

        $rows = $query->get()->map(function (SmsTemplate $st) {
            return [
                'id'           => $st->id,
                'type'         => $st->type,
                'label'        => NotificationService::templateLabel($st->type),
                'message'      => $st->message,
                'placeholders' => $st->placeholders ?? [],
                'updated_at'   => $st->getAttributes()['updated_at'] ?? null,
            ];
        });

        return CommonHelper::responseWithData($rows, $total);
    }

    /** Template + all its per-language translations (for the edit screen). */
    public function edit($id)
    {
        $template = SmsTemplate::find($id);
        if (!$template) {
            return CommonHelper::responseError('sms_template_not_found');
        }

        $translations = SmsTemplateTranslation::where('sms_template_id', $template->id)
            ->get(['language_id', 'message', 'gateway_template_ids']);

        return CommonHelper::responseWithData([
            'id'           => $template->id,
            'type'         => $template->type,
            'message'      => $template->message,
            'placeholders' => $template->placeholders ?? [],
            'translations' => $translations,
        ]);
    }

    /** Save one language's message (+ optional per-gateway DLT template id). SMS has no title. */
    public function update(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'id'          => 'required|integer|exists:sms_templates,id',
            'language_id' => 'required|integer',
            'message'     => 'required|string',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $template = SmsTemplate::find($request->id);

        // Per-gateway DLT template ids (e.g. {"msg91":"..","fast2sms":".."}). Accept a
        // JSON string or an array; keep only non-empty entries.
        $gatewayIds = $request->input('gateway_template_ids', []);
        if (is_string($gatewayIds)) {
            $gatewayIds = json_decode($gatewayIds, true) ?: [];
        }
        $gatewayIds = array_filter((array) $gatewayIds, fn ($v) => $v !== null && $v !== '');

        SmsTemplateTranslation::updateOrCreate(
            ['sms_template_id' => $template->id, 'language_id' => (int) $request->language_id],
            [
                'message'              => $request->message,
                'gateway_template_ids' => $gatewayIds ?: null,
            ]
        );

        // Keep the base row's message in sync with the default language (fallback source).
        if ((int) $request->language_id === CommonHelper::getDefaultLanguageId()) {
            $template->message = $request->message;
            $template->save();
        }

        return CommonHelper::responseSuccess('sms_template_updated_successfully');
    }
}
