<?php

namespace App\Jobs;

use App\Helpers\CommonHelper;
use App\Helpers\AddonHelper;
use App\Helpers\ProductHelper;
use App\Services\TaxService;
use App\Models\Cart;
use App\Models\DeliveryBoy;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Sends an admin-composed promotional email to many recipients in the background.
 * SMTP is the slowest channel we have (~1s+ per mail): sending to the whole customer
 * base inline would hold the admin request open for minutes and then time out.
 *
 * Recipients (resolved at RUN time, so profile-edited emails and new signups are
 * included, deleted accounts skipped):
 *  - user: active customers who HAVE an email — regardless of how they registered
 *    (phone signups can add an email in their profile later)
 *  - delivery_boy: active delivery boys; their login email lives on the linked admin
 *  - cart: active customers with at least one item still in their cart. The
 *    [Cart Products] placeholder is rendered per recipient with THEIR cart lines.
 *
 * $ids = null means "all" of the chosen recipient type.
 */
class SendBulkPromotionalEmailJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $timeout = 3600;
    public $tries = 1;

    /** Token the admin drops into the message; replaced with that customer's cart. */
    public const CART_PLACEHOLDER = '[Cart Products]';

    private string $recipientType; // user | delivery_boy | cart
    private ?array $ids;
    private string $title;
    private string $message;
    private ?string $imagePath;

    public function __construct(string $recipientType, ?array $ids, string $title, string $message, ?string $imagePath = null)
    {
        $this->recipientType = $recipientType;
        $this->ids = $ids;
        $this->title = $title;
        $this->message = $message;
        $this->imagePath = $imagePath;
    }

    public function handle(): void
    {
        $appName = Setting::get_value('app_name') ?? '';
        $supportEmail = Setting::get_value('smtp_from_mail') ?? '';
        $attachment = $this->imagePath ? storage_path('app/public/' . $this->imagePath) : null;

        $query = $this->recipientQuery();

        $query->chunk(200, function ($recipients) use ($appName, $supportEmail, $attachment) {
            foreach ($recipients as $r) {
                if (empty($r->email)) {
                    continue;
                }
                $replacements = [$r->name, $r->email, $appName, $supportEmail];
                $placeholders = ['[Customer Name]', '[Customer Email]', '[App Name]', '[Support Email]'];

                $subject = str_replace($placeholders, $replacements, $this->title);
                $message = str_replace($placeholders, $replacements, $this->message);

                if (str_contains($message, self::CART_PLACEHOLDER)) {
                    $message = str_replace(self::CART_PLACEHOLDER, $this->cartTable((int) $r->id), $message);
                }

                $data = [
                    'name' => $r->name,
                    'content' => $message,
                    'type' => 'promotional_mail',
                    'attachment' => $attachment,
                ];

                try {
                    CommonHelper::sendMail($r->email, $subject, $data);
                } catch (\Throwable $e) {
                    Log::error("Error sending promotional email to {$r->email}: " . $e->getMessage());
                }
            }
        });
    }

    /**
     * That customer's cart rendered as an e-mail-safe HTML table (inline styles and
     * a plain table layout — mail clients strip <style> blocks and ignore flex/grid).
     *
     * Price is per-branch: a variant costs what the fulfilling branch charges, so the
     * line joins product_variant_branch_stocks on variant + branch, and the currency
     * comes from that branch's country.
     */
    private function cartTable(int $userId): string
    {
        $lines = Cart::query()
            ->join('products as p', 'carts.product_id', '=', 'p.id')
            ->join('product_variants as v', 'carts.product_variant_id', '=', 'v.id')
            ->leftJoin('product_variant_branch_stocks as pvss', function ($j) {
                $j->on('pvss.product_variant_id', '=', 'carts.product_variant_id')
                    ->on('pvss.branch_id', '=', 'carts.branch_id');
            })
            ->leftJoin('branches as s', 'carts.branch_id', '=', 's.id')
            ->leftJoin('zones as z', 's.zone_id', '=', 'z.id')
            ->leftJoin('countries as c', 'z.country_id', '=', 'c.id')
            ->where('carts.user_id', $userId)
            ->orderBy('carts.id')
            ->get([
                'carts.qty',
                'carts.product_id',
                'carts.branch_id',
                'carts.addons',
                'v.name as variant_name',
                'v.image as variant_image',
                'p.name as product_name',
                'p.image as product_image',
                'pvss.price',
                'pvss.discounted_price',
                'pvss.pricing_slabs',
                'pvss.is_tax_inclusive',
                'c.currency',
            ]);

        if ($lines->isEmpty()) {
            return '';
        }

        $fallbackCurrency = Setting::get_value('currency') ?: '';
        $rows = '';
        $total = 0.0;

        TaxService::warmFor(
            $lines->pluck('product_id')->map(fn ($v) => (int) $v)->all(),
            $lines->pluck('branch_id')->map(fn ($v) => (int) $v)->all()
        );

        foreach ($lines as $l) {
            $qty = max(1, (int) $l->qty);
            $unit = (float) ProductHelper::lineUnitPrice($l, $qty, AddonHelper::unit(
                AddonHelper::parse($l->addons), $l->branch_id ? (int) $l->branch_id : null
            ));
            $rate = TaxService::rateForProduct(
                (int) $l->product_id,
                $l->branch_id ? (int) $l->branch_id : null
            );
            $lineTotal = TaxService::applyTax($unit, $rate, (bool) $l->is_tax_inclusive) * $qty;
            $total += $lineTotal;

            $currency = $l->currency ?: $fallbackCurrency;
            $image = $l->variant_image ?: $l->product_image;
            $imageUrl = $image ? asset('storage/' . $image) : '';
            $name = e($l->variant_name ?: $l->product_name);

            $thumb = $imageUrl !== ''
                ? '<img src="' . e($imageUrl) . '" width="56" height="56" alt="" style="width:56px;height:56px;object-fit:cover;border-radius:6px;display:block;">'
                : '';

            $rows .= '<tr>'
                . '<td style="padding:10px 8px;border-bottom:1px solid #eceff4;width:64px;">' . $thumb . '</td>'
                . '<td style="padding:10px 8px;border-bottom:1px solid #eceff4;font-size:14px;color:#2b3445;">' . $name . '</td>'
                . '<td style="padding:10px 8px;border-bottom:1px solid #eceff4;font-size:14px;color:#5b6473;text-align:center;">x' . $qty . '</td>'
                . '<td style="padding:10px 8px;border-bottom:1px solid #eceff4;font-size:14px;color:#2b3445;text-align:right;white-space:nowrap;">'
                . e($currency) . number_format($lineTotal, 2) . '</td>'
                . '</tr>';
        }

        $currency = $lines->first()->currency ?: $fallbackCurrency;

        return '<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" '
            . 'style="border-collapse:collapse;margin:12px 0;">'
            . '<tbody>' . $rows . '</tbody>'
            . '<tfoot><tr>'
            . '<td colspan="3" style="padding:10px 8px;font-size:14px;font-weight:bold;color:#2b3445;">' . e(__('total')) . '</td>'
            . '<td style="padding:10px 8px;font-size:14px;font-weight:bold;color:#2b3445;text-align:right;white-space:nowrap;">'
            . e($currency) . number_format($total, 2) . '</td>'
            . '</tr></tfoot>'
            . '</table>';
    }

    /** Rows exposing ->name and ->email for the chosen recipient type. */
    private function recipientQuery()
    {
        if ($this->recipientType === 'delivery_boy') {
            // A boy's login email is on the linked admin account.
            return DeliveryBoy::query()
                ->join('admins', 'admins.id', '=', 'delivery_boys.admin_id')
                ->where('delivery_boys.status', 1)
                ->whereNotNull('admins.email')
                ->where('admins.email', '!=', '')
                ->when($this->ids !== null, fn ($q) => $q->whereIn('delivery_boys.id', $this->ids))
                ->orderBy('delivery_boys.id')
                ->select(['delivery_boys.id', 'delivery_boys.name', 'admins.email']);
        }

        if ($this->recipientType === 'cart') {
            return User::query()
                ->where('status', 1)
                ->whereNotNull('email')
                ->where('email', '!=', '')
                ->whereExists(fn ($q) => $q->selectRaw('1')->from('carts')->whereColumn('carts.user_id', 'users.id'))
                ->when($this->ids !== null, fn ($q) => $q->whereIn('id', $this->ids))
                ->orderBy('id')
                ->select(['id', 'name', 'email']);
        }

        // Customers: anyone ACTIVE with an email, whatever their signup type —
        // filtering on login type (email/gmail/apple) silently skipped google- and
        // phone-registered accounts that added an email later.
        return User::query()
            ->where('status', 1)
            ->whereNotNull('email')
            ->where('email', '!=', '')
            ->when($this->ids !== null, fn ($q) => $q->whereIn('id', $this->ids))
            ->orderBy('id')
            ->select(['id', 'name', 'email']);
    }
}
