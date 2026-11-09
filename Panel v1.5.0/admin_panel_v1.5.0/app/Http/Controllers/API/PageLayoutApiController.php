<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\PageLayout;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

/**
 * Page Builder: standalone pages built from Home Builder sections. Pages are
 * global; the only ownership rule is that a branch user sees and edits its own
 * branch's pages, while admin pages (branch_id null) belong to the admin panel.
 */
class PageLayoutApiController extends Controller
{
    private array $metaFields = ['name', 'slug', 'is_active', 'header_color', 'title_color'];

    /** '#rgb', '#rrggbb' or '#rrggbbaa' — what the panel's colour picker emits. */
    private const HEX_COLOR = 'regex:/^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/';

    private array $jsonFields = ['title', 'draft_json', 'published_json'];

    public function getPages(Request $request)
    {
        $pages = PageLayout::query()
            ->select(['id', 'name', 'slug', 'title', 'branch_id', 'status', 'is_active', 'published_at', 'created_at', 'updated_at'])
            ->orderByDesc('id');

        $branchId = $this->ownBranchId();
        if ($branchId !== null) {
            $pages->where('branch_id', $branchId);
        }

        return CommonHelper::responseWithData($pages->get());
    }

    /**
     * Pages a redirect picker may target. Every page is listed (the builder
     * labels drafts / inactive ones) so a banner can be wired before the page
     * goes live. A branch user sees its own pages plus the admin's.
     */
    public function options()
    {
        $pages = PageLayout::query()
            ->select(['id', 'name', 'slug', 'status', 'is_active'])
            ->orderBy('name');

        $branchId = $this->ownBranchId();
        if ($branchId !== null) {
            $pages->where(fn ($q) => $q->whereNull('branch_id')->orWhere('branch_id', $branchId));
        }

        return CommonHelper::responseWithData($pages->get());
    }

    public function edit($id)
    {
        $page = PageLayout::find($id);
        if (!$page || !$this->canAccess($page)) {
            return CommonHelper::responseError('page_not_found');
        }
        return CommonHelper::responseWithData($page);
    }

    public function save(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'id'             => 'nullable|integer',
            'name'           => 'required|string|max:191',
            'slug'           => 'nullable|string|max:191',
            'title'          => 'nullable|array',
            'is_active'      => 'nullable|boolean',
            'draft_json'     => 'nullable|array',
            'published_json' => 'nullable|array',
            'header_color'   => ['nullable', 'string', self::HEX_COLOR],
            'title_color'    => ['nullable', 'string', self::HEX_COLOR],
            'seo'            => 'nullable|array',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $existing = $request->filled('id') ? PageLayout::find($request->id) : null;
        if ($request->filled('id') && (!$existing || !$this->canAccess($existing))) {
            return CommonHelper::responseError('page_not_found');
        }

        // Slug: given → normalised and must be free; blank → kept, or derived from the name.
        $slug = $request->filled('slug')
            ? Str::slug($request->input('slug'))
            : ($existing?->slug ?: '');
        if ($slug === '') {
            $slug = CommonHelper::slugify($request->input('name'), 'page_layouts');
        }
        $taken = PageLayout::where('slug', $slug)
            ->when($existing, fn ($q) => $q->where('id', '!=', $existing->id))
            ->exists();
        if ($taken) {
            return CommonHelper::responseError('slug_already_exists');
        }
        $request->merge(['slug' => $slug]);

        return DB::transaction(function () use ($request, $existing) {
            $page = $existing ?: new PageLayout();

            foreach ($this->metaFields as $field) {
                if ($request->has($field)) {
                    $page->{$field} = $request->input($field);
                }
            }
            // The bar is white unless a colour is picked; the title's default belongs to
            // the apps, so a blank one is left null for them to decide.
            if ($request->has('header_color') && trim((string) $request->input('header_color')) === '') {
                $page->header_color = '#FFFFFF';
            }
            if ($request->has('title_color') && trim((string) $request->input('title_color')) === '') {
                $page->title_color = null;
            }
            if ($request->has('seo')) {
                $page->seo = self::cleanSeo($request->input('seo'));
            }
            // Uploaded image URLs are stored as storage-relative paths, same as home layouts.
            foreach ($this->jsonFields as $field) {
                if ($request->has($field)) {
                    $page->{$field} = HomeLayoutApiController::normalizeImagePaths($request->input($field));
                }
            }

            if (!$page->exists) {
                $page->status   = 'draft';
                $page->branch_id = $this->ownBranchId();
            }

            $page->save();

            return CommonHelper::responseSuccessWithData('page_saved_successfully', $page->fresh());
        });
    }

