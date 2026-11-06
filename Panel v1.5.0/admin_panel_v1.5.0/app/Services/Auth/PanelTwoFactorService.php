<?php

namespace App\Services\Auth;

use App\Helpers\CommonHelper;
use App\Models\Admin;
use App\Models\Role;
use App\Models\Setting;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Two-factor for panel logins.
 *
 * The password proves who you claim to be; this proves you can read that account's inbox.
 * Between the two steps sits a challenge parked on the admin's own row — the password is
 * spent, but no access token exists yet, so a stolen password alone buys nothing. One
 * admin can only be mid-login once, so the challenge is state of the user rather than a
 * table of its own: starting a login overwrites whatever was there.
 */
class PanelTwoFactorService
{
    /** Wrong codes allowed before the challenge is burned and the password must be re-entered. */
    public const MAX_ATTEMPTS = 5;

    /** Total emails per challenge, the first one included. */
    public const MAX_SENDS = 3;

    /** Seconds between resends, so the button cannot be used to spam an inbox. */
    public const RESEND_COOLDOWN = 60;

    /** Is 2FA switched on for this particular user? */
    public function appliesTo(Admin $user): bool
    {
        if ((int) Setting::get_value('panel_two_factor') !== 1) {
            return false;
        }

        /* Riders never get a challenge. Their app is compiled against the one-step login
           and would read a reply with no access token as a failure, locking out every
           delivery boy the moment an admin turns this on. */
        if ((int) $user->role_id === (int) Role::$roleDeliveryBoy) {
            return false;
        }

        if ($user->isBranchUser()) {
            return (int) Setting::get_value('panel_two_factor_branch_users') === 1;
        }

        return true;
    }

    /** How long a code stays valid, in minutes. */
    public function expiryMinutes(): int
    {
        $minutes = (int) Setting::get_value('panel_two_factor_expiry');

        return $minutes >= 1 ? min($minutes, 60) : 10;
    }

    /**
     * Open a challenge for a user whose password already checked out, and email the code.
     *
     * @return array{token: string, expires_in: int, sends_left: int}
     */
    public function start(Admin $user, Request $request): array
    {
        $token = Str::random(64);
        $code = $this->generateCode();
        $expiresAt = now()->addMinutes($this->expiryMinutes());

        /* Overwriting in place is what invalidates the previous half-finished login: an
           old code must stop working the moment a new one is asked for. */
        $this->store($user, [
            'two_factor_token' => hash('sha256', $token),
            'two_factor_code' => Hash::make($code),
            'two_factor_attempts' => 0,
            'two_factor_sends' => 1,
            'two_factor_sent_at' => now(),
            'two_factor_expires_at' => $expiresAt,
        ]);

        Log::info("[2FA] challenge opened for admin {$user->id} from {$request->ip()}.");

        $this->email($user, $code);

        return [
            'token' => $token,
            'expires_in' => max($expiresAt->timestamp - now()->timestamp, 0),
            'sends_left' => self::MAX_SENDS - 1,
        ];
    }

    /**
     * Send the code again for an open challenge.
     *
     * @return array{ok: bool, message: string, sends_left?: int, retry_after?: int}
     */
    public function resend(string $token, Request $request): array
    {
        $user = $this->findOpen($token);
        if (!$user) {
            return ['ok' => false, 'message' => 'login_session_expired_please_sign_in_again'];
        }

        if ((int) $user->two_factor_sends >= self::MAX_SENDS) {
            return ['ok' => false, 'message' => 'resend_limit_reached_please_sign_in_again'];
        }

        /* Plain timestamps rather than a Carbon diff: diffInSeconds is unsigned in some
           versions and signed in others, and a negative wait would hand out a cooldown
           longer than the cooldown. */
        $waited = $user->two_factor_sent_at
            ? now()->timestamp - strtotime((string) $user->two_factor_sent_at)
            : self::RESEND_COOLDOWN;

        if ($waited < self::RESEND_COOLDOWN) {
            return [
                'ok' => false,
                'message' => 'please_wait_before_requesting_another_code',
                'retry_after' => (int) max(self::RESEND_COOLDOWN - $waited, 1),
            ];
        }

        /* A fresh code rather than a repeat of the old one, so a code glimpsed on a
           screen that was never used cannot be revived by pressing resend. */
        $code = $this->generateCode();
        $sends = (int) $user->two_factor_sends + 1;

        $this->store($user, [
            'two_factor_code' => Hash::make($code),
            'two_factor_sends' => $sends,
            'two_factor_sent_at' => now(),
            // The clock restarts, otherwise a late resend would arrive already expired.
            'two_factor_expires_at' => now()->addMinutes($this->expiryMinutes()),
            'two_factor_attempts' => 0,
        ]);

        $this->email($user, $code);

        return [
            'ok' => true,
            'message' => 'verification_code_sent',
            'sends_left' => self::MAX_SENDS - $sends,
        ];
    }

