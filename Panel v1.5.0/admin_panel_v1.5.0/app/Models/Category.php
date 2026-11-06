<?php

namespace App\Models;


use App\Helpers\CommonHelper;
use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\LogsActivity;

class Category extends Model
{
    use HasFactory, HasTranslations, LogsActivity;

    protected $translatable = [
        'name',
        'meta_title',
        'meta_keywords',
        'schema_markup',
        'meta_description',
    ];

    protected $translationModel = 'CategoryTranslation';

    protected $appends = ['image_url','has_child','has_active_child','translations'];

    protected $hidden = ['created_at','updated_at','deleted_at'];

    public function getImageUrlAttribute(){
        return CommonHelper::modelImageUrl($this, 'image');
    }

    public function parent(){
        return $this->hasOne(Category::class,'id','parent_id');
    }

    public function allParents() {
        return $this->parent()->with('allParents');
    }

    public function childs() {
        return $this->hasMany(Category::class,'parent_id','id');
    }

    public function allChilds() {
        return $this->childs()->with('allChilds');
    }

    public function activeChilds() {
        return $this->hasMany(Category::class,'parent_id','id')->where('status',1);
    }

    public function allActiveChilds() {
        return $this->activeChilds()->with('allActiveChilds');
    }

    public function catChilds() {
        return $this->hasMany(Category::class,'parent_id','id');
    }

    public function getHasChildAttribute(){
        $hasChild = false;
        if($this->catChilds->count() > 0){
            $hasChild = true;
        }
        unset($this->catChilds);
        return $hasChild;
    }

    public function catActiveChilds() {
        return $this->hasMany(Category::class,'parent_id','id')->where('status',1);
    }

    public function getHasActiveChildAttribute(){
        $hasChild = false;
        if($this->catActiveChilds->count() > 0){
            $hasChild = true;
            foreach ($this->catActiveChilds as $child) {
                $child->parent_name = $this->name; // Assuming you want to use the name of the parent as parent_name
            }
        }

        return $hasChild;
    }

    public function categoryAttributes()
    {
        return $this->belongsToMany(Attribute::class, 'category_attribute')
            ->withPivot(['is_overridden_off'])
            ->withTimestamps();
    }

    public function customSections()
    {
        return $this->hasMany(CategoryCustomSection::class)->orderBy('sort_order');
    }

    public function products()
    {
        return $this->hasMany(Product::class, 'category_id', 'id');
    }

    /**
     * Walk parent chain. Returns ancestor categories root-first (root..parent..self excluded).
     */
    public function ancestorChain(): array
    {
        $chain = [];
        $current = $this;
        $guard = 0;
        while ($current && $current->parent_id && $guard++ < 50) {
            $parent = self::find($current->parent_id);
            if (!$parent) {
                break;
            }
            array_unshift($chain, $parent);
            $current = $parent;
        }
        return $chain;
    }

    /**
     * Effective attributes for this category: own + inherited from ancestors,
     * minus any that descendants flagged is_overridden_off=1.
     * Returns collection keyed by attribute_id.
     */
    public function effectiveAttributes()
    {
        $chain = $this->ancestorChain();
        $chain[] = $this;

        $effective = collect();
        $turnedOff = collect();

        foreach ($chain as $cat) {
            if (!$cat->relationLoaded('categoryAttributes')) {
                $cat->load(['categoryAttributes' => function ($q) {
                    $q->withPivot(['is_overridden_off'])
                        ->with(['values' => function ($vq) {
                            $vq->withAllTranslations();
                        }])
                        ->withAllTranslations();
                }]);
            }
            foreach ($cat->categoryAttributes as $attr) {
                $pivot = $attr->pivot;
                if ($pivot->is_overridden_off) {
                    $turnedOff->push($attr->id);
                    continue;
                }
                $effective->put($attr->id, $attr);
            }
        }

        $items = $effective->reject(fn ($a) => $turnedOff->contains($a->id))->values()->all();
        return new \Illuminate\Database\Eloquent\Collection($items);
    }

    /**
     * Effective custom sections (with fields). Inherited from ancestors,
     * overridden by descendants when they re-define same name, or suppressed via is_overridden_off.
     */
    public function effectiveCustomSections()
    {
        $chain = $this->ancestorChain();
        $chain[] = $this;

        $effective = collect();
        $turnedOff = collect();

        foreach ($chain as $cat) {
            if (!$cat->relationLoaded('customSections')) {
                $cat->load(['customSections' => function ($q) {
                    $q->withAllTranslations()
                        ->with(['fields' => function ($fq) {
                            $fq->withAllTranslations();
                        }]);
                }]);
            }
            $sections = $cat->customSections;
            foreach ($sections as $section) {
                if ($section->is_overridden_off) {
                    $turnedOff->push($section->name);
                    continue;
                }
                // child section with same name overrides parent
                $effective->put($section->name, $section);
            }
        }

        $items = $effective->reject(fn ($s) => $turnedOff->contains($s->name))->values()->all();
        return new \Illuminate\Database\Eloquent\Collection($items);
    }
}
