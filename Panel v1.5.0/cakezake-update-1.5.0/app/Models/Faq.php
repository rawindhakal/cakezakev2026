<?php

namespace App\Models;

use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\LogsActivity;

class Faq extends Model
{
    use HasFactory,HasTranslations, LogsActivity;
    public $timestamps = false;

        protected $translatable = [
        'question',
        'answer',
    ];

        protected $translationForeignKey = 'faq_id';
    protected $translationModel = 'FaqTranslation';

    protected $appends = ['translations'];

    protected $hidden = ['status','branch_id'];

    protected $fillable = ['question', 'answer', 'sort_order', 'status', 'branch_id'];

}
