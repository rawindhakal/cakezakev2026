<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AttributeTranslation extends Model
{
    use HasFactory;

    protected $table = 'attribute_translations';

    protected $fillable = [
        'attribute_id',
        'language_id',
        'name',
    ];

    protected $hidden = ['created_at', 'updated_at'];

    public function attribute()
    {
        return $this->belongsTo(Attribute::class, 'attribute_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}
