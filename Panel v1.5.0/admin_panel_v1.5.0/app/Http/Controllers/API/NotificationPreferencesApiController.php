<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\NotificationAdminSetting;
use App\Models\NotificationPreference;
use App\Services\NotificationService;
use Illuminate\Http\Request;
class NotificationPreferencesApiController extends Controller
{
    /** Content language: header/param when the client sends one, else null = all langs. */
    private function langCode(Request $request): ?string
    {
        $code = $request->header('Content-Language') ?: $request->input('language');
        $code = is_string($code) ? trim($code) : '';
        return $code !== '' ? $code : null;
    }

    // ---- Customer app ----
    public function customerIndex(Request $request)
    {
        $user = $request->user('api-customers');
        return $this->buildList('customer', $user ? (int) $user->id : 0, $this->langCode($request));
    }

    public function customerSave(Request $request)
    {
        $user = $request->user('api-customers');
        return $this->save('customer', $user ? (int) $user->id : 0, $request);
    }

    // ---- Delivery-boy app (authenticates via the linked admin id) ----
    public function deliveryBoyIndex(Request $request)
    {
        $user = $request->user();
        return $this->buildList('delivery_boy', $user ? (int) $user->id : 0, $this->langCode($request));
    }

    public function deliveryBoySave(Request $request)
    {
        $user = $request->user();
        return $this->save('delivery_boy', $user ? (int) $user->id : 0, $request);
    }

    // ---- Branch panel (a branch user is the `admin` audience, user_type = 2) ----
    // Branch users only manage branch-relevant events (orders + return requests),
    // not the full admin catalog (withdrawals, chat, forgot-password, ...).
    private array $branchCategories = ['Orders', 'Order Items', 'Returns', 'Chat'];

    public function branchIndex(Request $request)
    {
        $user = $request->user();
        if (!$user || !$user->isBranchUser()) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }
        return $this->buildList('admin', (int) $user->id, $this->langCode($request), $this->branchCategories);
    }

    public function branchSave(Request $request)
    {
        $user = $request->user();
        if (!$user || !$user->isBranchUser()) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }
        return $this->save('admin', (int) $user->id, $request, $this->branchCategories);
    }

    // ---- shared ----
    private function buildList(string $audience, int $userId, ?string $langCode = null, ?array $categories = null)
    {
        $userType = NotificationService::userTypeForAudience($audience);

        $adminRows = NotificationAdminSetting::where('audience', $audience)->get()
            ->keyBy(fn ($r) => $r->event_key . '|' . $r->channel);
        $prefRows = NotificationPreference::where('user_type', $userType)->where('user_id', $userId)->get()
            ->keyBy(fn ($r) => $r->event_key . '|' . $r->channel);

        $grouped = [];
        foreach (NotificationService::events() as $e) {
            if ($e['audience'] !== $audience) {
                continue;
            }
            if ($categories !== null && !in_array($e['category'], $categories, true)) {
                continue; // caller restricts to a subset of categories
            }
            $channels = [];
            foreach ($e['channels'] as $channel => $default) {
                $adminRow = $adminRows->get($e['key'] . '|' . $channel);
                $adminEnabled = $adminRow ? (bool) $adminRow->is_enabled : (bool) $default;
                if (!$adminEnabled) {
                    continue; // admin hid this channel
                }
                $pref = $prefRows->get($e['key'] . '|' . $channel);
                $channels[$channel] = $pref === null ? true : (bool) $pref->is_enabled;
            }
            if (empty($channels)) {
                continue; // no channel available -> hide event
            }
            $grouped[$e['category']][] = [
                'key'      => $e['key'],
                'label'    => NotificationService::eventLabel($e['key'], $langCode),
                'channels' => $channels,
            ];
        }

        // Preserve catalog category order.
        $out = [];
        foreach (NotificationService::categories() as $cat) {
            if (!empty($grouped[$cat])) {
                $out[] = ['category' => $cat, 'events' => $grouped[$cat]];
            }
        }

        return CommonHelper::responseWithData($out);
    }

    private function save(string $audience, int $userId, Request $request, ?array $categories = null)
    {
        if (!$userId) {
            return CommonHelper::responseError('unauthorized');
        }
        $userType = NotificationService::userTypeForAudience($audience);
        $events = $request->input('preferences', $request->input('events', []));
        if (!is_array($events)) {
            return CommonHelper::responseError('invalid_request');
        }

        // When restricted, only accept keys whose catalog category is allowed.
        $allowedKeys = null;
        if ($categories !== null) {
            $allowedKeys = [];
            foreach (NotificationService::events() as $e) {
                if ($e['audience'] === $audience && in_array($e['category'], $categories, true)) {
                    $allowedKeys[$e['key']] = true;
                }
            }
        }

        foreach ($events as $ev) {
            $key = $ev['key'] ?? null;
            $channels = $ev['channels'] ?? [];
            if (!$key || !is_array($channels)) {
                continue;
            }
            if ($allowedKeys !== null && !isset($allowedKeys[$key])) {
                continue; // key outside the caller's allowed categories
            }
            // Only accept channels this (event,audience) actually defines + admin allows.
            foreach ($channels as $channel => $value) {
                if (!in_array($channel, ['mail', 'sms', 'push'], true)) {
                    continue;
                }
                if (!NotificationService::catalogHas($key, $audience)) {
                    continue;
                }
                $adminEnabled = NotificationAdminSetting::where('event_key', $key)->where('audience', $audience)
                    ->where('channel', $channel)->value('is_enabled');
                if ($adminEnabled === null) {
                    $adminEnabled = NotificationService::catalogDefault($key, $audience, $channel);
                }
                if (!$adminEnabled) {
                    continue; // can't set a pref for a channel admin disabled
                }
                NotificationPreference::updateOrCreate(
                    ['user_type' => $userType, 'user_id' => $userId, 'event_key' => $key, 'channel' => $channel],
                    ['is_enabled' => (bool) $value]
                );
            }
        }

        return CommonHelper::responseSuccess('notification_preferences_saved');
    }
}
