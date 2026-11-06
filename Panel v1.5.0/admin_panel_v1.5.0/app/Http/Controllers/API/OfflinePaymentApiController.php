<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Services\OfflinePayments;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;

/** Admin: payment method settings (with QR uploads) and manual verification. */
class OfflinePaymentApiController extends Controller
{
    public function settings()
    {
        $c = OfflinePayments::config();
        $c['esewa']['qr_url'] = OfflinePayments::url($c['esewa']['qr_image']);
        $c['qr']['qr_url'] = OfflinePayments::url($c['qr']['qr_image']);
        return CommonHelper::responseWithData($c);
    }

    public function save(Request $request)
    {
        $v = Validator::make($request->all(), [
            'esewa_qr' => 'nullable|image|max:4096',
            'qr_image' => 'nullable|image|max:4096',
            'config' => 'required|string',
        ]);
        if ($v->fails()) return CommonHelper::responseError($v->errors()->first());

        $incoming = json_decode($request->input('config'), true);
        if (!is_array($incoming)) return CommonHelper::responseError('Invalid config');

        $current = OfflinePayments::config();
        $new = OfflinePayments::defaults();
        foreach ($new as $k => $defaults) {
            foreach ($defaults as $field => $dv) {
                if ($field === 'qr_image') continue;
                $val = $incoming[$k][$field] ?? $current[$k][$field];
                $new[$k][$field] = $field === 'enabled' ? ((int) $val ? 1 : 0) : trim((string) $val);
            }
            if (array_key_exists('qr_image', $defaults)) $new[$k]['qr_image'] = $current[$k]['qr_image'];
        }

        foreach (['esewa' => 'esewa_qr', 'qr' => 'qr_image'] as $section => $field) {
            if ($request->hasFile($field)) {
                if ($current[$section]['qr_image']) Storage::disk('public')->delete($current[$section]['qr_image']);
                $new[$section]['qr_image'] = $request->file($field)->store('payment_qr', 'public');
            } elseif (!empty($incoming[$section]['remove_qr'])) {
                if ($current[$section]['qr_image']) Storage::disk('public')->delete($current[$section]['qr_image']);
                $new[$section]['qr_image'] = '';
            }
        }

        OfflinePayments::save($new);
        return $this->settings();
    }

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
