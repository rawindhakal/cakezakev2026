<?php

namespace App\Services;

use App\Helpers\CommonHelper;
use App\Helpers\SmsHelper;
use App\Models\Language;
use App\Models\NotificationAdminSetting;
use App\Models\NotificationPreference;
use Illuminate\Support\Facades\Log;

/**
 * Central authority for the notification catalog + the two-tier gate
 * (admin master switch → recipient preference, default ON).
 *
 * Order/return status events are per-status but several share ONE underlying
 * template per channel (Option C): the per-status split exists only so admin and
 * recipients can toggle each status; templateType() collapses them to the real
 * template row.
 */
class NotificationService
{
    /** @var array<string,mixed>|null memoized catalog */
    private static ?array $catalog = null;

    /**
     * The notification catalog — single declarative source of every event with its
     * audience, category, default channels and full placeholder set. (Was
     * config/notifications.php; merged here so the data lives with its logic.)
     *
     * Order/return status events are per-status but share one template per channel
     * (see templateType()) — the split exists only so each status can be toggled.
     */
    public static function catalog(): array
    {
        if (self::$catalog !== null) {
            return self::$catalog;
        }

        $orderStatuses = [
            1 => 'payment_pending', 2 => 'received', 3 => 'processed', 4 => 'shipped',
            5 => 'out_for_delivery', 6 => 'delivered', 7 => 'cancelled', 8 => 'returned',
            9 => 'preparing', 10 => 'ready_for_pickup', 11 => 'picked_up',
        ];
        $returnStatuses = [
            1 => 'return_requested', 2 => 'accepted', 3 => 'rejected', 4 => 'delivery_boy_assigned',
            5 => 'out_for_pickup', 6 => 'received_from_customer', 7 => 'return_to_branch', 8 => 'refund_completed',
        ];
        $returnDbStatuses = ['delivery_boy_assigned', 'out_for_pickup', 'received_from_customer', 'return_to_branch'];

        // Full placeholder sets = every key the send site provides.
        // {order_items_html} is available on every customer order-status mail (the
        // send always provides it); default wording only uses it for received/delivered.
        // branch_name / branch_address: where a self-pickup order is collected (set for every order).
        $orderPhCustomer = ['{app_name}', '{customer_name}', '{order_id}', '{status_name}', '{final_total}', '{currency}', '{created_at}', '{order_items_html}', '{branch_name}', '{branch_address}'];
        $orderPhDb       = ['{app_name}', '{delivery_boy_name}', '{order_id}', '{status_name}', '{product_name}'];
        $orderPhAdmin    = ['{app_name}', '{admin_name}', '{order_id}', '{status_name}', '{product_name}'];

        // Standard default channel sets. sms starts OFF everywhere; admins get no sms.
        $recipientCh = ['mail' => true, 'sms' => false, 'push' => true];
        $adminCh     = ['mail' => true, 'push' => false];
        $events = [];

        // Orders: order status (per status × audience)
        foreach ($orderStatuses as $slug) {
            $key = 'order_status_' . $slug;
            $events[] = ['key' => $key, 'audience' => 'customer', 'category' => 'Orders',
                'channels' => $recipientCh, 'placeholders' => $orderPhCustomer];
            $events[] = ['key' => $key, 'audience' => 'delivery_boy', 'category' => 'Orders',
                'channels' => $recipientCh, 'placeholders' => $orderPhDb];
            $events[] = ['key' => $key, 'audience' => 'admin', 'category' => 'Orders',
                'channels' => $adminCh, 'placeholders' => $orderPhAdmin];
        }

        // Orders: assignment
        $events[] = ['key' => 'assign_order', 'audience' => 'customer', 'category' => 'Orders',
            'channels' => $recipientCh, 'placeholders' => ['{app_name}', '{customer_name}', '{order_id}', '{delivery_boy_name}']];
        $events[] = ['key' => 'assign_order', 'audience' => 'delivery_boy', 'category' => 'Orders',
            'channels' => $recipientCh, 'placeholders' => ['{app_name}', '{delivery_boy_name}', '{order_id}', '{redirect_url}']];

        // Orders: payment failed (order auto-cancelled by the gateway webhook)
        $events[] = ['key' => 'payment_failed', 'audience' => 'customer', 'category' => 'Orders',
            'channels' => $recipientCh, 'placeholders' => ['{app_name}', '{customer_name}', '{order_id}', '{amount}', '{currency}']];

        /* Order items: the promised delivery date moved. */
        $events[] = ['key' => 'order_item_delivery_estimate', 'audience' => 'customer', 'category' => 'Order Items',
            'channels' => $recipientCh,
            'placeholders' => ['{app_name}', '{customer_name}', '{order_id}', '{order_item_id}', '{product_name}',
                '{quantity}', '{estimated_delivery_date}', '{previous_delivery_date}', '{currency}', '{final_total}']];

        // Order items (customer)
        foreach (['order_item_status', 'order_item_cancelled', 'order_item_returned'] as $k) {
            $events[] = ['key' => $k, 'audience' => 'customer', 'category' => 'Order Items',
                'channels' => $recipientCh, 'placeholders' => ['{app_name}', '{customer_name}', '{order_id}', '{order_item_id}', '{product_name}', '{quantity}', '{status_name}', '{currency}', '{final_total}']];
        }

        // Returns: return status (per status)
        $returnPhCustomer = ['{app_name}', '{customer_name}', '{return_request_id}', '{order_id}', '{status_name}', '{support_email}'];
        $returnPhDb       = ['{app_name}', '{delivery_boy_name}', '{return_request_id}', '{order_id}', '{status_name}'];
        foreach ($returnStatuses as $slug) {
            $key = 'return_status_' . $slug;
            $events[] = ['key' => $key, 'audience' => 'customer', 'category' => 'Returns',
                'channels' => $recipientCh, 'placeholders' => $returnPhCustomer];
            if (in_array($slug, $returnDbStatuses, true)) {
                $events[] = ['key' => $key, 'audience' => 'delivery_boy', 'category' => 'Returns',
                    'channels' => $recipientCh, 'placeholders' => $returnPhDb];
            }
        }

        $events[] = ['key' => 'return_request_new', 'audience' => 'admin', 'category' => 'Returns',
            'channels' => ['mail' => false, 'push' => true],
            'placeholders' => ['{app_name}', '{return_request_id}', '{order_id}', '{status_name}']];

        // Wallet (customer + delivery boy)
        $walletPh = ['{app_name}', '{customer_name}', '{amount}', '{currency}', '{balance}', '{order_id}', '{product_name}', '{message}', '{txn_id}'];
        foreach (['wallet_recharged', 'wallet_cashback', 'wallet_referral_bonus', 'wallet_admin_credit', 'wallet_refund_cancelled', 'wallet_refund_returned'] as $k) {
            $events[] = ['key' => $k, 'audience' => 'customer', 'category' => 'Wallet',
                'channels' => $recipientCh, 'placeholders' => $walletPh];
        }
        // Wallet recharge payment failed
        $events[] = ['key' => 'wallet_recharge_failed', 'audience' => 'customer', 'category' => 'Wallet',
            'channels' => $recipientCh, 'placeholders' => ['{app_name}', '{customer_name}', '{amount}', '{currency}']];
        foreach (['wallet_credited', 'wallet_debited'] as $k) {
            $events[] = ['key' => $k, 'audience' => 'delivery_boy', 'category' => 'Wallet',
                'channels' => $recipientCh, 'placeholders' => ['{app_name}', '{delivery_boy_name}', '{amount}', '{currency}', '{balance}', '{reason}']];
        }

        // Delivery boy salary payout
        $events[] = ['key' => 'salary_paid', 'audience' => 'delivery_boy', 'category' => 'Wallet',
            'channels' => $recipientCh, 'placeholders' => ['{app_name}', '{delivery_boy_name}', '{amount}', '{currency}', '{paid_on}', '{note}']];

        // Withdrawal
        $events[] = ['key' => 'withdrawal_request', 'audience' => 'admin', 'category' => 'Withdrawal',
            'channels' => ['mail' => true, 'push' => true], 'placeholders' => ['{app_name}', '{delivery_boy_name}', '{amount}', '{currency}', '{withdrawal_request_id}']];
        $events[] = ['key' => 'withdrawal_status', 'audience' => 'delivery_boy', 'category' => 'Withdrawal',
            'channels' => $recipientCh, 'placeholders' => ['{app_name}', '{delivery_boy_name}', '{amount}', '{currency}', '{status_name}', '{remark}', '{withdrawal_request_id}']];

        // Back in stock (customer): a variant they asked to be told about is orderable again.
        $events[] = ['key' => 'back_in_stock', 'audience' => 'customer', 'category' => 'Products',
            'channels' => $recipientCh,
            'placeholders' => ['{app_name}', '{customer_name}', '{product_name}', '{variant_name}', '{price}', '{currency}']];

        // App version update
        foreach (['customer' => '{customer_name}', 'delivery_boy' => '{delivery_boy_name}'] as $aud => $namePlaceholder) {
            $events[] = ['key' => 'app_version_update', 'audience' => $aud, 'category' => 'App',
                'channels' => $recipientCh,
                'placeholders' => ['{app_name}', $namePlaceholder, '{version}', '{platform}', '{store_url}']];
        }

        // Cart (customer)
        foreach (['cart_reminder_first', 'cart_reminder_interval'] as $k) {
            $events[] = ['key' => $k, 'audience' => 'customer', 'category' => 'Cart',
                'channels' => $recipientCh, 'placeholders' => ['{app_name}', '{product_name}']];
        }

        // Chat
        $chatPh = ['{app_name}', '{sender_name}', '{message}'];
        foreach (['customer', 'delivery_boy', 'admin'] as $aud) {
            $events[] = ['key' => 'chat_message', 'audience' => $aud, 'category' => 'Chat',
                'channels' => ['push' => true], 'placeholders' => $chatPh];
        }

        // Account — each channel matches the only place it's actually sent.
        $events[] = ['key' => 'otp', 'audience' => 'customer', 'category' => 'Account',
            'channels' => ['sms' => true], 'placeholders' => ['{app_name}', '{otp}']];
        $events[] = ['key' => 'verify_email', 'audience' => 'customer', 'category' => 'Account',
            'channels' => ['mail' => true], 'placeholders' => ['{app_name}', '{customer_name}', '{code}']];
        $events[] = ['key' => 'forgot_password', 'audience' => 'admin', 'category' => 'Account',
            'channels' => ['mail' => true], 'placeholders' => ['{app_name}', '{code}', '{reset_link}']];
        $events[] = ['key' => 'welcome', 'audience' => 'customer', 'category' => 'Account',
            'channels' => ['mail' => true, 'push' => true], 'placeholders' => ['{app_name}', '{customer_name}']];
        $events[] = ['key' => 'password_changed', 'audience' => 'customer', 'category' => 'Account',
            'channels' => ['mail' => true, 'push' => true], 'placeholders' => ['{app_name}', '{customer_name}']];
        // Account activate / deactivate — customer + delivery boy (replaces the
        // old email-only delivery_boy_status template with a gated multi-channel event).
        $events[] = ['key' => 'account_status', 'audience' => 'customer', 'category' => 'Account',
            'channels' => $recipientCh, 'placeholders' => ['{app_name}', '{customer_name}', '{status_name}']];
        $events[] = ['key' => 'account_status', 'audience' => 'delivery_boy', 'category' => 'Account',
            'channels' => $recipientCh, 'placeholders' => ['{app_name}', '{delivery_boy_name}', '{status_name}']];

        // Promotions (broadcast to customers)
        $events[] = ['key' => 'promo_code', 'audience' => 'customer', 'category' => 'Promotions',
            'channels' => $recipientCh, 'placeholders' => ['{app_name}', '{customer_name}', '{promo_code}', '{discount}', '{message}', '{expiry_date}']];
        $events[] = ['key' => 'new_blog', 'audience' => 'customer', 'category' => 'Promotions',
            'channels' => ['mail' => true, 'push' => true], 'placeholders' => ['{app_name}', '{customer_name}', '{blog_title}', '{blog_url}']];

        return self::$catalog = [
            'recipient_audiences' => ['customer', 'delivery_boy'],
            'order_statuses'      => $orderStatuses,
            'return_statuses'     => $returnStatuses,
            'categories'          => ['Orders', 'Order Items', 'Returns', 'Wallet', 'Withdrawal', 'Cart', 'Products', 'Chat', 'Account', 'App', 'Promotions'],
            'events'              => $events,
        ];
    }

