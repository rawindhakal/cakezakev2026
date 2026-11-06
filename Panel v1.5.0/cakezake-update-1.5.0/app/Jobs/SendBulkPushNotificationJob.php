<?php

namespace App\Jobs;

use App\Helpers\FirebaseHelper;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Sends an admin-composed push notification to a (possibly large) token list in the
 * background, so the admin panel's "send notification" request returns instantly
 * instead of blocking on thousands of FCM calls.
 *
 * Carries token IDs — not tokens — and re-reads rows per chunk: stale/deleted tokens
 * are skipped naturally and FirebaseHelper::sendBulk can still prune invalid ones
 * via the model class.
 */
class SendBulkPushNotificationJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    private const CHUNK = 500;

    public $timeout = 1800;
    public $tries = 1;

    private array $tokenIds;
    private string $tokenModelClass;
    private array $fcmMsg;
    private array $notification;

    public function __construct(array $tokenIds, string $tokenModelClass, array $fcmMsg, array $notification)
    {
        $this->tokenIds = $tokenIds;
        $this->tokenModelClass = $tokenModelClass;
        $this->fcmMsg = $fcmMsg;
        $this->notification = $notification;
    }

    public function handle(): void
    {
        $model = $this->tokenModelClass;

        foreach (array_chunk($this->tokenIds, self::CHUNK) as $chunk) {
            $rows = $model::whereIn('id', $chunk)->get();
            if ($rows->isEmpty()) {
                continue;
            }
            try {
                FirebaseHelper::sendBulk($rows, $this->fcmMsg, $model);
            } catch (\Throwable $e) {
                // One bad chunk must not kill the rest of the broadcast.
                Log::error('Bulk push chunk failed: ' . $e->getMessage());
            }
        }
    }
}
