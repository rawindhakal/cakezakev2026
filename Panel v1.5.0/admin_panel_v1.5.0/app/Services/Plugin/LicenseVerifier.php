<?php

namespace App\Services\Plugin;

use Illuminate\Support\Facades\Log;

/**
 * Checks the signature on a validator's answer.
 *
 * A purchase-code check is only worth as much as its transport. `error: false` over
 * HTTPS proves the answer came from whoever holds the certificate; a signature proves
 * it came from the key CakeZake signs with, which is the claim that actually matters
 * once a client controls their own DNS, hosts file and CA branch.
 *
 * Two rules keep this honest:
 *
 *  * The signature is checked against the exact bytes the validator signed
 *    (`payload_b64`), never against a payload rebuilt from fields we store. Rebuilding
 *    would mean a client could edit a column and have the signature still agree.
 *  * Keys are pinned in config and never fetched. A validator that could hand us the
 *    key to check it with could sign anything at all.
 *
 * The validator does not sign yet. Until it does, `verifyFreshResponse()` returns
 * `null` for an unsigned answer and the caller decides what that means — currently
 * "accept on the error flag", switchable to "refuse" with `license.require_signature`
 * the day signing ships, without touching this class.
 */
final class LicenseVerifier
{
    /** True when the answer carries something for us to check at all. */
    public function isSigned(array $response): bool
    {
        return !empty($response['payload_b64']) && !empty($response['signature']);
    }

    /**
     * Verify a just-received answer and return its decoded payload.
     *
     * Null means "do not trust this", for every reason: unsigned, bad signature,
     * unknown key, undecodable, or a timestamp too far from now. A replayed answer from
     * months ago is refused by the skew guard — which is applied only here, to a live
     * response, because a stored token is old by definition.
     */
    public function verifyFreshResponse(array $response): ?array
    {
        if (!$this->isSigned($response)) {
            return null;
        }

        $payload = $this->verifiedBytes($response);

        if ($payload === null) {
            return null;
        }

        $decoded = json_decode($payload, true);

        if (!is_array($decoded)) {
            return null;
        }

        $skew = (int) config('license.issued_at_skew_seconds', 300);

        if (isset($decoded['issued_at']) && abs(time() - (int) $decoded['issued_at']) > $skew) {
            Log::warning('[Licence] signed answer rejected: issued_at outside the allowed skew.', [
                'issued_at' => $decoded['issued_at'],
                'skew'      => $skew,
            ]);

            return null;
        }

        return $decoded;
    }

    /**
     * Verify a stored token, which has no skew guard to apply.
     *
     * Used when a decision has to be made without asking the validator again, so the
     * answer on file is still proven rather than assumed.
     */
    public function verifiedPayload(array $stored): ?array
    {
        if (!$this->isSigned($stored)) {
            return null;
        }

        $payload = $this->verifiedBytes($stored);

        if ($payload === null) {
            return null;
        }

        $decoded = json_decode($payload, true);

        return is_array($decoded) ? $decoded : null;
    }

    /** The signed bytes, returned only when the signature over them checks out. */
    private function verifiedBytes(array $response): ?string
    {
        $alg = strtolower((string) ($response['alg'] ?? 'ed25519'));
        $publicKey = $this->publicKey($alg, $response['key_id'] ?? null);

        if (!$publicKey) {
            Log::warning('[Licence] no pinned public key for this answer.', [
                'alg'    => $alg,
                'key_id' => $response['key_id'] ?? null,
            ]);

            return null;
        }

        $payload = base64_decode((string) $response['payload_b64'], true);
        $signature = base64_decode((string) $response['signature'], true);

        if ($payload === false || $signature === false) {
            return null;
        }

        return $this->signatureValid($payload, $signature, $publicKey, $alg) ? $payload : null;
    }

    private function signatureValid(string $payload, string $signature, string $publicKey, string $alg): bool
    {
        if ($alg === 'ed25519') {
            if (!function_exists('sodium_crypto_sign_verify_detached')) {
                // No ext-sodium. The RSA variant exists precisely for this host.
                Log::warning('[Licence] ext-sodium is not installed; an Ed25519 answer cannot be verified.');

                return false;
            }

            // Pinned Ed25519 keys are base64 of the raw 32 bytes, not PEM.
            $rawKey = base64_decode($publicKey, true);

            if ($rawKey === false || strlen($rawKey) !== SODIUM_CRYPTO_SIGN_PUBLICKEYBYTES) {
                Log::warning('[Licence] pinned Ed25519 key is not 32 raw bytes of base64.');

                return false;
            }

            try {
                return sodium_crypto_sign_verify_detached($signature, $payload, $rawKey);
            } catch (\SodiumException $e) {
                return false;
            }
        }

        if ($alg === 'rsa') {
            return openssl_verify($payload, $signature, $publicKey, OPENSSL_ALGO_SHA256) === 1;
        }

        Log::warning("[Licence] unknown signature algorithm '{$alg}'.");

        return false;
    }

    /** A key is used only if it was pinned here before the validator used it. */
    private function publicKey(string $alg, ?string $keyId): ?string
    {
        $keyId = $keyId !== null && $keyId !== '' ? $keyId : 'v1';
        $bag = $alg === 'rsa' ? 'license.rsa_public_keys' : 'license.ed25519_public_keys';
        $key = (string) config($bag . '.' . $keyId, '');

        return trim($key) !== '' ? $key : null;
    }
}
