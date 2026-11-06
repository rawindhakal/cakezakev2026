<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Country;
use App\Models\DeliveryBoy;
use App\Models\Role;
use App\Models\WithdrawalRequest;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;

class WithdrawalRequestsApiController extends Controller
{
    public function getWithdrawalRequests(Request $request)
    {
        $limit = isset($request->limit) ? $request->limit : '';
        $offset = isset($request->offset) ? $request->offset : '';
        $search = isset($request->search) ? $request->search : '';

        // Customer withdrawals are disabled — only delivery-boy requests exist now.
        $withdrawalRequestsQuery = WithdrawalRequest::select(
            'withdrawal_requests.*',
            'delivery_boys.name as delivery_boy_name',
            'delivery_boys.balance as delivery_boy_balance'
        )
            ->where('withdrawal_requests.type', WithdrawalRequest::$typeDeliveryBoy)
            ->leftJoin('delivery_boys', function ($join) {
                $join->where('withdrawal_requests.type', '=', WithdrawalRequest::$typeDeliveryBoy)
                    ->on('withdrawal_requests.type_id', '=', 'delivery_boys.id');
            });

        $type_id = null;
        if (auth()->user()->role_id == Role::$roleDeliveryBoy) {
            $type = WithdrawalRequest::$typeDeliveryBoy;
            $type_id = auth()->user()->deliveryBoy->id;
            $withdrawalRequestsQuery->where(['withdrawal_requests.type' => $type, 'withdrawal_requests.type_id' => $type_id]);
        }

        // Global header country filter (admin panel). Requests created before the currency
        // snapshot existed have a null country_id — keep them visible so nothing disappears.
        if ($request->filled('country_id')) {
            $withdrawalRequestsQuery->where(function ($q) use ($request) {
                $q->where('withdrawal_requests.country_id', $request->country_id)
                    ->orWhereNull('withdrawal_requests.country_id');
            });
        }

        if (isset($request->type) && $request->type != null) {
            $withdrawalRequestsQuery->where('withdrawal_requests.type', $request->type);
        }
        if (isset($request->status) && $request->status != null) {
            $withdrawalRequestsQuery->where('withdrawal_requests.status', $request->status);
        }

        if ($search) {
            $withdrawalRequestsQuery->where(function ($query) use ($search) {
                $query->where('delivery_boys.name', 'like', '%' . $search . '%')
                    ->orWhere('withdrawal_requests.id', 'like', '%' . $search . '%')
                    ->orWhere('withdrawal_requests.amount', 'like', '%' . $search . '%')
                    ->orWhere('withdrawal_requests.message', 'like', '%' . $search . '%')
                    ->orWhere('withdrawal_requests.remark', 'like', '%' . $search . '%')
                    ->orWhere('withdrawal_requests.created_at', 'like', '%' . $search . '%');
            });
        }

        $total = $withdrawalRequestsQuery->count();
        $withdrawalRequestsQuery->orderBy('withdrawal_requests.id', 'DESC');
        if (isset($request->limit)) {
            $withdrawalRequestsQuery->skip($offset)->take($limit);
        }
        $withdrawalRequests = $withdrawalRequestsQuery->get()->toArray();

        $contacts = CommonHelper::deliveryBoyContactMap(array_column($withdrawalRequests, 'type_id'));

        $data = array();
        $data['withdraw_requests'] = [];
        foreach ($withdrawalRequests as $request) {
            $subData = array();
            $subData["id"] = $request["id"];
            $subData["type"] = $request["type"];

            if (strtolower($request["origional_type"]) == WithdrawalRequest::$typeDeliveryBoy) {
                $subData["name"] = $request["delivery_boy_name"];
                $subData["balance"] = $request["delivery_boy_balance"];
                $c = $contacts[$request["type_id"]] ?? null;
                $subData["delivery_boy_id"] = (int) $request["type_id"];
                $subData["profile_url"]  = $c["profile_url"] ?? '';
                $subData["email"]        = $c["email"] ?? '';
                $subData["mobile"]       = $c["mobile"] ?? '';
                $subData["country_code"] = $c["country_code"] ?? '';
            }
            $subData["amount"] = $request["amount"];
            // Currency snapshotted when the request was filed.
            $subData["country_id"] = $request["country_id"] ?? null;
            $subData["currency"] = $request["currency"] ?? null;
            $subData["currency_code"] = $request["currency_code"] ?? null;
            $subData["message"] = CommonHelper::translateLedgerMessage($request["message"]);
            $subData["status"] = $request["status"];
            $subData["remark"] = $request["remark"];
            $subData["receipt_image"] = $request["receipt_image"];
            $subData["receipt_image_url"] = $request["receipt_image_url"];
            $subData["created_at"] = $request["created_at"] ?? '';

            $data['withdraw_requests'][] = $subData;
        }

        if (auth()->user()->role_id == Role::$roleDeliveryBoy) {
            $pending_amount = WithdrawalRequest::where('status', WithdrawalRequest::$statusPending)
                ->where('type', WithdrawalRequest::$typeDeliveryBoy)
                ->where('type_id', $type_id)
                ->sum('amount');
            $data['balance'] = round(auth()->user()->deliveryBoy->balance - $pending_amount, 2);
            // Currency of the delivery boy's registered country (for the balance/amount fields).
            $dbCountryId = auth()->user()->country_id ?? (auth()->user()->deliveryBoy->country_id ?? null);
            $data['currency'] = $dbCountryId ? (Country::find($dbCountryId)->currency ?? '') : '';
        }

        if (!empty($data)) {
            return CommonHelper::responseWithData($data, $total);
        } else {
            return CommonHelper::responseError('withdrawal_request_not_found');
        }
    }
    
