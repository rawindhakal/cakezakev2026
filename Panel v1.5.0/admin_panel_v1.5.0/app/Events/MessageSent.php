<?php

namespace App\Events;

use App\Models\Conversation;
use App\Models\Message;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageSent implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public Message $message;
    public array $payload;
    public ?Conversation $conversation;

    public function __construct(Message $message, array $payload, ?Conversation $conversation = null)
    {
        $this->message = $message;
        $this->payload = $payload;
        $this->conversation = $conversation;
    }

    public function broadcastOn(): array
    {
        // Conversation channel (open thread) + the recipient's inbox channel (sidebar badge).
        $channels = [new PrivateChannel('chat.conversation.' . $this->message->conversation_id)];

        $c = $this->conversation;
        $sender = $this->message->sender_type;
        if (!$c) {
            return $channels;
        }

        $toPanel = function () use (&$channels) {
            $channels[] = new PrivateChannel('chat.admins');
        };

        if ($c->type === Conversation::TYPE_ADMIN_CUSTOMER) {
            $sender === Message::SENDER_CUSTOMER
                ? $toPanel()
                : $channels[] = new PrivateChannel('chat.user.' . $c->user_id);
        } elseif ($c->type === Conversation::TYPE_ORDER_ADMIN) {
            $sender === Message::SENDER_CUSTOMER
                ? $toPanel()
                : $channels[] = new PrivateChannel('chat.user.' . $c->user_id);
        } elseif ($c->type === Conversation::TYPE_ADMIN_DELIVERY_BOY) {
            $sender === Message::SENDER_DELIVERY_BOY
                ? $toPanel()
                : $channels[] = new PrivateChannel('chat.delivery_boy.' . $c->delivery_boy_id);
        } elseif ($c->type === Conversation::TYPE_DELIVERY_BOY_CUSTOMER) {
            $sender === Message::SENDER_CUSTOMER
                ? $channels[] = new PrivateChannel('chat.delivery_boy.' . $c->delivery_boy_id)
                : $channels[] = new PrivateChannel('chat.user.' . $c->user_id);
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'message.sent';
    }

    public function broadcastWith(): array
    {
        return $this->payload;
    }
}
