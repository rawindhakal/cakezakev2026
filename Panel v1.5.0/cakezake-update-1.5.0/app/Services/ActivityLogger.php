<?php

namespace App\Services;

use App\Helpers\CommonHelper;
use App\Models\ActivityLog;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Central writer for the audit trail.
 *
 * Everything funnels through here so redaction, causer resolution and request
 * context are applied identically no matter which event produced the entry.
 * Logging must never break the action being logged, so every write is wrapped:
 * a failed audit row is a logged warning, not a 500 for the admin.
 */
class ActivityLogger
{
    /** Never store these — credentials, tokens and other secrets. */
    private const REDACTED_KEYS = [
        'password', 'password_confirmation', 'current_password', 'remember_token',
        'api_key', 'secret', 'secret_key', 'token', 'access_token', 'refresh_token',
        'client_secret', 'private_key', 'smtp_email_password', 'text_gen_key',
        'razorpay_secret_key', 'stripe_secret_key', 'paystack_secret_key',
        'phonepe_salt_key', 'paypal_secret', 'fcm_token', 'otp',
    ];

    /** Noise: bookkeeping columns whose change carries no audit meaning. */
    private const IGNORED_KEYS = [
        'created_at', 'updated_at', 'deleted_at', 'remember_token',
        'email_verified_at', 'last_login_at',
    ];

    /** Values longer than this are truncated so one row can't store a blob. */
    private const MAX_VALUE_LENGTH = 500;

    /** Write an arbitrary entry. */
    public static function log(
        string $event,
        ?Model $subject = null,
        array $properties = [],
        ?string $description = null,
        string $logName = 'model',
        ?Model $causer = null
    ): void {
        try {
            $causer = $causer ?: self::resolveCauser();
            $request = request();

            ActivityLog::create([
                'log_name' => $logName,
                'event' => $event,
                'description' => $description ?: self::describe($event, $subject),
                'subject_type' => $subject ? get_class($subject) : null,
                'subject_id' => $subject?->getKey(),
                'subject_label' => $subject ? self::labelFor($subject) : null,
                'causer_type' => $causer ? get_class($causer) : null,
                'causer_id' => $causer?->getKey(),
                'causer_name' => $causer ? self::labelFor($causer) : null,
                'causer_role' => $causer ? self::roleFor($causer) : null,
                'properties' => $properties ?: null,
                'ip_address' => $request ? CommonHelper::clientIp($request) : null,
                'user_agent' => Str::limit((string) $request?->userAgent(), 500, ''),
                'method' => $request?->method(),
                'url' => $request ? Str::limit($request->fullUrl(), 500, '') : null,
            ]);
        } catch (\Throwable $e) {
            // Auditing must never take down the operation it is auditing.
            Log::warning('[ActivityLogger] could not write entry: ' . $e->getMessage());
        }
    }

    /** Model create/update/delete entry, with only the meaningful changes. */
    public static function logModel(string $event, Model $subject): void
    {
        $properties = match ($event) {
            'created' => ['attributes' => self::clean($subject->getAttributes())],
            'updated' => self::changeSet($subject),
            'deleted', 'restored' => ['attributes' => self::clean($subject->getAttributes())],
            default => [],
        };

        // An "update" that changed nothing meaningful (only timestamps, or a
        // no-op save) is not worth an audit row.
        if ($event === 'updated' && empty($properties['attributes'])) {
            return;
        }

        self::log($event, $subject, $properties);
    }

    /** Old + new values for the changed columns only. */
    private static function changeSet(Model $subject): array
    {
        $changes = self::clean($subject->getDirty());
        $old = [];
        foreach (array_keys($changes) as $key) {
            $old[$key] = self::sanitizeValue($key, $subject->getOriginal($key));
        }

        return ['old' => $old, 'attributes' => $changes];
    }

    /** Drop ignored keys, redact secrets, shorten long values. */
    private static function clean(array $attributes): array
    {
        $out = [];
        foreach ($attributes as $key => $value) {
            if (in_array($key, self::IGNORED_KEYS, true)) {
                continue;
            }
            $out[$key] = self::sanitizeValue($key, $value);
        }

        return $out;
    }

    private static function sanitizeValue(string $key, $value)
    {
        if (in_array(strtolower($key), self::REDACTED_KEYS, true)) {
            return '••••••••';
        }
        if (is_object($value)) {
            $value = method_exists($value, '__toString') ? (string) $value : json_encode($value);
        }
        if (is_array($value)) {
            $value = json_encode($value, JSON_UNESCAPED_UNICODE);
        }
        if (is_string($value) && mb_strlen($value) > self::MAX_VALUE_LENGTH) {
            return mb_substr($value, 0, self::MAX_VALUE_LENGTH) . '…';
        }

        return $value;
    }

    /** "Product #12 created" style fallback description. */
    private static function describe(string $event, ?Model $subject): string
    {
        if (!$subject) {
            return ucfirst(str_replace('_', ' ', $event));
        }

        $label = self::labelFor($subject);
        $identifier = ($label !== null && $label !== '') ? $label : ('#' . $subject->getKey());

        return class_basename($subject) . ' ' . $identifier . ' ' . str_replace('_', ' ', $event);
    }

    /**
     * Readable label for a model. Tries the usual name-ish columns; products have
     * no name column of their own (it lives on the first variant), so the model's
     * own accessor is used when present.
     */
    private static function labelFor(Model $model): ?string
    {

        foreach (['order_number', 'return_number', 'name', 'title', 'display_name', 'username', 'email', 'slug'] as $key) {
            try {
                $value = $model->{$key} ?? null;
            } catch (\Throwable $e) {
                continue; // accessor blew up (missing relation etc.) — try the next
            }
            if (is_string($value) && trim($value) !== '') {
                return Str::limit(trim($value), 180, '');
            }
        }

        return null;
    }

    /** Role name for an admin causer; 'customer' for the storefront guard. */
    private static function roleFor(Model $causer): ?string
    {
        if ($causer instanceof \App\Models\User) {
            return 'customer';
        }
        try {
            if (isset($causer->role_id)) {
                return \App\Models\Role::where('id', $causer->role_id)->value('name');
            }
        } catch (\Throwable $e) {
            // fall through
        }

        return null;
    }

    /**
     * Who is acting. The panel and the delivery-boy app share the `api` guard
     * (Admin), the storefront uses `api-customers` (User); console runs have none.
     */
    private static function resolveCauser(): ?Model
    {
        foreach (['api', 'api-customers', 'web'] as $guard) {
            try {
                $user = Auth::guard($guard)->user();
            } catch (\Throwable $e) {
                continue; // guard not configured in this context
            }
            if ($user instanceof Model) {
                return $user;
            }
        }

        return null;
    }
}