    /** Whitelist and trim the SEO block so the page head and JSON-LD stay predictable. */
    public static function cleanSeo($raw): array
    {
        $raw = is_array($raw) ? $raw : [];
        $str = fn ($k, $max) => mb_substr(trim(strip_tags((string) ($raw[$k] ?? ''))), 0, $max);
        $faqs = [];
        foreach ((array) ($raw['faqs'] ?? []) as $f) {
            $q = mb_substr(trim(strip_tags((string) ($f['q'] ?? ''))), 0, 200);
            $a = mb_substr(trim(strip_tags((string) ($f['a'] ?? ''))), 0, 1000);
            if ($q !== '' && $a !== '') {
                $faqs[] = ['q' => $q, 'a' => $a];
            }
        }
        $og = trim((string) ($raw['og_image'] ?? ''));
        $og = preg_replace('#^https?://[^/]+/storage/#', '', $og);
        return [
            'meta_title'       => $str('meta_title', 70),
            'meta_description' => $str('meta_description', 180),
            'keywords'         => $str('keywords', 300),
            'h1'               => $str('h1', 120),
            'intro'            => $str('intro', 2500),
            'og_image'         => $og,
            'kind'             => $str('kind', 30),
            'faqs'             => array_slice($faqs, 0, 12),
        ];
    }

    public function publish(Request $request)
    {
        $page = $this->findOwned($request);
        if (!$page) {
            return CommonHelper::responseError('page_not_found');
        }

        if ($request->input('from') === 'published') {
            $page->markPublished();
        } else {
            $page->publishDraft();
        }

        return CommonHelper::responseSuccessWithData('page_published_successfully', $page->fresh());
    }

    public function clone(Request $request)
    {
        $source = $this->findOwned($request);
        if (!$source) {
            return CommonHelper::responseError('page_not_found');
        }

        // A copy starts as a draft seeded with whatever the source is showing.
        $copy = $source->replicate(['published_at']);
        $copy->name           = $request->filled('name') ? $request->input('name') : $source->name . ' (copy)';
        $copy->slug           = CommonHelper::slugify($copy->name, 'page_layouts');
        $copy->status         = 'draft';
        $copy->published_at   = null;
        $copy->draft_json     = $source->published_json ?: $source->draft_json;
        $copy->published_json = null;
        $copy->is_active      = 1;
        $copy->save();

        return CommonHelper::responseWithData([
            'id'      => $copy->id,
            'message' => __('page_cloned_successfully'),
        ]);
    }

    /** Only a published page can be switched on/off — a draft has nothing to serve. */
    public function toggleActive(Request $request)
    {
        $page = $this->findOwned($request);
        if (!$page) {
            return CommonHelper::responseError('page_not_found');
        }
        if ($page->status !== 'published') {
            return CommonHelper::responseError('only_published_page_can_be_activated');
        }
        $page->is_active = (int) $request->boolean('is_active');
        $page->save();

        return CommonHelper::responseSuccessWithData('page_status_updated', $page->fresh());
    }

    /**
     * A page that home layouts / other pages still redirect to is only deleted
     * with `force=1` — the first call reports who uses it so the panel can ask
     * again. Once gone, those redirects degrade to 'none' when served.
     */
    public function delete(Request $request)
    {
        if (!$request->filled('id')) {
            return CommonHelper::responseError('page_not_found');
        }
        $page = PageLayout::find($request->id);
        if (!$page) {
            return CommonHelper::responseSuccess('page_deleted_successfully');
        }
        if (!$this->canAccess($page)) {
            return CommonHelper::responseError('page_not_found');
        }

        if (!$request->boolean('force')) {
            $usedBy = $page->referencedBy();
            if ($usedBy) {
                return CommonHelper::responseWithData([
                    'in_use'  => true,
                    'used_by' => $usedBy,
                ]);
            }
        }

        $page->delete();

        return CommonHelper::responseSuccess('page_deleted_successfully');
    }

    /** Page images live in their own folder (page_builder/), apart from home layouts. */
    public function uploadImage(Request $request)
    {
        return (new HomeLayoutApiController())->uploadImage($request, 'page_builder');
    }

    // ---------------------------------------------------------------- helpers

    /** The page named by `id`, or null when missing / not this user's. */
    private function findOwned(Request $request): ?PageLayout
    {
        if (!$request->filled('id')) {
            return null;
        }
        $page = PageLayout::find($request->id);
        return $page && $this->canAccess($page) ? $page : null;
    }

    /** Branch users own only their branch's pages; everyone else is unrestricted. */
    private function canAccess(PageLayout $page): bool
    {
        $branchId = $this->ownBranchId();
        return $branchId === null || (int) $page->branch_id === $branchId;
    }

    /** The branch a branch user acts for, null for admin-panel users. */
    private function ownBranchId(): ?int
    {
        $user = auth()->user();
        if ($user && $user->isBranchUser() && $user->branch) {
            return (int) $user->branch->id;
        }
        return null;
    }
}
