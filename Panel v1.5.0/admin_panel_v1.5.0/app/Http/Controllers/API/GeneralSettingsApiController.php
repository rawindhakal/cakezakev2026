<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Helpers\EnvHelper;
use App\Http\Controllers\Controller;
use App\Jobs\SendAppVersionUpdateNotification;
use App\Models\ApiCallTracking;
use Illuminate\Http\Request;
use App\Models\Setting;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Config;

class GeneralSettingsApiController extends Controller
{
    /** Realtime chat drivers the panel can switch between. */
    private const BROADCAST_DRIVERS = ['reverb', 'pusher'];

    public function index()
    {
        $countries = json_decode(file_get_contents(base_path('config/countries_currency.json')), true);
        $store_settingsArray = array(
            "system_configurations" => 1,
            "system_configurations_id" => "13",
            "app_name" => "",
            "support_number" => "",
            "support_email" => "",
            "order_prefix" => "",
            "return_request_prefix" => "",
            "invoice_prefix" => "",

            // App version control — one set per app (customer / delivery boy).
            "is_version_system_on_customer" => 0,
            "required_force_update_customer" => 0,
            "current_version_customer" => "1.0.0",
            "ios_is_version_system_on_customer" => 0,
            "ios_required_force_update_customer" => 0,
            "ios_current_version_customer" => "1.0.0",

            "is_version_system_on_delivery_boy" => 0,
            "required_force_update_delivery_boy" => 0,
            "current_version_delivery_boy" => "1.0.0",
            "ios_is_version_system_on_delivery_boy" => 0,
            "ios_required_force_update_delivery_boy" => 0,
            "ios_current_version_delivery_boy" => "1.0.0",

            // Tick once and every later version bump announces itself; untick to stay quiet.
            "notify_version_update_customer" => 0,
            "notify_version_update_delivery_boy" => 0,

            "customer_light_mode_color" => "#FE3C5E",
            "customer_dark_mode_color" => "#1A2A3A",
            "delivery_boy_light_mode_color" => "#FE3C5E",
            "delivery_boy_dark_mode_color" => "#1A2A3A",

            "logo" => "",
            "admin_favicon" => "",
            "copyright_details" => "",
            "branch_address" => "",
            "store_map_url" => "",
            'map_latitude' => "",
            "map_longitude" => "",
            "currency" => "",
            "currency_code" => "",
            "decimal_point" => "",
            "default_city_id" => 0,

            "max_cart_items_count" => "",
            "product_rating" => 0,
            // Does the storefront offer "do you deliver to my pincode?" at all.
            "pincode_delivery_check" => 0,
            "date_format" => "d-m-Y",
            "time_format" => "h:i A",

            "delivery_boy_bonus_settings" => 0,
            "delivery_boy_bonus_type" => 0,
            "delivery_boy_bonus_percentage" => 0,
            "delivery_boy_bonus_min_amount" => 0,
            "delivery_boy_bonus_max_amount" => 0,

            "from_mail" => "",
            "reply_to" => "",
            "generate_otp" => 0,

            "mailer" => "smtp",
            "smtp_from_mail" => "",
            "smtp_reply_to" => "",
            "smtp_email_password" => "",
            "smtp_host" => "",
            "smtp_port" => "",
            "smtp_content_type" => "",
            "smtp_encryption_type" => "",
            "google_place_api_key" => "",
            "google_map_api_key" => "",
            "apiKey" => "",
            "googleMapApiKey" => "",
            "text_gen_key" => "",
            "map_provider" => "osm",
            "playstore_url" => "",
            "appstore_url" => "",
            "delivery_boy_playstore_url" => "",
            "delivery_boy_appstore_url" => "",
            "deeplink_schema" => "",
            "phone_login" => "",
            "google_login" => "",
            "apple_login" => "",
            "email_login" => "",
            "panel_login_background_img",
            "notification_delay_after_cart_addition",
            "notification_interval",
            "notification_stop_time",
        );
        $variables = array_keys($store_settingsArray);
        $store_settings = Setting::whereIn('variable', $variables)->get();

        $login_settingsArray = array(
            "phone_login" => "",
            "google_login" => "",
            "apple_login" => "",
            "email_login" => "",
            "phone_auth_otp" => "",
            "phone_auth_password" => "",
            "firebase_authentication" => "",
            "custom_sms_gateway_otp_based" => "",
            "password_min_length" => "",
            "password_max_length" => "",
            "password_require_uppercase" => "",
            "password_require_lowercase" => "",
            "password_require_number" => "",
            "password_require_special" => "",
            "panel_two_factor" => "",
            "panel_two_factor_branch_users" => "",
            "panel_two_factor_expiry" => "",
        );
        $login_variables = array_keys($login_settingsArray);
        $login_settings = Setting::whereIn('variable', $login_variables)->get();

        // Refer & Earn is country-wise now (configured on the Country form).

        $store_settings = $this->maskConfidentialSettings($store_settings);
        $login_settings = $this->maskConfidentialSettings($login_settings);

        $data = array(
            "store_settingsObject" => $store_settingsArray,
            "currency_code" => $countries,
            "store_settings" => $store_settings,
            "login_settings" => $login_settings,
            "courier_available" => count(app(\App\Plugins\Registries\ShippingProviderRegistry::class)->usable('ecommerce')) > 0,
        );
        return CommonHelper::responseWithData($data);
    }

    public function getPasswordPolicy()
    {
        $min = (int) (Setting::get_value('password_min_length') ?: 0);
        $bool = fn ($key) => in_array((string) Setting::get_value($key), ['1', 'true', 'on'], true) ? 1 : 0;
        return CommonHelper::responseWithData([
            'min_length'        => $min > 0 ? $min : 5,
            'max_length'        => (int) (Setting::get_value('password_max_length') ?: 0),
            'require_uppercase' => $bool('password_require_uppercase'),
            'require_lowercase' => $bool('password_require_lowercase'),
            'require_number'    => $bool('password_require_number'),
            'require_special'   => $bool('password_require_special'),
        ]);
    }

    public function clearCache()
    {
        $data = [];
        foreach (['cache:clear' => 'cache', 'config:clear' => 'config', 'route:clear' => 'route', 'view:clear' => 'view'] as $command => $key) {
            Artisan::call($command);
            $data[$key] = Artisan::output();
        }
        return CommonHelper::responseSuccessWithData('Cache cleared successfully!', $data);
    }

