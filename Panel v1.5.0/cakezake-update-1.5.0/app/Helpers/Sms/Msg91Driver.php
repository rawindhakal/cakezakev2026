<?php

namespace App\Helpers\Sms;

use App\Models\Setting;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * MSG91 SMS via the Flow API (DLT-compliant). Each message type maps to a
 * DLT-approved template id (per language, stored on the sms_template_translation).
 * The template's placeholders are sent as flow variables.
 *
 * Settings keys: msg91_auth_key, msg91_sender_id.
 */
class Msg91Driver implements SmsDriverInterface
{
    private const FLOW_URL = 'https://control.msg91.com/api/v5/flow/';

    public function send(string $to, string $message, array $context = []): bool
    {
        $authKey    = Setting::get_value('msg91_auth_key');
        $sender     = Setting::get_value('msg91_sender_id');
        $templateId = $context['template_id'] ?? '';
        $vars       = $context['vars'] ?? [];

        if (empty($authKey)) {
            Log::error('MSG91: auth key missing.');
            return false;
        }
        if (empty($templateId)) {
            // DLT/Flow requires a template id per message type + language.
            Log::error('MSG91: DLT template id missing for this SMS type/language — cannot send.');
            return false;
        }

        // MSG91 wants the number with country code and NO leading '+'.
        $mobiles = ltrim(trim($to), '+');
        if ($mobiles === '') {
            return false;
        }

        // Recipient carries the DLT variables alongside the mobile number.
        $recipient = array_merge(['mobiles' => $mobiles], $this->stringifyVars($vars));

        $payload = [
            'template_id' => $templateId,
            'short_url'   => '0',
            'recipients'  => [$recipient],
        ];
        if (!empty($sender)) {
            $payload['sender'] = $sender;
        }

        try {
            $response = Http::withHeaders([
                'authkey'      => $authKey,
                'Content-Type' => 'application/json',
                'Accept'       => 'application/json',
            ])->post(self::FLOW_URL, $payload);

            if (!$response->successful()) {
                Log::error('MSG91 send failed', ['status' => $response->status(), 'body' => $response->body()]);
                return false;
            }
            return true;
        } catch (\Throwable $e) {
            Log::error('MSG91 send exception: ' . $e->getMessage());
            return false;
        }
    }

    /** Flow variables must be strings. */
    private function stringifyVars(array $vars): array
    {
        $out = [];
        foreach ($vars as $k => $v) {
            $out[$k] = is_scalar($v) ? (string) $v : json_encode($v);
        }
        return $out;
    }
}
