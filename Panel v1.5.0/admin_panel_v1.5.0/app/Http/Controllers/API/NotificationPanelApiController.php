<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\PanelNotification;
use Illuminate\Http\Request;

class NotificationPanelApiController extends Controller
{
    public function getNotifications(Request $request)
    {
        $limit = $request->input('per_page');
        $page = $request->input('page', 1);
        $offset = ($page - 1) * $limit;

        $notifications = PanelNotification::where('notifiable_id', auth()->user()->id)
            ->orderBy('id', 'DESC');

        $search = trim((string) $request->input('search', ''));
        if ($search !== '') {
            $notifications->where('data', 'like', '%' . $search . '%');
        }

        $total = $notifications->count();

        if ($limit) {
            $notifications = $notifications->limit($limit)->offset($offset);
        }

        $notifications = $notifications->get();

        return CommonHelper::responseWithData($notifications, $total);
    }

    /** Remove a single notification from the panel list. */
    public function delete(Request $request)
    {
        $notification = PanelNotification::find($request->input('id'));
        if (!$notification) {
            return CommonHelper::responseError('notification_not_found');
        }

        $notification->delete();

        return CommonHelper::responseSuccess('notification_deleted_successfully');
    }
}
