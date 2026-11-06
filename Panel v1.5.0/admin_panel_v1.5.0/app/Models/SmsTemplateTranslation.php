<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SmsTemplateTranslation extends Model
{
    use HasFactory;

    protected $table = 'sms_template_translations';

    protected $fillable = [
        'sms_template_id',
        'language_id',
        'message',
        'gateway_template_ids',
    ];

    protected $casts = [
        'gateway_template_ids' => 'array',
    ];

    public function template()
    {
        return $this->belongsTo(SmsTemplate::class, 'sms_template_id');
    }
}
