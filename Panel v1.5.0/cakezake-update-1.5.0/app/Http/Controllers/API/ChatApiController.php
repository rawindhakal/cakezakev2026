<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\DeliveryBoy;
use App\Models\Message;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Setting;
use App\Models\User;
use App\Services\ChatService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
class ChatApiController extends Controller
{
    protected ChatService $chat;

    public function __construct(ChatService $chat)
    {
        $this->chat = $chat;
    }

    /* ============================ ADMIN ============================ */

    /** All conversations for the admin panel, newest activity first. */
    public function conversations(Request $request)
    {
        $type = $request->input('type');
        $search = trim((string) $request->input('search', ''));

        $q = Conversation::query();
        if ($type === 'order') {
            $q->whereIn('type', Conversation::ORDER_SCOPED_TYPES);
        } elseif (in_array($type, [
            Conversation::TYPE_ADMIN_CUSTOMER,
            Conversation::TYPE_ADMIN_DELIVERY_BOY,
            Conversation::TYPE_DELIVERY_BOY_CUSTOMER,
            Conversation::TYPE_ORDER_ADMIN,
        ], true)) {
            $q->where('type', $type);
        }

        if ($search !== '') {
            $userIds = User::where('name', 'like', "%{$search}%")->pluck('id')->all();
            $dbIds = DeliveryBoy::where('name', 'like', "%{$search}%")->pluck('id')->all();
            $orderIds = Order::where('order_number', 'like', "%{$search}%")->pluck('id')->all();
            $q->where(function ($w) use ($userIds, $dbIds, $orderIds, $search) {
                $w->whereIn('user_id', $userIds ?: [0])
                    ->orWhereIn('delivery_boy_id', $dbIds ?: [0])
                    ->orWhereIn('order_id', $orderIds ?: [0])
                    ->orWhere('order_id', is_numeric($search) ? (int) $search : 0);
            });
        }

        // Global header country/zone filter. Country resolves per conversation type:
        // order chats via order->country_id (+ zone_id), delivery-boy chats via
        // delivery_boy->country_id. Customer chats have no country link → kept visible.
        $countryId = (int) $request->input('country_id', 0);
        $zoneId = (int) $request->input('zone_id', 0);
        if ($countryId) {
            $q->where(function ($w) use ($countryId, $zoneId) {
                $w->whereHas('order', function ($o) use ($countryId, $zoneId) {
                    $o->where('country_id', $countryId)
                        ->when($zoneId, fn ($x) => $x->where('zone_id', $zoneId));
                })
                ->orWhereHas('deliveryBoy', fn ($d) => $d->where('country_id', $countryId))
                ->orWhere('type', Conversation::TYPE_ADMIN_CUSTOMER);
            });
        }

        $total = (clone $q)->count();
        $limit = max(1, min(100, (int) $request->input('limit', 10)));
        $offset = max(0, (int) $request->input('offset', 0));

        $rows = $q->orderByDesc('last_message_at')->orderByDesc('id')
            ->offset($offset)->limit($limit)->get();

        // Bulk-load participants / orders / unread counts for the whole page.
        $this->chat->preloadConversations($rows, Message::SENDER_ADMIN);
        $items = $rows->map(fn ($c) => $this->chat->shapeConversation($c, Message::SENDER_ADMIN))->values();

        return CommonHelper::responseWithData($items, $total);
    }

