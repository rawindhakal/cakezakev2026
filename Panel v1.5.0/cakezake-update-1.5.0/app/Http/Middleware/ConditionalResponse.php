<?php

namespace App\Http\Middleware;

use App\Services\LanguageFileService;
use App\Services\SpinWheelService;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Symfony\Component\HttpFoundation\Response;

/**
 * Answers "has this changed?" without sending the body again.
 *
 * The app keeps the `ETag` from a response and sends it back as `If-None-Match`. When it
 * still matches, this replies `304 Not Modified` with no body at all — the app uses what
 * it already has. Worth it on the GETs that are read on every launch, are large, and
 * change about once a month: the catalogue's shape, the settings bundle, the translation
 * files, the reference lists.
 *
 * Three things decide whether this is a saving or a liability.
 *
 * **The tag has to cover everything the body depends on.** These responses vary by more
 * than the path: the language of their translations, the country and zone that scope
 * them, the sales channel, and — where a route is per-customer — who is asking. A tag
 * that forgets one of those hands a Hindi shopper a 304 against the English copy, and
 * behind a shared proxy it hands one customer another's body. So the scope is hashed
 * into the tag rather than assumed away, and the response is marked `private` so no
 * shared cache keeps it.
 *
 * **A cheap fingerprint is what makes it worth doing.** Hashing the finished body saves
 * the transfer but none of the work that built it. A route that can say "nothing behind
 * this has changed since X" is answered before the real query runs — which is why the
 * fingerprint comes from SOURCES below, not from the body.
 *
 * **Nothing time-dependent may be tagged.** A body that changes on the clock rather than
 * on a write — a campaign that opens at ten, a countdown — has no fingerprint to find,
 * and would be revalidated as current after it had already changed. Those routes are
 * left out on purpose, as are per-customer and fast-moving ones.
 *
 * The middleware is registered on the whole customer group; SOURCES is what decides. A
 * path that is not listed is passed straight through, so adding an endpoint means adding
 * one line here and nothing in the routes file.
 */
