<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Maintenance mode toggled for a surface (web | customer | delivery_boy).
 * Broadcast on a PUBLIC channel so unauthenticated web/app clients can react
 * live without an auth handshake.
 */
class MaintenanceToggled implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public string $surface;
    public int $mode;
    public array $remark;

    public function __construct(string $surface, int $mode, array $remark = [])
    {
        $this->surface = $surface;
        $this->mode = $mode;
        $this->remark = $remark;
    }

    public function broadcastOn(): array
    {
        // Public channel — no channels.php auth entry needed.
        return [new Channel('maintenance')];
    }

    public function broadcastAs(): string
    {
        return 'maintenance.toggled';
    }

    public function broadcastWith(): array
    {
        return [
            'surface' => $this->surface,
            'mode'    => $this->mode,
            'remark'  => $this->remark,
        ];
    }
}
