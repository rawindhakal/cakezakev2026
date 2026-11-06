<?php

namespace App\Models;

use App\Services\LanguageService;
use App\Traits\HasTranslations;
use App\Traits\LogsActivity;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * One question a food product puts to the customer — "Choose crust", "Add toppings".
 *
 * The group belongs to ONE product. Twenty pizzas each own their toppings list, so
 * repricing one cannot silently reprice the other nineteen; the admin's copy-from-another-
 * product tool is what stops that meaning twenty rounds of typing.
 */
class ProductAddonGroup extends Model
{
    use HasFactory, HasTranslations, SoftDeletes, LogsActivity;

    protected $fillable = [
        'product_id',
        'name',
        'input_type',
        'is_required',
        'min_select',
        'max_select',
        'max_qty_per_option',
        'sort_order',
        'status',
    ];

    protected $casts = [
        'is_required'        => 'boolean',
        'min_select'         => 'integer',
        'max_select'         => 'integer',
        'max_qty_per_option' => 'integer',
        'sort_order'         => 'integer',
        'status'             => 'integer',
    ];

    protected $translatable = ['name'];

    protected $translationModel = 'ProductAddonGroupTranslation';

    protected $translationForeignKey = 'addon_group_id';

    protected $appends = ['translations'];

    protected $hidden = ['created_at', 'updated_at', 'deleted_at'];

    /** Exactly one choice, or several — this is what the apps render from. */
    public function isSingleChoice(): bool
    {
        return $this->input_type === 'radio';
    }

    /**
     * The helper line under the group's title: "Required • Select any 1 option".
     *
     * Derived from the rules rather than typed by an operator, for two reasons: it can
     * never contradict what the group actually enforces, and it comes out in the
     * customer's own language without anyone translating it by hand. The locale is the
     * one the request resolved (Content-Language), falling back to the app default.
     */
    public function selectionText(?string $locale = null): string
    {
        $locale = $locale ?: (LanguageService::getCurrentCode() ?: app()->getLocale());

        $min  = (int) $this->min_select;
        $max  = (int) $this->max_select;          // 0 = no limit
        $per  = max(1, (int) $this->max_qty_per_option);

        $parts = [];
        if ($this->is_required) {
            $parts[] = __('addon_rule_required', [], $locale);
        }

        if ($this->isSingleChoice()) {
            $parts[] = __('addon_rule_select_one', [], $locale);
        } elseif ($min > 0 && $max > 0 && $min === $max) {
            $parts[] = trans_choice('addon_rule_select_exactly', $max, ['count' => $max], $locale);
        } elseif ($min > 0 && $max > 0) {
            $parts[] = __('addon_rule_select_between', ['min' => $min, 'max' => $max], $locale);
        } elseif ($max > 0) {
            $parts[] = trans_choice('addon_rule_select_up_to', $max, ['count' => $max], $locale);
        } elseif ($min > 0) {
            $parts[] = trans_choice('addon_rule_select_at_least', $min, ['count' => $min], $locale);
        } else {
            $parts[] = __('addon_rule_select_any', [], $locale);
        }

        if ($per > 1) {
            $parts[] = trans_choice('addon_rule_up_to_each', $per, ['count' => $per], $locale);
        }

        return implode(' • ', array_filter($parts));
    }

    public function product()
    {
        return $this->belongsTo(Product::class, 'product_id');
    }

    public function options()
    {
        return $this->hasMany(ProductAddonOption::class, 'addon_group_id')
            ->orderBy('sort_order')->orderBy('id');
    }

    /** Only the options a customer may actually pick right now. */
    public function activeOptions()
    {
        return $this->options()->where('status', 1);
    }

    public function translations()
    {
        return $this->hasMany(ProductAddonGroupTranslation::class, 'addon_group_id');
    }
}
