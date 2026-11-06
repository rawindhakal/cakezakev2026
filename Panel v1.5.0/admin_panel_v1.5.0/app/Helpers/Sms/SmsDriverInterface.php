<?php

namespace App\Helpers\Sms;

/**
 * One SMS gateway driver. New gateways just implement this and get registered
 * in SmsHelper::driver(). $context carries gateway-specific extras (e.g. MSG91's
 * DLT template id + variables) that plain-text gateways ignore.
 */
interface SmsDriverInterface
{
    /**
     * @param string $to      Recipient phone (country code + number).
     * @param string $message Rendered message text (used by plain-text gateways).
     * @param array  $context ['template_id' => ?string, 'vars' => array] for DLT gateways.
     * @return bool  true on success.
     */
    public function send(string $to, string $message, array $context = []): bool;
}