class ConditionalResponse
{
    /**
     * What each taggable route is built from, registered rather than guessed.
     *
     * A plain string is a table: it is stamped with its row count and newest change, so
     * an edit, an insert and a delete all move the tag. An array is a callable, for the
     * few sources that are not a table — the translation files on disk, for one.
     *
     * Every table listed here is bounded (reference data, settings, the catalogue's
     * shape). Nothing that grows with orders or customers belongs in this list: the
     * stamp counts rows, and counting an orders table to save one response is a poor
     * trade.
     *
     * Missing on purpose, with the reason, so the next person does not read the gap as
     * an oversight:
     *   customer/spin_wheel          per-customer spins, and a campaign that opens on
     *                                the clock — no write to fingerprint
     *   customer/blogs/most_viewed   a view counter moves on nearly every read
     *   customer/products/get_seo    one product, so it wants that row's own stamp
     *   customer/products/ratings_list   same, and ratings churn
     *   customer/categories          only categories that still have stocked products
     *                                in the caller's zone — moves with products, stock
     *                                and branches, not with the category rows
     *   customer/home_layout,        the layout row is the least of it: prices, stock,
     *   customer/page_builder        favourites and whether the branch is open right now
     *                                all live in the body
     *   cart, orders, favorites, notifications, chat, user_details, transactions,
     *   promo_code, recently_visited, live_tracking, notification_preferences
     *                                per-customer and fast-moving
     *
     * @var array<string, array<int, string|array{0:string,1:string}>>
     */
    private const SOURCES = [
        // Catalogue shape: large, read on every launch, edited rarely.
        'customer/brands'      => ['brands', 'brand_translations'],

        /* One product, so it gets that product's own stamp rather than a count over the
           whole catalogue — see productDetailStamp. The list endpoints next to it are
           deliberately absent: their only honest fingerprint is the whole `products`
           table, which costs a full count on every request and is invalidated by any one
           product changing, so a single order would expire every shopper's copy. */
        'customer/product_by_id' => [[self::class, 'productDetailStamp']],

        /* The settings bundle: ~110 keys, translations resolved per language, read on
           every launch. `languages` is in there because the default language decides
           which translation a key falls back to, and the campaign callback because one
           flag in the body is computed rather than stored. */
        'customer/settings' => ['settings', 'social_media', 'languages', [self::class, 'campaignStamp']],
        'customer/settings/payment_methods' => ['countries', 'plugins'],
        'customer/settings/get_seo_settings' => ['web_seo_pages', 'settings'],
        'customer/categories/get_seo' => ['categories', 'settings'],

        /* Translation bundles — the biggest payloads the API serves, and they change
           only when an admin saves a language. */
        'customer/system_languages' => ['languages', 'supported_languages', [self::class, 'langFileStamp']],

        // Geography and reference lists.
        'customer/countries'      => ['countries', 'country_translations'],
        'customer/country_setting' => ['countries', 'country_translations', 'zones'],
        'customer/regions'        => ['regions'],
        'customer/zones'          => ['zones', 'countries'],
        'customer/zone'           => ['zones'],
        'customer/order_status_lists' => ['order_status_lists', 'languages', [self::class, 'translationStamp']],
        'customer/faqs'           => ['faqs', 'faq_translations'],
        'customer/social_media'   => ['social_media'],

        // Blog: `blogs` is in the category list because each row carries a post count.
        'customer/blog_categories'   => ['blog_categories', 'blog_category_translations', 'blogs'],
        'customer/blogs'             => ['blogs', 'blog_translations', 'blog_categories'],
        'customer/blog_popular_tags' => ['blog_tag', 'blogs'],

        /* ---------------------------------------------------------------- panel
         *
         * The panel refetches its reference data constantly — every form that has a
         * category picker, a zone picker or a language switcher asks again on open — and
         * that data is edited a few times a week. These are the same bounded tables the
         * customer side already stamps.
         *
         * A panel response is scoped to the admin who asked, because `branch.scope`
         * narrows lists by the user's branch; that is covered, since the tag carries the
         * audience. The lists are paginated and searched through the query string, which
         * the tag also carries.
         *
         * Left out here for the same reasons as on the customer side: anything built on
         * orders, customers, carts, chats, transactions, media, activity logs, stock
         * alerts, notifications, reports or the dashboard. `api/order_statuses` looks
         * like reference data and is not — it counts orders per status, so its body
         * changes with every order placed. */
        'api/categories'        => ['categories', 'category_translations'],
        'api/categories/active' => ['categories', 'category_translations'],
        'api/categories/main'   => ['categories', 'category_translations'],

        'api/attributes'          => ['attributes', 'attribute_values', 'attribute_translations'],
        'api/attributes/dropdown' => ['attributes', 'attribute_values'],

        'api/countries'         => ['countries', 'country_translations'],
        'api/countries/active'  => ['countries', 'country_translations'],
        'api/countries/regions' => ['regions'],
        'api/zones'             => ['zones'],

        'api/branches'             => ['branches', 'zones', 'regions'],
        'api/branches/for_channel' => ['branches', 'zones'],

        // Permission catalogues: edited when a release adds a permission, not by admins.
        'api/branches/permission_catalog' => ['permission_categories', 'permissions', 'roles'],
        'api/role/permissions'          => ['permission_categories', 'permissions'],

        'api/languages'                   => ['languages', 'supported_languages'],
        'api/active_languages'            => ['languages', 'supported_languages'],
        'api/languages/supported_languages' => ['supported_languages', 'languages'],
        'api/system_languages'            => ['languages', 'supported_languages', [self::class, 'langFileStamp']],

        'api/faqs'                     => ['faqs', 'faq_translations'],
        'api/social_media'             => ['social_media'],
        'api/blog_categories'          => ['blog_categories', 'blog_category_translations', 'blogs'],
        'api/blog_categories/dropdown' => ['blog_categories'],
        'api/blog_tags'                => ['blog_tag'],
        'api/home_layout_templates'    => ['home_layout_templates'],

        // Template libraries: long lists, and only a release or an admin edit moves them.
        'api/email_templates/list'   => ['email_templates'],
        'api/notification_templates' => ['notification_templates'],
        'api/sms_templates'          => ['sms_templates'],

        /* Read before anyone has logged in, by the panel's own boot — so these are
           guest-scoped, which is right: the data behind them is not per-admin. */
        'api/role'            => ['roles', 'permissions'],
        'api/delivery_cities' => ['zones', 'countries'],
        'api/delivery_areas'  => ['zones', 'countries'],

        /* ------------------------------------------------------- delivery boy
         *
         * A rider refreshes these screens far more often than they finish a delivery,
         * and between two deliveries none of it moves — which is when a tag earns its
         * keep. All of it is per-rider, so the fingerprints are per-rider too, asked
         * through indexed `delivery_boy_id` columns (the release migration adds the
         * indexes that were missing; without them each of these reads was a full scan).
         *
         * Three fingerprints rather than one, split along what actually moves together:
         * riderStamp for the orders, cash and money screens, riderChatStamp for chat,
         * and riderProfileStamp for the account screen. Chat is separate because folding
         * it in meant every incoming message expired the 99 KB order list with it.
         *
         * Left out: `chat/messages`, because fetching its first page marks the other
         * side's messages read — a GET that writes, and a 304 returns before the
         * controller runs, which would quietly stop the unread badge from clearing.
         * `delete_account` is a GET that deletes. `login` and `register` are auth. */
        'delivery_boy/dashboard'            => [[self::class, 'riderStamp'], 'order_status_lists'],
        'delivery_boy/orders'               => [[self::class, 'riderStamp'], 'order_status_lists'],
        'delivery_boy/ecom_orders'          => [[self::class, 'riderStamp'], 'order_status_lists'],
        'delivery_boy/order_by_id'          => [[self::class, 'riderStamp'], 'order_status_lists'],
        'delivery_boy/cash_collection'      => [[self::class, 'riderStamp']],
        'delivery_boy/settlement_history'   => [[self::class, 'riderStamp']],
        'delivery_boy/salary_transactions'  => [[self::class, 'riderStamp']],
        'delivery_boy/withdrawal_requests'  => [[self::class, 'riderStamp']],
        'delivery_boy/return_requests'      => [[self::class, 'riderStamp']],
        'delivery_boy/chat/conversations'   => [[self::class, 'riderChatStamp']],
        'delivery_boy/chat/unread_count'    => [[self::class, 'riderChatStamp']],

        /* The status catalogue, not a count of anything — it was left out of this
           list at first on the assumption that it tallied orders per status, which it
           does not. It reads `order_status_lists`, hard-coded return statuses, and the
           translated name of each, so the translation files are a dependency too. */
        'delivery_boy/order_statuses' => ['order_status_lists', 'languages', [self::class, 'orderStatusStamp']],

        /* The rider's own profile, and the notification switches they and the admin
           share. Both are small and change rarely, but the app reads them on the
           account screen every time it is opened. */
        'delivery_boy/edit' => [[self::class, 'riderProfileStamp']],
        'delivery_boy/get_delivery_boy_status' => [[self::class, 'riderStatusStamp']],
        'delivery_boy/notification_preferences' => ['notification_admin_settings', [self::class, 'notificationPrefsStamp']],

        'delivery_boy/settings'         => ['settings', 'languages'],
        'delivery_boy/country_setting'  => ['countries', 'country_translations'],
        'delivery_boy/countries'        => ['countries', 'country_translations'],
        'delivery_boy/zones'            => ['zones'],
        'delivery_boy/system_languages' => ['languages', 'supported_languages', [self::class, 'langFileStamp']],

        'api/order_statuses' => ['order_status_lists', 'languages', [self::class, 'orderStatusStamp']],
        'api/seo_settings'   => ['web_seo_pages', 'settings'],
        'api/web_settings'   => ['settings'],
        'api/admin_settings' => ['settings'],
    ];