    /** All catalog events (flat list). */
    public static function events(): array
    {
        return self::catalog()['events'];
    }

    public static function orderStatuses(): array
    {
        return self::catalog()['order_statuses'];
    }

    public static function returnStatuses(): array
    {
        return self::catalog()['return_statuses'];
    }

    public static function categories(): array
    {
        return self::catalog()['categories'];
    }

    /**
     * Translatable label for an event_key, read from the panel language files
     * (system_type 4). With a $langCode -> single string for that language; without
     * -> map of {code: label} across every active panel language (as other
     * multilang endpoints do). Falls back to a humanized key when untranslated.
     */
    public static function eventLabel(string $key, ?string $langCode = null)
    {
        if ($langCode !== null) {
            return self::labelInLang($key, $langCode);
        }
        $out = [];
        foreach (Language::where('system_type', 4)->where('status', 1)->get() as $lang) {
            $code = LanguageFileService::codeFor($lang);
            if ($code) {
                $out[$code] = self::labelInLang($key, $code);
            }
        }
        return $out ?: ['en' => self::labelInLang($key, 'en')];
    }

    /** Reverse map: template `type` -> [event_key, audience], built from the catalog. */
    public static function reverseTemplateMap(): array
    {
        static $map = null;
        if ($map !== null) {
            return $map;
        }
        $map = [];
        foreach (self::events() as $e) {
            $type = self::templateType($e['key'], $e['audience']);
            if ($type && !isset($map[$type])) {
                $map[$type] = [$e['key'], $e['audience']];
            }
        }
        return $map;
    }

