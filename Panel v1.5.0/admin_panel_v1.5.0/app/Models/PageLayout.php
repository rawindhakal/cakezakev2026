<?php

namespace App\Models;

use App\Traits\LogsActivity;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Page Builder page: a standalone tree of Home Builder sections.
 *
 * Global by design — no zone/channel; product blocks resolve against the
 * customer's zone when served. Like HomeLayout it deliberately avoids
 * HasTranslations (that trait bypasses $casts on the JSON columns); the
 * translatable title is a {langId: text} map flattened by the customer API.
 */
class PageLayout extends Model
{
    use HasFactory, LogsActivity;

    protected $table = 'page_layouts';

    protected $guarded = [];

    protected $casts = [
        'branch_id'       => 'integer',
        'title'          => 'array',
        'draft_json'     => 'array',
        'published_json' => 'array',
        'is_active'      => 'boolean',
        'published_at'   => 'datetime',
    ];

    /** The owning branch; null for an admin page. */
    public function branch()
    {
        return $this->belongsTo(Branch::class, 'branch_id');
    }

    /** Pages the app may open: published and switched on. */
    public function scopeServable(Builder $query): Builder
    {
        return $query->where('status', 'published')->where('is_active', 1);
    }

    /** Promote the draft tree to published. */
    public function publishDraft(): void
    {
        $this->published_json = $this->draft_json;
        $this->status = 'published';
        $this->published_at = now();
        $this->save();
    }

    public function markPublished(): void
    {
        $this->status = 'published';
        $this->published_at = now();
        $this->save();
    }

    /**
     * Names of the home layouts and other pages whose trees (draft or published)
     * still redirect to this page. Walked in PHP: the tables hold a handful of
     * rows and redirect ids are stored as int or string depending on the picker.
     *
     * @return string[]
     */
    public function referencedBy(): array
    {
        $id = (int) $this->id;
        $found = false;
        $walk = function ($node) use (&$walk, &$found, $id) {
            if ($found || !is_array($node)) {
                return;
            }
            if (($node['redirect_type'] ?? null) === 'page' && (int) ($node['redirect_id'] ?? 0) === $id) {
                $found = true;
                return;
            }
            foreach ($node as $child) {
                $walk($child);
            }
        };

        $names = [];
        $layoutCols = ['draft_json', 'published_json', 'category_layouts_draft', 'category_layouts_published'];
        foreach (HomeLayout::select(array_merge(['id', 'name'], $layoutCols))->cursor() as $layout) {
            $found = false;
            foreach ($layoutCols as $col) {
                $walk($layout->{$col});
            }
            if ($found) {
                $names[] = $layout->name;
            }
        }
        foreach (static::where('id', '!=', $id)->select(['id', 'name', 'draft_json', 'published_json'])->cursor() as $page) {
            $found = false;
            $walk($page->draft_json);
            $walk($page->published_json);
            if ($found) {
                $names[] = $page->name;
            }
        }

        return $names;
    }
}