    public function handle(Request $request, Closure $next): Response
    {
        // Only a GET can be answered this way; a client will not revalidate anything else.
        if (!$request->isMethod('GET')) {
            return $next($request);
        }

        /* Who is asking, decided before any work: null means "cannot tell", and a
           request whose audience is unknown is never tagged. */
        $audience = $this->audience($request);
        if ($audience === null) {
            return $next($request);
        }

        $fingerprint = $this->fingerprintFor($request);
        if ($fingerprint === null) {
            return $next($request);
        }

        $etag = $this->tag($request, $fingerprint, $audience);

        if ($this->matches($request, $etag)) {
            return $this->tagged(response('', 304), $etag);
        }

        $response = $next($request);

        /* Only a successful, complete body is worth tagging.
         *
         * HTTP 200 is not enough to go on here: this API answers a refused request with
         * 200 and `status: 0` in the body, so tagging on the status line alone would have
         * the app revalidating against a validation error and treating it as current
         * content. The payload has to say it succeeded. */
        if ($this->isSuccessful($response)) {
            $this->tagged($response, $etag);
        }

        return $response;
    }

    /**
     * The headers that make a response revalidatable.
     *
     * `no-cache` is the point, and it does not mean "do not store": it means store the
     * body but never serve it without asking us first. That is the whole bargain here —
     * the client keeps the bytes, we keep the right to say they are still good.
     *
     * `must-revalidate` alone was not enough. It governs what a cache may do once a
     * response is **stale**, and nothing here states a freshness lifetime — no `max-age`,
     * no `Last-Modified` — so a browser was free to apply heuristic freshness and serve
     * its copy without a request at all. That is a panel showing categories an admin
     * has already changed. `max-age=0` is sent beside `no-cache` for the older caches
     * that only understand the former.
     *
     * `private` keeps it out of shared caches, since these responses are scoped to a
     * language, a zone and sometimes a single customer.
     *
     * The tag is also named in `Access-Control-Expose-Headers`, without which a browser
     * refuses to let JavaScript read it on a cross-origin call — the storefront runs on
     * a different host from this API, so a web client wanting to handle revalidation
     * itself would see `null` and conclude the header was never sent.
     */
    private function tagged(Response $response, string $etag): Response
    {
        $response->setEtag($etag, true);
        $response->headers->set('Cache-Control', 'private, no-cache, max-age=0, must-revalidate');

        // Added to whatever CORS already exposes rather than replacing it.
        $exposed = array_filter(array_map('trim', explode(
            ',',
            (string) $response->headers->get('Access-Control-Expose-Headers', '')
        )));
        if (!in_array('ETag', $exposed, true)) {
            $exposed[] = 'ETag';
        }
        $response->headers->set('Access-Control-Expose-Headers', implode(', ', $exposed));

        return $response;
    }

