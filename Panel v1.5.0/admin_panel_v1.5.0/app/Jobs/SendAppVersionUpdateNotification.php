<?php

namespace App\Jobs;

use App\Models\Admin;
use App\Models\AdminToken;
use App\Models\DeliveryBoy;
use App\Models\Role;
use App\Models\Setting;
use App\Models\User;
use App\Models\UserToken;
use App\Services\NotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Tells an app's users that a newer build is on the store.
 *
 * Fired from App Settings, and only when the version string actually CHANGED and the
 * admin ticked the notify box on that card — the save endpoint, not this job, is where
 * that is decided, because only the request knows what the value was before it.
 *
 * Runs off the request because the audience is the whole user base: SMTP alone is ~1s
 * per mail, so the admin's Save must not wait on it.
 *
 * Platform-scoped, which is the whole reason this is not a plain broadcast. Only the
 * platforms whose version moved are passed in, and a recipient is reached only through
 * the tokens they actually registered on one of those platforms. An iOS-only customer is
 * never told to go and update on Play, and someone who has never opened the app is not
 * mailed at all.
 *
 * Each channel is still gated by NotificationService's two tiers (admin master switch →
 * the recipient's own preference), so a user who switched these off keeps them off.
 *
 * @param array<string,string> $versions platform => new version, e.g. ['android' => '1.4.2']
 */
class SendAppVersionUpdateNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $timeout = 3600;

    public $tries = 1;

    /** What the customer reads for {platform} — the store's name, not our column's. */
    private const PLATFORM_LABELS = ['android' => 'Android', 'ios' => 'iOS'];

    private const EVENT = 'app_version_update';

    public function __construct(private string $audience, private array $versions)
    {
    }

    public function handle(): void
    {
        $platforms = array_keys(array_filter($this->versions, fn ($v) => trim((string) $v) !== ''));
        if ($platforms === []) {
            return;
        }

        $appName = Setting::get_value('app_name');
        $storeUrls = $this->audience === 'delivery_boy'
            ? [
                'android' => Setting::get_value('delivery_boy_playstore_url'),
                'ios'     => Setting::get_value('delivery_boy_appstore_url'),
            ]
            : [
                'android' => Setting::get_value('playstore_url'),
                'ios'     => Setting::get_value('appstore_url'),
            ];

        if ($this->audience === 'delivery_boy') {
            $this->notifyDeliveryBoys($platforms, $appName, $storeUrls);

            return;
        }

        $this->notifyCustomers($platforms, $appName, $storeUrls);
    }

    private function notifyCustomers(array $platforms, string $appName, array $storeUrls): void
    {
        User::where('status', 1)
            ->whereExists(function ($q) use ($platforms) {
                $q->select(DB::raw(1))
                    ->from('user_tokens')
                    ->whereColumn('user_tokens.user_id', 'users.id')
                    ->where('user_tokens.type', 'customer')
                    ->whereIn('user_tokens.platform', $platforms);
            })
            ->select(['id', 'name', 'email', 'mobile', 'country_code', 'language_id'])
            ->chunkById(200, function ($users) use ($platforms, $appName, $storeUrls) {
                // One token query per chunk, not per user.
                $tokens = UserToken::where('type', 'customer')
                    ->whereIn('platform', $platforms)
                    ->whereIn('user_id', $users->pluck('id')->all())
                    ->get()
                    ->groupBy('user_id');

                foreach ($users as $user) {
                    $this->send(
                        (int) $user->id,
                        (string) ($user->name ?? ''),
                        $user->email,
                        $user->mobile ? trim(($user->country_code ?? '') . $user->mobile) : null,
                        $user->language_id,
                        $tokens->get($user->id) ?: collect(),
                        $appName,
                        $storeUrls
                    );
                }
            });
    }

    private function notifyDeliveryBoys(array $platforms, string $appName, array $storeUrls): void
    {
        DeliveryBoy::where('status', DeliveryBoy::$statusActive)
            ->whereNotNull('admin_id')
            ->whereExists(function ($q) use ($platforms) {
                $q->select(DB::raw(1))
                    ->from('admin_tokens')
                    ->whereColumn('admin_tokens.user_id', 'delivery_boys.admin_id')
                    ->where('admin_tokens.type', Role::$roleNameDeliveryBoy)
                    ->whereIn('admin_tokens.platform', $platforms);
            })
            ->select(['id', 'admin_id', 'name', 'mobile', 'country_code'])
            ->chunkById(200, function ($boys) use ($platforms, $appName, $storeUrls) {
                $adminIds = $boys->pluck('admin_id')->filter()->map(fn ($i) => (int) $i)->unique()->all();

                // A rider's login email lives on the linked admin row, not on the rider.
                $emails = Admin::whereIn('id', $adminIds)->pluck('email', 'id');
                $tokens = AdminToken::where('type', Role::$roleNameDeliveryBoy)
                    ->whereIn('platform', $platforms)
                    ->whereIn('user_id', $adminIds)
                    ->get()
                    ->groupBy('user_id');

                foreach ($boys as $boy) {
                    $adminId = (int) $boy->admin_id;
                    $boyTokens = $tokens->get($adminId) ?: collect();
                    // Neither `delivery_boys` nor `admins` carries a language, so the
                    // rider's app language is read off the device token that reported it.
                    $this->send(
                        $adminId,
                        (string) ($boy->name ?? ''),
                        $emails[$adminId] ?? null,
                        $boy->mobile ? trim(($boy->country_code ?? '') . $boy->mobile) : null,
                        optional($boyTokens->first())->language_id,
                        $boyTokens,
                        $appName,
                        $storeUrls
                    );
                }
            });
    }

    /**
     * One recipient, every enabled channel.
     *
     * Push goes per platform group, so a user on both stores is told the right version
     * for each device. Mail and SMS are sent ONCE — they are not platform-addressable,
     * and two emails about the same release reads as a bug.
     */
    private function send(
        int $userId,
        string $name,
        ?string $email,
        ?string $phone,
        $languageId,
        $tokens,
        string $appName,
        array $storeUrls
    ): void {
        try {
            $groups = $tokens->groupBy('platform');
            if ($groups->isEmpty()) {
                return;
            }

            foreach ($groups as $platform => $platformTokens) {
                $version = $this->versions[$platform] ?? null;
                if (!$version) {
                    continue;
                }
                NotificationService::pushIfAllowed(
                    $this->audience,
                    $userId,
                    self::EVENT,
                    $platformTokens,
                    $this->placeholders($name, (string) $platform, (string) $version, $appName, $storeUrls),
                    ['type' => 'app_version_update']
                );
            }

            // Prefer Android's numbers when someone is on both stores — arbitrary but
            // fixed, so the mail and the SMS always agree with each other.
            $primary = null;
            foreach (['android', 'ios'] as $candidate) {
                if ($groups->has($candidate) && !empty($this->versions[$candidate])) {
                    $primary = $candidate;
                    break;
                }
            }
            if ($primary === null) {
                return;
            }

            $placeholders = $this->placeholders($name, $primary, (string) $this->versions[$primary], $appName, $storeUrls);
            NotificationService::mailIfAllowed($this->audience, $userId, self::EVENT, $email, $placeholders, $languageId);
            NotificationService::smsIfAllowed($this->audience, $userId, self::EVENT, $phone, $placeholders, $languageId);
        } catch (\Throwable $e) {
            // One bad address must not stop the release announcement.
            Log::error('app version notify failed for ' . $this->audience . ' #' . $userId . ': ' . $e->getMessage());
        }
    }

    private function placeholders(string $name, string $platform, string $version, string $appName, array $storeUrls): array
    {
        $nameKey = $this->audience === 'delivery_boy' ? 'delivery_boy_name' : 'customer_name';

        return [
            'app_name'  => $appName,
            $nameKey    => $name,
            'version'   => $version,
            'platform'  => self::PLATFORM_LABELS[$platform] ?? ucfirst($platform),
            'store_url' => (string) ($storeUrls[$platform] ?? ''),
        ];
    }
}
