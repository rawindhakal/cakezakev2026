<?php

namespace App\Helpers\Sms;

use App\Models\Setting;
use Illuminate\Support\Facades\Log;
use Twilio\Rest\Client;

/**
 * Twilio plain-text SMS. Self-contained (like the other drivers): reads its own
 * credentials and returns false on any error/missing config — never throws, so a
 * mis-configured gateway can't break an order/webhook flow.
 *
 * Settings keys: twilio_sid, twilio_auth_token, twilio_phone_number.
 */
class TwilioDriver implements SmsDriverInterface
{
    public function send(string $to, string $message, array $context = []): bool
    {
        if ($to === '' || $message === '') {
            return false;
        }

        $sid   = Setting::get_value('twilio_sid');
        $token = Setting::get_value('twilio_auth_token');
        $from  = Setting::get_value('twilio_phone_number');

        if (empty($sid) || empty($token) || empty($from)) {
            Log::error('Twilio: credentials (sid/token/phone) missing.');
            return false;
        }

        try {
            $client = new Client($sid, $token);
            $client->messages->create($to, ['from' => $from, 'body' => $message]);
            return true;
        } catch (\Throwable $e) {
            Log::error('Twilio send exception: ' . $e->getMessage());
            return false;
        }
    }
}
