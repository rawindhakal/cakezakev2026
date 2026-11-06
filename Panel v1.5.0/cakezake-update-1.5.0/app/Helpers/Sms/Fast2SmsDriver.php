<?php

namespace App\Helpers\Sms;

use App\Models\Setting;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Fast2SMS (India). Two modes, chosen automatically:
 *   - DLT route  : when the SMS template has a gateway_template_id (Fast2SMS DLT
 *                  message id). Sends sender_id + template id + pipe-joined variables.
 *   - Quick (q)  : otherwise — sends the rendered plain-text message.
 *
 * Settings keys: fast2sms_api_key, fast2sms_sender_id.
 * Fast2SMS domestic routes use 10-digit numbers, so the country code is stripped.
 */
class Fast2SmsDriver implements SmsDriverInterface
{
    private const URL = 'https://www.fast2sms.com/dev/bulkV2';

    public function send(string $to, string $message, array $context = []): bool
    {
        $apiKey = Setting::get_value('fast2sms_api_key');
        if (empty($apiKey)) {
            Log::error('Fast2SMS: API key missing.');
            return false;
        }

        $numbers = $this->normalizeNumber($to);
        if ($numbers === '') {
            return false;
        }

        $templateId = $context['template_id'] ?? '';

        if (!empty($templateId)) {
            // DLT route: content lives in the Fast2SMS-approved template; we pass variables.
            $vars = array_map(
                fn ($v) => is_scalar($v) ? (string) $v : json_encode($v),
                array_values($context['vars'] ?? [])
            );
            $params = [
                'route'            => 'dlt',
                'sender_id'        => Setting::get_value('fast2sms_sender_id'),
                'message'          => $templateId,
                'variables_values' => implode('|', $vars),
                'numbers'          => $numbers,
                'flash'            => '0',
            ];
        } else {
            // Quick route: send the rendered message as plain text.
            if ($message === '') {
                return false;
            }
            $params = [
                'route'    => 'q',
                'message'  => $message,
                'language' => 'english',
                'numbers'  => $numbers,
                'flash'    => '0',
            ];
        }

        try {
            $response = Http::withHeaders([
                'authorization' => $apiKey,
                'Accept'        => 'application/json',
            ])->asForm()->post(self::URL, $params);

            $body = $response->json();
            if (!$response->successful() || !($body['return'] ?? false)) {
                Log::error('Fast2SMS send failed', ['status' => $response->status(), 'body' => $response->body()]);
                return false;
            }
            return true;
        } catch (\Throwable $e) {
            Log::error('Fast2SMS send exception: ' . $e->getMessage());
            return false;
        }
    }

    /** Fast2SMS domestic routes want a 10-digit number — strip '+' and a leading 91. */
    private function normalizeNumber(string $to): string
    {
        $n = ltrim(trim($to), '+');
        $n = preg_replace('/\D/', '', $n); // digits only
        if (strlen($n) === 12 && str_starts_with($n, '91')) {
            $n = substr($n, 2);
        }
        return $n;
    }
}
