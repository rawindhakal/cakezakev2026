<?php

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * A new order was placed / became payable. Broadcast to the admin orders channel
 * so the Orders page can surface it live without a manual reload.
 */
class OrderPlaced implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public Order $order;

    public function __construct(Order $order)
    {
        $this->order = $order;
    }

    public function broadcastOn(): array
    {
        return [new PrivateChannel('admin.orders')];
    }

    public function broadcastAs(): string
    {
        return 'order.placed';
    }

    public function broadcastWith(): array
    {
        // Minimal — the page refetches (server-side filtered) on receipt.
        return [
            'order_id'   => $this->order->id,
            'channel'    => $this->order->channel,
            'country_id' => $this->order->country_id,
            'zone_id'    => $this->order->zone_id,
        ];
    }
}