    /**
     * Label for a template `type` — identical to the Notification Settings label
     * ("Event - Audience"), so listings/edit modals match. Humanized fallback for
     * types outside the catalog.
     */
    public static function templateLabel(string $type, ?string $langCode = null): string
    {
        $langCode = $langCode ?: app()->getLocale();
        $m = self::reverseTemplateMap();
        if (isset($m[$type])) {
            [$key, $audience] = $m[$type];
            return self::eventLabel($key, $langCode) . ' - ' . self::eventLabel($audience, $langCode);
        }
        // Non-catalog type (e.g. delivery_boy_status): still translate via lang key.
        return self::eventLabel($type, $langCode);
    }

    private static function labelInLang(string $key, string $code): string
    {
        static $cache = [];
        if (!array_key_exists($code, $cache)) {
            $cache[$code] = LanguageFileService::readArray(4, $code);
        }
        $v = $cache[$code][$key] ?? null;
        return ($v !== null && $v !== '') ? (string) $v : ucwords(str_replace('_', ' ', $key));
    }

    public static function userTypeForAudience(string $audience): int
    {
        return match ($audience) {
            'delivery_boy' => 3,
            'admin'        => 2,
            default        => 0, // customer
        };
    }

    /** OrderStatusList id -> event_key (order_status_<slug>). */
    public static function orderStatusEventKey(int $statusId): ?string
    {
        $slug = self::orderStatuses()[$statusId] ?? null;
        return $slug ? 'order_status_' . $slug : null;
    }

