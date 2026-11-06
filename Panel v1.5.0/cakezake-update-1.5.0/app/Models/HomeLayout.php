<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\LogsActivity;

/**
 * Home Builder layout config.
 *
 * NOTE: deliberately does NOT use HasTranslations. The trait's getAttribute()
 * override returns raw attributes for $translatable fields, bypassing $casts —
 * which would break the JSON columns here. Translatable text in the Home Builder
 * lives inside the layout JSON as per-language maps ({langId: "text"}) and is
 * flattened by the customer API.
 */
class HomeLayout extends Model
{
    use HasFactory, LogsActivity;

    protected $table = 'home_layouts';

    protected $guarded = [];

    protected $casts = [
        'zone_id' => 'integer',
        'channel_label' => 'array',
        'category_ids' => 'array',
        'category_ids_quick' => 'array',
        'category_ids_ecommerce' => 'array',
        'draft_json' => 'array',
        'published_json' => 'array',
        'category_layouts_draft' => 'array',
        'category_layouts_published' => 'array',
        'category_tabs_draft' => 'array',
        'category_tabs_published' => 'array',
        'is_active' => 'boolean',
        'published_at' => 'datetime',
        'scheduled_publish_at' => 'datetime',
    ];

    /** A layout targets exactly one zone, or is the global fallback (zone_id null). */
    public function zone()
    {
        return $this->belongsTo(Zone::class, 'zone_id');
    }

    public function isGlobal(): bool
    {
        return $this->zone_scope === 'global';
    }

    /**
     * Promote the current draft to published: copy draft trees over the published
     * ones, flip status, stamp published_at, and clear any pending schedule.
     * Shared by the manual publish endpoint and the scheduled-publish cron.
     */
    public function publishDraft(): void
    {
        $this->published_json = $this->draft_json;
        $this->category_layouts_published = $this->category_layouts_draft;
        $this->category_tabs_published = $this->category_tabs_draft;
        $this->status = 'published';
        $this->published_at = now();
        $this->scheduled_publish_at = null;
        $this->save();
    }

    public function markPublished(): void
    {
        $this->status = 'published';
        $this->published_at = now();
        $this->save();
    }
}