    public function update(Request $request)
    {

        $validator = Validator::make($request->all(), [
            'status' => 'required',
            'receipt_image' => 'required_if:status,1',
            'remark' => 'required_if:status,2|nullable|string|max:500'
        ], [
            'status.required' => 'The status field is mandatory.',
            'receipt_image.required_if' => __('the_receipt_image_is_required_when_the_status_is_approved'),
            'remark.required_if' => 'A remark is required when the status is Rejected.',
            'remark.string' => 'The remark must be a string.',
            'remark.max' => 'The remark may not be greater than 500 characters.'
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        if (isset($request->id)) {

            DB::beginTransaction();
            try {

                $withdrawalRequest = WithdrawalRequest::find($request->id);
                if ($withdrawalRequest->status != WithdrawalRequest::$statusApproved) {
                    if ($request->status == $withdrawalRequest->status) {
                        return CommonHelper::responseError('this_record_have_same_status');
                    }

                    if (intval($request->status) == WithdrawalRequest::$statusApproved) {

                        // Only delivery boys have withdrawals now (customer withdrawals removed).
                        if (strtolower($withdrawalRequest->origional_type) == WithdrawalRequest::$typeDeliveryBoy) {

                            $deliveryboy_id = $withdrawalRequest->type_id;

                            $deliveryboy = DeliveryBoy::find($deliveryboy_id);
                            if (empty($deliveryboy)) {
                                return CommonHelper::responseError('delivery_boy_not_found');
                            }

                            if ($deliveryboy->balance <= $withdrawalRequest->amount) {
                                return CommonHelper::responseError('the_amount_is_greater_than_your_balance');
                            }
                           
                            // Message stores a translation key; '|' suffix is appended verbatim on display.
                            CommonHelper::addDeliveryBoySettlement($deliveryboy_id, floatval($withdrawalRequest->amount), 'debit', 'withdrawal_request_approved|#' . $request->id);
                        }

                        $receipt_image = '';
                        if ($request->hasFile('receipt_image')) {
                            $validator = Validator::make($request->all(), [
                                'receipt_image' => 'image|mimes:jpeg,png,jpg|max:2048',
                            ]);
                            if ($validator->fails()) {
                                return CommonHelper::responseError($validator->errors()->first());
                            }
                            $receipt_image = CommonHelper::uploadFile($request, 'receipt_image', 'withdraw_requests', $withdrawalRequest->receipt_image);
                        }
                        $withdrawalRequest->receipt_image = $receipt_image;
                    }

                    $withdrawalRequest->status = $request->status;
                    $remark = $request->remark;
                    $withdrawalRequest->remark = ($remark === null || $remark === 'null') ? '' : $remark;
                    $withdrawalRequest->save();

                    DB::commit();

                    CommonHelper::sendWithdrawalStatusNotification($withdrawalRequest);
                } else {
                    return CommonHelper::responseError('this_request_is_already_approved');
                }
            } catch (\Exception $e) {
                Log::info("Error : " . $e->getMessage());
                DB::rollBack();
                return CommonHelper::responseError('something_went_wrong');
            }
        }
        return CommonHelper::responseSuccess('withdrawal_request_status_updated_successfully');
    }

    public function delete(Request $request)
    {
        if (isset($request->id)) {
            $withdrawalRequest = WithdrawalRequest::find($request->id);
            if ($withdrawalRequest) {
                $withdrawalRequest->delete();
                return CommonHelper::responseSuccess('withdrawal_request_deleted_successfully');
            } else {
                return CommonHelper::responseSuccess("Withdrawal Request Already Deleted!");
            }
        }
    }

}
