<?php

namespace App\Jobs;

use App\Helpers\CommonHelper;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusList;
use App\Models\ReturnRequest;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * Credits an ecommerce order's promo cashback once the return window has passed —
 * but only if nothing was returned. If any item was returned (or a return request
 * exists), the cashback is forfeited.
 */
class ProcessOrderCashbackAfterReturnPeriod implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $orderId;

    public function __construct(int $orderId)
    {
        $this->orderId = $orderId;
    }

    public function handle()
    {
        $order = Order::find($this->orderId);
        if (!$order) {
            return;
        }
        if ((int) $order->active_status !== OrderStatusList::$delivered) {
            return;
        }
        if ((float) $order->cashback_amount <= 0 || (int) $order->cashback_credited === 1) {
            return;
        }

        // Any return or cancellation forfeits the cashback (the order is no longer the
        // one the promo was earned on).
        $forfeited = OrderItem::where('order_id', $order->id)
                ->whereIn('active_status', [OrderStatusList::$returned, OrderStatusList::$cancelled])->exists()
            || ReturnRequest::where('order_id', $order->id)->exists();
        if ($forfeited) {
            return;
        }

        CommonHelper::creditOrderCashback($order);
    }
}
