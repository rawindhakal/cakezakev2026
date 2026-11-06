<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FaqTranslation extends Model
{
     use HasFactory;

    protected $table = 'faq_translations';

    protected $fillable = [
        'faq_id',
        'language_id',
        'question',
        'answer',
    ];

    protected $hidden = [
        'created_at',
        'updated_at',
    ];

    public function faq()
    {
        return $this->belongsTo(Faq::class, 'faq_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}