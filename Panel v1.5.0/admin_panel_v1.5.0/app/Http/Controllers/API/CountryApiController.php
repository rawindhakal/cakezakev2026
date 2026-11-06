<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Services\LanguageService;
use App\Models\Country;
use App\Models\Region;
use App\Models\CountryTranslation;
use App\Models\Language;
use App\Models\Zone;
use App\Models\Order;
use App\Models\DeliveryBoy;
use App\Models\User;
use App\Models\UserWallet;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\DB;

class CountryApiController extends Controller
{

    protected $languageService;

    /** Country-scoped, multi-language policy fields (stored in country_translations). */
    private $policyFields = [
        'privacy_policy',
        'return_policy',
        'shipping_policy',
        'cancellation_policy',
        'terms_conditions',
        'privacy_policy_delivery_boy',
        'terms_conditions_delivery_boy',
    ];

    public function __construct(LanguageService $languageService)
    {
        $this->languageService = $languageService;
    }

    /** Build the per-language translation payload (name + all policy fields). */
    private function translationPayload(array $data): array
    {
        $payload = ['name' => $data['name'] ?? ''];
        foreach ($this->policyFields as $f) {
            $payload[$f] = $data[$f] ?? '';
        }
        return $payload;
    }

    /** Mirror the default-language policy values into the countries base columns (fallback). */
    private function applyBasePolicies($country, array $translations, $defaultLanguageId): void
    {
        $def = $translations[$defaultLanguageId] ?? [];
        foreach ($this->policyFields as $f) {
            $country->$f = $def[$f] ?? '';
        }
    }

    /** All policy fields must be filled in the default language. */
    private function validateDefaultPolicies(array $translations, $defaultLanguageId): ?string
    {
        $def = $translations[$defaultLanguageId] ?? [];
        foreach ($this->policyFields as $f) {
            if (trim(strip_tags((string) ($def[$f] ?? ''))) === '') {
                return __('please_fill_all_policies_in_default_language');
            }
        }
        return null;
    }

    public function index()
    {
        $request = request();

        if ($request->id) {

            $country = Country::with('translations')
                ->where('id', $request->id)
                ->first();

            if (!$country) {
                return CommonHelper::responseError('Country not found');
            }

            return CommonHelper::responseWithData($country);
        }

        $countries = Country::with('translations')
            ->orderBy('id', 'asc')
            ->get();

        return CommonHelper::responseWithData($countries);
    }

    public function active(Request $request)
    {
        // Only the fields dropdowns/header need — not the whole country (policies, gateways…).
        $countries = Country::where('status', 1)->orderBy('id', 'asc')
            ->get(['id', 'name', 'is_default', 'code', 'currency', 'currency_code', 'dial_code', 'min_mobile_length', 'max_mobile_length', 'logo', 'date_format', 'time_format', 'referral_min_order_amount', 'referral_credit_first_order', 'referral_credit_referred'])
            ->map(fn ($c) => [
                'id'                => $c->id,
                'name'              => $c->name,
                'is_default'        => $c->is_default,
                'code'              => $c->code,
                'currency'          => $c->currency,
                'currency_code'     => $c->currency_code,
                'dial_code'         => $c->dial_code,
                'min_mobile_length' => (int) ($c->min_mobile_length ?: 7),
                'max_mobile_length' => (int) ($c->max_mobile_length ?: 15),
                'logo_url'          => $c->logo_url,
                'date_format'       => $c->date_format ?: 'd-m-Y',
                'time_format'       => $c->time_format ?: 'h:i A',
                'is_referal_on'     => (
                    (float) $c->referral_min_order_amount > 0
                    || (float) $c->referral_credit_first_order > 0
                    || (float) $c->referral_credit_referred > 0
                ) ? 1 : 0,
            ]);
        return CommonHelper::responseWithData($countries);
    }

    public function save(Request $request)
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();

        $translations = json_decode($request->translations, true);

