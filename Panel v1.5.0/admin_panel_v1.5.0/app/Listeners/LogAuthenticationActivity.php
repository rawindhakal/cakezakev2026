<?php

namespace App\Listeners;

use App\Services\ActivityLogger;
use Illuminate\Auth\Events\Failed;
use Illuminate\Auth\Events\Lockout;
use Illuminate\Auth\Events\Login;
use Illuminate\Auth\Events\Logout;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Database\Eloquent\Model;

/**
 * Sign-in activity, recorded from Laravel's own auth events. The framework fires
 * these for every guard, so panel, delivery-boy and storefront logins all land in
 * the same trail.
 *
 * Methods are named on*, NOT handle* — Laravel auto-discovers listener methods
 * beginning with "handle" and would then register them a second time alongside
 * the explicit Event::listen calls in AppServiceProvider, double-logging events.
 */
class LogAuthenticationActivity
{
    public function onLogin(Login $event): void
    {
        $user = $event->user instanceof Model ? $event->user : null;

        ActivityLogger::log(
            event: 'login',
            subject: $user,
            properties: ['guard' => $event->guard],
            description: __('logged_in'),
            logName: 'auth',
            causer: $user
        );
    }

    public function onLogout(Logout $event): void
    {
        $user = $event->user instanceof Model ? $event->user : null;

        ActivityLogger::log(
            event: 'logout',
            subject: $user,
            properties: ['guard' => $event->guard],
            description: __('logged_out'),
            logName: 'auth',
            causer: $user
        );
    }

    /**
     * Failed attempts matter most in an audit trail — there is no causer, so the
     * attempted identifier is recorded instead (never the password).
     */
    public function onFailed(Failed $event): void
    {
        $identifier = $event->credentials['email']
            ?? $event->credentials['username']
            ?? $event->credentials['mobile']
            ?? null;

        ActivityLogger::log(
            event: 'failed_login',
            subject: $event->user instanceof Model ? $event->user : null,
            properties: ['guard' => $event->guard, 'identifier' => $identifier],
            description: __('failed_login_attempt') . ($identifier ? ': ' . $identifier : ''),
            logName: 'auth'
        );
    }

    public function onLockout(Lockout $event): void
    {
        ActivityLogger::log(
            event: 'lockout',
            properties: ['identifier' => $event->request->input('email') ?? $event->request->input('username')],
            description: __('too_many_login_attempts_lockout'),
            logName: 'auth'
        );
    }

    public function onPasswordReset(PasswordReset $event): void
    {
        $user = $event->user instanceof Model ? $event->user : null;

        ActivityLogger::log(
            event: 'password_reset',
            subject: $user,
            description: __('password_was_reset'),
            logName: 'auth',
            causer: $user
        );
    }
}
