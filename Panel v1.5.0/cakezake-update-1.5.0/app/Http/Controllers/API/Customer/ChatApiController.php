<?php

namespace App\Http\Controllers\API\Customer;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\Order;
use App\Models\OrderItem;
use App\Services\ChatService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * Customer chat: a general thread with admin/support, plus order-scoped threads
 * with the delivery boy assigned to each of the customer's orders.
 */
class ChatApiController extends Controller
{
    protected ChatService $chat;

    public function __construct(ChatService $chat)
    {
        $this->chat = $chat;
    }

    private function userId(): int
    {
        return (int) auth()->id();
    }

    private function requestZoneId(Request $request): ?int
    {
        $lat = $request->input('latitude');
        $lng = $request->input('longitude');
        if (!is_numeric($lat) || !is_numeric($lng)) {
            return null;
        }

        // A location may sit in a quick zone, an ecommerce zone, or both.
        foreach (['quick', 'ecommerce'] as $channel) {
            $zone = CommonHelper::getDeliverableCity((float) $lat, (float) $lng, $channel);
            if ($zone) {
                return (int) $zone->id;
            }
        }

        return null;
    }

    /** Open (or create) the support (admin) conversation. */
    public function startAdmin(Request $request)
    {
        $c = $this->chat->adminCustomer($this->userId());
        return CommonHelper::responseWithData($this->chat->shapeConversation($c, Message::SENDER_CUSTOMER));
    }

    /** Open (or create) the order's delivery-boy conversation. */
    public function startOrderDeliveryBoy(Request $request)
    {
        $validator = Validator::make($request->all(), ['order_id' => 'required|integer']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $order = Order::where('id', $request->order_id)->where('user_id', $this->userId())->first();
        if (!$order) {
            return CommonHelper::responseError('order_not_found');
        }

        // Ecommerce assigns delivery boys per item → resolve the boy from the given item.
        // Quick keeps the order-level flow unchanged.
        $deliveryBoyId = null;
        if ($order->channel === 'ecommerce') {
            $v2 = Validator::make($request->all(), ['order_item_id' => 'required|integer']);
            if ($v2->fails()) {
                return CommonHelper::responseError($v2->errors()->first());
            }
            $item = OrderItem::where('id', $request->order_item_id)->where('order_id', $order->id)->first();
            if (!$item) {
                return CommonHelper::responseError('order_item_not_found');
            }
            if (!$item->delivery_boy_id) {
                return CommonHelper::responseError('delivery_boy_not_assigned_yet');
            }
            $deliveryBoyId = (int) $item->delivery_boy_id;
        }

        $c = $this->chat->orderConversation($order, $deliveryBoyId);
        if (!$c) {
            return CommonHelper::responseError('delivery_boy_not_assigned_yet');
        }
        return CommonHelper::responseWithData($this->chat->shapeConversation($c, Message::SENDER_CUSTOMER));
    }

    /** Open (or create) the order's admin conversation (customer <-> admin about an order). */
    public function startOrderAdmin(Request $request)
    {
        $validator = Validator::make($request->all(), ['order_id' => 'required|integer']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $order = Order::where('id', $request->order_id)->where('user_id', $this->userId())->first();
        if (!$order) {
            return CommonHelper::responseError('order_not_found');
        }
        $c = $this->chat->orderAdminConversation($order);
        if (!$c) {
            return CommonHelper::responseError('order_not_found');
        }
        return CommonHelper::responseWithData($this->chat->shapeConversation($c, Message::SENDER_CUSTOMER));
    }

    public function messages(Request $request)
    {
        $c = Conversation::find($request->input('conversation_id'));
        if (!$c || (int) $c->user_id !== $this->userId()) {
            return CommonHelper::responseError('conversation_not_found');
        }
        $limit = (int) $request->input('limit', 30);
        $offset = (int) $request->input('offset', 0);
        if ($offset === 0) {
            $this->chat->markRead($c, Message::SENDER_CUSTOMER);
        }
        $page = $this->chat->pagedMessages($c, $limit, $offset);
        return CommonHelper::responseWithData([
            'conversation' => $this->chat->shapeConversation($c, Message::SENDER_CUSTOMER),
            'messages'     => $page['messages'],
        ], $page['total']);
    }

    public function markRead(Request $request)
    {
        $c = Conversation::find($request->input('conversation_id'));
        if (!$c || (int) $c->user_id !== $this->userId()) {
            return CommonHelper::responseError('conversation_not_found');
        }
        $this->chat->markRead($c, Message::SENDER_CUSTOMER);
        return CommonHelper::responseWithData(['done' => true]);
    }

    public function send(Request $request)
    {
        $validator = Validator::make($request->all(), ChatService::sendRules());
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $c = Conversation::find($request->conversation_id);
        if (!$c || (int) $c->user_id !== $this->userId()) {
            return CommonHelper::responseError('conversation_not_found');
        }
        $text = trim((string) $request->input('message', ''));
        $paths = ChatService::collectAttachments($request);
        if ($text === '' && empty($paths)) {
            return CommonHelper::responseError('message_or_image_required');
        }

        $zoneId = $this->requestZoneId($request);

        $out = [];
        foreach ($paths as $p) {
            $out[] = $this->chat->shapeMessage($this->chat->postMessage($c, Message::SENDER_CUSTOMER, $this->userId(), null, $p, $zoneId));
        }
        if ($text !== '') {
            $out[] = $this->chat->shapeMessage($this->chat->postMessage($c, Message::SENDER_CUSTOMER, $this->userId(), $text, null, $zoneId));
        }
        return CommonHelper::responseWithData($out);
    }
}
