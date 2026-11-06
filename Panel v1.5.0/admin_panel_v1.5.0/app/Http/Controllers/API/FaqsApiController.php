<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Faq;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use App\Services\LanguageService;

class FaqsApiController extends Controller
{
    protected $languageService;

    public function __construct(LanguageService $languageService)
    {
        $this->languageService = $languageService;
    }

    public function index()
    {
        $request = request();
        $query = Faq::with('translations')->orderBy('sort_order')->orderBy('id');

        // If ID passed → return single FAQ (for edit)
        if ($request->has('id')) {

            $faq = $query->where('id', $request->id)->first();

            if (!$faq) {
                return CommonHelper::responseError("FAQ not found");
            }

            return CommonHelper::responseWithData($faq);
        }

        // Otherwise return full listing (no duplication)
        $faqs = $query->get();

        return CommonHelper::responseWithData($faqs);
    }

    public function save(Request $request)
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $isDefaultLanguage = ($request->language_id == $defaultLanguage->id);

        $rules = [
            'question' => 'required',
            'language_id' => 'required|exists:languages,id'
        ];

        $validator = Validator::make($request->all(), $rules);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $faq = null;
        if ($isDefaultLanguage) {

            $faq = new Faq();
            $faq->sort_order = (int) Faq::max('sort_order') + 1;
            $faq->question = $request->question;
            $faq->answer = $request->answer ?? '';
            $faq->status = 1;
            $faq->save();
        } else {
            return CommonHelper::responseError(__('default_language_required_first'));
        }
        $translationData = [
            'question' => $request->question,
            'answer'   => $request->answer ?? '',
        ];

        $faq->saveTranslation($request->language_id, $translationData);

        return CommonHelper::responseWithData([
            'id' => $faq->id,
            'message' => __('faq_saved_successfully')
        ]);
    }

    public function update(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'id' => 'required|exists:faqs,id',
            'question' => 'required',
            'language_id' => 'required|exists:languages,id'
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $faq = Faq::find($request->id);
        $defaultLanguage = $this->languageService->getDefaultLanguage();

        // If default → update base table
        if ($request->language_id == $defaultLanguage->id) {
            $faq->question = $request->question;
            $faq->answer   = $request->answer ?? "";
            $faq->save();
        }

        // Save translation
        $faq->saveTranslation($request->language_id, [
            'question' => $request->question,
            'answer'   => $request->answer ?? "",
        ]);

        return CommonHelper::responseSuccess("faq_updated_successfully");
    }

    /** Drag-and-drop order from the panel: ids in display order, first = top. */
    public function updateOrder(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'ids'   => 'required|array|min:1',
            'ids.*' => 'integer|exists:faqs,id',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        foreach (array_values($request->ids) as $position => $id) {
            Faq::where('id', (int) $id)->update(['sort_order' => $position + 1]);
        }

        return CommonHelper::responseSuccess('faqs_order_updated_successfully');
    }

    public function delete(Request $request)
    {
        if (isset($request->id)) {
            $faq = Faq::find($request->id);
            if ($faq) {
                $faq->delete();
                return CommonHelper::responseSuccess("faq_deleted_successfully");
            } else {
                return CommonHelper::responseSuccess("FAQs Already Deleted!");
            }
        }
    }
}