    /**
     * The tag: what the body depends on, then how current it is.
     *
     * Weak (`W/`) because these responses are semantically equivalent rather than
     * byte-identical — a re-encode or a reordered key does not mean the shopper is
     * looking at different categories.
     */
    private function tag(Request $request, string $fingerprint, string $audience): string
    {
        $scope = [
            $request->path(),
            // Query string, order-insensitive, so ?a=1&b=2 and ?b=2&a=1 share a tag.
            $this->normalisedQuery($request),
            (string) $request->header('Content-Language', ''),
            (string) $request->header('channel', ''),
            (string) $request->input('country_id', ''),
            (string) $request->input('zone_id', ''),
            // A per-customer body must never be revalidated against somebody else's.
            $audience,
        ];

        return hash('xxh128', implode('|', $scope) . '|' . $fingerprint);
    }

    private function audience(Request $request): ?string
    {
        $user = $request->user('api-customers') ?: $request->user();
        if ($user) {
            return 'user:' . $user->getAuthIdentifier();
        }

        if ($request->bearerToken() || $request->hasHeader('Authorization')) {
            return null;
        }

        return 'guest';
    }

    private function normalisedQuery(Request $request): string
    {
        $query = $request->query();
        ksort($query);

        return (string) json_encode($query);
    }

