<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SmsTemplate extends Model
{
    use HasFactory;
    // Specify the table if it's different from the default plural form
    protected $table = 'sms_templates';

    // Specify the fields that are mass assignable
    protected $fillable = [
        'message',
        'type',
        'placeholders',
    ];

    protected $casts = [
        'placeholders' => 'array',
    ];

    public function translations()
    {
        return $this->hasMany(SmsTemplateTranslation::class, 'sms_template_id');
    }
}