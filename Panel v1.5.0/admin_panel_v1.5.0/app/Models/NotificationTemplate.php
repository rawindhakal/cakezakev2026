<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class NotificationTemplate extends Model
{
    protected $table = 'notification_templates';

    protected $fillable = ['type', 'title', 'message', 'placeholders'];

    protected $casts = [
        'placeholders' => 'array',
    ];

    /**
     * Translations per language (title, message).
     */
    public function translations(): HasMany
    {
        return $this->hasMany(NotificationTemplateTranslation::class, 'notification_template_id');
    }
}