    /**
     * Did this response actually succeed?
     *
     * The status line, and then the body's own verdict — `status: 0` is this API's way
     * of refusing a request while still answering 200.
     */
    private function isSuccessful(Response $response): bool
    {
        if ($response->getStatusCode() !== 200) {
            return false;
        }

        $content = (string) $response->getContent();

        if (preg_match('/^\s*\{\s*(?:"error"\s*:\s*(?:true|false)\s*,\s*)?"status"\s*:\s*(-?\d+)/', $content, $m)) {
            return (int) $m[1] === 1;
        }

        $body = json_decode($content, true);

        // Not JSON, or no verdict in it: take the status line at its word.
        if (!is_array($body) || !array_key_exists('status', $body)) {
            return true;
        }

        return (int) $body['status'] === 1;
    }

    /** Several tags may be offered; any match means the app's copy is current. */
    private function matches(Request $request, string $etag): bool
    {
        $offered = (string) $request->headers->get('If-None-Match', '');
        if ($offered === '') {
            return false;
        }

        foreach (explode(',', $offered) as $candidate) {
            $candidate = trim($candidate, " \t\"");
            $candidate = preg_replace('/^W\//', '', $candidate);
            $candidate = trim((string) $candidate, '"');

            $candidate = (string) preg_replace('/-(gzip|br|deflate|zstd)$/', '', $candidate);

            if ($candidate === '*' || hash_equals($etag, $candidate)) {
                return true;
            }
        }

        return false;
    }

    /**
     * The fingerprint for this route, or null when the route is not one of ours.
     *
     * A failure here must never cost a response: if a stamp throws, the request simply
     * goes through untagged.
     */
    private function fingerprintFor(Request $request): ?string
    {
        $sources = self::SOURCES[trim($request->path(), '/')] ?? null;
        if (!$sources) {
            return null;
        }

        try {
            $parts = [];
            foreach ($sources as $source) {
                $parts[] = is_array($source)
                    ? (string) call_user_func($source, $request)
                    : self::stamp($source);
            }

            return implode('/', $parts);
        } catch (\Throwable $e) {
            Log::warning('[ETag] could not fingerprint ' . $request->path() . ': ' . $e->getMessage());

            return null;
        }
    }

    /* ------------------------------------------------------------------ stamps */

    /**
     * One cheap row per table: how current it is, and how many rows there are.
     *
     * The count is what catches a deletion, which moves no `updated_at` at all.
     */
    private static function stamp(string $table): string
    {
        $columns = self::columns($table);
        if ($columns === []) {
            return $table . ':-';
        }

        if (in_array('updated_at', $columns, true)) {
            $row = DB::table($table)
                ->selectRaw('COUNT(*) as rows_count, MAX(updated_at) as last_change')
                ->first();

            return $table . ':' . ($row->rows_count ?? 0) . ':' . ($row->last_change ?? '0');
        }

        $concat = 'CONCAT_WS(0x1f, ' . implode(', ', array_map(
            static fn ($c) => "COALESCE(`" . str_replace('`', '', $c) . "`, 0x00)",
            $columns
        )) . ')';

        $row = DB::table($table)
            ->selectRaw("COUNT(*) as rows_count, SUM(CRC32({$concat})) as digest")
            ->first();

        return $table . ':' . ($row->rows_count ?? 0) . ':' . ($row->digest ?? '0');
    }

