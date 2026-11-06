<?php

namespace App\Providers;

use App\Listeners\LogAuthenticationActivity;
use Illuminate\Auth\Events\Failed;
use Illuminate\Auth\Events\Lockout;
use Illuminate\Auth\Events\Login;
use Illuminate\Auth\Events\Logout;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Auth\Events\Registered;
use Illuminate\Auth\Listeners\SendEmailVerificationNotification;
use Illuminate\Database\Schema\Builder;
use App\Helpers\AddonHelper;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\ServiceProvider;
use Laravel\Passport\Console\ClientCommand;
use Laravel\Passport\Console\InstallCommand;
use Laravel\Passport\Console\KeysCommand;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->guardBroadcastDriver();
    }

    private function guardBroadcastDriver(): void
    {
        $driver = config('broadcasting.default');

        $required = match ($driver) {
            'reverb' => ['key', 'secret', 'app_id'],
            'pusher' => ['key', 'secret', 'app_id'],
            default  => [],
        };

        if ($required === []) {
            return;
        }

        foreach ($required as $key) {
            if (blank(config("broadcasting.connections.{$driver}.{$key}"))) {
                Log::warning("Broadcast driver [{$driver}] is missing [{$key}]; falling back to the null broadcaster. Chat will use polling only.");
                config(['broadcasting.default' => 'null']);
                return;
            }
        }

        if ($driver === 'pusher' && blank(config('broadcasting.connections.pusher.options.cluster'))) {
            Log::warning('Pusher is missing [cluster]; falling back to the null broadcaster. Chat will use polling only.');
            config(['broadcasting.default' => 'null']);
        }
    }

    public function boot(): void
    {
        Builder::defaultStringLength(191);

        $this->commands([
            InstallCommand::class,
            ClientCommand::class,
            KeysCommand::class,
        ]);

        Event::listen(Registered::class, SendEmailVerificationNotification::class);

        Queue::before(fn () => AddonHelper::flushCache());

        // Audit trail — Laravel's own auth events feed the activity log. Model
        // changes are picked up separately by the LogsActivity trait.
        Event::listen(Login::class, [LogAuthenticationActivity::class, 'onLogin']);
        Event::listen(Logout::class, [LogAuthenticationActivity::class, 'onLogout']);
        Event::listen(Failed::class, [LogAuthenticationActivity::class, 'onFailed']);
        Event::listen(Lockout::class, [LogAuthenticationActivity::class, 'onLockout']);
        Event::listen(PasswordReset::class, [LogAuthenticationActivity::class, 'onPasswordReset']);

        Validator::extend('validate_packet_images', function ($attribute, $value, $parameters, $validator) {
            $validExtensions = ['jpg', 'jpeg', 'png', 'gif'];
            $maxSizeInBytes = 5 * 1024 * 1024;

            foreach ($value as $subArray) {
                if (!is_array($subArray)) {
                    return false;
                }

                foreach ($subArray as $file) {
                    if (!$file->isValid()) {
                        return false;
                    }

                    $extension = $file->getClientOriginalExtension();
                    if (!in_array($extension, $validExtensions)) {
                        return false;
                    }

                    if ($file->getSize() > $maxSizeInBytes) {
                        return false;
                    }
                }
            }

            return true;
        });
    }
}
