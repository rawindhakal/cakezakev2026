<?php

namespace Database\Seeders;

use App\Models\Country;
use App\Models\Region;
use App\Services\LanguageService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;

/**
 * Seeds a single default country (India) with COD enabled, so the panel has a
 * working country out of the box. Other countries are added/imported manually.
 */
class DefaultCountrySeeder extends Seeder
{
    public function run(): void
    {
        if (Country::whereRaw('UPPER(code) = ?', ['IN'])->exists()) {
            return;
        }

        $country = new Country();
        $country->name = 'India';
        $country->dial_code = '+91';
        $country->min_mobile_length = 10;
        $country->max_mobile_length = 10;
        $country->code = 'IN';
        $country->currency = '₹';
        $country->currency_code = 'INR';
        $country->decimal_point = 2;
        $country->date_format = 'd-m-Y';
        $country->time_format = 'h:i A';
        $country->timezone = 'Asia/Calcutta';
        $country->referral_min_order_amount = 0;
        $country->referral_credit_first_order = 0;
        $country->referral_credit_referred = 0;
        $country->status = 1;
        $country->is_default = 1;
        $country->payment_gateways = $this->defaultGateways();
        // Default-language policy fallback on the base table.
        foreach ($this->placeholderPolicies() as $field => $value) {
            $country->$field = $value;
        }
        $country->save();

        $defaultLanguage = app(LanguageService::class)->getDefaultLanguage();
        if ($defaultLanguage) {
            $country->saveTranslation($defaultLanguage->id, array_merge(
                ['name' => 'India'],
                $this->placeholderPolicies()
            ));
        }

        if (Schema::hasTable('regions')) {
            Region::importFromDataset((int) $country->id, 'IN', null, $defaultLanguage?->id);
        }
    }

    /** Placeholder policy content so the default country is edit-valid out of the box. */
    private function placeholderPolicies(): array
    {
        return [
            'privacy_policy'                => '<p>Privacy Policy</p>',
            'return_policy'  => '<p>Returns and Exchanges Policy</p>',
            'shipping_policy'               => '<p>Shipping Policy</p>',
            'cancellation_policy'           => '<p>Cancellation Policy</p>',
            'terms_conditions'              => '<p>Terms &amp; Conditions</p>',
            'privacy_policy_delivery_boy'   => '<p>Delivery Partner Privacy Policy</p>',
            'terms_conditions_delivery_boy' => '<p>Delivery Partner Terms &amp; Conditions</p>',
        ];
    }

    /** All gateways disabled except COD (enabled by default). */
    private function defaultGateways(): array
    {
        return [
            'payment_method_settings' => 1,
            'cod_payment_method' => 1, 'cod_mode' => 'global',
            'paypal_payment_method' => 0, 'paypal_mode' => '', 'paypal_currency_code' => '',
            'paypal_client_id' => '', 'paypal_client_secret' => '', 'paypal_webhook_id' => '',
            'razorpay_payment_method' => 0, 'razorpay_key' => '', 'razorpay_secret_key' => '',
            'paystack_payment_method' => 0, 'paystack_public_key' => '', 'paystack_secret_key' => '', 'paystack_currency_code' => '',
            'stripe_payment_method' => 0, 'stripe_mode' => '', 'stripe_publishable_key' => '', 'stripe_secret_key' => '',
            'stripe_webhook_secret_key' => '', 'stripe_currency_code' => '',
            'midtrans_payment_method' => 0, 'midtrans_mode' => '', 'midtrans_server_key' => '',
            'phonepay_payment_method' => 0, 'phonepay_mode' => '', 'phonepay_merchant_id' => '', 'phonepay_client_id' => '',
            'phonepay_client_version' => '', 'phonepay_client_secret' => '',
            'cashfree_payment_method' => 0, 'cashfree_mode' => '', 'cashfree_app_id' => '', 'cashfree_secret_key' => '',
            'paytabs_payment_method' => 0, 'paytabs_mode' => '', 'paytabs_profile_id' => '', 'paytabs_secret_key' => '',
        ];
    }
}