    private static function stampMany(array $tables): string
    {
        $selects = [];
        foreach ($tables as $table) {
            if (!in_array('updated_at', self::columns($table), true)) {
                continue;
            }
            $safe = str_replace('`', '', $table);
            $selects[] = "SELECT '{$safe}' AS t, COUNT(*) AS c, COALESCE(MAX(updated_at), 0) AS m FROM `{$safe}`";
        }

        if ($selects === []) {
            return '-';
        }

        $rows = DB::select(implode(' UNION ALL ', $selects));
        $parts = [];
        foreach ($rows as $row) {
            $parts[] = $row->t . ':' . $row->c . ':' . $row->m;
        }
        sort($parts);

        return implode('/', $parts);
    }

    public static function productDetailStamp(Request $request): string
    {
        $id = self::productId($request);
        if ($id === null) {
            // No such product: the response will be a refusal, which is never tagged.
            return 'product:none';
        }

        $own = DB::selectOne(
            'SELECT'
            . ' (SELECT COALESCE(MAX(updated_at), 0) FROM products WHERE id = ?) AS p,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(updated_at), 0)) FROM product_translations WHERE product_id = ?) AS pt,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(updated_at), 0)) FROM product_variants WHERE product_id = ?) AS pv,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(t.updated_at), 0)) FROM product_variant_translations t'
            . '    JOIN product_variants v ON v.id = t.product_variant_id WHERE v.product_id = ?) AS pvt,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(s.updated_at), 0)) FROM product_variant_branch_stocks s'
            . '    JOIN product_variants v2 ON v2.id = s.product_variant_id WHERE v2.product_id = ?) AS pvs,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(c.updated_at), 0)) FROM product_variant_custom_values c'
            . '    JOIN product_variants v3 ON v3.id = c.product_variant_id WHERE v3.product_id = ?) AS pvc,'
            /* product_images has no timestamps, so its rows are digested — an image
               swapped in place changes the path even when the row count does not. */
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(SUM(CRC32(CONCAT_WS(0x1f, id, COALESCE(image, 0x00)))), 0))'
            . '    FROM product_images WHERE product_id = ?) AS pi,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(updated_at), 0)) FROM product_ratings WHERE product_id = ?) AS pr',
            array_fill(0, 8, $id)
        );

        $shared = self::stampMany([
            'attributes', 'attribute_values', 'attribute_translations',
            'category_custom_fields', 'category_custom_field_translations',
            'category_custom_sections', 'category_custom_section_translations',
            'brands', 'brand_translations', 'categories', 'category_translations',
            'branches', 'zones', 'plugins',
            'product_addon_groups', 'product_addon_group_translations', 'product_addon_options',
            'product_addon_option_translations', 'product_addon_option_branches',
        ]);