    /** Open (or create) the general admin↔customer conversation. */
    public function startCustomer(Request $request)
    {
        $validator = Validator::make($request->all(), ['user_id' => 'required|integer|exists:users,id']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $c = $this->chat->adminCustomer((int) $request->user_id);
        return CommonHelper::responseWithData($this->chat->shapeConversation($c, Message::SENDER_ADMIN));
    }

    /** Open (or create) the general admin↔delivery-boy conversation. */
    public function startDeliveryBoy(Request $request)
    {
        $validator = Validator::make($request->all(), ['delivery_boy_id' => 'required|integer|exists:delivery_boys,id']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $c = $this->chat->adminDeliveryBoy((int) $request->delivery_boy_id);
        return CommonHelper::responseWithData($this->chat->shapeConversation($c, Message::SENDER_ADMIN));
    }

    /** Open (or create) the order's admin↔customer conversation (order_admin). */
    public function startOrder(Request $request)
    {
        $validator = Validator::make($request->all(), ['order_id' => 'required|integer']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $order = Order::find($request->order_id);
        if (!$order) {
            return CommonHelper::responseError('order_not_found');
        }
        if (empty($order->user_id)) {
            return CommonHelper::responseError('no_customer_on_this_order');
        }
        $c = $this->chat->orderAdminConversation($order);
        if (!$c) {
            return CommonHelper::responseError('could_not_start_chat');
        }
        return CommonHelper::responseWithData($this->chat->shapeConversation($c, Message::SENDER_ADMIN));
    }

    /** Unread conversation count for the admin sidebar badge. */
    public function unreadCount(Request $request)
    {
        return CommonHelper::responseWithData(['count' => $this->chat->unreadConversationCount(Message::SENDER_ADMIN)]);
    }

    /** Mark the other side's messages read (admin view). */
    public function markRead(Request $request)
    {
        $c = Conversation::find($request->input('conversation_id'));
        if (!$c) {
            return CommonHelper::responseError('conversation_not_found');
        }
        // Admin is observer-only on customer↔delivery-boy threads: viewing must NOT consume
        // the participants' unread state, so never mark those read on the admin's behalf.
        if ($c->type !== Conversation::TYPE_DELIVERY_BOY_CUSTOMER) {
            $this->chat->markRead($c, Message::SENDER_ADMIN);
        }
        return CommonHelper::responseWithData(['done' => true]);
    }

    /** Messages of a conversation (admin view) + mark the other side's as read. */
    public function messages(Request $request)
    {
        $c = Conversation::find($request->input('conversation_id'));
        if (!$c) {
            return CommonHelper::responseError('conversation_not_found');
        }
        $limit = (int) $request->input('limit', 30);
        $offset = (int) $request->input('offset', 0);
        // Observer-only on delivery_boy_customer: don't mark the participants' messages read.
        if ($offset === 0 && $c->type !== Conversation::TYPE_DELIVERY_BOY_CUSTOMER) {
            $this->chat->markRead($c, Message::SENDER_ADMIN);
        }
        $page = $this->chat->pagedMessages($c, $limit, $offset);
        return CommonHelper::responseWithData([
            'conversation' => $this->chat->shapeConversation($c, Message::SENDER_ADMIN),
            'messages'     => $page['messages'],
        ], $page['total']);
    }

    /** Send a message as admin (into admin↔customer / admin↔delivery-boy / order↔admin). */
    public function send(Request $request)
    {
        $validator = Validator::make($request->all(), ChatService::sendRules());
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $c = Conversation::find($request->conversation_id);
        if (!$c) {
            return CommonHelper::responseError('conversation_not_found');
        }

        if (!in_array($c->type, [Conversation::TYPE_ADMIN_CUSTOMER, Conversation::TYPE_ADMIN_DELIVERY_BOY, Conversation::TYPE_ORDER_ADMIN], true)) {
            return CommonHelper::responseError('admin_cannot_message_this_conversation');
        }
        return $this->dispatchMessages($request, $c, Message::SENDER_ADMIN, (int) auth()->id());
    }

    /**
     * Create one message per attachment (images + audio) plus an optional text
     * message, in order. Returns the shaped messages array (or an error response).
     */
    private function dispatchMessages(Request $request, Conversation $c, string $senderType, int $senderId)
    {
        $text = trim((string) $request->input('message', ''));
        $paths = ChatService::collectAttachments($request);
        if ($text === '' && empty($paths)) {
            return CommonHelper::responseError('message_or_image_required');
        }

        $out = [];
        foreach ($paths as $p) {
            $out[] = $this->chat->shapeMessage($this->chat->postMessage($c, $senderType, $senderId, null, $p));
        }
        if ($text !== '') {
            $out[] = $this->chat->shapeMessage($this->chat->postMessage($c, $senderType, $senderId, $text, null));
        }
        return CommonHelper::responseWithData($out);
    }

    /* ========================= DELIVERY BOY ========================= */

    private function deliveryBoyId(): ?int
    {
        return optional(optional(auth()->user())->deliveryBoy)->id;
    }

    /** Conversations for the delivery boy: admin thread + assigned-order customer threads. */
    public function deliveryBoyConversations(Request $request)
    {
        $dbId = $this->deliveryBoyId();
        if (!$dbId) {
            return CommonHelper::responseError('unauthorized_access_delivery_boy_role_required');
        }
        $search = trim((string) $request->input('search', ''));

        $q = Conversation::where('delivery_boy_id', $dbId);
        if ($search !== '') {
            $userIds = User::where('name', 'like', "%{$search}%")->pluck('id')->all();

            $appName = (string) Setting::get_value('app_name');
            $matchesAdmin = ($appName !== '' && stripos($appName, $search) !== false)
                || stripos((string) __('support'), $search) !== false
                || stripos((string) __('admin'), $search) !== false;
            // Match the order by its human number (ORD-00042) as well as the raw id.
            $orderIds = Order::where('order_number', 'like', "%{$search}%")->pluck('id')->all();
            $q->where(function ($w) use ($userIds, $orderIds, $search, $matchesAdmin) {
                $w->whereIn('user_id', $userIds ?: [0])
                    ->orWhereIn('order_id', $orderIds ?: [0])
                    ->orWhere('order_id', is_numeric($search) ? (int) $search : 0);
                if ($matchesAdmin) {
                    $w->orWhere('type', Conversation::TYPE_ADMIN_DELIVERY_BOY);
                }
            });
        }

        $rows = $q->orderByDesc('last_message_at')->orderByDesc('id')->limit(300)->get();
        $this->chat->preloadConversations($rows, Message::SENDER_DELIVERY_BOY);
        $items = $rows->map(fn ($c) => $this->chat->shapeConversation($c, Message::SENDER_DELIVERY_BOY))->values();
        return CommonHelper::responseWithData($items);
    }

    /** Open (or create) the delivery boy's admin conversation. */
    public function deliveryBoyStartAdmin(Request $request)
    {
        $dbId = $this->deliveryBoyId();
        if (!$dbId) {
            return CommonHelper::responseError('unauthorized_access_delivery_boy_role_required');
        }
        $c = $this->chat->adminDeliveryBoy($dbId);
        return CommonHelper::responseWithData($this->chat->shapeConversation($c, Message::SENDER_DELIVERY_BOY));
    }

    /** Open (or create) the customer conversation for an order assigned to this delivery boy. */
    public function deliveryBoyStartOrder(Request $request)
    {
        $dbId = $this->deliveryBoyId();
        if (!$dbId) {
            return CommonHelper::responseError('unauthorized_access_delivery_boy_role_required');
        }
        $validator = Validator::make($request->all(), ['order_id' => 'required|integer']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $order = Order::find($request->order_id);
        if (!$order) {
            return CommonHelper::responseError('order_not_found');
        }

        // Ecommerce assigns delivery boys per item → verify this boy is on the given item.
        // Quick keeps the order-level assignment check unchanged.
        if ($order->channel === 'ecommerce') {
            $v2 = Validator::make($request->all(), ['order_item_id' => 'required|integer']);
            if ($v2->fails()) {
                return CommonHelper::responseError($v2->errors()->first());
            }
            $item = OrderItem::where('id', $request->order_item_id)
                ->where('order_id', $order->id)
                ->where('delivery_boy_id', $dbId)
                ->first();
            if (!$item) {
                return CommonHelper::responseError('order_not_assigned_to_you');
            }
        } elseif ((int) $order->delivery_boy_id !== (int) $dbId) {
            return CommonHelper::responseError('order_not_assigned_to_you');
        }

        $c = $this->chat->orderConversation($order, $dbId);
        if (!$c) {
            return CommonHelper::responseError('conversation_not_found');
        }
        return CommonHelper::responseWithData($this->chat->shapeConversation($c, Message::SENDER_DELIVERY_BOY));
    }

    public function deliveryBoyMessages(Request $request)
    {
        $dbId = $this->deliveryBoyId();
        $c = Conversation::find($request->input('conversation_id'));
        if (!$c || (int) $c->delivery_boy_id !== (int) $dbId) {
            return CommonHelper::responseError('conversation_not_found');
        }
        $limit = (int) $request->input('limit', 30);
        $offset = (int) $request->input('offset', 0);
        if ($offset === 0) {
            $this->chat->markRead($c, Message::SENDER_DELIVERY_BOY);
        }
        $page = $this->chat->pagedMessages($c, $limit, $offset);
        return CommonHelper::responseWithData([
            'conversation' => $this->chat->shapeConversation($c, Message::SENDER_DELIVERY_BOY),
            'messages'     => $page['messages'],
        ], $page['total']);
    }

    public function deliveryBoyUnreadCount(Request $request)
    {
        $dbId = $this->deliveryBoyId();
        if (!$dbId) {
            return CommonHelper::responseError('unauthorized_access_delivery_boy_role_required');
        }
        return CommonHelper::responseWithData([
            'count'           => $this->chat->unreadConversationCount(Message::SENDER_DELIVERY_BOY, $dbId),
            'delivery_boy_id' => $dbId,
        ]);
    }

    public function deliveryBoyMarkRead(Request $request)
    {
        $dbId = $this->deliveryBoyId();
        $c = Conversation::find($request->input('conversation_id'));
        if (!$c || (int) $c->delivery_boy_id !== (int) $dbId) {
            return CommonHelper::responseError('conversation_not_found');
        }
        $this->chat->markRead($c, Message::SENDER_DELIVERY_BOY);
        return CommonHelper::responseWithData(['done' => true]);
    }

    public function deliveryBoySend(Request $request)
    {
        $validator = Validator::make($request->all(), ChatService::sendRules());
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $dbId = $this->deliveryBoyId();
        $c = Conversation::find($request->conversation_id);
        if (!$c || (int) $c->delivery_boy_id !== (int) $dbId) {
            return CommonHelper::responseError('conversation_not_found');
        }
        return $this->dispatchMessages($request, $c, Message::SENDER_DELIVERY_BOY, (int) $dbId);
    }
}