    /** ReturnStatusList id -> event_key (return_status_<slug>). */
    public static function returnStatusEventKey(int $statusId): ?string
    {
        $slug = self::returnStatuses()[$statusId] ?? null;
        return $slug ? 'return_status_' . $slug : null;
    }

    /** Events indexed by "event_key|audience" for O(1) lookups. */
    private static function eventIndex(): array
    {
        static $idx = null;
        if ($idx === null) {
            $idx = [];
            foreach (self::events() as $e) {
                $idx[$e['key'] . '|' . $e['audience']] = $e;
            }
        }
        return $idx;
    }

    /** Config default-enabled for an (event, audience, channel), pre-sync fallback. */
    public static function catalogDefault(string $eventKey, string $audience, string $channel): bool
    {
        $e = self::eventIndex()[$eventKey . '|' . $audience] ?? null;
        return $e ? (bool) ($e['channels'][$channel] ?? false) : false;
    }

    /** Does the catalog define this (event, audience) at all? */
    public static function catalogHas(string $eventKey, string $audience): bool
    {
        return isset(self::eventIndex()[$eventKey . '|' . $audience]);
    }

    /**
     * The two-tier gate. Returns true if a notification for
     * (audience, userId, eventKey, channel) should actually be sent.
     *
     * - Admin master OFF  -> false (hard gate).
     * - No recipient row  -> true  (default ON).
     * - Recipient row     -> its value.
     *
     * $userId null (e.g. admin audience) skips the preference tier.
     * Unknown events (not in catalog) -> true, so legacy sends never regress.
     */
    public static function allowed(string $audience, ?int $userId, string $eventKey, string $channel): bool
    {
        if (!self::catalogHas($eventKey, $audience)) {
            return true; // outside the managed catalog — don't block legacy sends
        }

        $adminEnabled = NotificationAdminSetting::where('event_key', $eventKey)
            ->where('audience', $audience)
            ->where('channel', $channel)
            ->value('is_enabled');

        if ($adminEnabled === null) {
            // Not synced yet — fall back to the catalog's default.
            $adminEnabled = self::catalogDefault($eventKey, $audience, $channel);
        }
        if (!$adminEnabled) {
            return false;
        }

        if ($userId === null) {
            return true;
        }

        $pref = NotificationPreference::where('user_type', self::userTypeForAudience($audience))
            ->where('user_id', $userId)
            ->where('event_key', $eventKey)
            ->where('channel', $channel)
            ->value('is_enabled');

        return $pref === null ? true : (bool) $pref;
    }

