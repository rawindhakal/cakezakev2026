<?php

namespace App\Helpers\Sms;

use App\Models\Setting;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * 2Factor (2factor.in) transactional SMS via the V1 TSMS endpoint:
 *   POST https://2factor.in/API/V1/{api_key}/ADDON_SERVICES/SEND/TSMS
 * It is DLT-based, so it still needs a DLT-approved template NAME + positional
 * variables (VAR1, VAR2, ...). The api key travels in the URL path.
 *
 * Settings keys: twofactor_api_key, twofactor_sender_id.
 * The template's DLT template NAME is stored in the per-language gateway map under
 * the 'twofactor' key (passed here as $context['template_id']).
 */
class TwoFactorDriver implements SmsDriverInterface
{
    private const URL_TEMPLATE = 'https://2factor.in/API/V1/%s/ADDON_SERVICES/SEND/TSMS';

    public function send(string $to, string $message, array $context = []): bool
    {
        $apiKey       = Setting::get_value('twofactor_api_key');
        $sender       = Setting::get_value('twofactor_sender_id');
        $templateName = $context['template_id'] ?? '';

        if (empty($apiKey)) {
            Log::error('2Factor: API key missing.');
            return false;
        }
        if (empty($templateName)) {
            // TSMS is DLT transactional — a DLT-approved template name is mandatory.
            Log::error('2Factor: DLT template name missing for this SMS type/language — cannot send.');
            return false;
        }

        $number = preg_replace('/\D/', '', ltrim(trim($to), '+'));
        if ($number === '') {
            return false;
        }

        $params = [
            'From'         => $sender,
            'To'           => $number,
            'TemplateName' => $templateName,
        ];

        // Positional variables VAR1, VAR2, ... in the template's variable order.
        $i = 1;
        foreach (array_values($context['vars'] ?? []) as $value) {
            $params['VAR' . $i] = is_scalar($value) ? (string) $value : json_encode($value);
            $i++;
        }

        $url = sprintf(self::URL_TEMPLATE, rawurlencode($apiKey));

        try {
            $response = Http::acceptJson()->asForm()->post($url, $params);
            $body = $response->json();

            if (!$response->successful() || strtolower((string) ($body['Status'] ?? '')) !== 'success') {
                Log::error('2Factor send failed', ['status' => $response->status(), 'body' => $response->body()]);
                return false;
            }
            return true;
        } catch (\Throwable $e) {
            Log::error('2Factor send exception: ' . $e->getMessage());
            return false;
        }
    }
}
