<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * The pairing between our reference and a universal plugin's own payment id.
 *
 * See the table's migration for why it has to exist. In short: the universal format
 * gives the host no way to make a plugin carry our reference through the gateway, so
 * the host writes down which gateway payment belongs to which order before the shopper
 * leaves, and re-asks the gateway about that id when they come back.
 */
class PluginPaymentIntent extends Model
{
    protected $fillable = [
        'plugin_slug',
        'reference',
        'gateway_payment_id',
        'amount',
        'currency',
        'user_id',
        'country_id',
        'purpose',
        'status',
    ];

    protected $casts = [
        'amount'     => 'float',
        'user_id'    => 'integer',
        'country_id' => 'integer',
    ];

    public function isSettled(): bool
    {
        return in_array($this->status, ['succeed', 'failed'], true);
    }
}
