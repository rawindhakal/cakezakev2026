<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * What one addon option costs at one branch, and whether that branch offers it at all.
 *
 * Money is per branch for the same reason product money is (`product_variant_branch_stocks`):
 * a branch sits in a zone, a zone in a country, and every country prices in its own currency
 * with no conversion anywhere in the stack. A missing row means the option is not offered
 * at that branch, rather than offered at some other branch's number.
 */
class ProductAddonOptionBranch extends Model
{
    use HasFactory;

    protected $table = 'product_addon_option_branches';

    protected $fillable = [
        'addon_option_id',
        'branch_id',
        'is_available',
        'price',
        'discounted_price',
    ];

    protected $casts = [
        'is_available'     => 'boolean',
        'price'            => 'float',
        'discounted_price' => 'float',
    ];

    protected $hidden = ['created_at', 'updated_at'];

    /**
     * What this row actually charges, per unit. `discounted_price` of 0 means "no offer" —
     * the same convention products use — so an offer applies only when it is set and
     * genuinely cheaper than the list price.
     */
    public function chargeablePrice(): float
    {
        $price = (float) $this->price;
        $offer = (float) $this->discounted_price;

        return ($offer > 0 && $offer < $price) ? $offer : $price;
    }

    public function option()
    {
        return $this->belongsTo(ProductAddonOption::class, 'addon_option_id');
    }

    public function branch()
    {
        return $this->belongsTo(Branch::class, 'branch_id');
    }
}
