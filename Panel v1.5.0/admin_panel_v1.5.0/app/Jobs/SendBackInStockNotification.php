<?php

namespace App\Jobs;

use App\Helpers\CommonHelper;
use App\Models\Notification;
use App\Models\ProductStockAlert;
use App\Models\ProductVariant;
use App\Models\ProductVariantBranchStock;
use App\Models\Setting;
use App\Models\Branch;
use App\Models\User;
use App\Models\UserToken;
use App\Services\NotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Tells the customers waiting on a variant that it is orderable again.
 *
 * Runs off the request: the stock write that fired it (a cancel, a stock edit, an
 * import) must not wait on mail, SMS and FCM. Everything is re-read here from the
 * variant + branch ids, and the stock is checked again before anything is sent — a job
 * that sat in the queue while the last unit sold must say nothing.
 *
 * Zone-scoped by design: the branch that came back in stock serves one zone, and only
 * alerts raised from that zone are settled. Everyone else keeps waiting for their own
 * branch. Inactive accounts are skipped and left waiting.
 */
class SendBackInStockNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $tries = 3;

    public $backoff = 60;

    public function __construct(private int $variantId, private int $branchId)
    {
    }

    public function handle(): void
    {
        $branch = Branch::find($this->branchId);
        $variant = ProductVariant::with('product')->find($this->variantId);
        if (!$branch || !$variant || !$variant->product) {
            return;
        }

        $row = ProductVariantBranchStock::where('product_variant_id', $this->variantId)
            ->where('branch_id', $this->branchId)
            ->first();
        if (!$row || (int) $row->is_listed !== 1) {
            return;
        }
        $inStock = (int) $row->is_unlimited_stock === 1
            || ((int) $row->stock_status === 1 && (int) $row->available > 0);
        if (!$inStock) {
            return;
        }

        $alerts = ProductStockAlert::waiting()
            ->where('product_variant_id', $this->variantId)
            ->where('zone_id', (int) $branch->zone_id)
            ->get();
        if ($alerts->isEmpty()) {
            return;
        }

        // Variant names usually repeat the product name ("Masoor Dal - 500g"); the
        // templates print both, so hand them the distinguishing part only.
        $productName = trim((string) $variant->product->name);
        $variantName = trim((string) $variant->name);
        if ($productName !== '' && stripos($variantName, $productName) === 0) {
            $variantName = trim(ltrim(substr($variantName, strlen($productName)), " -–:/|"));
        }

        $country = $branch->zone?->country;
        $currency = CommonHelper::countryCurrency($country);
        $price = (float) ($row->discounted_price > 0 ? $row->discounted_price : ($row->price ?? $variant->discounted_price ?: $variant->price));
        $appName = Setting::get_value('app_name');

        foreach ($alerts as $alert) {
            $user = User::find($alert->user_id);
            // An inactive account is skipped, not settled: if it is reactivated the
            // alert is still there for the next restock.
            if (!$user || (int) $user->status !== 1) {
                continue;
            }

            $placeholders = [
                'app_name'      => $appName,
                'customer_name' => $user->name ?? '',
                'product_name'  => $productName,
                'variant_name'  => $variantName,
                'price'         => CommonHelper::doubleNumber($price),
                'currency'      => $currency['currency'] ?? '',
            ];

            try {
                NotificationService::dispatch('customer', (int) $user->id, 'back_in_stock', [
                    'email'       => $user->email,
                    'phone'       => $user->mobile ? trim(($user->country_code ?? '') . $user->mobile) : null,
                    'tokens'      => UserToken::where('user_id', $user->id)->where('type', 'customer')->get(),
                    'language_id' => $user->language_id,
                ], $placeholders, [
                    'payloadType' => 'product',
                    'payloadId'   => $variant->product_id,
                    'payloadSlug' => $variant->product->slug ?? null,
                ]);

                $bell = new Notification();
                $bell->type = 'user';
                $bell->type_id = (int) $user->id;
                $bell->type_link = '';
                $bell->title = __('back_in_stock');
                $bell->message = __('back_in_stock_message', [
                    'product' => trim($placeholders['product_name'] . ' ' . $placeholders['variant_name']),
                ]);
                $bell->image = $variant->image ?: ($variant->product->image ?? '');
                $bell->date_sent = now();
                $bell->save();
            } catch (\Throwable $e) {
                Log::error('back in stock notify failed for alert #' . $alert->id . ': ' . $e->getMessage());
                continue;
            }

            $alert->status = ProductStockAlert::STATUS_NOTIFIED;
            $alert->notified_at = now();
            $alert->save();
        }
    }
}
