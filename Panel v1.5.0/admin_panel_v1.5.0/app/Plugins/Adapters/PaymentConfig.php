<?php

namespace App\Plugins\Adapters;

use App\Helpers\CommonHelper;
use App\Models\PaymentConfiguration;

/**
 * Turns a country's gateway keys into the config object a universal plugin expects.
 *
 * CakeZake keeps a gateway's credentials in `countries.payment_gateways`, prefixed with
 * the gateway's code: `payu-india-payment-gateway_api_key`. The universal format
 * expects an object with bare generic columns: `api_key`. This is the whole of the
 * translation, and keeping it in one function is what lets the per-country decision
 * stay a CakeZake detail the plugin never sees.
 */
final class PaymentConfig
{
    /**
     * @param array $values either a country's full `payment_gateways` array, or the
     *                      already-un-prefixed credentials from a PaymentContext
     */
    public static function build(string $code, array $values): PaymentConfiguration
    {
        return PaymentConfiguration::view($code, self::credentials($code, $values));
    }

    /**
     * Accepts both shapes a caller might hold.
     *
     * `initiate()` is handed credentials core already stripped; the webhook door only
     * has the raw country column. Detecting which we were given — rather than demanding
     * one — is what keeps the bridge callable from both without the caller caring.
     */
    private static function credentials(string $code, array $values): array
    {
        $prefix = strtolower($code) . '_';

        foreach (array_keys($values) as $key) {
            if (str_starts_with(strtolower((string) $key), $prefix)) {
                return CommonHelper::gatewayCredentials($values, $code);
            }
        }

        return $values;
    }
}
