<?php

namespace App\Models;

use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class AttributeValue extends Model
{
    use HasFactory, HasTranslations, SoftDeletes;

    protected $fillable = [
        'attribute_id',
        'value',
    ];

    protected $translatable = ['value'];

    protected $translationModel = 'AttributeValueTranslation';

    protected $translationForeignKey = 'attribute_value_id';

    protected $appends = ['translations'];

    protected $hidden = ['created_at', 'updated_at', 'deleted_at'];

    public function attribute()
    {
        return $this->belongsTo(Attribute::class);
    }
}
