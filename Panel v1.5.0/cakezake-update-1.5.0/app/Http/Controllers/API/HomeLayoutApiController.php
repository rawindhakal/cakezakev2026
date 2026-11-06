<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\HomeLayout;
use App\Models\Role;
use App\Models\Zone;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class HomeLayoutApiController extends Controller
{
    /**
     * Metadata fields persisted by save() (everything except the layout JSON).
     */
    private array $metaFields = [
        'name', 'mode', 'home_type', 'zone_scope', 'zone_id', 'category_scope',
        'category_build_method', 'is_active',
    ];

    private array $jsonFields = [
        'category_ids', 'category_ids_quick', 'category_ids_ecommerce',
        'channel_label', 'draft_json', 'published_json', 'category_layouts_draft', 'category_layouts_published',
        'category_tabs_draft', 'category_tabs_published',
    ];

    public function getLayouts(Request $request)
    {
        $layouts = HomeLayout::with('zone:id,name,sales_channel')->orderBy('id', 'desc')->get();

        // Branch users only manage their own zone's layouts — never the global default.
        $authUser = auth()->user();
        if ($authUser && $authUser->isBranchUser() && $authUser->branch) {
            $branchZoneId = (int) $authUser->branch->zone_id;
            $layouts = $layouts->filter(
                fn ($l) => ($l->zone_scope ?? 'global') === 'zone' && (int) $l->zone_id === $branchZoneId
            )->values();
            return CommonHelper::responseWithData($layouts);
        }

        $countryId = (int) $request->input('country_id', 0);
        if ($countryId) {
            $countryZoneIds = Zone::where('country_id', $countryId)->pluck('id')->map(fn ($id) => (int) $id)->all();
            $layouts = $layouts->filter(function ($layout) use ($countryZoneIds) {
                if (($layout->zone_scope ?? 'global') === 'global') {
                    return true;
                }
                return in_array((int) $layout->zone_id, $countryZoneIds, true);
            })->values();
        }

        $zoneId = (int) $request->input('zone_id', 0);
        if ($zoneId) {
            $layouts = $layouts->filter(function ($layout) use ($zoneId) {
                if (($layout->zone_scope ?? 'global') === 'global') {
                    return true;
                }
                return (int) $layout->zone_id === $zoneId;
            })->values();
        }

        return CommonHelper::responseWithData($layouts);
    }

    public function edit($id)
    {
        $layout = HomeLayout::find($id);
        if (!$layout) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        if (!$this->branchCanAccessLayout($layout)) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        return CommonHelper::responseWithData($layout);
    }

    /**
     * A branch user may only touch its OWN zone's layout (never the global default
     * or another zone's). Non-branch users are unrestricted.
     */
    private function branchCanAccessLayout(?HomeLayout $layout): bool
    {
        $authUser = auth()->user();
        if (!$authUser || !$authUser->isBranchUser()) {
            return true;
        }
        if (!$layout || !$authUser->branch) {
            return false;
        }
        return ($layout->zone_scope ?? 'global') === 'zone'
            && (int) $layout->zone_id === (int) $authUser->branch->zone_id;
    }

    public function save(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name'       => 'required|string|max:191',
            'mode'       => 'required|in:quick,ecommerce',
            'home_type'  => 'required|in:single,category_wise',
            'zone_scope' => 'required|in:global,zone',
            'zone_id'    => 'nullable|integer|exists:zones,id',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // A branch user's layout is always zone-scoped to its own branch's zone —
        // it can never create/own the global default.
        $branchUser = auth()->user();
        if ($branchUser && $branchUser->isBranchUser() && $branchUser->branch) {
            $request->merge(['zone_scope' => 'zone', 'zone_id' => (int) $branchUser->branch->zone_id]);
        }

        // A default (global) layout's channel + scope are locked so each channel
        // always keeps a fallback default — ignore any attempt to change them.
        $existing = $request->filled('id') ? HomeLayout::find($request->id) : null;
        if ($existing && !$this->branchCanAccessLayout($existing)) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        if ($existing && $existing->zone_scope === 'global') {
            $request->merge(['mode' => $existing->mode, 'zone_scope' => 'global']);
        }

        $conflict = $this->findScopeConflict($request);
        if ($conflict) {
            return CommonHelper::responseError($conflict);
        }

        return DB::transaction(function () use ($request) {
            $layout = $request->filled('id') ? HomeLayout::find($request->id) : new HomeLayout();
            if ($request->filled('id') && !$layout) {
                return CommonHelper::responseError('home_layout_not_found');
            }

            foreach ($this->metaFields as $field) {
                if ($request->has($field)) {
                    $layout->{$field} = $request->input($field);
                }
            }
            // Layout JSON + array columns — casts handle encoding.
            foreach ($this->jsonFields as $field) {
                if ($request->has($field)) {
                    $layout->{$field} = self::normalizeImagePaths($request->input($field));
                }
            }

            // Keep status: a published layout stays 'published' while its draft
            // diverges; only re-publish flips published_json.
            if (!$layout->exists) {
                $layout->status = 'draft';
            }

            $layout->save();

            return CommonHelper::responseSuccessWithData('home_layout_saved_successfully', $layout->fresh());
        });
    }

    /**
     * Enforces scope uniqueness:
     *  - only one DEFAULT layout (zone_scope=global) per channel
     *  - a zone may belong to only one layout per channel
     * Layouts conflict only when they share the same channel (mode).
     *
     * @return string|null  translation key of the conflict, or null when clear
     */
    private function findScopeConflict(Request $request): ?string
    {
        $mode      = $request->input('mode');
        $zoneScope = $request->input('zone_scope');
        $selfId    = $request->input('id');

        $overlaps = fn ($other) => $other === $mode;

        $others = HomeLayout::when($selfId, fn ($q) => $q->where('id', '!=', $selfId))->get();

        if ($zoneScope === 'global') {
            foreach ($others as $o) {
                if ($o->zone_scope === 'global' && $overlaps($o->mode)) {
                    return 'a_default_layout_already_exists';
                }
            }
            return null;
        }

        $zoneId = (int) $request->input('zone_id');
        if (!$zoneId) {
            return 'please_select_a_zone';
        }

        // The zone must actually serve this layout's channel — a 'both' zone serves either.
        $zone = Zone::find($zoneId);
        if (!$zone || !$zone->servesChannel($mode)) {
            return 'selected_zone_does_not_serve_this_channel';
        }

        foreach ($others as $o) {
            if ($o->zone_scope === 'zone' && $overlaps($o->mode) && (int) $o->zone_id === $zoneId) {
                return 'some_zones_already_have_layout';
            }
        }
        return null;
    }

    public function clone(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'id'      => 'required|integer|exists:home_layouts,id',
            'zone_id' => 'required|integer|exists:zones,id',
            'name'    => 'nullable|string|max:191',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $source = HomeLayout::find($request->input('id'));
        if (!$this->branchCanAccessLayout($source)) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        $zoneId = (int) $request->input('zone_id');

        $zone = Zone::find($zoneId);
        if (!$zone || !$zone->servesChannel($source->mode)) {
            return CommonHelper::responseError(__('selected_zone_does_not_serve_this_channel'));
        }

        // One layout per (zone, channel).
        $taken = HomeLayout::where('zone_scope', 'zone')
            ->where('zone_id', $zoneId)
            ->where('mode', $source->mode)
            ->exists();
        if ($taken) {
            return CommonHelper::responseError(__('some_zones_already_have_layout'));
        }

        $copy = $source->replicate([
            'published_at',
        ]);
        $copy->zone_scope = 'zone';
        $copy->zone_id    = $zoneId;
        $copy->name       = $request->filled('name')
            ? $request->input('name')
            : $source->name . ' (' . ($zone->getRawOriginal('name') ?: ('Zone #' . $zone->id)) . ')';

        // Start as an unpublished draft, seeded with whatever the source is showing
        $copy->status                     = 'draft';
        $copy->published_at               = null;
        $copy->draft_json                 = $source->published_json ?: $source->draft_json;
        $copy->category_layouts_draft     = $source->category_layouts_published ?: $source->category_layouts_draft;
        $copy->category_tabs_draft        = $source->category_tabs_published ?: $source->category_tabs_draft;
        $copy->published_json             = null;
        $copy->category_layouts_published = null;
        $copy->category_tabs_published    = null;
        $copy->is_active                  = 1;
        $copy->save();

        return CommonHelper::responseWithData([
            'id'      => $copy->id,
            'message' => __('home_layout_cloned_successfully'),
        ]);
    }

    public function publish(Request $request)
    {
        if (!$request->filled('id')) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        $layout = HomeLayout::find($request->id);
        if (!$layout) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        if (!$this->branchCanAccessLayout($layout)) {
            return CommonHelper::responseError('home_layout_not_found');
        }

        if ($request->input('from') === 'published') {
            $layout->markPublished();
        } else {
            $layout->publishDraft();
        }

        return CommonHelper::responseSuccessWithData('home_layout_published_successfully', $layout->fresh());
    }

    public function schedule(Request $request)
    {
        if (!$request->filled('id')) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        $layout = HomeLayout::find($request->id);
        if (!$layout) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        if (!$this->branchCanAccessLayout($layout)) {
            return CommonHelper::responseError('home_layout_not_found');
        }

        $raw = trim((string) $request->input('scheduled_publish_at'));

        // Empty → cancel any existing schedule.
        if ($raw === '') {
            $layout->scheduled_publish_at = null;
            $layout->save();
            return CommonHelper::responseSuccessWithData('home_layout_schedule_cancelled', $layout->fresh());
        }

        try {
            $when = Carbon::parse($raw, 'UTC');
        } catch (\Throwable $e) {
            return CommonHelper::responseError('invalid_schedule_time');
        }

        if ($when->lessThanOrEqualTo(Carbon::now('UTC'))) {
            return CommonHelper::responseError('schedule_time_must_be_in_future');
        }

        $layout->scheduled_publish_at = $when;
        $layout->save();

        return CommonHelper::responseSuccessWithData('home_layout_scheduled_successfully', $layout->fresh());
    }

    /**
     * Toggle a layout's active flag. Only published layouts can be toggled —
     * a draft has no published_json to serve, so activating it is meaningless.
     */
    public function toggleActive(Request $request)
    {
        if (!$request->filled('id')) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        $layout = HomeLayout::find($request->id);
        if (!$layout) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        if (!$this->branchCanAccessLayout($layout)) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        if ($layout->status !== 'published') {
            return CommonHelper::responseError('only_published_layout_can_be_activated');
        }
        $active = $request->boolean('is_active');
        // The global (default) layout is the customer app's fallback — it must
        // always stay active so there is something to resolve.
        if (!$active && $layout->zone_scope === 'global') {
            return CommonHelper::responseError('default_home_layout_cannot_be_deactivated');
        }
        $layout->is_active = (int) $active;
        $layout->save();

        return CommonHelper::responseSuccessWithData('home_layout_status_updated', $layout->fresh());
    }

    public function delete(Request $request)
    {
        if (!$request->filled('id')) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        $layout = HomeLayout::find($request->id);
        if (!$layout) {
            return CommonHelper::responseSuccess('home_layout_deleted_successfully');
        }
        if (!$this->branchCanAccessLayout($layout)) {
            return CommonHelper::responseError('home_layout_not_found');
        }
        // A global layout is the fallback the customer app resolves when no
        // zone-scoped layout matches. At least one must always exist, so the
        // last remaining global layout cannot be deleted.
        if ($layout->zone_scope === 'global'
            && HomeLayout::where('zone_scope', 'global')->count() <= 1) {
            return CommonHelper::responseError('at_least_one_global_home_layout_required');
        }
        $layout->delete();
        return CommonHelper::responseSuccess('home_layout_deleted_successfully');
    }

    public static function normalizeImagePaths($value)
    {
        if (is_array($value)) {
            return array_map([self::class, 'normalizeImagePaths'], $value);
        }
        if (is_string($value) && preg_match('#^https?://[^/]+/storage/((?:home_builder|page_builder)/.+)$#i', $value, $m)) {
            return $m[1];
        }
        return $value;
    }

    /**
     * Upload a banner / title image used inside the layout JSON.
     * Returns the storage-relative path the builder branches in the config
     * (plus the resolved URL for immediate preview).
     */
    public function uploadImage(Request $request, string $dir = 'home_builder')
    {
        // Kept in step with HbImageUpload.vue's maxSizeMb, and stated in MB rather than
        // Laravel's default kilobyte wording so the panel shows the admin the real limit.
        $maxMb = 10;
        $size = $maxMb . ' MB';
        // These two keys are shared with the Vue uploader, whose __() takes {name}
        // placeholders, so they are filled here by hand rather than through __()'s :name.
        $validator = Validator::make($request->all(), [
            'image' => 'required|file|mimes:jpeg,jpg,png,gif,webp,svg|max:' . ($maxMb * 1024),
        ], [
            'image.max'   => str_replace('{size}', $size, __('file_size_exceeds_limit_x')),
            'image.mimes' => str_replace(
                ['{types}', '{size}'],
                ['JPG, PNG, GIF, WEBP, SVG', $size],
                __('allowed_types_and_max_size')
            ),
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $path = CommonHelper::uploadFile($request, 'image', $dir);

        return CommonHelper::responseWithData([
            'path' => $path,
            'url'  => asset('storage/' . $path),
        ]);
    }
}
