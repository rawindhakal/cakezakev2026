<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A shipping plugin's credentials, in the shared format's generic columns.
 *
 * The payment side has `PaymentConfiguration`; this is its counterpart, and the columns
 * are deliberately the same generic ones — `api_key`, `secret_key`, `additional_data_1`
 * — so a plugin reads `$config->secret_key` without the host having to understand what
 * that carrier calls it. That is what lets the same package run in another product.
 *
 * Unlike the payment one this is a real row: a courier account is one contract with one
 * carrier, not something that varies per country the way a merchant account does.
 */
class ShippingConfiguration extends Model
{
    protected $table = 'shipping_configurations';

    protected $fillable = [
        'provider',
        'api_key',
        'secret_key',
        'webhook_secret_key',
        'additional_data_1',
        'additional_data_2',
        'payment_mode',
        'username',
        'password',
        'currency_code',
        'status',
        'extra',
    ];

    protected $casts = [
        'status' => 'boolean',
        'extra'  => 'array',
    ];

    /**
     * Columns holding something that must never be sent back to a browser.
     *
     * Saving the form must not require retyping them, so the panel is told whether each
     * is set rather than what it is.
     */
    public const SECRET_COLUMNS = ['secret_key', 'webhook_secret_key', 'password'];

    /** The row for one plugin, created empty the first time it is asked for. */
    public static function forProvider(string $provider): self
    {
        return static::firstOrNew(['provider' => $provider]);
    }

    public function isSecretColumn(string $column): bool
    {
        return in_array($column, self::SECRET_COLUMNS, true);
    }

    /**
     * What the settings form may show.
     *
     * A secret comes back empty, never masked-but-present: the form sends its values
     * straight back on save, so a placeholder string would be written into the column
     * the first time someone saved the page without retyping the password. Whether a
     * secret is set is reported separately, in `secretsSet()`, which the form uses only
     * to decide what the empty box should say.
     */
    public function exposedValues(array $columns): array
    {
        $out = [];

        foreach ($columns as $column) {
            $out[$column] = $this->isSecretColumn($column) ? '' : (string) ($this->{$column} ?? '');
        }

        return $out;
    }

    /** column => whether something is stored, for the "••••••••" placeholder. */
    public function secretsSet(array $columns): array
    {
        $out = [];

        foreach ($columns as $column) {
            if ($this->isSecretColumn($column)) {
                $out[$column] = filled($this->{$column});
            }
        }

        return $out;
    }

    /**
     * A host-side policy value, kept in `extra`.
     *
     * These are not credentials and not the plugin's to declare — "assign the waybill
     * as soon as a parcel is booked" is a decision about how this shop wants to work,
     * and a carrier integration has no opinion on it. They live beside the credentials
     * because they are configured on the same screen and scoped to the same carrier.
     */
    public function policy(string $key, $default = null)
    {
        return data_get($this->extra ?? [], $key, $default);
    }

    public function setPolicy(string $key, $value): void
    {
        $extra = (array) ($this->extra ?? []);
        $extra[$key] = $value;
        $this->extra = $extra;
    }
}