    /**
     * Check a submitted code and, if it is right, consume the challenge.
     *
     * @return array{ok: bool, user?: Admin, message?: string, attempts_left?: int}
     */
    public function verify(string $token, string $code, Request $request): array
    {
        $user = $this->findOpen($token);
        if (!$user) {
            return ['ok' => false, 'message' => 'login_session_expired_please_sign_in_again'];
        }

        if ((int) $user->two_factor_attempts >= self::MAX_ATTEMPTS) {
            $this->clear($user);

            return ['ok' => false, 'message' => 'too_many_incorrect_codes_please_sign_in_again'];
        }

        if (!Hash::check($code, (string) $user->two_factor_code)) {
            $attempts = (int) $user->two_factor_attempts + 1;
            $left = self::MAX_ATTEMPTS - $attempts;

            if ($left <= 0) {
                $this->clear($user);

                return ['ok' => false, 'message' => 'too_many_incorrect_codes_please_sign_in_again'];
            }

            $this->store($user, ['two_factor_attempts' => $attempts]);
            Log::warning("[2FA] wrong code for admin {$user->id} from {$request->ip()}; {$left} left.");

            return ['ok' => false, 'message' => 'incorrect_verification_code', 'attempts_left' => $left];
        }

        // Single use: the challenge goes before the token is issued.
        $this->clear($user);

        return ['ok' => true, 'user' => $user];
    }

    /** The user whose live, unexpired challenge this raw token opens, or null. */
    private function findOpen(string $token): ?Admin
    {
        $token = trim($token);
        if ($token === '') {
            return null;
        }

        return Admin::where('two_factor_token', hash('sha256', $token))
            ->where('two_factor_expires_at', '>', now())
            ->first();
    }

    /**
     * Write challenge columns without touching anything else on the row.
     *
     * A bare update rather than `save()`: the row may carry appended attributes and
     * relations, and a login must never rewrite a field the admin did not change.
     */
    private function store(Admin $user, array $values): void
    {
        Admin::where('id', $user->id)->update($values);
        $user->forceFill($values);
    }

    /** Spend the challenge. */
    private function clear(Admin $user): void
    {
        $this->store($user, [
            'two_factor_token' => null,
            'two_factor_code' => null,
            'two_factor_attempts' => 0,
            'two_factor_sends' => 0,
            'two_factor_sent_at' => null,
            'two_factor_expires_at' => null,
        ]);
    }

    /**
     * Six digits, from a generator fit for secrets.
     *
     * `random_int` rather than `rand`: the code is the whole second factor, and a
     * predictable sequence would make it worthless.
     */
    private function generateCode(): string
    {
        return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    }

    /**
     * Mail the code after the response has gone out.
     *
     * `CommonHelper::sendMail()` talks to SMTP inline, which would hold the login
     * response open for the length of a Gmail handshake. The code is already stored, so
     * nothing about the login depends on this finishing first.
     */
    private function email(Admin $user, string $code): void
    {
        $minutes = $this->expiryMinutes();

        dispatch(function () use ($user, $code, $minutes) {
            try {
                CommonHelper::sendMailByTemplate($user->email, 'two_factor_code_admin', [
                    'username' => $user->username ?: $user->email,
                    'code' => $code,
                    'expiry_minutes' => (string) $minutes,
                ]);
            } catch (\Throwable $e) {
                Log::error("[2FA] could not email a login code to admin {$user->id}: " . $e->getMessage());
            }
        })->afterResponse();
    }
}
