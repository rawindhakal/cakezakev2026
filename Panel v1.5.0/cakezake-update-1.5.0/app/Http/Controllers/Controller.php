<?php

namespace App\Http\Controllers;

use App\Models\Country;
use App\Models\HomeLayout;
use App\Models\Setting;
use App\Models\Branch;
use App\Models\Zone;
use Carbon\Carbon;
use Illuminate\Http\Request;
use App\Helpers\CommonHelper;
use App\Models\PanelNotification;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Session;
use Illuminate\Routing\Controller as BaseController;

class Controller extends BaseController
{
    public function doLanguageChange(Request $request)
    {
        Session::put('lang', $request->language);
        Session::put('app_locale', $request->language);
        return response()->json(['status' => true]);
    }
    
    public function createSlug($text)
    {
        $slug = CommonHelper::slugify($text);
        return CommonHelper::responseWithData($slug);
    }

    public function getTopNotifications()
    {
        $notifications = PanelNotification::where('notifiable_id', auth()->user()->id);
        $unReadCount = (clone $notifications)->where('read_at', NULL)->get()->count();
        $notifications = $notifications->orderBy('created_at', 'DESC')->get();

        $data = array();
        $data['unread'] = $unReadCount;
        $data['notifications'] = $notifications;
        return CommonHelper::responseWithData($data);
    }

    public function markAsReadNotifications(Request $request)
    {
        auth()->user()
            ->unreadNotifications
            ->when($request->input('id'), function ($query) use ($request) {
                return $query->where('id', $request->input('id'));
            })
            ->markAsRead();
        return CommonHelper::responseWithData("Notification Mark as Read Successfully!");
    }

    public function unauthorized()
    {
        $data = [];
        $invoice = view('unauthorized', $data)->render();
        return $invoice;
    }
    public function getAdminSettings()
    {
        $logo = "";
        $app_name = "";
        $support_email = "";
        $support_number = "";
        $google_place_api_key = "";
        $google_map_api_key = "";
        $googleMapApiKey = "";
        $currency = "";
        $logo_full_path = "";
        $delivery_boy_bonus_settings = 0;
        $isDemoMode = 0;

        $website_url = "";
        $copyright_details = "";

        // Firebase keys
        $apiKey = "";
        $authDomain = "";
        $projectId = "";
        $storageBucket = "";
        $messagingSenderId = "";
        $appId = "";
        $measurementId = "";


        $app_name = Setting::get_value('app_name') ?? "CakeZake";
        $support_email = Setting::get_value('support_email') ?? "";
        $support_number = Setting::get_value('support_number') ?? "";

        $logo = Setting::get_value('logo') ?? "";
        if ($logo !== "") {
            $logo_full_path = url('/') . '/storage/' . $logo;
        } else {
            $logo_full_path = asset('images/favicon.png');
        }

        $panel_login_background_img = Setting::get_value('panel_login_background_img') ?? "";
        $panel_login_background_img_full_path = '';
        if ($panel_login_background_img !== "") {
            $panel_login_background_img_full_path = url('/') . '/storage/' . $panel_login_background_img;
        } else {
            $panel_login_background_img_full_path = asset('images/panel_login_background_img.png');
        }

        $google_place_api_key = Setting::get_value('google_place_api_key') ?? "";
        $google_map_api_key = Setting::get_value('google_map_api_key') ?? "";
        $apiKey = Setting::get_value('firebase_apiKey') ?? "";
        $googleMapApiKey = Setting::get_value('googleMapApiKey') ?? "";
        $currency = Setting::get_value('currency') ?? "$";

        $website_url = Setting::get_value('website_url') ?? "";
        $copyright_details = Setting::get_value('copyright_details') ?? "";

        $delivery_boy_bonus_settings = Setting::get_value('delivery_boy_bonus_settings') ?? 0;

        // Firebase keys
        $authDomain = Setting::get_value('authDomain') ?? "";
        $projectId = Setting::get_value('projectId') ?? "";
        $storageBucket = Setting::get_value('storageBucket') ?? "";
        $messagingSenderId = Setting::get_value('messagingSenderId') ?? "";
        $appId = Setting::get_value('appId') ?? "";
        $measurementId = Setting::get_value('measurementId') ?? "";

        $isDemoMode = isDemoMode() ?? 0;

        return response()->json([
            'app_name' => $app_name,
            'support_email' => $support_email,
            'support_number' => $support_number,
            'logo_full_path' => $logo_full_path,
            'panel_login_background_img_full_path' => $panel_login_background_img_full_path,
            'google_place_api_key' => $google_place_api_key,
            'google_map_api_key' => $google_map_api_key,
            'googleMapApiKey' => $googleMapApiKey,
            'currency' => $currency,
            'website_url' => $website_url,
            'copyright_details' => $copyright_details,
            'delivery_boy_bonus_settings' => $delivery_boy_bonus_settings,
            'firebase' => [
                'apiKey' => $apiKey,
                'authDomain' => $authDomain,
                'projectId' => $projectId,
                'storageBucket' => $storageBucket,
                'messagingSenderId' => $messagingSenderId,
                'appId' => $appId,
                'measurementId' => $measurementId,
            ],
            'isDemoMode' => $isDemoMode,
        ]);
    }

