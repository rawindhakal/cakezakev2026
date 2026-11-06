<?php

namespace App\Helpers;

use App\Models\AdminToken;
use App\Models\Setting;
use App\Models\UserToken;
use Illuminate\Support\Facades\Log;
use Google\Client;
use Exception;
use Illuminate\Support\Facades\Cache;

class FirebaseHelper
{
    /** Chunk size for parallel FCM sends (avoids timeout when sending to many devices). */
    const BULK_CHUNK_SIZE = 50;

    public static function send($platform, $registration_ids, $fcm_msg)
    {
        $fields = self::buildMessageFields($platform, $registration_ids, $fcm_msg);
        if ($fields === null) {
            return false;
        }
        return self::sendPushNotification($fields);
    }

    public static function sendBulk($tokenRows, $fcm_msg, $tokenModelClass = null)
    {
        $list = [];
        foreach ($tokenRows as $row) {
            $token = $row->fcm_token ?? null;
            $platform = $row->platform ?? 'android';
            if (empty($token)) {
                continue;
            }
            $fields = self::buildMessageFields($platform, $token, $fcm_msg);
            if ($fields !== null) {
                $list[] = ['fields' => $fields, 'token' => $token, 'row' => $row];
            }
        }

        if (empty($list)) {
            return;
        }

        $chunks = array_chunk($list, self::BULK_CHUNK_SIZE);
        foreach ($chunks as $chunk) {
            self::sendChunkParallel($chunk, $tokenModelClass);
        }
    }

    /**
     * Build FCM v1 message fields for one token (used by send and sendBulk).
     */
    private static function buildMessageFields($platform, $registration_id, $fcm_msg)
    {
        if ($platform == "android" || $platform == "web") {
            // FCM v1 requires every data value to be a string; a null (e.g. type_slug on a
            // chat push) makes Google return 400, which the send handler used to misread as
            // an expired token. Cast all values and drop nulls.
            $data = [];
            foreach ($fcm_msg as $k => $v) {
                $data[$k] = $v === null ? '' : (string) $v;
            }
            $fields = [
                "message" => [
                    "token" => $registration_id,
                    "data" => $data
                ]
            ];
            if ($platform == "android") {
                $fields["message"]["android"] = ["priority" => "HIGH"];
            }
            return $fields;
        }
        if ($platform == "ios") {
            return [
                "message" => [
                    "token" => $registration_id,
                    "data" => $fcm_msg,
                    "notification" => [
                        "title" => $fcm_msg["title"] ?? '',
                        "body" => $fcm_msg["body"] ?? '',
                    ],
                    "apns" => [
                        "payload" => [
                            "aps" => [
                                "sound" => self::isOrderAssignOrderSound($fcm_msg)
                                    ? "order_sound.aiff"
                                    : "default"
                            ]
                        ]
                    ]
                ]
            ];
        }
        Log::error("Invalid platform specified for Firebase push notification: " . $platform);
        return null;
    }

    /**
     * Uses sound_type when set (semantic type in "type" field), else legacy type field.
     */
    private static function isOrderAssignOrderSound(array $fcm_msg): bool
    {
        $t = isset($fcm_msg['sound_type']) && $fcm_msg['sound_type'] !== ''
            ? (string) $fcm_msg['sound_type']
            : (string) ($fcm_msg['type'] ?? '');
        return $t === 'new_order' || $t === 'assign_order';
    }

    /**
     * Send one chunk of FCM requests in parallel using curl_multi.
     */
    private static function sendChunkParallel(array $chunk, $tokenModelClass = null)
    {
        $projectID = optional(Setting::where('variable', 'projectId')->first())->value;
        if (!$projectID) {
            Log::error("Firebase project ID not found in settings.");
            return;
        }

        $access_token = self::getAccessToken();
        if (!$access_token) {
            return;
        }

        $url = 'https://fcm.googleapis.com/v1/projects/' . $projectID . '/messages:send';
        $handles = [];
        $tokenByHandle = [];

        foreach ($chunk as $item) {
            $data = json_encode($item['fields']);
            $headers = [
                'Authorization: Bearer ' . $access_token,
                'Content-Type: application/json',
            ];
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
            curl_setopt($ch, CURLOPT_TIMEOUT, 10);
            $handles[] = $ch;
            $tokenByHandle[(int) $ch] = ['token' => $item['token'], 'row' => $item['row']];
        }

        $mh = curl_multi_init();
        foreach ($handles as $ch) {
            curl_multi_add_handle($mh, $ch);
        }

        $running = null;
        do {
            curl_multi_exec($mh, $running);
            curl_multi_select($mh, 0.1);
        } while ($running > 0);

        foreach ($handles as $ch) {
            $result = curl_multi_getcontent($ch);
            $info = $tokenByHandle[(int) $ch] ?? null;
            curl_multi_remove_handle($mh, $ch);
            unset($ch);

            if ($info && $result !== false) {
                $response = json_decode($result, true);
                if (isset($response['error']['code']) && in_array((int) $response['error']['code'], [400, 404], true)) {
                    if ($tokenModelClass && method_exists($tokenModelClass, 'where')) {
                        $tokenModelClass::where('fcm_token', $info['token'])->delete();
                    }
                    Log::warning("Deleted invalid FCM token: " . $info['token']);
                }
            }
        }
        curl_multi_close($mh);
    }

    public static function sendPushNotification($fields)
    {
        $data1 = json_encode($fields);

        $access_token = self::getAccessToken();
        $projectID = optional(Setting::where('variable', 'projectId')->first())->value;

        if (!$projectID) {
            Log::error("Firebase project ID not found in settings.");
            return false;
        }

        $url = 'https://fcm.googleapis.com/v1/projects/' . $projectID . '/messages:send';

        $headers = [
            'Authorization: Bearer ' . $access_token,
            'Content-Type: application/json',
        ];

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 2);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $data1);

        // Execute post
        $result = curl_exec($ch);

        if ($result === false) {
            Log::error('FCM request failed: ' . curl_error($ch));
            unset($ch);
            return false;
        }

        unset($ch);

        $response = json_decode($result, true);
        if (isset($response['error'])) {
            // Only prune the token when FCM says the registration itself is dead
            // (404 NOT_FOUND / UNREGISTERED). A 400 INVALID_ARGUMENT is almost always a
            // payload problem — deleting on 400 was wrongly wiping valid, freshly-added
            // tokens. Delete from whichever table holds it (admin + app users).
            $code = $response['error']['code'] ?? null;
            $status = $response['error']['status'] ?? '';
            $fcmErrorCode = $response['error']['details'][0]['errorCode'] ?? '';
            $unregistered = ($code == 404) || ($status === 'NOT_FOUND') || ($fcmErrorCode === 'UNREGISTERED');

            if ($unregistered) {
                $token = $fields['message']['token'] ?? '';
                UserToken::where('fcm_token', $token)->delete();
                AdminToken::where('fcm_token', $token)->delete();
            }
        }

        return $response;
    }

    private static function getAccessToken()
    {
        // FCM OAuth tokens are valid ~1h; cache to avoid a Google round-trip per push.
        return Cache::remember('fcm_access_token', 3300, function () {
            $filePath = base_path('config/firebase.json');

            if (!file_exists($filePath)) {
                throw new Exception('Service account file not found');
            }

            $client = new Client();
            $client->setAuthConfig($filePath);
            $client->setScopes(['https://www.googleapis.com/auth/firebase.messaging']);

            $accessToken = $client->fetchAccessTokenWithAssertion();

            return $accessToken['access_token'] ?? null;
        });
    }
}