        if (
            !$translations ||
            !isset($translations[$defaultLanguage->id]['name']) ||
            trim($translations[$defaultLanguage->id]['name']) == ''
        ) {
            return CommonHelper::responseError(__('default_language_required'));
        }

        $validator = Validator::make($request->all(), [
            'dial_code' => 'required',
            'code' => 'required',
            'logo' => 'required|file',
            'timezone' => 'required',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        if ($err = $this->invalidTimezoneError($request->timezone)) {
            return $err;
        }
        if ($err = $this->invalidBuyerTaxRegexError($request)) {
            return $err;
        }

        $country = new Country();
        $country->dial_code = $request->dial_code;
        $country->code = $request->code;
        $country->status = $request->status ?? 1;

        $country->logo = CommonHelper::uploadFile($request, 'logo', 'countries');

        // Save default-language name + policies in base table (fallback copy).
        $country->name = $translations[$defaultLanguage->id]['name'];
        $this->applyBasePolicies($country, $translations, $defaultLanguage->id);

        // Currency symbol + code are required.
        if (trim((string) $request->currency) === '' || trim((string) $request->currency_code) === '') {
            return CommonHelper::responseError(__('currency_is_required'));
        }
        // At least one payment gateway must be enabled.
        $gateways = json_decode($request->payment_gateways, true) ?: [];
        if (!$this->hasEnabledPaymentMethod($gateways)) {
            return CommonHelper::responseError(__('at_least_one_payment_method_must_be_enabled'));
        }

        // Policies are required in the default language.
        if ($err = $this->validateDefaultPolicies($translations, $defaultLanguage->id)) {
            return CommonHelper::responseError($err);
        }

        $this->applyCountryConfig($country, $request);
        $country->save();

        // Save translations (name + policies)
        foreach ($translations as $languageId => $data) {
            $country->saveTranslation($languageId, $this->translationPayload($data));
        }

        return CommonHelper::responseSuccess('country_saved_successfully');
    }

    private function invalidTimezoneError($tz)
    {
        $tz = trim((string) $tz);
        if ($tz === '' || @timezone_open($tz) === false) {
            return CommonHelper::responseError(__('invalid_timezone'));
        }
        return null;
    }

    /** At least one *_payment_method toggle must be enabled. */
    private function hasEnabledPaymentMethod(array $gateways): bool
    {
        foreach ($gateways as $key => $value) {
            if (is_string($key) && str_ends_with($key, '_payment_method')
                && in_array($value, [1, '1', true, 'true'], true)) {
                return true;
            }
        }
        return false;
    }

    private function applyCountryConfig(Country $country, Request $request): void
    {
        if ($request->has('currency')) {
            $country->currency = $request->currency;
        }
        if ($request->has('currency_code')) {
            $country->currency_code = $request->currency_code;
        }
        if ($request->has('decimal_point')) {
            $country->decimal_point = (int) $request->decimal_point;
        }
       
        if ($request->has('min_mobile_length') || $request->has('max_mobile_length')) {
            $absMin = CommonHelper::MOBILE_LENGTH_MIN;
            $absMax = CommonHelper::MOBILE_LENGTH_MAX;
            $min = (int) $request->input('min_mobile_length', $country->min_mobile_length ?: 7);
            $max = (int) $request->input('max_mobile_length', $country->max_mobile_length ?: 15);
            $min = max($absMin, min($min, $absMax));
            $max = max($absMin, min($max, $absMax));
            if ($max < $min) {
                $max = $min;
            }
            $country->min_mobile_length = $min;
            $country->max_mobile_length = $max;
        }
        if ($request->has('date_format')) {
            $country->date_format = $request->date_format;
        }
        if ($request->has('time_format')) {
            $country->time_format = $request->time_format;
        }
        if ($request->has('timezone')) {
            $country->timezone = trim((string) $request->timezone);
        }
        if ($request->has('referral_min_order_amount')) {
            $country->referral_min_order_amount = (float) $request->referral_min_order_amount;
        }
        if ($request->has('referral_credit_first_order')) {
            $country->referral_credit_first_order = (float) $request->referral_credit_first_order;
        }
        if ($request->has('referral_credit_referred')) {
            $country->referral_credit_referred = (float) $request->referral_credit_referred;
        }
        if ($request->has('referral_usage_limit')) {
            $limit = trim((string) $request->referral_usage_limit);
            $country->referral_usage_limit = ($limit === '' || (int) $limit <= 0) ? null : (int) $limit;
        }
        if ($request->has('payment_gateways')) {
            $gateways = json_decode($request->payment_gateways, true) ?: [];
            $old = is_array($country->payment_gateways) ? $country->payment_gateways : [];
            // Payment QR images (eSewa / QR payment): a new upload replaces the old file,
            // an emptied path removes it.
            foreach (['esewa_qr' => 'esewa_qr_image', 'qr_image' => 'qr_image'] as $field => $key) {
                $prev = (string) ($old[$key] ?? '');
                if ($request->hasFile($field) && $request->file($field)->isValid()) {
                    $gateways[$key] = $request->file($field)->store('payment_qr', 'public');
                } else {
                    // Never trust a client-supplied path: keep the stored one, or clear it.
                    $gateways[$key] = empty($gateways[$key]) ? '' : $prev;
                }
                if ($prev !== '' && $prev !== $gateways[$key]) {
                    \Illuminate\Support\Facades\Storage::disk('public')->delete($prev);
                }
            }
            $country->payment_gateways = $gateways;
        }
        /* Buyer tax registration field. The label is what this country calls the number
           a business buyer puts on the invoice — GSTIN, VAT Number, TRN — and the regex
           is a format check only. Both are free text because only the operator knows
           what their jurisdiction asks for; BuyerTaxIdentity seeds sensible starting
           values per ISO code. */
        if ($request->has('buyer_tax_enabled')) {
            $country->buyer_tax_enabled = (int) $request->boolean('buyer_tax_enabled');
        }
        if ($request->has('buyer_tax_label')) {
            $label = trim((string) $request->input('buyer_tax_label'));
            $country->buyer_tax_label = $label !== '' ? $label : null;
        }
        if ($request->has('buyer_tax_regex')) {
            $country->buyer_tax_regex = trim((string) $request->input('buyer_tax_regex')) ?: null;
        }
    }

    /**
     * A broken pattern would reject every number a buyer typed, so it is checked here
     * rather than discovered at checkout. @ suppresses the warning preg_match emits for
     * an unparsable pattern — the false return is the answer we want.
     */
    private function invalidBuyerTaxRegexError(Request $request)
    {
        $regex = trim((string) $request->input('buyer_tax_regex', ''));
        if ($regex === '') {
            return null;
        }
        if (@preg_match('/' . str_replace('/', '\\/', $regex) . '/', '') === false) {
            return CommonHelper::responseError(__('invalid_tax_number_format_pattern'));
        }
        return null;
    }
    public function update(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'id' => 'required|exists:countries,id',
            'timezone' => 'required',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        if ($err = $this->invalidTimezoneError($request->timezone)) {
            return $err;
        }
        if ($err = $this->invalidBuyerTaxRegexError($request)) {
            return $err;
        }

        $country = Country::find($request->id);

        $translations = json_decode($request->translations, true);

        $defaultLanguage = $this->languageService->getDefaultLanguage();

        $country->dial_code = $request->dial_code ?? $country->dial_code;
        $country->code = $request->code ?? $country->code;
        $country->status = $request->status ?? $country->status;

        $country->logo = CommonHelper::uploadFile($request, 'logo', 'countries', $country->logo);

        // Update base name + policies from default language (fallback copy).
        if (is_array($translations) && isset($translations[$defaultLanguage->id])) {
            if (isset($translations[$defaultLanguage->id]['name'])) {
                $country->name = $translations[$defaultLanguage->id]['name'];
            }
            $this->applyBasePolicies($country, $translations, $defaultLanguage->id);
        }

        // Currency is required.
        if ($request->has('currency') && (trim((string) $request->currency) === '' || trim((string) $request->currency_code) === '')) {
            return CommonHelper::responseError(__('currency_is_required'));
        }
        // At least one payment gateway must be enabled (when gateways are provided).
        if ($request->has('payment_gateways')) {
            $gateways = json_decode($request->payment_gateways, true) ?: [];
            if (!$this->hasEnabledPaymentMethod($gateways)) {
                return CommonHelper::responseError(__('at_least_one_payment_method_must_be_enabled'));
            }
        }

        // Policies are required in the default language.
        if (is_array($translations)) {
            if ($err = $this->validateDefaultPolicies($translations, $defaultLanguage->id)) {
                return CommonHelper::responseError($err);
            }
        }

        $this->applyCountryConfig($country, $request);
        $country->save();

        foreach ($translations as $languageId => $data) {
            $country->saveTranslation($languageId, $this->translationPayload($data));
        }

        return CommonHelper::responseSuccess('country_updated_successfully');
    }

    public function setDefault(Request $request)
    {
        if (!isset($request->id)) {
            return CommonHelper::responseError('id_is_required');
        }
        $country = Country::find($request->id);
        if (!$country) {
            return CommonHelper::responseError('country_not_found');
        }
        if ((int) $country->status !== 1) {
            return CommonHelper::responseError('only_active_country_can_be_default');
        }

        DB::transaction(function () use ($country) {
            Country::where('is_default', 1)->where('id', '!=', $country->id)->update(['is_default' => 0]);
            $country->is_default = 1;
            $country->save();
        });

        return CommonHelper::responseSuccess('default_country_updated_successfully');
    }

    public function delete(Request $request)
    {
        if (!isset($request->id)) {
            return CommonHelper::responseError('id_is_required');
        }
        $country = Country::find($request->id);
        if (!$country) {
            return CommonHelper::responseSuccess("Country Already Deleted!");
        }

        if ((int) $country->is_default === 1) {
            return CommonHelper::responseError('default_country_cannot_be_deleted');
        }

        // Block hard-delete when referenced anywhere (history must survive). Admin should
        // deactivate (status = 0) instead.
        $referenced = Zone::where('country_id', $country->id)->exists()
            || Order::where('country_id', $country->id)->exists()
            || DeliveryBoy::where('country_id', $country->id)->exists()
            || User::where('country_id', $country->id)->exists()
            || UserWallet::where('country_id', $country->id)->exists()
            || DB::table('tax_rules')->where('country_id', $country->id)->exists();

        if ($referenced) {
            return CommonHelper::responseError('country_in_use_deactivate_instead');
        }

        $regionIds = Region::where('country_id', $country->id)->pluck('id');
        if ($regionIds->isNotEmpty()) {
            DB::table('region_translations')->whereIn('region_id', $regionIds)->delete();
            Region::whereIn('id', $regionIds)->delete();
        }

        $country->delete();
        return CommonHelper::responseSuccess('country_deleted_successfully');
    }

    /** All countries from config/Country.json, flagged with `imported` + a flag URL. */
    public function importList()
    {
        $all = json_decode(file_get_contents(config_path('Country.json')), true) ?: [];
        $existing = Country::pluck('code')->map(fn ($c) => strtoupper((string) $c))->all();
        $list = array_map(function ($c) use ($existing) {
            $code = strtoupper($c['code'] ?? '');
            $c['imported'] = in_array($code, $existing, true);
            $c['flag_url'] = 'https://flagcdn.com/24x18/' . strtolower($code) . '.png';
            return $c;
        }, $all);
        return CommonHelper::responseWithData($list);
    }

    /** Import selected countries by code; download each flag from a flag CDN. */
    public function import(Request $request)
    {
        $codes = $request->input('codes', []);
        if (is_string($codes)) {
            $codes = json_decode($codes, true) ?: [];
        }
        if (empty($codes)) {
            return CommonHelper::responseError('select_at_least_one_country');
        }

        $all = collect(json_decode(file_get_contents(config_path('Country.json')), true) ?: [])
            ->keyBy(fn ($c) => strtoupper($c['code'] ?? ''));
        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $imported = 0;
        $regionCount = 0;

        foreach ($codes as $code) {
            $code = strtoupper((string) $code);
            $src = $all->get($code);
            if (!$src || Country::whereRaw('UPPER(code) = ?', [$code])->exists()) {
                continue;
            }

            $country = new Country();
            $country->name = $src['name'] ?? $code;
            $country->dial_code = $src['dial_code'] ?? '';
            $country->code = $code;
            $country->status = 0; // inactive until admin configures currency/gateways
            $country->logo = $this->downloadFlag($code);
            $country->save();

            if ($defaultLanguage) {
                $country->saveTranslation($defaultLanguage->id, ['name' => $country->name]);
            }

            $regionCount += Region::importFromDataset(
                (int) $country->id,
                $code,
                null,
                $defaultLanguage?->id
            );

            $imported++;
        }

        return CommonHelper::responseSuccessWithData('countries_imported_successfully', [
            'imported'         => $imported,
            'regions_imported' => $regionCount,
        ]);
    }

    /** Resolve the country from country_id / country_code, else first active. */
    private function resolveCountryId(Request $request): ?int
    {
        if ($request->filled('country_id')) {
            return (int) $request->country_id;
        }
        if ($request->filled('country_code')) {
            $id = Country::whereRaw('UPPER(code) = ?', [strtoupper($request->country_code)])->value('id');
            if ($id) {
                return (int) $id;
            }
        }
        return Country::where('status', 1)->orderBy('id')->value('id');
    }

    /** Country-scoped policy content for a language, with default-language fallback. */
    private function policyContent(string $field, Request $request): string
    {
        $countryId = $this->resolveCountryId($request);
        if (!$countryId) {
            return '';
        }

        $langCode = $request->input('lang', 'en');
        $langId = optional($this->languageService->getLanguageByCode($langCode))->id;

        $val = $langId
            ? CountryTranslation::where('country_id', $countryId)->where('language_id', $langId)->value($field)
            : null;

        if (empty($val)) {
            $defLangId = Language::where('is_default', 1)->value('id');
            $val = CountryTranslation::where('country_id', $countryId)->where('language_id', $defLangId)->value($field);
        }
        if (empty($val)) {
            // Fallback to the default-language value stored on the countries base table.
            $val = Country::where('id', $countryId)->value($field);
        }

        return (string) ($val ?? '');
    }

    public function printPrivacyPolicy(Request $request)
    {
        echo $this->policyContent('privacy_policy', $request);
    }

    public function printReturnsAndExchangesPolicy(Request $request)
    {
        echo $this->policyContent('return_policy', $request);
    }

    public function printShippingPolicy(Request $request)
    {
        echo $this->policyContent('shipping_policy', $request);
    }

    public function printCancellationPolicy(Request $request)
    {
        echo $this->policyContent('cancellation_policy', $request);
    }

    public function printTermsConditions(Request $request)
    {
        echo $this->policyContent('terms_conditions', $request);
    }

    public function printPrivacyPolicyDeliveryBoy(Request $request)
    {
        echo $this->policyContent('privacy_policy_delivery_boy', $request);
    }

    public function printTermsConditionsDeliveryBoy(Request $request)
    {
        echo $this->policyContent('terms_conditions_delivery_boy', $request);
    }

    /** Download a country's flag by ISO code and store it; null on failure. */
    private function downloadFlag(string $code): ?string
    {
        try {
            $url = 'https://flagcdn.com/w160/' . strtolower($code) . '.png';
            $resp = Http::timeout(10)->get($url);
            if (!$resp->successful() || empty($resp->body())) {
                return null;
            }
            $path = 'countries/' . strtolower($code) . '_' . time() . '.png';
            Storage::disk('public')->put($path, $resp->body());
            return $path;
        } catch (\Throwable $e) {
            return null;
        }
    }
}
