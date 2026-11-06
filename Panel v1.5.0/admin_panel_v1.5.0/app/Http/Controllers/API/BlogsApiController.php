<?php

namespace App\Http\Controllers\API;

use Illuminate\Support\Str;
use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\ApiCallTracking;
use App\Models\Blog;
use App\Models\BlogCategory;
use App\Models\BlogTag;
use App\Models\BlogView;
use App\Models\Setting;
use Illuminate\Support\Facades\Log;
use App\Services\LanguageService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class BlogsApiController extends Controller
{
    protected $languageService;

    public function __construct(LanguageService $languageService)
    {
        $this->languageService = $languageService;
    }

    public function getBlogCategories(Request $request)
    {
        try {
            $query = BlogCategory::with('translations')
                ->withCount(['activeBlogs'])
                ->orderByDesc('id');

            if ($request->filled('search')) {
                $search = $request->search;
                $query->where(function ($q) use ($search) {
                    if (is_numeric($search)) {
                        $q->where('id', $search);
                    } else {
                        $q->where('name', 'like', '%' . $search . '%');
                    }

                    if (strtolower($search) == 'active' || $search == '1') {
                        $q->orWhere('status', 1);
                    } elseif (strtolower($search) == 'deactive' || strtolower($search) == 'inactive' || $search == '0') {
                        $q->orWhere('status', 0);
                    }

                    $q->orWhere('name', 'like', '%' . $search . '%')
                        ->orWhereHas('translations', function ($query) use ($search) {
                            $query->where('name', 'like', '%' . $search . '%');
                        });
                });
            }


            $total = (clone $query)->count();
            $categories = $query->get();

            return CommonHelper::responseWithData($categories, $total);
        } catch (\Throwable $e) {
            return CommonHelper::responseError('something_went_wrong');
        }
    }

    public function createBlogCategory(Request $request)
    {
        $defaultLangId = $this->languageService->getDefaultLanguage()->id;

        // Check if translations array exists
        if (empty($request->translations) || !is_array($request->translations)) {
            return CommonHelper::responseError('default_language_name_required');
        }

        // Handle both string and integer keys for language ID
        $defaultTranslation = null;
        if (isset($request->translations[$defaultLangId]) && is_array($request->translations[$defaultLangId])) {
            $defaultTranslation = $request->translations[$defaultLangId];
        } elseif (isset($request->translations[(string) $defaultLangId]) && is_array($request->translations[(string) $defaultLangId])) {
            $defaultTranslation = $request->translations[(string) $defaultLangId];
        }

        if (!$defaultTranslation || empty($defaultTranslation['name']) || trim($defaultTranslation['name']) === '') {
            return CommonHelper::responseError('default_language_name_required');
        }

        try {
            $validator = Validator::make($request->all(), [
                'slug' => 'required|string|max:255|unique:blog_categories,slug',
                'status' => 'required|in:0,1',
                'translations' => 'required|array',
                'translations.*.name' => 'nullable|string|max:255',
                'translations.*.meta_title' => 'nullable|string|max:255',
                'translations.*.meta_keywords' => 'nullable|string',
                'translations.*.meta_description' => 'nullable|string',
            ]);

            if ($validator->fails()) {
                return CommonHelper::responseError($validator->errors()->first());
            }

            // Get the name value, ensuring it's not empty
            $categoryName = trim($defaultTranslation['name'] ?? '');
            if (empty($categoryName)) {
                return CommonHelper::responseError('default_language_name_required');
            }

            // Create base category
            $category = BlogCategory::create([
                'slug' => $request->slug,
                'status' => $request->status,
                'name' => $categoryName,
                'meta_title' => $defaultTranslation['meta_title'] ?? '',
                'meta_keywords' => $defaultTranslation['meta_keywords'] ?? '',
                'meta_description' => $defaultTranslation['meta_description'] ?? '',
                'schema_markup' => $defaultTranslation['schema_markup'] ?? '',
            ]);

            // Save translation

            foreach ($request->translations as $langId => $data) {

                $category->saveTranslation($langId, [
                    'name' => $data['name'] ?: null,
                    'meta_title' => $data['meta_title'] ?: null,
                    'meta_keywords' => $data['meta_keywords'] ?: null,
                    'meta_description' => $data['meta_description'] ?: null,
                    'schema_markup' => $data['schema_markup'] ?: null,
                ]);
            }
            return CommonHelper::responseSuccessWithData(
                'category_created_successfully',
                $category->load('translations')
            );
        } catch (\Exception $e) {
            return CommonHelper::responseError($e->getMessage());
        }
    }

    public function updateBlogCategory(Request $request)
    {
        $defaultLangId = $this->languageService->getDefaultLanguage()->id;
        $category = BlogCategory::find($request->id);

        if (!$category) {
            return CommonHelper::responseError('category_not_found');
        }

        // Handle both string and integer keys for language ID
        $defaultTranslation = null;
        if (isset($request->translations[$defaultLangId])) {
            $defaultTranslation = $request->translations[$defaultLangId];
        } elseif (isset($request->translations[(string) $defaultLangId])) {
            $defaultTranslation = $request->translations[(string) $defaultLangId];
        }

        $category->update([
            'slug' => $request->slug,
            'status' => $request->status,
            'name' => $defaultTranslation['name'] ?? $category->name, // insert default language name
            'meta_title' => $defaultTranslation['meta_title'] ?? $category->meta_title,
            'meta_keywords' => $defaultTranslation['meta_keywords'] ?? $category->meta_keywords,
            'meta_description' => $defaultTranslation['meta_description'] ?? $category->meta_description,
            'schema_markup' => $defaultTranslation['schema_markup'] ?? $category->schema_markup,
        ]);
        foreach ($request->translations as $langId => $data) {
            $category->saveTranslation($langId, [
                'name' => $data['name'] ?: null,
                'meta_title' => $data['meta_title'] ?: null,
                'meta_keywords' => $data['meta_keywords'] ?: null,
                'meta_description' => $data['meta_description'] ?: null,
                'schema_markup' => $data['schema_markup'] ?: null,
            ]);
        }

        return CommonHelper::responseSuccess('category_updated_successfully');
    }

    public function deleteBlogCategory(Request $request)
    {
        $category = BlogCategory::find($request->id);

        if (!$category) {
            return CommonHelper::responseError('category_not_found');
        }

        if ($category->blogs()->count() > 0) {
            return CommonHelper::responseError('cannot_delete_category_with_blogs');
        }

        $category->translations()->delete();
        $category->delete();

        return CommonHelper::responseSuccess('category_deleted_successfully');
    }

    public function getBlogs(Request $request)
    {
        try {
            $limit = (int) $request->input('limit', 10);
            $page = (int) $request->input('page', 1);
            $offset = ($page - 1) * $limit;
            $search = $request->input('search');
            $categoryId = $request->input('category_id');

            $slug = $request->input('slug');
            $tagId = $request->input('tag_id');
            $query = Blog::with('translations')
                ->with([
                    'category' => fn($q) => $q->with('translations')
                ])
                ->whereHas('category', fn($q) => $q->where('status', 1));

            if ($search) {
                $query->search($search);
            }

            if ($slug) {
                $query->where('slug', $slug);
            }

            if ($categoryId) {
                $query->where('category_id', $categoryId);
            }

            if ($tagId) {
                $query->whereRaw(
                    'FIND_IN_SET(?, COALESCE(tags, ""))',
                    [$tagId]
                );
            }

            $total = (clone $query)->count();

            $blogs = $query->orderByDesc('id')
                ->offset($offset)
                ->limit($limit)
                ->get();

            $blogs = $this->appendTagsMetadata($blogs);


            return CommonHelper::responseWithData($blogs, $total);
        } catch (\Throwable $e) {
            return CommonHelper::responseError('something_went_wrong');
        }
    }

    public function createBlog(Request $request)
    {
        $defaultLang = $this->languageService->getDefaultLanguage();
        $defaultLangId = $this->languageService->getDefaultLanguage()->id;

        if (
            empty($request->translations[$defaultLang->id]['title'])
        ) {
            return CommonHelper::responseError('default_language_required_first');
        }

        try {
            $imagePath = CommonHelper::uploadFile($request, 'image', 'blogs');

            $tagString = $this->mergeTagIdsByLanguage($request->tag_ids_by_language ?? [])
                ?: (implode(',', $this->prepareTagIds($request->tag_ids, $request->tag_language_id)));

            $blog = Blog::create([
                'slug' => $request->slug,
                'category_id' => $request->category_id,
                'status' => $request->status ?? 1,
                'image' => $imagePath,
                'tags' => $tagString,
                'title' => $request->translations[$defaultLangId]['title'],
                'description' => $request->translations[$defaultLangId]['description'] ?? '',
                'short_description' => $request->translations[$defaultLangId]['short_description'] ?? '',
                'meta_title' => $request->translations[$defaultLangId]['meta_title'] ?? '',
                'meta_keywords' => $request->translations[$defaultLangId]['meta_keywords'] ?? '',
                'meta_description' => $request->translations[$defaultLangId]['meta_description'] ?? '',
                'schema_markup' => $request->translations[$defaultLangId]['schema_markup'] ?? '',
            ]);

            foreach ($request->translations as $langId => $data) {
                $blog->saveTranslation($langId, [
                    'title' => $data['title'] ?? '',
                    'description' => $data['description'] ?? '',
                    'short_description' => $data['short_description'] ?? '',
                    'meta_title' => $data['meta_title'] ?? '',
                    'meta_keywords' => $data['meta_keywords'] ?? '',
                    'meta_description' => $data['meta_description'] ?? '',
                    'schema_markup' => $data['schema_markup'] ?? '',
                ]);
            }

            dispatch(function () use ($blog) {
                CommonHelper::sendBlogNotification($blog);
            })->afterResponse();

            return CommonHelper::responseSuccessWithData(
                'blog_created_successfully',
                $blog->load(['category', 'translations'])
            );
        } catch (\Throwable $e) {
            return CommonHelper::responseError($e->getMessage());
        }
    }

    public function updateBlog(Request $request, $id)
    {
        $defaultLangId = $this->languageService->getDefaultLanguage()->id;
        $blog = Blog::with('translations')->find($id);
        if (!$blog) {
            return CommonHelper::responseError('blog_not_found');
        }

        $defaultLang = $this->languageService->getDefaultLanguage();

        try {
            $blog->image = CommonHelper::uploadFile($request, 'image', 'blogs', $blog->image);

            if ($request->has('tag_ids_by_language') && is_array($request->tag_ids_by_language)) {
                $blog->tags = $this->mergeTagIdsByLanguage($request->tag_ids_by_language);
            } elseif ($request->has('tag_ids')) {
                $blog->tags = implode(',', $this->prepareTagIds($request->tag_ids, $request->tag_language_id));
            }

            $blog->update([
                'slug' => $request->slug
                    ?: Str::slug(
                        $request->translations[$defaultLang->id]['title']
                        ?? $blog->slug
                    ),
                'category_id' => $request->category_id,
                'status' => $request->status,
                'title' => $request->translations[$defaultLangId]['title'],
                'description' => $request->translations[$defaultLangId]['description'] ?? $blog->description,
                'short_description' => $request->translations[$defaultLangId]['short_description'] ?? $blog->short_description,
                'meta_title' => $request->translations[$defaultLangId]['meta_title'] ?? $blog->meta_title,
                'meta_keywords' => $request->translations[$defaultLangId]['meta_keywords'] ?? $blog->meta_keywords,
                'meta_description' => $request->translations[$defaultLangId]['meta_description'] ?? $blog->meta_description,
                'schema_markup' => $request->translations[$defaultLangId]['schema_markup'] ?? $blog->schema_markup,
            ]);

            foreach ($request->translations as $langId => $data) {
                $blog->saveTranslation($langId, [
                    'title' => $data['title'] ?? '',
                    'description' => $data['description'] ?? '',
                    'short_description' => $data['short_description'] ?? '',
                    'meta_title' => $data['meta_title'] ?? '',
                    'meta_keywords' => $data['meta_keywords'] ?? '',
                    'meta_description' => $data['meta_description'] ?? '',
                    'schema_markup' => $data['schema_markup'] ?? '',
                ]);
            }

            return CommonHelper::responseSuccessWithData(
                'blog_updated_successfully',
                $blog->load(['category', 'translations'])
            );
        } catch (\Throwable $e) {
            return CommonHelper::responseError($e->getMessage());
        }
    }

    public function deleteBlog($id)
    {
        $blog = Blog::find($id);
        if (!$blog) {
            return CommonHelper::responseError('blog_not_found');
        }

        CommonHelper::deleteFile($blog->image);

        $blog->delete();

        return CommonHelper::responseSuccess('blog_deleted_successfully');
    }

    public function getBlogCategoriesForDropdown()
    {
        try {
            $query = BlogCategory::with('translations')
                ->where('status', 1)
                ->orderBy('id', 'asc');

            $categories = $query->get()->map(function ($cat) {

                return [
                    'id' => $cat->id,
                    'slug' => $cat->slug,
                    'status' => $cat->status,
                    'name' => $cat->name,
                    'translations' => $cat->translations,
                ];
            });

            return CommonHelper::responseSuccessWithData('success', $categories);
        } catch (\Exception $e) {
            return CommonHelper::responseError($e->getMessage());
        }
    }

    public function getBlogTags(Request $request)
    {
        try {
            $all = $request->boolean('all');
            $languageId = $request->input('language_id') ? (int) $request->input('language_id') : null;

            if ($all) {
                $tags = BlogTag::orderBy('language_id')->orderBy('name')->get(['id', 'name', 'language_id']);
            } else {
                $langId = $languageId ?? $this->languageService->getDefaultLanguage()->id;
                $tags = BlogTag::where('language_id', $langId)
                    ->orderBy('name', 'asc')
                    ->get(['id', 'name', 'language_id']);
            }

            return CommonHelper::responseSuccessWithData('success', $tags);
        } catch (\Exception $e) {
            return CommonHelper::responseError('something_went_wrong');
        }
    }

    public function getPopularBlogTags()
    {
        try {
            $allTagStrings = Blog::select('tags')
                ->whereNotNull('tags')
                ->pluck('tags');

            $tagUsage = [];
            foreach ($allTagStrings as $tagString) {
                $tagIds = $this->parseTagIdsFromString($tagString);
                foreach ($tagIds as $tagId) {
                    if (!isset($tagUsage[$tagId])) {
                        $tagUsage[$tagId] = 0;
                    }
                    $tagUsage[$tagId]++;
                }
            }

            if (empty($tagUsage)) {
                return CommonHelper::responseSuccessWithData('success', []);
            }

            arsort($tagUsage);
            $topTagIds = array_slice(array_keys($tagUsage), 0, 8);

            $langId = app()->has('lang_id') ? app('lang_id') : $this->languageService->getDefaultLanguage()->id;
            $tagRecords = BlogTag::whereIn('id', $topTagIds)
                ->where('language_id', $langId)
                ->get()
                ->keyBy('id');

            $result = [];
            foreach ($topTagIds as $tagId) {
                if (!isset($tagRecords[$tagId])) {
                    continue;
                }
                $result[] = [
                    'id' => (int) $tagId,
                    'name' => $tagRecords[$tagId]->name,
                    'usage_count' => $tagUsage[$tagId]
                ];
            }

            return CommonHelper::responseSuccessWithData('success', $result);
        } catch (\Exception $e) {
            return CommonHelper::responseError('something_went_wrong');
        }
    }

    public function trackBlogView(Request $request)
    {
        try {
            $blog_id = $request->input('blog_id');
            if (empty($blog_id)) {
                return CommonHelper::responseError('blog_id_is_required');
            }
            $blog = Blog::find($blog_id);
            if (!$blog) {
                return CommonHelper::responseError('blog_not_found');
            }

            $ipAddress = CommonHelper::clientIp($request);

            $existingView = BlogView::where('blog_id', $blog_id)
                ->where('ip_address', $ipAddress)
                ->first();

            if (!$existingView) {
                BlogView::create([
                    'blog_id' => $blog_id,
                    'ip_address' => $ipAddress
                ]);

                $blog->increment('views_count');
            }

            $totalViews = $blog->fresh()->views_count;

            return CommonHelper::responseSuccessWithData('view_tracked_successfully', [
                'blog_id' => $blog_id,
                'total_views' => $totalViews
            ]);
        } catch (\Exception $e) {
            return CommonHelper::responseError($e->getMessage());
        }
    }

    public function getMostViewedBlogs(Request $request)
    {
        try {
            $limit = $request->input('limit', 5);

            $blogs = Blog::active()
                ->with('category')->whereHas('category', function ($q) {
                    $q->where('status', 1);
                })
                ->orderBy('views_count', 'desc')
                ->limit($limit)
                ->get();

            $blogs = $this->appendTagsMetadata($blogs);

            return CommonHelper::responseSuccessWithData('success', $blogs);
        } catch (\Exception $e) {
            return CommonHelper::responseError('something_went_wrong');
        }
    }

    private function appendTagsMetadata($blogs)
    {
        $tagIds = $blogs->pluck('tags')
            ->filter()
            ->flatMap(fn($v) => explode(',', $v))
            ->unique()
            ->values()
            ->all();

        if (empty($tagIds)) {
            foreach ($blogs as $blog) {
                $blog->tag_names = [];
            }
            return $blogs;
        }

        $langId = app()->has('lang_id') ? app('lang_id') : $this->languageService->getDefaultLanguage()->id;
        $tags = BlogTag::whereIn('id', $tagIds)->where('language_id', $langId)->get();
        $tagMap = $tags->pluck('name', 'id')->toArray();

        foreach ($blogs as $blog) {
            $blog->tag_names = collect(explode(',', $blog->tags ?? ''))
                ->map(fn($id) => $tagMap[$id] ?? null)
                ->filter()
                ->values()
                ->all();
        }

        return $blogs;
    }

    private function parseTagIdsFromString($tagValue)
    {
        if (empty($tagValue)) {
            return [];
        }

        if (is_array($tagValue)) {
            $tagItems = $tagValue;
        } else {
            $tagItems = explode(',', $tagValue);
        }

        return array_values(array_filter(array_map(function ($item) {
            if ($item === null) {
                return '';
            }
            return trim((string) $item);
        }, $tagItems), function ($item) {
            return $item !== '';
        }));
    }

    private function prepareTagIds($tagInput, $languageId = null)
    {
        if (empty($tagInput)) {
            return [];
        }

        $tagItems = $this->parseTagIdsFromString($tagInput);
        $langId = $languageId ? (int) $languageId : $this->languageService->getDefaultLanguage()->id;
        $tagIds = [];
        foreach ($tagItems as $item) {
            if (is_numeric($item)) {
                $tagIds[] = (int) $item;
            } else {
                $tagName = trim((string) $item);
                $blogTag = BlogTag::firstOrCreate(
                    ['name' => $tagName, 'language_id' => $langId],
                    ['name' => $tagName, 'language_id' => $langId]
                );
                $tagIds[] = $blogTag->id;
            }
        }

        return array_values(array_unique($tagIds));
    }

    private function mergeTagIdsByLanguage($tagIdsByLanguage): string
    {
        if (empty($tagIdsByLanguage)) {
            return '';
        }
        if (is_string($tagIdsByLanguage)) {
            $tagIdsByLanguage = json_decode($tagIdsByLanguage, true) ?: [];
        }
        $allIds = [];
        foreach ($tagIdsByLanguage as $langId => $tagInput) {
            if ($tagInput === null || $tagInput === '') {
                continue;
            }
            $ids = $this->prepareTagIds($tagInput, $langId);
            $allIds = array_merge($allIds, $ids);
        }

        return implode(',', array_values(array_unique($allIds)));
    }

    /*------------------Google Gemini AI Content Generation---------------*/
    public function googleGeminiAI(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'source' => 'required|string|in:app,web',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // 2 Track API usage
        ApiCallTracking::incrementCallCount('google_gemini', $request->source);

        try {
            // 3 Get Gemini API key
            $apiKey = Setting::get_value('text_gen_key');

            if (empty($apiKey)) {
                return CommonHelper::responseError('Google Gemini API key not configured');
            }

            // 4 Prompt for Gemini AI
            $finalPrompt = "
            You are an experienced professional SEO blog writer.
            
            Blog Title:
            \"{$request->title}\"
            
            Instructions:
            1. Generate a compelling short_description strictly under 120 characters (including spaces).
            2. Write a high-quality, original blog description relevant to the given title.
            3. description MUST be valid, well-structured HTML only (no markdown).
            4. Use proper HTML tags such as <h2>, <h3>, <p>, <ul>, <li>, <strong> where appropriate.
            5. The content must be informative, engaging, and optimized for SEO without keyword stuffing.
            6. Include clear headings and subheadings to improve readability and search engine indexing.
            7. Total word count of description must be between 250 and 1000 words.
            8. Do NOT include inline styles, scripts, comments, emojis, or external links.
            9. Do NOT include introduction or conclusion labels explicitly (e.g., avoid text like 'Introduction' or 'Conclusion').
            10. Avoid generic filler phrases and AI disclaimers.
            11. Ensure factual accuracy and natural language flow.
            12. Return ONLY a valid JSON object — no extra text before or after.
            
            Required JSON Format:
            {
              \"short_description\": \"\",
              \"description\": \"<h2>...</h2><p>...</p>\"
            }
            ";

            // 5 Gemini API endpoint
            $url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=' . $apiKey;

            // 6 API request body
            $payload = [
                'contents' => [
                    [
                        'parts' => [
                            ['text' => $finalPrompt]
                        ]
                    ]
                ],
                'generationConfig' => [
                    'response_mime_type' => 'application/json',
                ]
            ];

            // 7 Call Gemini API
            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => json_encode($payload),
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_SSL_VERIFYPEER => false,
                CURLOPT_TIMEOUT => 60,
                CURLOPT_HTTPHEADER => [
                    'Content-Type: application/json',
                    'Accept: application/json'
                ],
            ]);

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError = curl_error($ch);
            unset($ch);

            if ($curlError) {
                return CommonHelper::responseError('Network error: ' . $curlError);
            }

            if ($httpCode !== 200 || empty($response)) {
                Log::error('Gemini Blog AI Error: ' . $response);
                return CommonHelper::responseError('Failed to generate content from Gemini');
            }

            // 8 Read Gemini response
            $data = json_decode($response, true);
            $text = $data['candidates'][0]['content']['parts'][0]['text'] ?? '';

            if (empty($text)) {
                return CommonHelper::responseError('Empty AI response');
            }

            // 9 Convert JSON string to array
            $blogData = json_decode($text, true);

            if (!$blogData) {
                return CommonHelper::responseError('Invalid AI JSON format');
            }

            // 10 Force 120 character limit (final safety)
            if (!empty($blogData['short_description']) && mb_strlen($blogData['short_description']) > 120) {
                $blogData['short_description'] = mb_substr($blogData['short_description'], 0, 117) . '...';
            }

            // Success response
            return CommonHelper::responseWithData($blogData);
        } catch (\Exception $e) {
            Log::error('Gemini Blog AI Error: ' . $e->getMessage());
            return CommonHelper::responseError('AI generation failed');
        }
    }
}
