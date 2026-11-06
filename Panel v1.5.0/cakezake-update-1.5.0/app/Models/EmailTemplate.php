<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class EmailTemplate extends Model
{
    use HasFactory;
    public $timestamps = true;

    protected $fillable = ['type', 'title', 'message', 'placeholders'];

    protected $casts = [
        'placeholders' => 'array',
    ];

    public function translations(): HasMany
    {
        return $this->hasMany(EmailTemplateTranslation::class, 'email_template_id');
    }
}
