<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PromoCodeTranslation extends Model
{
    use HasFactory;

    protected $table = 'promo_code_translations';

    protected $fillable = [
        'promo_code_id',
        'language_id',
        'title',
        'description',
    ];

    protected $hidden = [
        'created_at',
        'updated_at',
    ];

    public function promoCode()
    {
        return $this->belongsTo(PromoCode::class, 'promo_code_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}