    public function save_login_setting(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'at_least_one' => 'At least one of phone login or google login must be enabled.',
        ]);

        $validator->after(function ($validator) use ($request) {
            // Validate that at least one of phone_login or google_login is enabled
            if (!$request->phone_login && !$request->google_login) {
                $validator->errors()->add('phone_login', 'At least one of phone login or google login must be enabled.');
                $validator->errors()->add('google_login', 'At least one of phone login or google login must be enabled.');
            }

            // Additional validation if phone_login is enabled
            if ($request->phone_login) {
                if (!$request->firebase_authentication && !$request->custom_sms_gateway_otp_based) {
                    $validator->errors()->add('firebase_authentication', 'When phone login is enabled, either Firebase Authentication or Custom SMS Gateway OTP Based must be enabled.');
                    $validator->errors()->add('custom_sms_gateway_otp_based', 'When phone login is enabled, either Firebase Authentication or Custom SMS Gateway OTP Based must be enabled.');
                }
            }

            if ($request->panel_two_factor) {
                $smtp = CommonHelper::smtpCheck();
                if (!$smtp['ok']) {
                    $validator->errors()->add(
                        'panel_two_factor',
                        __('panel_two_factor_smtp_check_failed', ['error' => $smtp['message']])
                    );
                }
            }

            // Custom SMS Gateway OTP needs an active SMS gateway to actually send the OTP.
            if ($request->custom_sms_gateway_otp_based) {
                $smsGateway = Setting::where('variable', 'sms_gateway')->value('value');
                if (empty(trim((string) $smsGateway))) {
                    $validator->errors()->add('custom_sms_gateway_otp_based', 'Enable an SMS gateway in SMS Settings before turning on Custom SMS Gateway OTP based login.');
                }
            }
        });

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        foreach ($request->all() as $key => $value) {
            $value = $value ?? " ";
            $setting = Setting::where('variable', $key)->first();
            if ($setting) {
                $setting->variable = $key;
                $setting->value = $value;

                $setting->save();
            } else {
                $setting = new Setting();
                $setting->variable = $key;
                $setting->value = $value;

                $setting->save();
            }
        }
        return CommonHelper::responseSuccess(__('login_settings_saved_successfully'));
    }

    /**
     * Save business basic settings (logo, app name, support details, etc.)
     */
    public function save_store_basic_setting(Request $request)
    {
        // The business's own address lives with the business basics (a single
        // translatable field, not a settings area of its own).
        $translatable = ['copyright_details', 'branch_address'];


        // Validate only if default language fields are empty
        $validator = Validator::make($request->all(), [
            'logo' => $request->hasFile('logo') ? 'mimes:jpeg,jpg,png,gif,svg,webp' : '',
            'admin_favicon' => $request->hasFile('admin_favicon') ? 'mimes:jpeg,jpg,png,gif,ico,svg,webp' : '',
            'panel_login_background_img' => $request->hasFile('panel_login_background_img') ? 'mimes:jpeg,jpg,png,gif,svg,webp' : '',
            'copyright_details' . config('app.default_language') => 'required|string',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $store_basic_variables = [
            'system_configurations',
            'system_configurations_id',
            'app_name',
            'support_number',
            'support_email',
            'logo',
            'admin_favicon',
            'panel_login_background_img',
            'copyright_details',
            'branch_address',
            'store_map_url',
            'max_cart_items_count',
            'product_rating',
            'pincode_delivery_check',
            'admin_theme_color',
            'order_prefix',
            'return_request_prefix',
            'invoice_prefix'
        ];

        foreach ($store_basic_variables as $key) {

            $setting = Setting::firstOrNew(['variable' => $key]);

            // FILES (directory is the setting key; old stored file is replaced/deleted)
            if ($request->hasFile($key)) {
                $setting->value = CommonHelper::uploadFile($request, $key, $key, $setting->value);
                $setting->save();
                continue;
            }

            // TRANSLATABLE
            if (in_array($key, $translatable) && $request->has($key)) {
                $setting->value = $this->cleanMultilangValue($request->$key, $setting->value);
                $setting->save();
                continue;
            }

            // NORMAL
            if ($request->has($key)) {
                $setting->value = $key === 'store_map_url'
                    ? $this->mapLocationUrl($request->$key)
                    : trim($request->$key);
                $setting->save();
            }
        }

        return CommonHelper::responseSuccess('store_settings_saved_successfully');
    }

    /** A Google Maps link to the branch's spot (Share → Copy link); anything else is dropped. */
    private function mapLocationUrl($raw): string
    {
        $raw = trim((string) $raw);
        if ($raw === '') {
            return '';
        }
        $host = strtolower((string) parse_url($raw, PHP_URL_HOST));
        $path = (string) parse_url($raw, PHP_URL_PATH);
        $ok = str_starts_with(strtolower($raw), 'https://') && (
            (preg_match('#^(www\.)?google\.[a-z.]+$#', $host) && str_starts_with($path, '/maps'))
            || preg_match('#^maps\.google\.[a-z.]+$#', $host)
            || $host === 'maps.app.goo.gl'
            || $host === 'goo.gl'
        );

        return $ok ? $raw : '';
    }

    private function cleanMultilangValue($value, $oldValue = null)
    {
        if (empty($value)) {
            return $oldValue ?? "";
        }

        $decoded = json_decode($value, true);
        $existing = json_decode($oldValue, true) ?? [];

        if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
            foreach ($decoded as $lang => $text) {
                if ($text === null || $text === '') {
                    continue; // preserve old translation
                }

                $text = preg_replace('/\r\n|\r|\n/', ' ', $text);
                $text = preg_replace('/\s+/', ' ', $text);
                $existing[$lang] = trim($text);
            }

            return json_encode(
                $existing,
                JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
            );
        }

        return trim($value);
    }


    /**
     * Save address settings (branch address, coordinates, currency, timezone, etc.)
     */
    public function save_address_setting(Request $request)
    {
        $translatable = ['branch_address'];

        $address_variables = [
            'branch_address',
            'map_latitude',
            'map_longitude',
            'currency',
            'currency_code',
            'decimal_point',
            'default_city_id'
        ];

        foreach ($address_variables as $key) {

            if (!array_key_exists($key, $request->all())) {
                continue;
            }

            $setting = Setting::firstOrNew(['variable' => $key]);

            if (in_array($key, $translatable)) {
                $value = $this->cleanMultilangValue(
                    $request->$key,
                    $setting->value
                );
                $setting->value = $value !== '' ? $value : json_encode([]);
            } else {
                $setting->value = trim($request->$key ?? '');
            }

            $setting->save();
        }

        return CommonHelper::responseSuccess('address_settings_saved_successfully');
    }

    /**
     * Save other settings (cart limits, order amounts, stock limits, etc.)
     */
    public function save_other_setting(Request $request)
    {
        $other_variables = [
            'max_cart_items_count',
            'product_rating',
            'date_format',
            'time_format',
            'country_code',
            'admin_theme_color',
        ];

        foreach ($request->all() as $key => $value) {
            if (in_array($key, $other_variables)) {
                $value = $value ?? " ";
                $setting = Setting::where('variable', $key)->first();

                if ($setting) {
                    $setting->variable = $key;
                    $setting->value = $value;
                    $setting->save();
                } else {
                    $setting = new Setting();
                    $setting->variable = $key;
                    $setting->value = $value;
                    $setting->save();
                }
            }
        }

        return CommonHelper::responseSuccess('other_settings_saved_successfully');
    }

    /**
     * Save delivery boy settings (bonus settings, OTP system, etc.)
     */
    public function save_delivery_boy_setting(Request $request)
    {
        $delivery_boy_variables = [
            'delivery_boy_bonus_settings',
            'delivery_boy_bonus_type',
            'delivery_boy_bonus_percentage',
            'delivery_boy_bonus_min_amount',
            'delivery_boy_bonus_max_amount',
            'generate_otp'
        ];

        foreach ($request->all() as $key => $value) {
            if (in_array($key, $delivery_boy_variables)) {
                $value = $value ?? " ";
                $setting = Setting::where('variable', $key)->first();

                if ($setting) {
                    $setting->variable = $key;
                    $setting->value = $value;
                    $setting->save();
                } else {
                    $setting = new Setting();
                    $setting->variable = $key;
                    $setting->value = $value;
                    $setting->save();
                }
            }
        }

        return CommonHelper::responseSuccess('delivery_boy_settings_saved_successfully');
    }

    /**
     * Save deeplink settings (URL schema used by the mobile apps).
     */
    public function save_deeplink_setting(Request $request)
    {
        $deeplink_variables = [
            'deeplink_schema',
        ];

        foreach ($request->all() as $key => $value) {
            if (in_array($key, $deeplink_variables)) {
                $setting = Setting::where('variable', $key)->first() ?? new Setting();
                $setting->variable = $key;
                $setting->value = $value ?? '';
                $setting->save();
            }
        }
        return CommonHelper::responseSuccess('deeplink_settings_saved_successfully');
    }

    /**
     * Save app settings (app modes, version control, branch URLs, etc.)
     */
    public function save_app_setting(Request $request)
    {
        $appVariables = [
            'playstore_url',
            'appstore_url',
            'delivery_boy_playstore_url',
            'delivery_boy_appstore_url',
            'is_version_system_on_customer',
            'required_force_update_customer',
            'current_version_customer',
            'ios_is_version_system_on_customer',
            'ios_required_force_update_customer',
            'ios_current_version_customer',
            'is_version_system_on_delivery_boy',
            'required_force_update_delivery_boy',
            'current_version_delivery_boy',
            'ios_is_version_system_on_delivery_boy',
            'ios_required_force_update_delivery_boy',
            'ios_current_version_delivery_boy',
            'notify_version_update_customer',
            'notify_version_update_delivery_boy',
            'customer_light_mode_color',
            'customer_dark_mode_color',
            'delivery_boy_light_mode_color',
            'delivery_boy_dark_mode_color',
            'delivery_boy_bonus_settings',
            'delivery_boy_bonus_type',
            'delivery_boy_bonus_percentage',
            'delivery_boy_bonus_min_amount',
            'delivery_boy_bonus_max_amount',
            'generate_otp',
        ];

        $translatable = [];

        // Read the versions BEFORE the loop overwrites them — "did this change?" is the
        // only question that cannot be asked afterwards.
        $versionsBefore = [];
        foreach (self::VERSION_KEYS as $map) {
            foreach ($map as $key) {
                $versionsBefore[$key] = (string) Setting::get_value($key);
            }
        }

        foreach ($appVariables as $key) {
            if (!$request->has($key)) continue;

            $setting = Setting::where('variable', $key)->first() ?? new Setting();
            $setting->variable = $key;

            if (in_array($key, $translatable)) {

                $setting->value = $this->cleanMultilangValue(
                    $request->$key,
                    $setting->value
                );
            } else {
                $value = $request->$key;
                $setting->value = ($value === null || $value === 'null') ? '' : $value;
            }

            $setting->save();
        }

        $this->announceVersionChange($request, $versionsBefore);

        return CommonHelper::responseSuccess('app_settings_saved_successfully');
    }

    /** Which setting holds each app's version, per platform. */
    private const VERSION_KEYS = [
        'customer' => [
            'android' => 'current_version_customer',
            'ios'     => 'ios_current_version_customer',
        ],
        'delivery_boy' => [
            'android' => 'current_version_delivery_boy',
            'ios'     => 'ios_current_version_delivery_boy',
        ],
    ];

    /**
     * Tell an app's users about a new build — but only on a real change.
     *
     * Three conditions, all required: the card's notify box is ticked, that platform's
     * version system is ON (with it off the app never asks about versions, so there is
     * nothing to update to), and the version string actually differs from what was
     * stored. Saving the page again with the same numbers sends nothing, which is what
     * keeps a colour tweak from mailing the whole customer base.
     *
     * Never allowed to fail the save: the settings are already written by this point.
     */
    private function announceVersionChange(Request $request, array $versionsBefore): void
    {
        try {
            foreach (self::VERSION_KEYS as $audience => $map) {
                if ((int) $request->input('notify_version_update_' . $audience, 0) !== 1) {
                    continue;
                }

                $changed = [];
                foreach ($map as $platform => $key) {
                    if (!$request->has($key)) {
                        continue;
                    }
                    $toggle = ($platform === 'ios' ? 'ios_is_version_system_on_' : 'is_version_system_on_') . $audience;
                    if ((int) $request->input($toggle, Setting::get_value($toggle)) !== 1) {
                        continue;
                    }
                    $new = trim((string) $request->input($key));
                    if ($new === '' || $new === ($versionsBefore[$key] ?? '')) {
                        continue;
                    }
                    $changed[$platform] = $new;
                }

                if ($changed === []) {
                    continue;
                }

                $job = new SendAppVersionUpdateNotification($audience, $changed);
                config('queue.default') === 'sync' ? dispatch($job)->afterResponse() : dispatch($job);
            }
        } catch (\Throwable $e) {
            Log::error('announceVersionChange: ' . $e->getMessage());
        }
    }

    private array $maintenanceSurfaces = [
        'website_mode'          => 'web',
        'app_mode_customer'     => 'customer',
        'app_mode_delivery_boy' => 'delivery_boy',
    ];

    /** Read all maintenance settings (mode, multilang remark, schedule) per surface. */
    public function maintenance_setting()
    {
        $out = [];
        foreach ($this->maintenanceSurfaces as $toggle => $surface) {
            $remarkRaw = Setting::where('variable', $toggle . '_remark')->value('value');
            $remark = [];
            if (!empty($remarkRaw)) {
                $decoded = json_decode($remarkRaw, true);
                $remark = is_array($decoded) ? $decoded : ['en' => (string) $remarkRaw];
            }
            $out[$surface] = [
                'mode'   => (int) (Setting::get_value($toggle) ?: 0),
                'remark' => (object) $remark,
                'start'  => (string) (Setting::get_value($toggle . '_start') ?: ''),
                'end'    => (string) (Setting::get_value($toggle . '_end') ?: ''),
            ];
        }
        return CommonHelper::responseWithData($out);
    }

    /**
     * Save maintenance settings for all three surfaces. Toggle changes broadcast
     * live; the remark is multilanguage; start/end drive the scheduler.
     */
    public function save_maintenance_setting(Request $request)
    {
        foreach ($this->maintenanceSurfaces as $toggle => $surface) {
            // Multilang remark (merged, whitespace-normalised).
            $remarkKey = $toggle . '_remark';
            if ($request->has($remarkKey)) {
                $s = Setting::where('variable', $remarkKey)->first() ?? new Setting();
                $s->variable = $remarkKey;
                $s->value = $this->cleanMultilangValue($request->$remarkKey, $s->value);
                $s->save();
            }

            // Schedule start/end (plain datetime strings; empty clears the schedule).
            foreach (['_start', '_end'] as $suffix) {
                $key = $toggle . $suffix;
                if ($request->has($key)) {
                    $s = Setting::where('variable', $key)->first() ?? new Setting();
                    $s->variable = $key;
                    $v = $request->$key;
                    $s->value = ($v === null || $v === 'null') ? '' : $v;
                    $s->save();
                }
            }

            // Toggle last so the broadcast carries the just-saved remark.
            if ($request->has($toggle)) {
                CommonHelper::applyMaintenance($toggle, (int) $request->$toggle);
            }
        }

        return CommonHelper::responseSuccess('maintenance_settings_saved_successfully');
    }

    /**
     * Save SMTP mail settings
     */
    public function save_smtp_mail_setting(Request $request)
    {
        $smtp_variables = [
            'mailer',
            'smtp_from_mail',
            'smtp_reply_to',
            'smtp_email_password',
            'smtp_host',
            'smtp_port',
            'smtp_content_type',
            'smtp_encryption_type'
        ];

        foreach ($request->all() as $key => $value) {
            if (in_array($key, $smtp_variables)) {
                $value = $value ?? " ";
                $setting = Setting::where('variable', $key)->first();

                if ($setting) {
                    $setting->variable = $key;
                    $setting->value = $value;
                    $setting->save();
                } else {
                    $setting = new Setting();
                    $setting->variable = $key;
                    $setting->value = $value;
                    $setting->save();
                }
            }
        }

        return CommonHelper::responseSuccess('smtp_mail_settings_saved_successfully');
    }

    /**
     * Save third party API credentials
     */
    public function save_third_party_api_setting(Request $request)
    {
        $api_variables = [
            'google_place_api_key', 'google_map_api_key', 'apiKey', 'googleMapApiKey', 'text_gen_key', 'map_provider',
            'clarity_project_id_panel', 'clarity_status_panel',
            'clarity_project_id_delivery_boy', 'clarity_status_delivery_boy',
            'clarity_project_id_web', 'clarity_status_web',
            'clarity_project_id_customer', 'clarity_status_customer',
        ];

        foreach ($request->all() as $key => $value) {
            if (in_array($key, $api_variables)) {
                $value = $value ?? " ";

                $setting = Setting::where('variable', $key)->first();

                if ($setting) {
                    $setting->variable = $key;
                    $setting->value = $value;
                    $setting->save();
                } else {
                    $setting = new Setting();
                    $setting->variable = $key;
                    $setting->value = $value;
                    $setting->save();
                }
            }
        }

        return CommonHelper::responseSuccess('third_party_api_settings_saved_successfully');
    }

    /** Confidential setting variables blanked in demo mode (super admin exempt). */
    private array $confidentialSettingKeys = [
        'smtp_email_password', 'apiKey', 'googleMapApiKey', 'google_map_api_key',
        'google_place_api_key', 'text_gen_key', 'android_map_key', 'ios_map_key',
        'firebase_authentication', 'reverb_app_secret', 'pusher_app_secret',
    ];

    /** Blank confidential values on a Setting collection when demo masking applies. */
    private function maskConfidentialSettings($settings)
    {
        if (!shouldDemoMask()) {
            return $settings;
        }
        foreach ($settings as $setting) {
            if (in_array($setting->variable, $this->confidentialSettingKeys, true) && !empty($setting->value)) {
                $setting->value = '';
            }
        }
        return $settings;
    }

    public function getAboutUs()
    {
        return CommonHelper::responseWithData(Setting::where('variable', 'about_us')->first());
    }

    public function saveAboutUs(Request $request)
    {
        $this->saveMultilangPage('about_us', $request->about_us ?? '');
        return CommonHelper::responseSuccess('about_us_saved_successfully');
    }

    public function printAboutUs(Request $request)
    {
        echo $this->multilangPageContent(Setting::get_value('about_us'), $request->input('lang', 'en'));
    }

    public function getContactUs()
    {
        return CommonHelper::responseWithData(Setting::where('variable', 'contact_us')->first());
    }

    public function saveContactUs(Request $request)
    {
        $this->saveMultilangPage('contact_us', $request->contact_us ?? '');
        return CommonHelper::responseSuccess('contact_us_saved_successfully');
    }

    public function printContactUs(Request $request)
    {
        echo $this->multilangPageContent(Setting::get_value('contact_us'), $request->input('lang', 'en'));
    }

    /** Store a language-wise JSON page value (whitespace-normalised), or plain text. */
    private function saveMultilangPage(string $variable, $raw): void
    {
        $setting = Setting::where('variable', $variable)->first() ?? new Setting();
        $setting->variable = $variable;
        $setting->value = $this->cleanMultilangPage($raw);
        $setting->save();
    }

    private function cleanMultilangPage($value): string
    {
        if (empty($value)) {
            return '';
        }
        $decoded = json_decode($value, true);
        if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
            $clean = [];
            foreach ($decoded as $lang => $content) {
                $content = preg_replace('/\r\n|\r|\n/', ' ', (string) $content);
                $content = preg_replace('/\s+/', ' ', $content);
                $clean[$lang] = trim($content);
            }
            return json_encode($clean, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }
        return trim(preg_replace('/\s+/', ' ', (string) $value));
    }

    /** Resolve the requested language's content (falls back to the first available). */
    private function multilangPageContent($value, string $lang): string
    {
        if (empty($value)) {
            return '';
        }
        $decoded = json_decode($value, true);
        if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
            $content = $decoded[$lang] ?? '';
            if ($content === '' || $content === null) {
                $content = reset($decoded);
            }
            return str_replace(["\r", "\n"], '', (string) $content);
        }
        return str_replace(["\r", "\n"], '', (string) $value);
    }

    public function getBroadcastSetting()
    {
        $driver = config('broadcasting.default');
        if (!in_array($driver, self::BROADCAST_DRIVERS, true)) {
            $driver = 'reverb';
        }

        // Blank the app secrets in demo mode (super admin exempt).
        $mask = fn ($value) => shouldDemoMask() ? '' : (string) $value;

        return CommonHelper::responseWithData([
            'broadcast_driver' => $driver,

            'reverb_app_id'     => (string) config('broadcasting.connections.reverb.app_id'),
            'reverb_app_key'    => (string) config('broadcasting.connections.reverb.key'),
            'reverb_app_secret' => $mask(config('broadcasting.connections.reverb.secret')),
            'reverb_host'       => (string) config('broadcasting.connections.reverb.options.host'),
            'reverb_port'       => (string) config('broadcasting.connections.reverb.options.port'),
            'reverb_scheme'     => (string) config('broadcasting.connections.reverb.options.scheme'),

            'pusher_app_id'      => (string) config('broadcasting.connections.pusher.app_id'),
            'pusher_app_key'     => (string) config('broadcasting.connections.pusher.key'),
            'pusher_app_secret'  => $mask(config('broadcasting.connections.pusher.secret')),
            'pusher_app_cluster' => (string) config('broadcasting.connections.pusher.options.cluster'),
        ]);
    }

    /**
     * Save the realtime chat driver + its credentials to .env.
     */
    public function save_broadcast_setting(Request $request)
    {
        $driver = $request->input('broadcast_driver');

        $rules = ['broadcast_driver' => 'required|in:' . implode(',', self::BROADCAST_DRIVERS)];

        // Only the active driver's credentials are required — the other one may be
        // left blank while it's switched off.
        if ($driver === 'reverb') {
            $rules += [
                'reverb_app_id'     => 'required|string',
                'reverb_app_key'    => 'required|string',
                'reverb_app_secret' => 'required|string',
                'reverb_host'       => 'required|string',
                'reverb_port'       => 'required|integer|min:1|max:65535',
                'reverb_scheme'     => 'required|in:http,https',
            ];
        } elseif ($driver === 'pusher') {
            $rules += [
                'pusher_app_id'      => 'required|string',
                'pusher_app_key'     => 'required|string',
                'pusher_app_secret'  => 'required|string',
                'pusher_app_cluster' => 'required|string',
            ];
        }

        $validator = Validator::make($request->all(), $rules);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $env = ['BROADCAST_DRIVER' => $driver];

        // Persist whatever was supplied for BOTH drivers, so switching back later
        // doesn't lose the other driver's credentials.
        $map = [
            'reverb_app_id'      => 'REVERB_APP_ID',
            'reverb_app_key'     => 'REVERB_APP_KEY',
            'reverb_app_secret'  => 'REVERB_APP_SECRET',
            'reverb_host'        => 'REVERB_HOST',
            'reverb_port'        => 'REVERB_PORT',
            'reverb_scheme'      => 'REVERB_SCHEME',
            'pusher_app_id'      => 'PUSHER_APP_ID',
            'pusher_app_key'     => 'PUSHER_APP_KEY',
            'pusher_app_secret'  => 'PUSHER_APP_SECRET',
            'pusher_app_cluster' => 'PUSHER_APP_CLUSTER',
        ];

        foreach ($map as $field => $envKey) {
            if ($request->has($field)) {
                $env[$envKey] = (string) $request->input($field, '');
            }
        }

        if (!EnvHelper::set($env)) {
            return CommonHelper::responseError(__('env_file_is_not_writable'));
        }

        // The frontend reads these through config() in the blade, so the cached
        // config has to go or the panel keeps talking to the old driver.
        Artisan::call('config:clear');

        return CommonHelper::responseSuccess('broadcast_settings_saved_successfully');
    }

    /**
     * Save cart settings
     */
    public function save_cart_setting(Request $request)
    {
        $cart_variables = [
            'cart_notification',
            'notification_delay_after_cart_addition',
            'notification_interval',
            'notification_stop_time'
        ];

        foreach ($request->all() as $key => $value) {
            if (in_array($key, $cart_variables)) {
                $value = $value ?? " ";
                $setting = Setting::where('variable', $key)->first();

                if ($setting) {
                    $setting->variable = $key;
                    $setting->value = $value;
                    $setting->save();
                } else {
                    $setting = new Setting();
                    $setting->variable = $key;
                    $setting->value = $value;
                    $setting->save();
                }
            }
        }

        return CommonHelper::responseSuccess('cart_settings_saved_successfully');
    }

    /** Keys behind Settings → Invoice, with the panel's defaults. */
    private const INVOICE_SETTING_KEYS = [
        'invoice_paper_size'      => 'a4',
        'invoice_custom_width'    => 80,
        'invoice_custom_height'   => 297,
        'invoice_font_size'       => 11,
        'invoice_bold_text'       => 0,
        'invoice_color_mode'      => 'color',
        'invoice_show_logo'       => 1,
        'invoice_logo'            => '',
        'invoice_logo_height'     => 30,
        'invoice_header_note'     => '',
        'invoice_footer_note'     => 'This is a computer-generated invoice and does not require a signature.',
        'invoice_show_thanks'     => 1,
        'invoice_thanks_text'     => 'Thank you for your business',
        'invoice_show_tax_summary' => 1,
        'invoice_show_signature'  => 0,
        'invoice_signature'       => '',
        'invoice_signature_label' => 'Authorised Signatory',

        'receipt_default_size'    => 'a4',
        'receipt_font_size'       => 11,
        'receipt_bold_text'       => 0,
        'receipt_show_logo'       => 1,
        'receipt_show_products'   => 1,
        'receipt_show_prices'     => 'auto',
        'receipt_show_signature'  => 0,
        'receipt_signature_label' => 'Received by',
        'receipt_footer_note'     => '',
    ];

    /** Current invoice / delivery-receipt print settings + the size options to offer. */
    public function invoiceSettings()
    {
        $stored = Setting::whereIn('variable', array_keys(self::INVOICE_SETTING_KEYS))
            ->pluck('value', 'variable');

        $settings = [];
        foreach (self::INVOICE_SETTING_KEYS as $key => $default) {
            $value = $stored[$key] ?? null;
            $settings[$key] = ($value === null || $value === '') ? $default : $value;
        }

        // The two uploads are stored as disk paths; the panel needs a URL to preview.
        foreach (['invoice_logo', 'invoice_signature'] as $key) {
            $path = (string) ($stored[$key] ?? '');
            $settings[$key . '_url'] = $path !== '' ? asset('storage/' . $path) : '';
        }

        $sizes = fn (array $list) => collect($list)
            ->map(fn ($p, $k) => ['value' => $k, 'label' => $p['label']])
            ->values()->all();

        return CommonHelper::responseWithData([
            'settings'      => $settings,
            'invoice_sizes' => $sizes(CommonHelper::INVOICE_SIZES),
            'receipt_sizes' => $sizes(CommonHelper::RECEIPT_SIZES),
        ]);
    }

    /**
     * Render a sample invoice / delivery receipt from the values currently in the form,
     * saved or not, so the admin can see the paper size and options before committing.
     * The newest order is used as the sample; a freshly picked logo or signature is read
     * straight from the upload so it shows up too.
     */
    public function previewInvoiceSetting(Request $request)
    {
        $doc = $request->input('doc') === 'receipt' ? 'receipt' : 'invoice';

        $files = [];
        foreach (['invoice_logo', 'invoice_signature'] as $key) {
            if ($request->hasFile($key)) {
                $files[$key] = $request->file($key)->getRealPath();
            }
            if ($request->boolean('remove_' . $key)) {
                $files[$key] = '';
            }
        }

        $cfg = CommonHelper::documentSettingsFromArray($request->all(), $files);

        /* A made-up order, not the latest real one: the preview is about paper and
           layout, and it must not show a customer's address on screen (and has to work
           before the shop has any orders). */
        $data = CommonHelper::sampleDocumentData();

        /* mode=html is the panel's live preview: the same blade rendered for the screen
           instead of mPDF, so every keystroke can refresh it without running the PDF
           engine. mode=pdf (the default) returns the real document. */
        if ($request->input('mode') === 'html') {
            return CommonHelper::responseWithData(
                $doc === 'receipt'
                    ? CommonHelper::deliveryReceiptHtml($data, $cfg['receipt'])
                    : CommonHelper::invoiceHtml($data, $cfg['invoice'])
            );
        }

        return $doc === 'receipt'
            ? CommonHelper::deliveryReceiptPdf($data, 'preview', $cfg['receipt']['size'], $cfg['receipt'])
            : CommonHelper::invoicePdfFromData($data, 'preview', $cfg['invoice']['size'], $cfg['invoice']);
    }

    public function save_invoice_setting(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'invoice_logo'      => $request->hasFile('invoice_logo') ? 'mimes:jpeg,jpg,png,gif,svg,webp|max:1024' : '',
            'invoice_signature' => $request->hasFile('invoice_signature') ? 'mimes:jpeg,jpg,png,gif,svg,webp|max:1024' : '',
            'invoice_paper_size' => 'nullable|in:' . implode(',', array_keys(CommonHelper::INVOICE_SIZES)),
            'receipt_default_size' => 'nullable|in:' . implode(',', array_keys(CommonHelper::RECEIPT_SIZES)),
            'receipt_show_prices' => 'nullable|in:auto,always,never',
            'invoice_color_mode'  => 'nullable|in:color,mono',
            'invoice_font_size'   => 'nullable|numeric|min:6|max:20',
            'receipt_font_size'   => 'nullable|numeric|min:6|max:20',
            'invoice_logo_height' => 'nullable|numeric|min:10|max:120',
            'invoice_custom_width'  => 'nullable|numeric|min:40|max:400',
            'invoice_custom_height' => 'nullable|numeric|min:50|max:1200',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        foreach (array_keys(self::INVOICE_SETTING_KEYS) as $key) {
            $setting = Setting::firstOrNew(['variable' => $key]);

            // FILES (the setting key doubles as the upload directory)
            if ($request->hasFile($key)) {
                $setting->value = CommonHelper::uploadFile($request, $key, $key, $setting->value);
                $setting->save();
                continue;
            }
            // An explicit "remove" clears the stored image.
            if ($request->boolean('remove_' . $key)) {
                $setting->value = '';
                $setting->save();
                continue;
            }
            if ($request->has($key)) {
                $setting->value = trim((string) $request->$key);
                $setting->save();
            }
        }

        return CommonHelper::responseSuccess('invoice_settings_saved_successfully');
    }

    public function system_update(Request $request)
    {
        if (shouldDemoMask()) {
            return CommonHelper::responseError('this_action_is_disabled_in_demo_mode');
        }

        $validator = Validator::make($request->all(), [
            'update_file'   => 'required|file|max:1048576',
            'purchase_code' => 'required|string',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        if (! $this->verifyPurchaseCode(trim((string) $request->purchase_code), $request->getSchemeAndHttpHost())) {
            return CommonHelper::responseError('invalid_purchase_code');
        }

        $file = $request->file('update_file');
        if (strtolower($file->getClientOriginalExtension()) !== 'zip') {
            return CommonHelper::responseError('please_upload_a_valid_zip_file');
        }

        if (! class_exists(\ZipArchive::class)) {
            return CommonHelper::responseError('php_zip_extension_is_required');
        }

        // fixed structure  cakezake-update-<x.y.z>.zip  — reject anything else.
        if (! preg_match('/^cakezake-update-(\d+\.\d+\.\d+)\.zip$/i', $file->getClientOriginalName(), $m)) {
            return CommonHelper::responseError('invalid_update_package_name');
        }
        $newVersion = $m[1];

        // Must be strictly newer than the installed version (blocks re-apply/downgrade).
        $currentVersion = trim((string) @file_get_contents(base_path('version.txt'))) ?: '0.0.0';
        if (version_compare($newVersion, $currentVersion, '<=')) {
            return CommonHelper::responseError('update_version_is_not_newer');
        }

        $work = storage_path('app/system_update/' . time());
        File::ensureDirectoryExists($work);

        try {
            $file->move($work, 'update.zip');
            $zipPath = $work . '/update.zip';

            $zip = new \ZipArchive();
            if ($zip->open($zipPath) !== true) {
                throw new \RuntimeException(__('please_upload_a_valid_zip_file'));
            }
            $extract = $work . '/extracted';
            File::ensureDirectoryExists($extract);
            $zip->extractTo($extract);
            $zip->close();

            $entries = array_values(array_diff(scandir($extract), ['.', '..']));
            $source = $extract;
            if (count($entries) === 1 && is_dir($extract . '/' . $entries[0])) {
                $source = $extract . '/' . $entries[0];
            }

            // Check every target BEFORE going down: a copy that dies half-way leaves the
            // panel in maintenance mode with a mixed set of old and new files. Files
            // owned by another user (root from a shell deploy, while PHP runs as the web
            // user) are the usual reason a copy fails with "Permission denied".
            $blocked = $this->unwritableTargets($source, base_path());
            if (!empty($blocked)) {
                $repaired = $this->makeWritable($blocked, base_path());
                if ($repaired) {
                    Log::info('system_update made writable: ' . implode(', ', $repaired));
                }
                $blocked = $this->unwritableTargets($source, base_path());
            }
            if (!empty($blocked)) {
                Log::error('system_update blocked, not writable: ' . implode(', ', $blocked));

                $paths = implode(', ', array_slice($blocked, 0, 5))
                    . (count($blocked) > 5 ? ' (+' . (count($blocked) - 5) . ' more)' : '');
                $message = __('update_files_not_writable', ['paths' => $paths]);
    
                if ($message === 'update_files_not_writable') {
                    $message = 'The update cannot be applied: the web server has no write permission on '
                        . $paths . '. Fix the ownership/permissions of those files and try again.';
                }

                throw new \RuntimeException($message);
            }

            Artisan::call('down');

            File::copyDirectory($source, base_path());
            Artisan::call('migrate', ['--force' => true]);
            Log::info('system_update migrate output: ' . Artisan::output());
            Artisan::call('optimize:clear');

            /* A daemon worker holds the old code in memory, so without this it would keep
               running the previous version's jobs against the new database. */
            try {
                Artisan::call('queue:restart');
            } catch (\Throwable $e) {
                Log::warning('system_update queue:restart failed: ' . $e->getMessage());
            }

            file_put_contents(base_path('version.txt'), $newVersion);

            return CommonHelper::responseSuccessWithData('system_updated_successfully', ['version' => $newVersion]);
        } catch (\Throwable $e) {
            Log::error('system_update failed: ' . $e->getMessage());
            return CommonHelper::responseError($e->getMessage() ?: __('something_went_wrong'));
        } finally {
            Artisan::call('up');
            File::deleteDirectory($work);
        }
    }

    /**
     * Try to make the listed paths writable, and every directory above them.
     *
     * chmod only succeeds when PHP owns the file, which covers the common case of a
     * package unzipped as the web user with a read-only mode. Anything owned by another
     * user fails silently here and is reported by the caller's re-check.
     *
     * @param  array<int, string>  $relatives  paths relative to the project root
     * @return array<int, string>  the ones that are writable afterwards
     */
    private function makeWritable(array $relatives, string $base): array
    {
        $base = rtrim($base, '/');
        $fixed = [];

        foreach ($relatives as $relative) {
            $target = $base . '/' . $relative;

            // Every directory from the project root down has to allow writing, or a
            // writable file inside an unwritable folder still cannot be replaced.
            $dirs = [];
            for ($dir = is_dir($target) ? $target : dirname($target); strlen($dir) > strlen($base); $dir = dirname($dir)) {
                $dirs[] = $dir;
            }
            foreach (array_reverse($dirs) as $dir) {
                if (is_dir($dir) && !is_writable($dir)) {
                    @chmod($dir, 0775);
                }
            }

            if (file_exists($target) && !is_writable($target)) {
                @chmod($target, is_dir($target) ? 0775 : 0664);
            }

            if ((file_exists($target) && is_writable($target)) || is_writable(dirname($target))) {
                $fixed[] = $relative;
            }
        }

        return $fixed;
    }

    /**
     * Paths the update would have to overwrite but cannot, relative to the project root.
     *
     * An existing file must itself be writable; a new one needs a writable place to land —
     * for a path whose directories do not exist yet, that is the nearest ancestor that
     * does, since the copy creates the rest.
     *
     * @return array<int, string>
     */
    private function unwritableTargets(string $source, string $base): array
    {
        $blocked = [];
        $baseLength = strlen(rtrim($base, '/')) + 1;

        $items = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($source, \FilesystemIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::SELF_FIRST
        );

        foreach ($items as $item) {
            $relative = substr($item->getPathname(), strlen(rtrim($source, '/')) + 1);
            $target = rtrim($base, '/') . '/' . $relative;

            if ($item->isDir()) {
                if (is_dir($target) && !is_writable($target)) {
                    $blocked[] = $relative;
                }
                continue;
            }

            if (file_exists($target)) {
                if (!is_writable($target)) {
                    $blocked[] = $relative;
                }
                continue;
            }

            // Walk up to the first directory that exists: the ones below it are created
            // by the copy, so their absence is not a permission problem.
            $dir = dirname($target);
            while (!is_dir($dir) && strlen($dir) > strlen(rtrim($base, '/'))) {
                $dir = dirname($dir);
            }
            if (!is_writable($dir)) {
                $blocked[] = $relative;
            }
        }

        return $blocked;
    }

    /**
     * Validate a purchase code for a domain against the CakeZake validator.
     */
    public function verifyPurchaseCode(string $code, ?string $domain = null): bool
    {
        $code = trim($code);
        if ($code === '') {
            return false;
        }

        $domain = $domain ?: (request()?->getSchemeAndHttpHost() ?: config('app.url'));

        $response = null;
        $lastError = null;
        foreach ([CURL_IPRESOLVE_WHATEVER, CURL_IPRESOLVE_V4, CURL_IPRESOLVE_V6] as $family) {
            try {
                $response = Http::timeout(15)
                    ->withOptions(['curl' => [CURLOPT_IPRESOLVE => $family]])
                    ->get('https://validator.cakezake.com/cakezake_validator', [
                        'purchase_code' => $code,
                        'domain_url'    => $domain,
                    ]);
                break;
            } catch (\Throwable $e) {
                $lastError = $e;
            }
        }

        if ($response === null) {
            // Validator unreachable on every family — treat as invalid rather than
            // letting the request die on a network exception.
            Log::error('Purchase code validation failed: ' . ($lastError?->getMessage() ?? 'unreachable'));
            return false;
        }

        if (! $response->successful()) {
            Log::error('Purchase code validation returned HTTP ' . $response->status());
            return false;
        }

        return $response->json('error') === false;
    }

    public function testMail(Request $request)
    {

        $validator = Validator::make($request->all(), [
            'mailer' => 'required',
            'email' => 'required|email',
            'host' => 'required',
            'username' => 'required',
            'password' => 'required',
            'port' => 'required',
            'encryption' => 'required',
            'support_email' => 'required',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $config = [
            'driver' => $request->mailer,
            'host' => $request->host,
            'username' => $request->username,
            'password' => $request->password,
            'port' => (int) $request->port,
            'encryption' => $request->encryption,
            'from'       => [
                'address' => $request->username,
                'name'    => $request->app_name,
            ]
        ];

        Config::set('mail', $config);

        Mail::purge($request->mailer);

        try {
            Mail::html('Email Test Successfully!', function ($message) use ($request) {
                $message->to($request->email)
                    ->subject('Testing Mail')
                    ->from($request->username, $request->app_name);
            });
            return CommonHelper::responseSuccess('test_mail_sent_successfully');
        } catch (\Exception $e) {
            return CommonHelper::responseError($e->getMessage());
        }
    }

    /*  *
     * Google Places Autocomplete API
     * Provides location suggestions based on user input
     */
    public function googlePlacesAutocomplete(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'input' => 'required|string|min:2',
            'language' => 'nullable|string|size:2',
            'types' => 'nullable|string',
            'components' => 'nullable|string',
            'sessiontoken' => 'nullable|string',
            'source' => 'required|string|in:app,web',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // Track API call
        ApiCallTracking::incrementCallCount('google_places_autocomplete', $request->source);

        try {
            // Get Google Places API key from settings
            $apiKey = Setting::get_value('apiKey');

            if (empty($apiKey)) {
                return CommonHelper::responseError('Google Places API key not configured');
            }

            $payload = [
                'input'        => $request->input,
                'languageCode' => $request->language ?? 'en',
            ];

            // Legacy "country:in", or a comma list of them → includedRegionCodes.
            if ($request->components) {
                $regions = [];
                foreach (explode('|', str_replace(',', '|', (string) $request->components)) as $part) {
                    $part = trim($part);
                    if (stripos($part, 'country:') === 0) {
                        $part = substr($part, strlen('country:'));
                    }
                    if ($part !== '') {
                        $regions[] = strtolower($part);
                    }
                }
                if (!empty($regions)) {
                    $payload['includedRegionCodes'] = array_slice(array_values(array_unique($regions)), 0, 15);
                }
            }

            if ($types = $this->newPlaceTypes($request->types)) {
                $payload['includedPrimaryTypes'] = $types;
            }

            if ($request->sessiontoken) {
                $payload['sessionToken'] = $request->sessiontoken;
            }

            $data = $this->placesApiRequest(
                'https://places.googleapis.com/v1/places:autocomplete',
                $apiKey,
                'suggestions.placePrediction.place,suggestions.placePrediction.placeId'
                    . ',suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat'
                    . ',suggestions.placePrediction.types',
                $payload
            );

            if (isset($data['__error'])) {
                return CommonHelper::responseError($data['__error']);
            }

            $suggestions = [];
            foreach (($data['suggestions'] ?? []) as $suggestion) {
                $prediction = $suggestion['placePrediction'] ?? null;
                if (!$prediction) {
                    continue;
                }

                $placeId = $prediction['placeId'] ?? '';
                $structured = $prediction['structuredFormat'] ?? [];

                $suggestions[] = [
                    'placePrediction' => [
                        'place' => $prediction['place'] ?? ('places/' . $placeId),
                        'placeId' => $placeId,
                        'text' => [
                            'text' => $prediction['text']['text'] ?? '',
                            'matches' => $prediction['text']['matches'] ?? []
                        ],
                        'structuredFormat' => [
                            'mainText' => [
                                'text' => $structured['mainText']['text'] ?? '',
                                'matches' => $structured['mainText']['matches'] ?? []
                            ],
                            'secondaryText' => [
                                'text' => $structured['secondaryText']['text'] ?? ''
                            ]
                        ],
                        'types' => $prediction['types'] ?? []
                    ]
                ];
            }

            return CommonHelper::responseWithData([
                'suggestions' => $suggestions,
                'status' => 'OK'
            ]);
        } catch (\Exception $e) {
            Log::error('Google Places Autocomplete Error: ' . $e->getMessage());
            return CommonHelper::responseError('An error occurred while fetching location suggestions');
        }
    }

    /**
     * Google Places Details API
     * Get detailed information about a specific place
     */
    public function googlePlacesDetails(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'place_id' => 'required|string',
            'fields' => 'nullable|string',
            'language' => 'nullable|string|size:2',
            'sessiontoken' => 'nullable|string',
            'source' => 'required|string|in:app,web',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // Track API call
        ApiCallTracking::incrementCallCount('google_places_details', $request->source);

        try {
            // Get Google Places API key from settings
            $apiKey = Setting::get_value('apiKey');

            if (empty($apiKey)) {
                return CommonHelper::responseError('Google Places API key not configured');
            }

            $query = ['languageCode' => $request->language ?? 'en'];
            if ($request->sessiontoken) {
                // Closes the autocomplete session, so the session is billed once.
                $query['sessionToken'] = $request->sessiontoken;
            }

            $url = 'https://places.googleapis.com/v1/places/' . rawurlencode($request->place_id)
                . '?' . http_build_query($query);

            $place = $this->placesApiRequest($url, $apiKey,
                'id,name,types,formattedAddress,shortFormattedAddress,adrFormatAddress,'
                . 'addressComponents,location,viewport,googleMapsUri,websiteUri,'
                . 'utcOffsetMinutes,iconMaskBaseUri,iconBackgroundColor,displayName,photos,'
                . 'pureServiceAreaBusiness'
            );

            if (isset($place['__error'])) {
                return CommonHelper::responseError($place['__error']);
            }

            $placeId = $place['id'] ?? $request->place_id;
            $mapsUri = $place['googleMapsUri'] ?? '';

            $formattedResponse = [
                'name' => $place['name'] ?? ('places/' . $placeId),
                'id' => $placeId,
                'types' => $place['types'] ?? [],
                'formattedAddress' => $place['formattedAddress'] ?? '',
                'addressComponents' => [],
                'location' => [
                    'latitude' => (float) ($place['location']['latitude'] ?? 0),
                    'longitude' => (float) ($place['location']['longitude'] ?? 0)
                ],
                'viewport' => [
                    'low' => [
                        'latitude' => (float) ($place['viewport']['low']['latitude'] ?? 0),
                        'longitude' => (float) ($place['viewport']['low']['longitude'] ?? 0)
                    ],
                    'high' => [
                        'latitude' => (float) ($place['viewport']['high']['latitude'] ?? 0),
                        'longitude' => (float) ($place['viewport']['high']['longitude'] ?? 0)
                    ]
                ],
                'googleMapsUri' => $mapsUri,
                'websiteUri' => $place['websiteUri'] ?? '',
                'utcOffsetMinutes' => (int) ($place['utcOffsetMinutes'] ?? 0),
                'adrFormatAddress' => $place['adrFormatAddress'] ?? '',
                'iconMaskBaseUri' => $place['iconMaskBaseUri'] ?? '',
                'iconBackgroundColor' => $place['iconBackgroundColor'] ?? '',
                'displayName' => [
                    'text' => $place['displayName']['text'] ?? '',
                    'languageCode' => $place['displayName']['languageCode'] ?? ($request->language ?? 'en')
                ],
                'shortFormattedAddress' => $place['shortFormattedAddress'] ?? '',
                'photos' => [],
                'pureServiceAreaBusiness' => (bool) ($place['pureServiceAreaBusiness'] ?? false),
                'googleMapsLinks' => [
                    'directionsUri' => $mapsUri,
                    'placeUri' => $mapsUri,
                    'photosUri' => $mapsUri
                ],
            ];

            foreach (($place['addressComponents'] ?? []) as $component) {
                $formattedResponse['addressComponents'][] = [
                    'longText' => $component['longText'] ?? '',
                    'shortText' => $component['shortText'] ?? '',
                    'types' => $component['types'] ?? [],
                    'languageCode' => $component['languageCode'] ?? ($request->language ?? 'en')
                ];
            }

            foreach (($place['photos'] ?? []) as $photo) {
                $formattedResponse['photos'][] = [
                    // Already a resource name — "places/ID/photos/REF" — so a client can
                    // ask the Place Photo endpoint for it directly.
                    'name' => $photo['name'] ?? '',
                    'widthPx' => (int) ($photo['widthPx'] ?? 0),
                    'heightPx' => (int) ($photo['heightPx'] ?? 0),
                    'authorAttributions' => $photo['authorAttributions'] ?? [],
                    'flagContentUri' => $photo['flagContentUri'] ?? '',
                    'googleMapsUri' => $photo['googleMapsUri'] ?? ''
                ];
            }

            return CommonHelper::responseWithData($formattedResponse);
        } catch (\Exception $e) {
            Log::error('Google Places Details Error: ' . $e->getMessage());
            return CommonHelper::responseError('An error occurred while fetching place details');
        }
    }

    /**
     * Google Maps Geocoding API
     * Convert coordinates to address with fixed radius of 500
     */
    public function googleMapsGeocoding(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
            'source' => 'required|string|in:app,web',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // Track API call
        ApiCallTracking::incrementCallCount('google_maps_geocoding', $request->source);

        try {
            // Get Google Places API key from settings
            $apiKey = Setting::get_value('apiKey');

            if (empty($apiKey)) {
                return CommonHelper::responseError('Google Maps API key not configured');
            }

            // Build the API URL with fixed radius of 500
            $baseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
            $params = [
                'key' => $apiKey,
                'latlng' => $request->latitude . ',' . $request->longitude,
                'radius' => 500,
            ];

            // Make the request to Google Maps Geocoding API
            $url = $baseUrl . '?' . http_build_query($params);

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_TIMEOUT, 30);
            curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
            curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (compatible; cakezake/1.0)');

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError = curl_error($ch);
            unset($ch);

            if ($curlError) {
                return CommonHelper::responseError('Network error: ' . $curlError);
            }

            if ($httpCode !== 200) {
                return CommonHelper::responseError('Failed to fetch geocoding data. HTTP Code: ' . $httpCode);
            }

            if (empty($response)) {
                return CommonHelper::responseError('Empty response from Google Maps API');
            }

            $data = json_decode($response, true);

            if (json_last_error() !== JSON_ERROR_NONE) {
                return CommonHelper::responseError('Invalid response from Google Maps Geocoding API: ' . json_last_error_msg());
            }

            // Check if Google API returned an error
            if (isset($data['status']) && $data['status'] !== 'OK' && $data['status'] !== 'ZERO_RESULTS') {
                $errorMessage = $data['error_message'] ?? 'Google Maps Geocoding API error: ' . $data['status'];
                return CommonHelper::responseError($errorMessage);
            }

            // Format the response for better consumption
            $formattedResults = [];
            if (isset($data['results']) && is_array($data['results'])) {
                foreach ($data['results'] as $result) {
                    $formattedResults[] = [
                        'formatted_address' => $result['formatted_address'] ?? '',
                        'geometry' => $result['geometry'] ?? [],
                        'place_id' => $result['place_id'] ?? '',
                        'types' => $result['types'] ?? [],
                        'address_components' => $result['address_components'] ?? [],
                        'partial_match' => $result['partial_match'] ?? false,
                    ];
                }
            }

            return CommonHelper::responseWithData([
                'results' => $formattedResults,
                'status' => $data['status'] ?? 'OK',
                'radius' => 500
            ]);
        } catch (\Exception $e) {
            Log::error('Google Maps Geocoding Error: ' . $e->getMessage());
            return CommonHelper::responseError('An error occurred while processing geocoding request: ' . $e->getMessage());
        }
    }

    /**
     * Google Gemini AI API
     * Generate content using Google's Gemini AI model
     */
    public function googleGeminiAI(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'prompt' => 'required|string|min:1|max:10000',
            'source' => 'required|string|in:app,web',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // Track API call
        ApiCallTracking::incrementCallCount('google_gemini', $request->source);

        try {
            // Get Google Gemini API key from settings
            $apiKey = Setting::get_value('text_gen_key');

            if (empty($apiKey)) {
                return CommonHelper::responseError('Google Gemini API key not configured');
            }

            // Build the API URL
            $baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent';
            $url = $baseUrl . '?key=' . $apiKey;

            // Prepare the request payload - simplified format
            $payload = [
                'contents' => [
                    [
                        'parts' => [
                            [
                                'text' => $request->prompt
                            ]
                        ]
                    ]
                ]
            ];

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_TIMEOUT, 60);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Content-Type: application/json',
                'Accept: application/json'
            ]);

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError = curl_error($ch);
            unset($ch);
            // Log::info($response);
            if ($curlError) {
                return CommonHelper::responseError('Network error: ' . $curlError);
            }

            if ($httpCode !== 200) {
                return CommonHelper::responseError('Failed to generate content. HTTP Code: ' . $httpCode);
            }

            if (empty($response)) {
                return CommonHelper::responseError('Empty response from Google Gemini API');
            }

            $data = json_decode($response, true);

            if (json_last_error() !== JSON_ERROR_NONE) {
                return CommonHelper::responseError('Invalid response from Google Gemini API: ' . json_last_error_msg());
            }

            // Check if Gemini API returned an error
            if (isset($data['error'])) {
                $errorMessage = $data['error']['message'] ?? 'Google Gemini API error';
                return CommonHelper::responseError('Gemini API Error: ' . $errorMessage);
            }

            // Extract only the generated content - simplified response
            $generatedContent = '';
            if (isset($data['candidates'][0]['content']['parts'][0]['text'])) {
                $generatedContent = $data['candidates'][0]['content']['parts'][0]['text'];
            } else {
                return CommonHelper::responseError('No content generated by Gemini AI');
            }

            // Return only the essential data
            return CommonHelper::responseWithData($generatedContent);
        } catch (\Exception $e) {
            Log::error('Google Gemini AI Error: ' . $e->getMessage());
            return CommonHelper::responseError('An error occurred while generating content: ' . $e->getMessage());
        }
    }

    // ============================================================
    // Map provider dispatchers (google paid vs OSM free).
    // Frontend / app call these instead of the google_* endpoints —
    // each one routes to the configured provider and returns a
    // normalized response shape so callers do not branch.
    // ============================================================

    protected function activeMapProvider(): string
    {
        $provider = Setting::get_value('map_provider');
        return $provider === 'google' ? 'google' : 'osm';
    }

    public function placesAutocomplete(Request $request)
    {
        return $this->activeMapProvider() === 'google'
            ? $this->googlePlacesAutocomplete($request)
            : $this->osmPlacesAutocomplete($request);
    }

    public function placesDetails(Request $request)
    {
        return $this->activeMapProvider() === 'google'
            ? $this->googlePlacesDetails($request)
            : $this->osmPlacesDetails($request);
    }

    public function mapsGeocoding(Request $request)
    {
        return $this->activeMapProvider() === 'google'
            ? $this->googleMapsGeocoding($request)
            : $this->osmReverseGeocoding($request);
    }

    /**
     * Nominatim search → normalized to the Google-Places-Autocomplete shape
     * so frontend code can stay provider-agnostic.
     */
    public function osmPlacesAutocomplete(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'input'    => 'required|string|min:2',
            'language' => 'nullable|string|size:2',
            'source'   => 'required|string|in:app,web',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        ApiCallTracking::incrementCallCount('osm_places_autocomplete', $request->source);

        try {
            $params = [
                'q'              => $request->input,
                'format'         => 'json',
                'addressdetails' => 1,
                'limit'          => 5,
                'accept-language' => $request->language ?? 'en',
            ];
            $data = $this->nominatimRequest('search', $params);
            if (isset($data['__error'])) {
                return CommonHelper::responseError($data['__error']);
            }

            $suggestions = [];
            foreach ((array) $data as $row) {
                $osmType = $row['osm_type'] ?? '';
                $osmId   = $row['osm_id'] ?? '';
                // Encode a placeId callers can pass back to /places_details.
                $placeId = $osmType && $osmId ? (strtoupper(substr($osmType, 0, 1)) . $osmId) : '';
                $display = $row['display_name'] ?? '';
                $address = $row['address'] ?? [];
                $mainText = $address['city'] ?? $address['town'] ?? $address['village']
                    ?? $address['suburb'] ?? $address['road'] ?? $display;
                $secondary = trim(str_replace($mainText, '', $display), " ,");

                $suggestions[] = [
                    'placePrediction' => [
                        'place'    => 'osm/' . $placeId,
                        'placeId'  => $placeId,
                        'text'     => ['text' => $display, 'matches' => []],
                        'structuredFormat' => [
                            'mainText'      => ['text' => $mainText, 'matches' => []],
                            'secondaryText' => ['text' => $secondary],
                        ],
                        'types' => [$row['type'] ?? $row['class'] ?? 'place'],
                        // Provider-specific extras — frontend may use as fast path
                        // and skip the details round-trip if it wants.
                        '_osm' => [
                            'lat'     => isset($row['lat']) ? (float) $row['lat'] : null,
                            'lon'     => isset($row['lon']) ? (float) $row['lon'] : null,
                            'address' => $address,
                        ],
                    ],
                ];
            }

            return CommonHelper::responseWithData([
                'suggestions' => $suggestions,
                'status'      => 'OK',
                'provider'    => 'osm',
            ]);
        } catch (\Exception $e) {
            Log::error('OSM Places Autocomplete Error: ' . $e->getMessage());
            return CommonHelper::responseError('An error occurred while fetching location suggestions');
        }
    }

    /**
     * Nominatim lookup by encoded place_id (e.g. "N12345", "W67890", "R11").
     * Normalized to the Google-Places-Details shape.
     */
    public function osmPlacesDetails(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'place_id' => 'required|string',
            'language' => 'nullable|string|size:2',
            'source'   => 'required|string|in:app,web',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        ApiCallTracking::incrementCallCount('osm_places_details', $request->source);

        try {
            $placeId = (string) $request->place_id;
            // Expected forms: "N123", "W123", "R123" (T = node/way/relation prefix).
            if (!preg_match('/^[NWR]\d+$/i', $placeId)) {
                return CommonHelper::responseError('Invalid OSM place id');
            }
            $params = [
                'osm_ids'        => strtoupper($placeId),
                'format'         => 'json',
                'addressdetails' => 1,
                'accept-language' => $request->language ?? 'en',
            ];
            $data = $this->nominatimRequest('lookup', $params);
            if (isset($data['__error'])) {
                return CommonHelper::responseError($data['__error']);
            }
            $row = is_array($data) && !empty($data) ? $data[0] : null;
            if (!$row) {
                return CommonHelper::responseError('Place not found');
            }
            return CommonHelper::responseWithData($this->normalizeOsmPlace($row, $request->language ?? 'en'));
        } catch (\Exception $e) {
            Log::error('OSM Places Details Error: ' . $e->getMessage());
            return CommonHelper::responseError('An error occurred while fetching place details');
        }
    }

    /**
     * Nominatim reverse geocoding → shape matching googleMapsGeocoding().
     */
    public function osmReverseGeocoding(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude'  => 'required|numeric',
            'longitude' => 'required|numeric',
            'source'    => 'required|string|in:app,web',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        ApiCallTracking::incrementCallCount('osm_maps_geocoding', $request->source);

        try {
            $params = [
                'lat'            => $request->latitude,
                'lon'            => $request->longitude,
                'format'         => 'json',
                'addressdetails' => 1,
                'zoom'           => 18,
            ];
            $data = $this->nominatimRequest('reverse', $params);
            if (isset($data['__error'])) {
                return CommonHelper::responseError($data['__error']);
            }
            if (!is_array($data) || empty($data)) {
                return CommonHelper::responseWithData(['results' => [], 'status' => 'ZERO_RESULTS']);
            }

            $components = $this->osmAddressToComponents($data['address'] ?? []);
            $result = [
                'formatted_address'  => $data['display_name'] ?? '',
                'geometry'           => [
                    'location' => [
                        'lat' => isset($data['lat']) ? (float) $data['lat'] : 0,
                        'lng' => isset($data['lon']) ? (float) $data['lon'] : 0,
                    ],
                ],
                'place_id'           => ($data['osm_type'] ?? '') && ($data['osm_id'] ?? '')
                    ? strtoupper(substr($data['osm_type'], 0, 1)) . $data['osm_id']
                    : '',
                'types'              => [$data['type'] ?? 'place'],
                'address_components' => array_map(function ($c) {
                    return [
                        'long_name'  => $c['longText'],
                        'short_name' => $c['shortText'],
                        'types'      => $c['types'],
                    ];
                }, $components),
                'partial_match'      => false,
            ];

            return CommonHelper::responseWithData([
                'results'  => [$result],
                'status'   => 'OK',
                'provider' => 'osm',
            ]);
        } catch (\Exception $e) {
            Log::error('OSM Reverse Geocoding Error: ' . $e->getMessage());
            return CommonHelper::responseError('An error occurred while processing geocoding request');
        }
    }

        protected function placesApiRequest(string $url, string $apiKey, string $fieldMask, ?array $body = null): array
        {
            $headers = [
                'Content-Type: application/json',
                'X-Goog-Api-Key: ' . $apiKey,
                'X-Goog-FieldMask: ' . $fieldMask,
            ];

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_TIMEOUT, 30);
            curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
            if ($body !== null) {
                curl_setopt($ch, CURLOPT_POST, true);
                curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
            }

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $err = curl_error($ch);
            unset($ch);

            if ($err) {
                return ['__error' => 'Network error: ' . $err];
            }

            $data = json_decode((string) $response, true);
            if (json_last_error() !== JSON_ERROR_NONE) {
                return ['__error' => 'Invalid response from Google Places API'];
            }

            if ($httpCode !== 200 || isset($data['error'])) {
                return ['__error' => $data['error']['message'] ?? ('Google Places API error. HTTP ' . $httpCode)];
            }

            return is_array($data) ? $data : [];
        }

        protected function newPlaceTypes($types): array
        {
            $dropped = ['geocode', 'address', 'establishment'];
            $out = [];

            foreach (explode(',', (string) $types) as $type) {
                $type = strtolower(trim($type));
                if ($type === '' || in_array($type, $dropped, true)) {
                    continue;
                }
                if ($type === '(cities)' || $type === '(regions)') {
                    return [$type];
                }
                $out[] = $type;
            }

            return array_slice(array_values(array_unique($out)), 0, 5);
        }

    protected function nominatimRequest(string $endpoint, array $params): array
    {
        $url = 'https://nominatim.openstreetmap.org/' . $endpoint . '?' . http_build_query($params);

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        // Nominatim ToS requires a real User-Agent identifying the app.
        curl_setopt($ch, CURLOPT_USERAGENT, 'CakeZake/1.0 (' . parse_url(env('APP_URL', 'localhost'), PHP_URL_HOST) . ')');
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Accept: application/json']);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $err = curl_error($ch);
        unset($ch);

        if ($err) {
            return ['__error' => 'Network error: ' . $err];
        }
        if ($httpCode !== 200) {
            return ['__error' => 'OSM request failed. HTTP ' . $httpCode];
        }
        $data = json_decode($response, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            return ['__error' => 'Invalid response from OSM Nominatim'];
        }
        return $data;
    }

    protected function normalizeOsmPlace(array $row, string $language = 'en'): array
    {
        $addr = $row['address'] ?? [];
        $components = $this->osmAddressToComponents($addr);
        $lat = isset($row['lat']) ? (float) $row['lat'] : 0;
        $lon = isset($row['lon']) ? (float) $row['lon'] : 0;
        $placeId = ($row['osm_type'] ?? '') && ($row['osm_id'] ?? '')
            ? strtoupper(substr($row['osm_type'], 0, 1)) . $row['osm_id']
            : '';

        return [
            'name'                  => 'osm/' . $placeId,
            'id'                    => $placeId,
            'types'                 => [$row['type'] ?? $row['class'] ?? 'place'],
            'formattedAddress'      => $row['display_name'] ?? '',
            'addressComponents'     => array_map(function ($c) use ($language) {
                return $c + ['languageCode' => $language];
            }, $components),
            'location'              => ['latitude' => $lat, 'longitude' => $lon],
            'viewport'              => [
                'low'  => ['latitude' => $lat, 'longitude' => $lon],
                'high' => ['latitude' => $lat, 'longitude' => $lon],
            ],
            'googleMapsUri'         => '',
            'websiteUri'            => '',
            'utcOffsetMinutes'      => 0,
            'adrFormatAddress'      => '',
            'iconMaskBaseUri'       => '',
            'iconBackgroundColor'   => '',
            'displayName'           => [
                'text'         => $addr['city'] ?? $addr['town'] ?? $addr['village'] ?? ($row['name'] ?? $row['display_name'] ?? ''),
                'languageCode' => $language,
            ],
            'shortFormattedAddress' => $addr['city'] ?? $addr['town'] ?? $addr['village'] ?? '',
            'photos'                => [],
            'pureServiceAreaBusiness' => false,
            'googleMapsLinks'       => [
                'directionsUri' => '',
                'placeUri'      => '',
                'photosUri'     => '',
            ],
            'provider'              => 'osm',
        ];
    }

    /**
     * Map Nominatim address keys → Google address_components-style rows.
     */
    protected function osmAddressToComponents(array $addr): array
    {
        $map = [
            'house_number' => ['street_number'],
            'road'         => ['route'],
            'suburb'       => ['sublocality', 'sublocality_level_1'],
            'neighbourhood' => ['neighborhood'],
            'village'      => ['locality'],
            'town'         => ['locality'],
            'city'         => ['locality'],
            'county'       => ['administrative_area_level_2'],
            'state'        => ['administrative_area_level_1'],
            'state_district' => ['administrative_area_level_2'],
            'postcode'     => ['postal_code'],
            'country'      => ['country'],
            'country_code' => ['country'],
        ];
        $out = [];
        foreach ($map as $key => $types) {
            if (!empty($addr[$key])) {
                $val = $addr[$key];
                $shortVal = ($key === 'country_code') ? strtoupper((string) $val) : (string) $val;
                $longVal = ($key === 'country_code') ? ($addr['country'] ?? strtoupper((string) $val)) : (string) $val;
                $out[] = ['longText' => $longVal, 'shortText' => $shortVal, 'types' => $types];
            }
        }
        return $out;
    }

    /* ------------------------------------------------------------------
     | Website settings (merged from the old WebSettingsApiController).
     | Named webSettingsIndex/saveWebSettings so they don't collide with
     | this controller's own index()/save().
     ------------------------------------------------------------------ */

    public function webSettingsIndex()
    {
        $settingsArray = array(
            "site_title" => "",
            "website_url" => "",
            "light_mode_color" => "#FE3C5E",
            "dark_mode_color" => "#C8E5D5",

            "app_title" => "",
            "app_tagline" => "",
            "app_short_description" => "",

            "is_android_app" => 0,
            "android_app_url" => "",
            "play_store_logo" => "",

            "is_ios_app" => 0,
            "ios_app_url" => "",
            "ios_store_logo" => "",

            "copyright_details" => "",

            "common_meta_title" => "",
            "common_meta_description" => "",

            "cookie_consent_enabled" => 0,
            "cookie_consent_title" => "",
            "cookie_consent_description" => "",

            "favicon" => "",
            "web_logo" => "",
            "placeholder_image" => "",

            "broken_image" => "",
            "app_download_image" => "",

            "pwa_name" => "",
            "pwa_description" => "",
            "pwa_icon" => ""

        );
        $variables = array_keys($settingsArray);

        $settings = Setting::whereIn('variable', $variables)->get();

        $data = array(
            "settingsObject" => $settingsArray,
            "settings" => $settings
        );
        return CommonHelper::responseWithData($data);
    }
    public function saveWebSettings(Request $request)
    {
        $translatable = [
            'site_title',
            'common_meta_title',
            'common_meta_description',
            'app_title',
            'app_short_description',
            'cookie_consent_title',
            'cookie_consent_description',
        ];

        $validator = Validator::make($request->all(), [
            'site_title' . config('app.default_language') => 'required|string',
            'common_meta_title' . config('app.default_language') => 'required|string',
            'common_meta_description' . config('app.default_language') => 'required|string',
            'website_url' => 'required|url',
            'light_mode_color' => 'required',
            'dark_mode_color' => 'required',
            'android_app_url' => ['required_if:is_android_app,1'],
            'play_store_logo' => $request->hasFile('play_store_logo') ? 'mimes:jpeg,jpg,png,gif,svg' : '',
            'ios_app_url' => ['required_if:is_ios_app,1'],
            'ios_store_logo' => $request->hasFile('ios_store_logo') ? 'mimes:jpeg,jpg,png,gif,svg' : '',
            'favicon' => $request->hasFile('favicon') ? 'mimes:jpeg,jpg,png,gif,svg' : '',
            'web_logo' => $request->hasFile('web_logo') ? 'mimes:jpeg,jpg,png,gif,svg' : '',
            'placeholder_image' => $request->hasFile('placeholder_image') ? 'mimes:jpeg,jpg,png,gif,svg' : '',
            'broken_image' => $request->hasFile('broken_image') ? 'mimes:jpeg,jpg,png,gif,svg' : '',
            'pwa_icon' => $request->hasFile('pwa_icon') ? 'mimes:jpeg,jpg,png,webp' : '',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $filePaths = array();

        // Branch each uploaded front-end asset and delete the previously stored file.
        $webFileFields = ['play_store_logo', 'ios_store_logo', 'favicon', 'web_logo', 'placeholder_image', 'broken_image', 'app_download_image', 'pwa_icon'];
        foreach ($webFileFields as $field) {
            if ($request->hasFile($field)) {
                $filePaths[$field] = CommonHelper::uploadFile($request, $field, 'front_end/' . $field, Setting::get_value($field));
            }
        }
        foreach ($request->all() as $key => $value) {

            if (
                in_array($key, $webFileFields)
                && isset($filePaths[$key])
            ) {
                $value = $filePaths[$key];
            }

            $setting = Setting::firstOrNew(['variable' => $key]);

            if (in_array($key, $translatable)) {

                $value = $this->cleanMultilangValue(
                    $request->$key,
                    $setting->value
                );

                $setting->value = $value !== '' ? $value : json_encode([]);
            } else {

                $setting->value = $value ?? "";
            }

            $setting->save();
        }

        return CommonHelper::responseSuccess('web_settings_saved_successfully');
    }
}
