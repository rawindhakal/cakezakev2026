<?php

namespace App\Services\Plugin;

use App\Plugins\Dto\LicenceResult;
use App\Models\Plugin;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Checks a plugin's purchase code against the validator.
 *
 * Same wire rule as the core purchase-code check
 * (GeneralSettingsApiController::verifyPurchaseCode) — success is a JSON body with
 * `error: false`, tried over IPv4 then IPv6 because some hosts resolve only one — but a
 * different endpoint, built here rather than read from the package: a plugin that could
 * name the server that licenses it could name one that always says yes. The product is
 * identified by an `X-Product-Key` header; without it the validator answers 401.
 *
 * The one thing it adds — and the important one — is telling **unreachable** apart from
 * **rejected**. A validator outage must never switch off a paying client's plugin, so an
 * answer we could not get changes nothing; only an explicit "no" marks a licence invalid.
 */
final class PluginLicenceService
{
    /** Raw check against a validator URL. No database, no state. */
    public function verify(string $validatorUrl, string $code, ?string $domain = null, ?string $productKey = null): LicenceResult
    {
        $code = trim($code);
        if ($code === '' || trim($validatorUrl) === '') {
            return LicenceResult::rejected('purchase_code_is_required');
        }

        $domain = $domain ?: (request()?->getSchemeAndHttpHost() ?: config('app.url'));
        $query = ['purchase_code' => $code, 'domain_url' => $domain];
        $productKey = $productKey ?: (string) config('license.product_key', 'cakezake');

        $lastError = null;
        foreach ([CURL_IPRESOLVE_WHATEVER, CURL_IPRESOLVE_V4, CURL_IPRESOLVE_V6] as $family) {
            try {
                $response = Http::timeout(15)
                    ->withHeaders(['X-Product-Key' => $productKey])
                    ->withOptions(['curl' => [CURLOPT_IPRESOLVE => $family]])
                    ->get($validatorUrl, $query);
            } catch (\Throwable $e) {
                $lastError = $e->getMessage();
                continue;
            }

            if (!$response->ok()) {
                $lastError = 'HTTP ' . $response->status();
                // A broken gateway answers in pages of HTML; the gist is enough.
                Log::warning('[Plugins] licence check returned ' . $lastError . ' for ' . $validatorUrl
                    . ': ' . mb_strimwidth(trim(preg_replace('/\s+/', ' ', (string) $response->body())), 0, 200, '…'));

                return LicenceResult::unreachable($response->status() === 429
                    ? 'licence_too_many_attempts'
                    : $lastError);
            }

            if ($response->json('error') === false) {
                return $this->accept((array) ($response->json() ?: []), $validatorUrl);
            }

            $message = (string) ($response->json('message') ?? 'licence_was_rejected');

            if (stripos($message, 'plugin not found') !== false) {
                Log::warning('[Plugins] licence validator does not know ' . $validatorUrl);

                return LicenceResult::unreachable($message);
            }

            return LicenceResult::rejected($message);
        }

        Log::warning('[Plugins] licence validator unreachable: ' . (string) $lastError);

        return LicenceResult::unreachable((string) $lastError);
    }

    /**
     * An accepted answer, once its signature has had its say.
     *
     * The validator does not sign yet, so an unsigned answer is still accepted on its
     * `error` flag — that is the behaviour every CakeZake product ships today. What is
     * NOT allowed is a signature that fails: a forged answer is refused now, before
     * signing is switched on, which is the half of this that cannot wait. Flip
     * `license.require_signature` the day every answer is signed and an unsigned one
     * stops being enough, with no code change.
     */
    private function accept(array $body, string $validatorUrl): LicenceResult
    {
        $verifier = app(\App\Services\Plugin\LicenseVerifier::class);
        $signed = $verifier->isSigned($body);
        $required = (bool) config('license.require_signature', false);

        if (!$signed) {
            if ($required) {
                Log::warning('[Plugins] licence answer refused: unsigned, and signatures are required. ' . $validatorUrl);

                return LicenceResult::rejected('licence_answer_was_not_signed');
            }

            return LicenceResult::valid();
        }

        if ($verifier->verifyFreshResponse($body) === null) {
            // Signed but wrong: a forgery, or a key we were never told to trust.
            // Not an outage, so this is a rejection rather than an unreachable.
            Log::error('[Plugins] licence answer failed signature verification. ' . $validatorUrl);

            return LicenceResult::rejected('licence_signature_could_not_be_verified');
        }

        return LicenceResult::valid();
    }

    /**
     * Verify a purchase code for a plugin, wherever that plugin is sold.
     *
     * A plugin is either universal — one purchase, any CakeZake product — or sold as part
     * of one product's line, and the two live at different validator paths. The package
     * does not say which, deliberately: a manifest field naming its own licence server
     * would be a package choosing who may license it. So the universal line is asked
     * first and the product line second, and "not found" is the only answer that moves
     * on to the next. A rejection stops there, because a wrong code is a wrong code.
     *
     * @return LicenceResult with `url` set to whichever line answered
     */
    public function verifyPurchase(string $slug, string $code, ?string $domain = null): LicenceResult
    {
        $domain = $domain ?: (request()?->getSchemeAndHttpHost());

        foreach ([$this->universalValidatorUrlFor($slug), $this->validatorUrlFor($slug)] as $url) {
            $result = $this->verify($url, $code, $domain);
            $result->url = $url;

            if ($result->ok) {
                return $result;
            }

            // Only "this line has never heard of that plugin" is worth asking elsewhere.
            if ($result->reachable || stripos((string) $result->message, 'not found') === false) {
                return $result;
            }
        }

        return $result;
    }

    /**
     * Where a product-specific plugin is verified: `plugin/cakezake/cakezake-shiprocket`.
     *
     * Sold with CakeZake and licensed against CakeZake's own plugin line.
     */
    public function validatorUrlFor(string $slug): string
    {
        $product = (string) config('license.product_key', 'cakezake');

        return $this->validatorBase() . '/' . $product . '/' . $product . '-' . $slug;
    }

    /**
     * Where a universal plugin is verified: `plugin/universal-plugins/<slug>`.
     *
     * One purchase that works in any CakeZake product cannot be verified against a
     * per-product line — the same code has to check out whichever product asks. The
     * slug is unprefixed, because it is the same plugin everywhere.
     */
    public function universalValidatorUrlFor(string $slug): string
    {
        return $this->validatorBase() . '/universal-plugins/' . $slug;
    }

    /** `https://validator.cakezake.com/plugin`, with no trailing slash. */
    private function validatorBase(): string
    {
        return rtrim((string) config('license.validator_url', 'https://validator.cakezake.com'), '/') . '/plugin';
    }

}
