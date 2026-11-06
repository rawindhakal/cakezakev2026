<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Jobs\SendBulkPushNotificationJob;
use App\Models\Category;
use App\Models\Product;
use App\Models\Branch;
use App\Models\DeliveryBoy;
use App\Models\Notification;
use App\Models\User;
use App\Models\UserToken;
use App\Models\AdminToken;
use App\Models\Role;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
class NotificationsApiController extends Controller
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
        // Branch users may only target their own zone's delivery boys.
        $branchZoneId = $this->branchZoneId();
        if ($branchZoneId) {
            $delivery_boys = DeliveryBoy::where('status', 1)->where('zone_id', $branchZoneId)
                ->select('id', 'name')->orderBy('id', 'DESC')->get()->makeHidden('translations')->toArray();
            return CommonHelper::responseWithData([
                'users' => [], 'delivery_boys' => $delivery_boys, 'branches' => [],
                'categories' => [], 'products' => [], 'notifications' => [],
            ]);
        }

        $branches = Branch::where('status', 1)->select('id', 'name')->orderBy('id', 'DESC')->get()->makeHidden(['translations', 'categories'])->toArray();
        $delivery_boys = DeliveryBoy::where('status', 1)->select('id', 'name')->orderBy('id', 'DESC')->get()->makeHidden('translations')->toArray();
        $users = User::where('status', 1)->select('id', 'name')->orderBy('id', 'DESC')->get()->makeHidden('translations')->toArray();

        $categories = Category::where('status', 1)
            ->whereNotIn('id', function ($q) {
                $q->select('parent_id')->from('categories')->whereNotNull('parent_id');
            })
            ->select('id', 'name') // Only select specific columns
            ->orderBy('id', 'DESC')
            ->get()
            ->makeHidden(['translations', 'image_url', 'has_child', 'has_active_child'])
            ->toArray();
        $products = Product::where('status', 1)->select('id', 'name')->orderBy('id', 'DESC')->get()->makeHidden('translations')->toArray();
        $notifications = Notification::orderBy('id', 'DESC')->get();
        $data = array(
            "users" => $users,
            "delivery_boys" => $delivery_boys,
            "branches" => $branches,
            "categories" => $categories,
            "products" => $products,
            "notifications" => $notifications
        );
        return CommonHelper::responseWithData($data);
    }

    public function save(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'type' => 'required',
            'type_id' => 'required_if:type,category,product,user,branch,delivery_boy|numeric',
            'title' => 'required',
            'message' => 'required',
            'image' => ['required_if:include_image,true', 'nullable', 'mimes:jpeg,jpg,png,gif'],
            'type_link' => 'required_if:type,==,url',
        ]);
        $validator->setCustomMessages([
            'type_id.required_if' => 'The :attribute field is required when the type is category, product.',
            'type_id.numeric' => 'Please select Category or Product',

        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // Branch users can only push to their own zone's delivery boys.
        $branchZoneId = $this->branchZoneId();
        if ($branchZoneId) {
            if ($request->type !== 'delivery_boy') {
                return CommonHelper::responseError('you_can_only_notify_your_delivery_boys');
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

        if ($request->type == "user" || $request->type == "branch" || $request->type == "delivery_boy") {
            $type_ids = explode(',', $request->type_ids);
            foreach ($type_ids as $key => $type_id) {
                $notification = new Notification();
                $notification->type = $request->type;
                $notification->type_id = $type_id;
                $notification->type_link = $request->type_link ?? "";
                $notification->title = $request->title;
                $notification->message = $request->message;
                $image = '';
                if ($request->include_image == 'true' && $request->hasFile('image')) {
                    $image = CommonHelper::uploadFile($request, 'image', 'notifications');
                }
                $notification->image = $image;
                $notification->date_sent = now();
                $notification->save();
            }
        } else {
            $notification = new Notification();
            $notification->type = $request->type;
            $notification->type_id = $request->type_id;
            $notification->type_link = $request->type_link ?? "";
            $notification->title = $request->title;
            $notification->message = $request->message;
            $image = '';
            if ($request->include_image == 'true' && $request->hasFile('image')) {
                $image = CommonHelper::uploadFile($request, 'image', 'notifications');
            }
            $notification->image = $image;
            $notification->date_sent = now();
            $notification->save();
        }

        $pushNotification = CommonHelper::getPushObject($request, $image ?? '');

        // Fetch FCM tokens based on notification type: customers use UserToken, branches/delivery boys use AdminToken
        $tokensToSend = collect();
        if ($request->type === 'user') {
            if (isset($type_ids) && count($type_ids) > 0) {
                $tokensToSend = UserToken::where('type', 'customer')->whereIn('user_id', $type_ids)->get();
            } else {
                $tokensToSend = UserToken::where('type', 'customer')->get();
            }
        } elseif ($request->type === 'delivery_boy' && isset($type_ids) && count($type_ids) > 0) {
            $adminIds = DeliveryBoy::whereIn('id', $type_ids)->pluck('admin_id')->filter()->unique()->values();
            $tokensToSend = AdminToken::where('type', Role::$roleNameDeliveryBoy)->whereIn('user_id', $adminIds)->get();
        } elseif (in_array($request->type, ['default', 'category', 'product', 'url'])) {
            // Broadcast to all customers
            $tokensToSend = UserToken::where('type', 'customer')->get();
        }

        if ($tokensToSend->isNotEmpty()) {
            $tokenModelForInvalid = in_array($request->type, ['user', 'default', 'category', 'product', 'url']) ? UserToken::class : AdminToken::class;
            SendBulkPushNotificationJob::dispatch(
                $tokensToSend->pluck('id')->map(fn ($id) => (int) $id)->all(),
                $tokenModelForInvalid,
                $pushNotification['fcmMsg'],
                $pushNotification['notification']
            );
        } else {
            $notification = ['status' => 0, 'message' => "No FCM tokens found for the selected " . $request->type . "(s). They may not have logged in from the app yet."];
            return CommonHelper::responseSuccessWithData("notification_saved_successfully", $notification);
        }
        return CommonHelper::responseSuccess('notification_saved_successfully');
    }

    public function delete(Request $request)
    {
        if (isset($request->id)) {
            $notification = Notification::find($request->id);
            if ($notification) {
                CommonHelper::deleteFile($notification->image);
                $notification->delete();
                return CommonHelper::responseSuccess('notification_deleted_successfully');
            } else {
                return CommonHelper::responseSuccess('notification_already_deleted');
            }
        }
    }
}