        return 'product:' . $id
            . '|' . implode(',', (array) $own)
            . '|' . $shared
            . '|' . now()->toDateString();
    }

    public static function riderStamp(Request $request): string
    {
        $id = (int) (optional(optional($request->user())->deliveryBoy)->id ?? 0);
        if ($id === 0) {
            return 'rider:none';
        }

        $own = DB::selectOne(
            'SELECT'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(updated_at), 0)) FROM orders WHERE delivery_boy_id = ?) AS o,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(updated_at), 0)) FROM order_items WHERE delivery_boy_id = ?) AS oi,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(updated_at), 0)) FROM delivery_boy_cash_collections WHERE delivery_boy_id = ?) AS cc,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(updated_at), 0)) FROM delivery_boy_settlements WHERE delivery_boy_id = ?) AS st,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(updated_at), 0)) FROM delivery_boy_salaries WHERE delivery_boy_id = ?) AS sal,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(updated_at), 0)) FROM withdrawal_requests WHERE type = ? AND type_id = ?) AS wr,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(MAX(updated_at), 0)) FROM return_requests WHERE delivery_boy_id = ?) AS rr,'
            /* `cash_received` lives on the rider's own row, and the cash screen reads it. */
            . ' (SELECT COALESCE(MAX(updated_at), 0) FROM delivery_boys WHERE id = ?) AS db',
            [$id, $id, $id, $id, $id, self::withdrawalType(), $id, $id, $id]
        );

        return 'rider:' . $id
            . '|' . implode(',', (array) $own)
            . '|' . now()->toDateString();
    }

    /**
     * A rider's status and remark, and nothing else.
     *
     * The rider panel polls this every thirty seconds to notice a block, so the tag
     * wants to survive as long as possible. It is built from the two values the response
     * returns rather than from the row's timestamp: `delivery_boys` also carries
     * `cash_received`, which moves on every delivery, and stamping the row would expire
     * this tag each time a rider took money — for a body that had not changed.
     *
     * Safe to narrow this far only because the endpoint now always answers about the
     * caller's own rider; it used to take an `id` on trust.
     */
    public static function riderStatusStamp(Request $request): string
    {
        $row = DB::table('delivery_boys')
            ->where('admin_id', (int) (optional($request->user())->id ?? 0))
            ->selectRaw('id, COALESCE(status, -1) AS status, COALESCE(remark, "") AS remark')
            ->first();

        if (!$row) {
            return 'rider:none';
        }

        return 'status:' . $row->id . ':' . $row->status . ':' . crc32((string) $row->remark);
    }

    /**
     * A rider's own profile row.
     *
     * Their `delivery_boys` row, its translations, and the `admins` row the email is
     * read from — a password or email change on the account side has to show up
     * here. The translations table has no timestamps, so those rows are digested.
     */
    public static function riderProfileStamp(Request $request): string
    {
        $admin = $request->user();
        $adminId = (int) (optional($admin)->id ?? 0);
        $riderId = (int) (optional(optional($admin)->deliveryBoy)->id ?? 0);

        if ($riderId === 0) {
            return 'rider:none';
        }

        $row = DB::selectOne(
            'SELECT'
            . ' (SELECT COALESCE(MAX(updated_at), 0) FROM delivery_boys WHERE id = ?) AS d,'
            . ' (SELECT CONCAT(COUNT(*), ":", COALESCE(SUM(CRC32(CONCAT_WS(0x1f, id, COALESCE(name, 0x00),'
            . '      COALESCE(address, 0x00), COALESCE(other_payment_information, 0x00)))), 0))'
            . '    FROM delivery_boy_translations WHERE delivery_boy_id = ?) AS t,'
            . ' (SELECT COALESCE(MAX(updated_at), 0) FROM admins WHERE id = ?) AS a',
            [$riderId, $riderId, $adminId]
        );

        return 'profile:' . $riderId . ':' . implode(',', (array) $row);
    }

    /**
     * One rider's notification switches.
     *
     * Three things decide this body: what the admin has allowed per event, which lives
     * in `notification_admin_settings` and is stamped beside this; what this rider has
     * chosen, in their own `notification_preferences` rows; and the event labels, which
     * are translated at render time and so follow the language files. The event list
     * itself is defined in code, so only a deploy moves it.
     */
    public static function notificationPrefsStamp(Request $request): string
    {
        $userId = (int) (optional($request->user())->id ?? 0);
        if ($userId === 0) {
            return 'prefs:none';
        }

        $type = \App\Services\NotificationService::userTypeForAudience('delivery_boy');

        $row = DB::selectOne(
            'SELECT COUNT(*) AS c, COALESCE(MAX(updated_at), 0) AS m'
            . ' FROM notification_preferences WHERE user_type = ? AND user_id = ?',
            [$type, $userId]
        );

        return 'prefs:' . $userId . ':' . $row->c . ':' . $row->m . '|' . self::translationStamp($request);
    }

    /**
     * The translation files, for a body whose text comes from `__()`.
     *
     * Status names, and anything else translated at render time, are read from the JSON
     * bundles rather than from a table, and the Languages screen writes those files
     * directly. A tag built from tables alone would keep saying "unchanged" after an
     * admin had renamed every status. The whole `lang` tree is covered rather than one
     * bundle, because which one answers a given `__()` depends on the locale in force.
     */
    public static function translationStamp(Request $request): string
    {
        $newest = 0;
        $count = 0;

        foreach ((glob(lang_path('*.json')) ?: []) + (glob(lang_path('*/*.json')) ?: []) as $file) {
            $count++;
            $newest = max($newest, (int) @filemtime($file));
        }

        return 'lang:' . $count . ':' . $newest;
    }

    /**
     * The status catalogue, plus the one order it can be asked about.
     *
     * Passing `order_id` makes the answer follow that order's channel and delivery type,
     * so the order's own row joins the fingerprint. Everything else is the translation
     * files and the status table, which are stamped beside this.
     */
    public static function orderStatusStamp(Request $request): string
    {
        $stamp = self::translationStamp($request);

        $orderId = (int) $request->input('order_id', 0);
        if ($orderId > 0) {
            $row = DB::table('orders')->where('id', $orderId)
                ->selectRaw('CONCAT(COALESCE(channel, ""), ":", COALESCE(delivery_type, ""), ":", COALESCE(updated_at, 0)) AS s')
                ->first();
            $stamp .= '|order:' . $orderId . ':' . ($row->s ?? '-');
        }

        return $stamp;
    }

    /**
     * A rider's conversations, for the two chat screens.
     *
     * Separate from riderStamp because this is what a rider polls for: an incoming
     * message has to expire the tag within seconds, while nothing it touches has any
     * bearing on their orders or their cash. `last_message_at` is read as well as
     * `updated_at` because a new message moves the former.
     */
    public static function riderChatStamp(Request $request): string
    {
        $id = (int) (optional(optional($request->user())->deliveryBoy)->id ?? 0);
        if ($id === 0) {
            return 'rider:none';
        }

        $row = DB::selectOne(
            'SELECT COUNT(*) AS c, COALESCE(MAX(updated_at), 0) AS u, COALESCE(MAX(last_message_at), 0) AS l'
            . ' FROM conversations WHERE delivery_boy_id = ?',
            [$id]
        );

        return 'chat:' . $id . ':' . $row->c . ':' . $row->u . ':' . $row->l;
    }

    /** The owner type a rider's withdrawal rows carry, read from the model's own constant. */
    private static function withdrawalType(): string
    {
        return (string) (\App\Models\WithdrawalRequest::$typeDeliveryBoy ?? 'delivery_boy');
    }

    /** The product this request is about, by id, slug or barcode. */
    private static function productId(Request $request): ?int
    {
        if ($request->filled('id')) {
            return (int) $request->input('id') ?: null;
        }

        foreach (['slug' => 'slug', 'barcode' => 'barcode'] as $param => $column) {
            if ($request->filled($param)) {
                $id = DB::table('products')->where($column, $request->input($param))->value('id');

                return $id ? (int) $id : null;
            }
        }

        return null;
    }

    private static function columns(string $table): array
    {
        static $cache = [];

        if (!array_key_exists($table, $cache)) {
            try {
                // Kept across requests: under PHP-FPM a static lasts one request, and this
                // lookup was two schema queries per table on every tagged call.
                $cache[$table] = Cache::remember('etag_columns:' . $table, now()->addDay(),
                    fn () => Schema::hasTable($table) ? Schema::getColumnListing($table) : []);
            } catch (\Throwable) {
                $cache[$table] = [];
            }
        }

        return $cache[$table];
    }

    public static function campaignStamp(Request $request): string
    {
        $campaign = app(SpinWheelService::class)->activeCampaign();

        return 'campaign:' . ($campaign->id ?? 0);
    }

    public static function langFileStamp(Request $request): string
    {
        $type = (int) $request->input('system_type', 0);
        $dir = LanguageFileService::TYPE_DIRS[$type] ?? null;
        if ($dir === null) {
            return 'lang:-';
        }

        $newest = 0;
        $count = 0;
        foreach (glob(lang_path(($dir !== '' ? $dir . '/' : '') . '*.json')) ?: [] as $file) {
            $count++;
            $newest = max($newest, (int) @filemtime($file));
        }

        return 'lang:' . $type . ':' . $count . ':' . $newest;
    }
}
