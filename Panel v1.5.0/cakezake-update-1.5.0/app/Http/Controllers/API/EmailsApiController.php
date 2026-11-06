<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Jobs\SendBulkPromotionalEmailJob;
use App\Models\DeliveryBoy;
use App\Models\Email;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class EmailsApiController extends Controller
{
    /** Branch user's zone id, or null when not a branch user. */
    private function branchZoneId(): ?int
    {
        $user = auth()->user();
        if ($user && $user->isBranchUser() && $user->branch) {
            return (int) $user->branch->zone_id;
        }
        return null;
    }

    public function index()
    {
        // Branch users may only email their own zone's delivery boys.
        $branchZoneId = $this->branchZoneId();
        if ($branchZoneId) {
            $delivery_boys = DeliveryBoy::where('status', 1)->where('zone_id', $branchZoneId)
                ->select('id', 'name')->orderBy('id', 'DESC')->get()->makeHidden('translations')->toArray();
            return CommonHelper::responseWithData([
                'users' => [], 'delivery_boys' => $delivery_boys, 'emails' => [],
            ]);
        }

        $users = User::where('status', 1)->select('id', 'name')->orderBy('id', 'DESC')->get()->toArray();
        $delivery_boys = DeliveryBoy::where('status', 1)->select('id', 'name')->orderBy('id', 'DESC')
            ->get()->makeHidden('translations')->toArray();
        $emails = Email::orderBy('id', 'DESC')->get();
        $data = array(
            "users" => $users,
            "delivery_boys" => $delivery_boys,
            "emails" => $emails,
        );
        return CommonHelper::responseWithData($data);
    }

    public function save(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'type' => 'required|in:default,user,delivery_boy,cart',
            'type_id' => 'required_if:type,user',
            'title' => 'required',
            'message' => 'required',
            'image' => ['required_if:include_image,true', 'nullable', 'mimes:jpeg,jpg,png,gif,pdf'],
        ]);
        $validator->setCustomMessages([
            'type_id.required_if' => 'The :attribute field is required when the type is category, product.',

        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // Branch users can only email their own zone's delivery boys.
        $branchZoneId = $this->branchZoneId();
        if ($branchZoneId) {
            if ($request->type !== 'delivery_boy') {
                return CommonHelper::responseError('you_can_only_email_your_delivery_boys');
            }
            $allowedIds = DeliveryBoy::where('zone_id', $branchZoneId)->pluck('id')->map(fn ($i) => (int) $i)->all();
            $reqIds = array_values(array_intersect(
                array_map('intval', array_filter(explode(',', (string) $request->type_ids), 'strlen')),
                $allowedIds
            ));
            if (empty($reqIds)) {
                return CommonHelper::responseError('please_select_a_valid_delivery_boy');
            }
            $request->merge(['type_ids' => implode(',', $reqIds)]);
        }

        $email = new Email();
        $email->type = $request->type;
        $email->type_id = $request->type_ids ?? '';
        $email->title = $request->title;
        $email->message = $request->message;
        $image = '';
        if ($request->include_image == 'true' && $request->hasFile('image')) {
            $image = CommonHelper::uploadFile($request, 'image', 'emails');
        }
        $email->image = $image;
        $email->save();

        $recipientType = match ($request->type) {
            'delivery_boy' => 'delivery_boy',
            'cart'         => 'cart',
            default        => 'user',
        };
        $ids = null;
        if (in_array($request->type, ['user', 'delivery_boy'], true) && $request->type_ids != null) {
            $ids = array_map('intval', explode(',', $request->type_ids));
        }

        SendBulkPromotionalEmailJob::dispatch($recipientType, $ids, (string) $request->title, (string) $request->message, $image ?: null);

        return CommonHelper::responseSuccess('email_saved_successfully');
    }

    public function delete(Request $request)
    {
        if (isset($request->id)) {
            $email = Email::find($request->id);
            if ($email) {
                CommonHelper::deleteFile($email->image);
                $email->delete();
                return CommonHelper::responseSuccess('email_deleted_successfully');
            } else {
                return CommonHelper::responseSuccess('email_already_deleted');
            }
        }
    }
}
