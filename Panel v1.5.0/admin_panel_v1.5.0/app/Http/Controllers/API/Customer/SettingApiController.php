<?php

namespace App\Http\Controllers\API\Customer;

use App\Helpers\CommonHelper;
use App\Services\SpinWheelService;
use App\Http\Controllers\Controller;
use App\Models\Brand;
use App\Models\Category;
use App\Models\Product;
use App\Models\Setting;
use App\Models\SeoSetting;
use App\Models\SocialMedia;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class SettingApiController extends Controller
{
    public function getSettings(Request $request)
    {
        $variables = array(
            "app_name",
            "support_number",
            "support_email",
            "is_version_system_on_customer",
            "required_force_update_customer",
            "current_version_customer",
            "ios_is_version_system_on_customer",
            "ios_required_force_update_customer",
            "ios_current_version_customer",
            "branch_address",
            "store_map_url",
            "map_latitude",
            "map_longitude",
            "max_cart_items_count",
            "generate_otp",
            "app_mode_customer",
            "app_mode_customer_remark",
            "app_mode_delivery_boy",
            "app_mode_delivery_boy_remark",
            "contact_us",
            "about_us",
            "common_meta_keywords",
            "common_meta_title",
            "common_meta_description",
            "color",
            "google_play",
            "favicon",
            "web_logo",
            "placeholder_image",
            "broken_image",
            "popup_enabled",
            "popup_type",
            "popup_type_id",
            "popup_slug",
            "popup_url",
            "popup_image",
            "playstore_url",
            "appstore_url",
            "delivery_boy_playstore_url",
            "delivery_boy_appstore_url",
            "deeplink_schema",
            "website_mode",
            "website_mode_remark",
            "app_mode_customer_start",
            "app_mode_customer_end",
            "phone_login",
            "google_login",
            "apple_login",
            "email_login",
            "phone_auth_otp",
            "phone_auth_password",
            "firebase_authentication",
            "custom_sms_gateway_otp_based",
            "enable_road_path_tracking",
            "country_code",
            "customer_light_mode_color",
            "customer_dark_mode_color",
            "clarity_project_id_customer",
            "clarity_status_customer",
            "password_min_length",
            "password_max_length",
            "password_require_uppercase",
            "password_require_lowercase",
            "password_require_number",
            "password_require_special"
        );
        $data = CommonHelper::getSettings($variables);
        $data = CommonHelper::resolveTranslatedSettings($data);

        foreach ($variables as $key) {
            if (!array_key_exists($key, $data)) {
                $data[$key] = "";
            }
        }

        $popupTypeId = (int) ($data['popup_type_id'] ?? 0);
        $data['popup_type_name'] = $popupTypeId
            ? (string) (match ($data['popup_type'] ?? '') {
                'category' => optional(Category::find($popupTypeId))->name,
                'brand'    => optional(Brand::find($popupTypeId))->name,
                'product'  => optional(Product::find($popupTypeId))->name,
                default    => '',
            } ?? '')
            : '';

        $data['popup_has_child'] = ($popupTypeId && ($data['popup_type'] ?? '') === 'category')
            && Category::where('parent_id', $popupTypeId)->where('status', 1)->exists();

        $data['demo_mode'] = env('DEMO_MODE', 0);

        $data['broadcast_driver'] = CommonHelper::getBroadcastDriver();
        $data['broadcast_config'] = CommonHelper::getBroadcastClientConfig();

        $data['map_provider'] = Setting::get_value('map_provider') ?: 'osm';

        // Is there a live wheel right now? One flag so the app can decide whether to show
        // the entry point at all before it fetches the wheel itself.
        $data['spin_wheel_available'] = app(SpinWheelService::class)->activeCampaign() ? 1 : 0;

        if (isset($request->is_web_setting) && $request->is_web_setting == 1) {
            $webVariables = array(
                "site_title",
                "website_url",
                "color",
                "light_color",
                "app_title",
                "app_tagline",
                "app_short_description",
                "is_android_app",
                "android_app_url",
                "play_store_logo",
                "is_ios_app",
                "ios_app_url",
                "ios_store_logo",
                "copyright_details",
                "common_meta_title",
                "common_meta_description",
                "favicon",
                "web_logo",
                "placeholder_image",
                "broken_image",
                "website_mode",
                "website_mode_remark",
                "website_mode_start",
                "website_mode_end",
                "phone_login",
                "google_login",
                "apple_login",
                "email_login",
                "phone_auth_otp",
                "phone_auth_password",
                "firebase_authentication",
                "custom_sms_gateway_otp_based",
                "enable_road_path_tracking",
                "light_mode_color",
                "dark_mode_color",
                "app_download_image",
                "clarity_project_id_web",
                "clarity_status_web",
                "cookie_consent_enabled",
                "cookie_consent_title",
                "cookie_consent_description",
                "pwa_name",
                "pwa_description",
                "pwa_icon"
            );
            $web_settings = CommonHelper::getSettings($webVariables);
            $web_settings = CommonHelper::resolveTranslatedSettings($web_settings);
            foreach ($webVariables as $key) {
                if (!array_key_exists($key, $web_settings)) {
                    $web_settings[$key] = "";
                }
            }
            $data["web_settings"] = $web_settings;
            $data["social_media"] = SocialMedia::orderBy('id', 'ASC')->get();
            $data["demo_mode"] = env('DEMO_MODE', 0);
        }

        if (!empty($data)) {
            return CommonHelper::responseSuccessWithData('success', $data);
        } else {
            return  CommonHelper::responseError('No settings found!');
        }
    }

    /**
     * All country-scoped settings for the user's location in one call:
     * refer-&-earn, customer policies (Content-Language, default-lang fallback), and the
     * country's date/time format. latitude, longitude (required) → zone → country.
     */
    public function getCountrySetting(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude'  => 'required',
            'longitude' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $channel = strtolower(trim((string) $request->header('channel')));
        $channel = in_array($channel, ['quick', 'ecommerce'], true) ? $channel : null;

        $zone = CommonHelper::getDeliverableCity($request->latitude, $request->longitude, $channel);
        if (!$zone) {
            return CommonHelper::responseError(__('not_deliverable_to_this_location'));
        }
        $country = $zone->country;

        $buyerTaxConfig = \App\Services\BuyerTaxIdentity::config((int) $zone->country_id);
        $buyerTax = [
            'enabled' => $buyerTaxConfig['enabled'] ? 1 : 0,
            'label'   => $buyerTaxConfig['label'],
            'regex'   => $buyerTaxConfig['regex'],
        ];

        $policies = CommonHelper::countryPolicies($zone->country_id, [
            'privacy_policy',
            'return_policy',
            'shipping_policy',
            'cancellation_policy',
            'terms_conditions',
        ]);

        $data = array_merge([
            // Refer & Earn
            'referral_min_order_amount'   => (float) ($country->referral_min_order_amount ?? 0),
            'referral_credit_first_order' => (float) ($country->referral_credit_first_order ?? 0), // referrer reward
            'referral_credit_referred'    => (float) ($country->referral_credit_referred ?? 0),    // referred-user reward
            // Regional formats
            'date_format'                 => $country->date_format ?? 'd-m-Y',
            'time_format'                 => $country->time_format ?? 'h:i A',
            // Currency
            'currency'                    => $country->currency ?? null,
            'currency_code'               => $country->currency_code ?? null,
            /* Buyer tax registration field for the CHECKOUT form (it is not part of the
               address book — the number belongs to one order). The label is whatever this
               country calls it (GSTIN, VAT Number, TRN); the regex lets the app flag a
               typo before the place-order round-trip. Always optional — the server
               accepts an empty value whatever the country says. */
            'buyer_tax_field'             => $buyerTax,
        ], $policies);

        return CommonHelper::responseSuccessWithData('success', $data);
    }

    public function getPaymentMethods(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude'  => 'required',
            'longitude' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $channel = strtolower(trim((string) $request->header('channel')));
        if (!in_array($channel, ['quick', 'ecommerce'], true)) {
            return CommonHelper::responseError(__('invalid_channel_header'));
        }

        // Payment gateways are zone-wise now — resolve the zone from the location.
        $zone = CommonHelper::getDeliverableCity($request->latitude, $request->longitude, $channel);
        if (!$zone) {
            return CommonHelper::responseError(__('not_deliverable_to_this_location'));
        }

        // Same key set the app already consumes, now sourced from the zone's gateway map.
        $variables = array(
            "payment_method_settings",
            "cod_payment_method",
            "cod_mode",

            "paypal_payment_method",

            "razorpay_payment_method",
            "razorpay_key",

            "paystack_payment_method",
            "paystack_public_key",
            "paystack_currency_code",

            "stripe_payment_method",
            "stripe_publishable_key",
            "stripe_currency_code",
            "stripe_mode",

            "midtrans_payment_method",

            "phonepay_payment_method",
            "phonepay_mode",

            "cashfree_payment_method",
            "cashfree_mode",

            "paytabs_payment_method",
            "paytabs_mode"
        );

        /* Keys an plugin's gateway declared public — its on/off switch and whatever the
           app needs to open its checkout. Secrets are excluded by the driver itself, so
           adding a gateway plugin needs no edit here. */
        try {
            $registry = app(\App\Plugins\Registries\PaymentGatewayRegistry::class);
            foreach ($registry->keys() as $code) {
                $driver = $registry->driver($code);
                if (!$driver instanceof \App\Plugins\Contracts\PaymentGateway) {
                    continue;
                }
                $variables[] = $code . '_payment_method';
                foreach ($driver->publicSettingKeys() as $key) {
                    $variables[] = (string) $key;
                }
            }
            $variables = array_values(array_unique($variables));
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('[Payments] plugin public keys unavailable: ' . $e->getMessage());
        }

        $gateways = CommonHelper::countryPaymentGateways($zone?->country);
        $data = array();
        foreach ($variables as $key) {
            $data[$key] = $gateways[$key] ?? "";
        }

        $data = base64_encode(json_encode($data));
        return CommonHelper::responseWithData($data);
    }

    public function getSeoSettings(Request $request)
    {
        $query = SeoSetting::with('zone:id,name');

        // Filter by search term if provided
        if ($request->has('search')) {
            $query->where('page_type', 'like', '%' . $request->search . '%');
        }

        // Filter by specific page_type if provided
        if ($request->has('page_type')) {
            $query->where('page_type', $request->input('page_type'));
        }

        if ($request->filled('zone_id')) {
            $zoneId = (int) $request->input('zone_id');
            $query->where(function ($q) use ($zoneId) {
                $q->where('zone_id', $zoneId)->orWhere('zone_id', 0);
            })
                ->orderByRaw('zone_id = 0 asc');
        }

        $limit = $request->input('limit', 10);
        $offset = $request->input('offset', 0);

        $total = $query->count();

        $data = $query->offset($offset)
            ->limit($limit)
            ->get()
            ->map(function ($item) {
                $item->favicon = Setting::get_value('favicon')
                    ? asset('storage/' . Setting::get_value('favicon'))
                    : '';
                $item->zone_id = (int) $item->zone_id;
                $item->is_default = $item->zone_id === 0 ? 1 : 0;
                $item->zone_name = $item->zone_id === 0 ? __('default') : ($item->zone->name ?? '');
                $item->makeHidden('zone');
                return $item;
            });

        return response()->json([
            'error' => false,
            'message' => 'SEO pages fetched successfully',
            'total' => $total,
            'data' => $data
        ]);
    }
}