    /**
     * Canonical template `type` for an (event, audience): "<event_key>_<audience>".
     * ONE convention across every channel (mail/sms/push share the type string,
     * living in their own tables). $channel is accepted for signature stability but
     * no longer changes the result.
     */
    public static function templateType(string $eventKey, string $audience): ?string
    {
        return $eventKey . '_' . $audience;
    }

    /**
     * Push to the recipient's tokens if the (event, channel) is allowed.
     * $opts mirrors CommonHelper::sendNotificationByTemplate's tail params
     * (type, type_id, image, orderStatusId, returnStatusId, payloadType,
     * payloadId, payloadSlug, orderItemId).
     */
    public static function pushIfAllowed(string $audience, ?int $userId, string $eventKey, $tokens, array $placeholders, array $opts = []): void
    {
        if (!$tokens || (method_exists($tokens, 'isEmpty') && $tokens->isEmpty())) {
            return;
        }
        if (!self::allowed($audience, $userId, $eventKey, 'push')) {
            return;
        }
        CommonHelper::sendNotificationByTemplate(
            $tokens,
            self::templateType($eventKey, $audience),
            $placeholders,
            $opts['type'] ?? '',
            $opts['type_id'] ?? 0,
            $opts['image'] ?? '',
            $opts['orderStatusId'] ?? null,
            $opts['returnStatusId'] ?? null,
            $opts['payloadType'] ?? null,
            $opts['payloadId'] ?? null,
            $opts['payloadSlug'] ?? null,
            $opts['orderItemId'] ?? null
        );
    }

    /** SMS to the recipient's phone if the (event, channel) is allowed. */
    public static function smsIfAllowed(string $audience, ?int $userId, string $eventKey, ?string $phone, array $placeholders, $languageId = null): void
    {
        if (empty($phone)) {
            return;
        }
        if (!self::allowed($audience, $userId, $eventKey, 'sms')) {
            return;
        }
        SmsHelper::sendByTemplate($phone, self::templateType($eventKey, $audience), $placeholders, $languageId);
    }

    /** Email to the recipient's address if the (event, channel) is allowed. */
    public static function mailIfAllowed(string $audience, ?int $userId, string $eventKey, ?string $email, array $placeholders, $languageId = null): void
    {
        if (empty($email)) {
            return;
        }
        if (!self::allowed($audience, $userId, $eventKey, 'mail')) {
            return;
        }
        CommonHelper::sendMailByTemplate($email, self::templateType($eventKey, $audience), $placeholders, $languageId);
    }

    /**
     * Fire EVERY enabled channel of an event to one recipient. The send site just
     * provides the recipient's contact info; each channel is independently gated.
     *
     * In a web request the sends run after the response has gone out: SMTP, the SMS
     * gateway and FCM are each a network round trip, and together they held a delivery
     * boy's "delivered" tap for ~4s. From the console (queue workers, cron) there is
     * no response to wait for, so they run straight away.
     *
     * @param array $recipient ['email'=>?, 'phone'=>?, 'tokens'=>?collection, 'language_id'=>?]
     */
    public static function dispatch(string $audience, ?int $userId, string $eventKey, array $recipient, array $placeholders, array $pushOpts = []): void
    {
        $send = function () use ($audience, $userId, $eventKey, $recipient, $placeholders, $pushOpts) {
            try {
                $lang = $recipient['language_id'] ?? null;
                self::mailIfAllowed($audience, $userId, $eventKey, $recipient['email'] ?? null, $placeholders, $lang);
                self::smsIfAllowed($audience, $userId, $eventKey, $recipient['phone'] ?? null, $placeholders, $lang);
                self::pushIfAllowed($audience, $userId, $eventKey, $recipient['tokens'] ?? null, $placeholders, $pushOpts);
            } catch (\Throwable $e) {
                Log::error('NotificationService::dispatch ' . $eventKey . ': ' . $e->getMessage());
            }
        };

        if (app()->runningInConsole()) {
            $send();

            return;
        }

        app()->terminating($send);
    }

    /**
     * Reverse a canonical template `type` -> [event_key, audience]. Types are now
     * "<event_key>_<audience>", so this is just a catalog lookup. Null when unknown.
     */
    public static function eventFromTemplate(?string $type): ?array
    {
        return $type ? (self::reverseTemplateMap()[$type] ?? null) : null;
    }
}
