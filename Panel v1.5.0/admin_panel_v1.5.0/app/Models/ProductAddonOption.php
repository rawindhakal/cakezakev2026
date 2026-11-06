<?php

namespace App\Models;

use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * One answer to an addon group's question.
 *
 * A CUSTOM option is a name priced per branch. A LINKED option IS a catalogue product —
 * "add a Coke" — and draws on that variant's real stock at the same branch, which is the
 * whole point of linking rather than retyping it as a custom option: one selection is one
 * unit of that variant.
 *
 * The option carries no money of its own: every price lives in
 * `product_addon_option_branches`, exactly as a product variant's does.
 */
class ProductAddonOption extends Model
{
    use HasFactory, HasTranslations, SoftDeletes;

    protected $fillable = [
        'addon_group_id',
        'name',
        'image',
        'product_type',
        'linked_variant_id',
        'is_free',
        'price_source',
        'sort_order',
        'status',
    ];

    protected $casts = [
        'product_type'      => 'integer',
        'linked_variant_id' => 'integer',
        'is_free'           => 'integer',
        'sort_order'        => 'integer',
        'status'            => 'integer',
    ];

    protected $translatable = ['name'];

    protected $translationModel = 'ProductAddonOptionTranslation';

    protected $translationForeignKey = 'addon_option_id';

    protected $appends = ['translations'];

    protected $hidden = ['created_at', 'updated_at', 'deleted_at'];

    /**
     * The picture to show for this option, or '' when it has none.
     *
     * A linked option wears its own product's image rather than keeping a copy: the
     * catalogue is already the source of truth for what a Coke looks like, and a second
     * upload could only ever drift from it. Eager-load `linkedVariant.product` wherever
     * this is called in a loop.
     */
    public function imageUrl(): string
    {
        $path = $this->imagePath();

        return $path ? asset('storage/' . $path) : '';
    }

    /** Own image, else the linked variant's, else that variant's product image. */
    public function imagePath(): ?string
    {
        if ($this->image) {
            return $this->image;
        }

        if (!$this->linked_variant_id) {
            return null;
        }

        $variant = $this->linkedVariant;

        return $variant ? ($variant->image ?: ($variant->product->image ?? null)) : null;
    }

    public function productType(): int
    {
        if (!$this->linked_variant_id) {
            return (int) $this->product_type;
        }

        $variant = $this->linkedVariant;

        return (int) ($variant->product->product_type ?? 0);
    }

    public function isLinked(): bool
    {
        return !empty($this->linked_variant_id);
    }

    /** True when the price should follow the linked variant's own branch price. */
    public function followsCatalogue(): bool
    {
        return $this->isLinked() && $this->price_source === 'product';
    }

    public function group()
    {
        return $this->belongsTo(ProductAddonGroup::class, 'addon_group_id');
    }

    public function linkedVariant()
    {
        return $this->belongsTo(ProductVariant::class, 'linked_variant_id');
    }

    public function branchPrices()
    {
        return $this->hasMany(ProductAddonOptionBranch::class, 'addon_option_id');
    }

    public function translations()
    {
        return $this->hasMany(ProductAddonOptionTranslation::class, 'addon_option_id');
    }

    /** This option's row for one branch, or null when the branch does not carry it. */
    public function branchRow(?int $branchId): ?ProductAddonOptionBranch
    {
        if (!$branchId) {
            return null;
        }

        return $this->relationLoaded('branchPrices')
            ? $this->branchPrices->firstWhere('branch_id', $branchId)
            : $this->branchPrices()->where('branch_id', $branchId)->first();
    }
}
