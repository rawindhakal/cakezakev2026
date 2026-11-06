<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Services\OfflinePayments;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/** Admin: manual payment verification. */
class OfflinePaymentApiController extends Controller
{
    /** Staff verdict on a manual payment. */
    public function verify(Request $request)
    {
        $v = Validator::make($request->all(), [
            'order_id' => 'required|integer|exists:orders,id',
            'decision' => 'required|in:verified,rejected',
            'note' => 'nullable|string|max:500',
        ]);
        if ($v->fails()) return CommonHelper::responseError($v->errors()->first());

        $order = Order::find($request->order_id);
        if (!OfflinePayments::isManual($order->payment_method)) {
            return CommonHelper::responseError('This order is not a manual payment.');
        }
        $order->payment_verification = $request->decision;
        $order->payment_verification_note = $request->input('note');
        $order->payment_verified_at = now();
        $order->payment_verified_by = optional($request->user())->id;
        $order->save();

        return CommonHelper::responseSuccess($request->decision === 'verified' ? 'Payment verified' : 'Payment rejected');
    }
}
