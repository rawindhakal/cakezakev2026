<?php

/*
|--------------------------------------------------------------------------
| Universal plugin licensing
|--------------------------------------------------------------------------
|
| CakeZake products share one plugin format, so they must share one licence contract
| too. This file is that contract, and it is deliberately identical in every product
| — only `product_key` differs. A plugin sold as "universal" is verified against
| `{validator_url}/plugin/universal-plugins/{slug}`; one sold for a single product
| against `{validator_url}/plugin/{product_key}/{slug}`.
|
| Keys are pinned here, never fetched at runtime: a validator that could hand us the
| key it signed with could sign anything. Add a rotation as a second entry and deploy
| it BEFORE the validator starts using it, or clients will reject the new signatures.
|
| Ed25519 keys are base64 of the raw 32 bytes, NOT PEM. RSA keys are PEM, and are the
| fallback for a host without ext-sodium.
*/

return [

    'ed25519_public_keys' => [
        'v1' => env('LICENSE_ED25519_PUBLIC_KEY_V1', ''),
    ],

    'rsa_public_keys' => [
        'v1' => env('LICENSE_RSA_PUBLIC_KEY_V1', env('LICENSE_PUBLIC_KEY', '')),
    ],

    /** Base URL only; the installer appends the per-plugin path. */
    'validator_url' => env('LICENSE_VALIDATOR_URL', 'https://validator.cakezake.com'),

    /** Catalogue of buyable plugins. */
    'marketplace_url' => env('LICENSE_MARKETPLACE_URL', 'https://validator.cakezake.com/api/plugins'),

    /** Sent as X-Product-Key; the validator refuses the call without it. */
    'product_key' => env('LICENSE_PRODUCT_KEY', 'cakezake'),

    /**
     * Reject a just-fetched token whose issued_at is further from now than this.
     * Applies only to a live response — a stored token is old by definition.
     */
    'issued_at_skew_seconds' => (int) env('LICENSE_ISSUED_AT_SKEW', 300),

    /**
     * Whether an unsigned validator response is refused.
     *
     * The validator does not sign yet. Until it does, a response carrying no
     * payload_b64 is accepted on its `error` flag alone, and one that DOES carry a
     * signature is always verified — so signing can be switched on at the validator
     * without a client deploy, and a forged signature is rejected today. Flip this to
     * true once every validator answer is signed; then an unsigned answer is refused.
     */
    'require_signature' => (bool) env('LICENSE_REQUIRE_SIGNATURE', false),

];
