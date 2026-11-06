<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * An installed plugin.
 *
 * The row is the source of truth for what is installed and whether it may boot; the
 * compiled cache (bootstrap/cache/plugins.php) is only a fast copy of the enabled ones.
 * The purchase code is encrypted at rest and never leaves the server — the panel is
 * shown `purchase_code_last4` instead.
 */
class Plugin extends Model
{
    protected $table = 'plugins';

    protected $fillable = [
        'slug', 'name', 'version', 'type', 'manifest', 'status', 'enabled',
        'purchase_code', 'purchase_code_last4', 'verify_url',
        'licence_state', 'licence_verified_at', 'licence_message', 'lang_keys',
        'installed_by', 'installed_at', 'last_error',
    ];

    protected $hidden = ['purchase_code'];

    protected $casts = [
        'manifest'            => 'array',
        'lang_keys'           => 'array',
        'enabled'             => 'boolean',
        'purchase_code'       => 'encrypted',
        'licence_verified_at' => 'datetime',
        'installed_at'        => 'datetime',
    ];


    /* ---------------------------------------------------------------- status */

    public const STATUS_INSTALLED   = 'installed';
    public const STATUS_ACTIVE      = 'active';
    public const STATUS_DISABLED    = 'disabled';
    public const STATUS_UNINSTALLED = 'uninstalled';
    public const STATUS_BROKEN      = 'broken';

    /*
     | A purchase code is checked once, when the plugin is installed, and the answer
     | stands. There is no scheduled re-check: a shop that paid for a plugin should not
     | have it stop working because a validator was unreachable on a Tuesday, and a
     | nightly call to our own server on every client's install buys nothing that the
     | install-time check did not already establish.
     |
     | `unverified` is therefore not "not yet checked" — install never leaves a plugin
     | in it. It means the stored purchase code can no longer be decrypted, which
     | happens when APP_KEY is rotated. The plugin keeps working and the panel asks for
     | the code again, because an APP_KEY rotation is not a licence problem.
     */
    public const LICENCE_VALID      = 'valid';
    public const LICENCE_INVALID    = 'invalid';
    public const LICENCE_UNVERIFIED = 'unverified';

    /** Licence states in which a plugin is still allowed to run. */
    public function licenceAllowsBoot(): bool
    {
        return in_array($this->licence_state, [self::LICENCE_VALID, self::LICENCE_UNVERIFIED], true);
    }

    public function shouldBoot(): bool
    {
        return $this->enabled
            && $this->status !== self::STATUS_UNINSTALLED
            && $this->licenceAllowsBoot();
    }

    /** The code is write-only from the API's point of view; keep the hint in sync. */
    public function setPurchaseCode(?string $code): void
    {
        $code = trim((string) $code);
        $this->purchase_code = $code !== '' ? $code : null;
        $this->purchase_code_last4 = $code !== '' ? substr($code, -4) : null;
    }
}