    private ?array $setupSettings = null;

    public function setupGuide()
    {
        $this->setupSettings = Setting::whereIn('variable', [
            'smtp_host', 'smtp_port', 'smtp_from_mail',
            'firebase_apiKey', 'projectId', 'messagingSenderId', 'appId',
            'map_provider', 'google_map_api_key', 'google_place_api_key',
        ])->pluck('value', 'variable')->all();

        $steps = [
            $this->setupStep('country', __('setup_add_country'), __('setup_add_country_hint'),
                Country::where('status', 1)->exists(), '/countries'),

            $this->setupStep('zone', __('setup_add_zone'), __('setup_add_zone_hint'),
                Zone::query()->exists(), '/zones/create'),

            $this->setupStep('branch', __('setup_add_branch'), __('setup_add_branch_hint'),
                Branch::query()->exists(), '/branches/create'),

            $this->setupStep('home_builder', __('setup_home_builder'), __('setup_home_builder_hint'),
                HomeLayout::query()->exists(), '/home_builder'),

            $this->setupStep('smtp', __('setup_smtp'), __('setup_smtp_hint'),
                $this->setupSettingsFilled(['smtp_host', 'smtp_port', 'smtp_from_mail']), '/settings/smtp'),

            $this->setupFirebaseStep(),
            $this->setupMapStep(),
            $this->setupChatStep(),
            $this->setupCronStep(),
        ];

        $total = count($steps);
        $done = count(array_filter($steps, fn ($s) => $s['done']));

        return CommonHelper::responseWithData([
            'steps'       => $steps,
            'total'       => $total,
            'completed'   => $done,
            'pending'     => $total - $done,
            // The sidebar widget hides itself once this is true.
            'is_complete' => $done === $total,
            'percent'     => $total ? (int) round(($done / $total) * 100) : 100,
        ]);
    }

    private function setupStep(string $key, string $label, string $hint, bool $done, string $route): array
    {
        return compact('key', 'label', 'hint', 'done', 'route');
    }

    /** A setting counts as filled only when it is present AND not blank. */
    private function setupSettingsFilled(array $keys): bool
    {
        foreach ($keys as $key) {
            if ($this->setupSetting($key) === '') {
                return false;
            }
        }

        return true;
    }

    private function setupSetting(string $key): string
    {
        return trim((string) ($this->setupSettings[$key] ?? ''));
    }

    private function setupFirebaseStep(): array
    {
        $keys = $this->setupSettingsFilled(['firebase_apiKey', 'projectId', 'messagingSenderId', 'appId']);
        // Server-side push also needs the service account file the form uploads.
        $serviceAccount = file_exists(base_path('config/firebase.json'));

        return $this->setupStep('firebase', __('setup_firebase'), __('setup_firebase_hint'),
            $keys && $serviceAccount, '/settings/firebase');
    }

    /**
     * Only Google needs credentials: it wants the Map and Places keys. OpenStreetMap
     * tiles are free and keyless, so choosing OSM already completes this step.
     */
    private function setupMapStep(): array
    {
        $provider = $this->setupSetting('map_provider') ?: 'osm';
        $isGoogle = $provider === 'google';

        return $this->setupStep(
            'map',
            __('setup_map'),
            $isGoogle ? __('setup_map_hint_google') : __('setup_map_hint_osm'),
            $isGoogle
                ? $this->setupSettingsFilled(['google_map_api_key', 'google_place_api_key'])
                : true,
            '/settings/api'
        );
    }

    /**
     * Reverb credentials are generated during install, but a branch may switch to
     * Pusher — so check whichever driver is actually selected, and treat "no
     * driver chosen" as incomplete.
     */
    private function setupChatStep(): array
    {
        $driver = CommonHelper::getBroadcastDriver();

        if ($driver === 'reverb') {
            $done = $this->setupConfigFilled([
                'broadcasting.connections.reverb.app_id',
                'broadcasting.connections.reverb.key',
                'broadcasting.connections.reverb.secret',
            ]);
        } elseif ($driver === 'pusher') {
            $done = $this->setupConfigFilled([
                'broadcasting.connections.pusher.app_id',
                'broadcasting.connections.pusher.key',
                'broadcasting.connections.pusher.secret',
                'broadcasting.connections.pusher.options.cluster',
            ]);
        } else {
            $done = false;
        }

        return $this->setupStep('chat', __('setup_chat'), __('setup_chat_hint'), $done, '/settings/chat');
    }

    private function setupConfigFilled(array $paths): bool
    {
        foreach ($paths as $path) {
            if (trim((string) config($path)) === '') {
                return false;
            }
        }

        return true;
    }

    /**
     * The scheduler writes a heartbeat every minute; anything older than ~2.5
     * minutes means the server crontab is not firing.
     */
    private function setupCronStep(): array
    {
        $heartbeat = Cache::get('cron_last_heartbeat');
        $age = $heartbeat ? Carbon::parse($heartbeat)->diffInSeconds(now()) : null;

        return $this->setupStep('cron', __('setup_cron'), __('setup_cron_hint'),
            $age !== null && $age < 150, '/settings/cron_jobs');
    }
}
