<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use RuntimeException;

/**
 * A universal payment plugin's credentials, in the shape the format defines.
 *
 * Every CakeZake product hands a plugin one of these, so the plugin can read
 * `$config->api_key` without knowing anything about where the host keeps it. In most
 * products it is a row in a `payment_configurations` table. In CakeZake it is not: a
 * gateway's keys live per country in the `countries.payment_gateways` JSON column,
 * because the same shop sells through several countries with different merchant
 * accounts, and that is the behaviour plugin gateways have to inherit rather than lose.
 *
 * So this is a read-only view, built per request from the country the order belongs to
 * (see App\Plugins\Adapters\PaymentConfig). It is an Eloquent model only because
 * plugins may call `toArray()` or `getAttribute()` on it; it is never queried and never
 * saved, and saving is refused outright rather than silently writing a row that nothing
 * reads back.
 *
 * The column names are the format's, not ours. They are generic on purpose — `api_key`
 * is a client id for one gateway and a merchant key for another — which is what lets a
 * host store a plugin's settings without understanding them.
 */
class PaymentConfiguration extends Model
{
    protected $table = 'payment_configurations';

    public $timestamps = false;

    /** The format's full column set. A plugin may read any of them. */
    protected $fillable = [
        'payment_method',
        'api_key',
        'secret_key',
        'webhook_secret_key',
        'currency_code',
        'status',
        'additional_data_1',
        'additional_data_2',
        'payment_mode',
        'username',
        'password',
    ];

    /**
     * Build the view a plugin is given.
     *
     * Missing values come back as null rather than absent, so a plugin reading a
     * credential its host never collected gets the same "not configured" it would get
     * from an empty column instead of an undefined-property surprise.
     */
    public static function view(string $paymentMethod, array $values = []): self
    {
        $config = new self();

        $config->setRawAttributes(array_merge(
            array_fill_keys($config->getFillable(), null),
            ['payment_method' => $paymentMethod, 'status' => 1],
            array_intersect_key($values, array_flip($config->getFillable()))
        ));

        return $config;
    }

    /* ------------------------------------------------------------------ read only */

    public function save(array $options = [])
    {
        throw new RuntimeException(
            'PaymentConfiguration is a read-only view of countries.payment_gateways in CakeZake. '
            . 'Save the country instead.'
        );
    }

    public function delete()
    {
        throw new RuntimeException('PaymentConfiguration is a read-only view and cannot be deleted.');
    }
}
