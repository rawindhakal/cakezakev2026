<?php

namespace App\Support;

use Illuminate\Support\Facades\Log;

/**
 * Everything a gateway or carrier delivery does, in one file.
 *
 * A webhook is the one thing in this app nobody can watch happen: it arrives from
 * outside, settles money, and the only record of why it did what it did is the line it
 * wrote. Mixed into `laravel.log` with every other request that is a needle in a
 * haystack — and on shared hosting, where a support request means an admin reading a
 * file through a file manager, it is the difference between an answer and a shrug.
 *
 * So the delivery, the signature check, the settlement and the failure all write here,
 * rather than each layer picking its own channel. Rotates on its own schedule
 * (`config/logging.php`), kept longer than the default log.
 */
final class WebhookLog
{
    public static function info(string $message, array $context = []): void
    {
        self::write('info', $message, $context);
    }

    public static function warning(string $message, array $context = []): void
    {
        self::write('warning', $message, $context);
    }

    public static function error(string $message, array $context = []): void
    {
        self::write('error', $message, $context);
    }

    public static function write(string $level, string $message, array $context = []): void
    {
        try {
            Log::channel('webhooks')->{$level}($message, $context);
        } catch (\Throwable $e) {
            // An unwritable log must never fail a settlement. Fall back to the default
            // channel, which has already been written to by this point in the request.
            Log::{$level}($message, $context);
        }
    }
}
