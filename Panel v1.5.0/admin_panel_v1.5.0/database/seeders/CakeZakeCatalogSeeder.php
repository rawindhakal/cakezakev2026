<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Loads the cakezake.com catalogue (cakezake_products.json, prepared from products.csv)
 * plus the gifting lookups: occasions, recipient relationships and delivery types.
 * Idempotent: products are matched on slug.
 */
class CakeZakeCatalogSeeder extends Seeder
{
    public function run(): void
    {
        $now = now();

        // Nepal, NPR
        DB::table('countries')->where('id', 1)->update([
            'name' => 'Nepal', 'dial_code' => '+977', 'code' => 'NP', 'currency' => 'Rs', 'currency_code' => 'NPR',
            'timezone' => 'Asia/Kathmandu', 'min_mobile_length' => 10, 'max_mobile_length' => 10,
        ]);

        // Nepal's seven provinces replace the seeded Indian states.
        if (DB::table('regions')->where('code', 'like', 'IN-%')->exists()) {
            DB::table('regions')->where('country_id', 1)->delete();
            foreach (['Koshi', 'Madhesh', 'Bagmati', 'Gandaki', 'Lumbini', 'Karnali', 'Sudurpashchim'] as $i => $prov) {
                DB::table('regions')->insert(['country_id' => 1, 'name' => $prov . ' Province', 'code' => 'NP-' . ($i + 1),
                    'type' => 'province', 'status' => 1, 'created_at' => $now, 'updated_at' => $now]);
            }
        }

        // Delivery types
        $types = [
            ['standard', 'Standard Delivery', null, 0, null, 'Pick a date and a time slot.'],
            ['same-day', 'Same Day Delivery', 240, 0, null, 'Order before the cut-off for delivery today.'],
            ['express', 'Express Delivery', 60, 150, null, 'Delivered within 60 minutes.'],
            ['midnight', 'Midnight Delivery', null, 200, '23:00-23:59', 'A surprise at 12 AM.'],
        ];
        foreach ($types as $i => [$slug, $name, $lead, $extra, $win, $desc]) {
            DB::table('gift_delivery_types')->updateOrInsert(['slug' => $slug], [
                'name' => $name, 'lead_minutes' => $lead, 'extra_charge' => $extra, 'time_window' => $win,
                'description' => $desc, 'sort_order' => $i, 'status' => 1, 'created_at' => $now, 'updated_at' => $now,
            ]);
        }

        $data = json_decode(file_get_contents(__DIR__ . '/cakezake_products.json'), true);

        // Lookups from the data itself
        $label = fn ($s) => Str::of($s)->replace('-', ' ')->title()->replace('Fathers', "Father's")->replace('Mothers', "Mother's")
            ->replace('Sisters', "Sister's")->replace('Womens', "Women's")->replace('Girlfriends', "Girlfriend's")
            ->replace('Childrens', "Children's")->replace('Grandparents', "Grandparent's")->replace('Teachers', "Teacher's")
            ->replace('Valentines', "Valentine's")->toString();
        foreach (['occasions' => 'occasions', 'relationships' => 'relationships'] as $key => $table) {
            $slugs = collect($data)->pluck($key)->flatten()->unique()->sort()->values();
            foreach ($slugs as $i => $slug) {
                DB::table($table)->updateOrInsert(['slug' => $slug], [
                    'name' => $label($slug), 'sort_order' => $i, 'status' => 1, 'created_at' => $now, 'updated_at' => $now,
                ]);
            }
        }

        // Store
        $branchId = DB::table('branches')->value('id') ?: DB::table('branches')->insertGetId([
            'name' => 'CakeZake Kathmandu', 'fulfillment_type' => 'quick', 'service_modes' => 'delivery',
            'address' => 'Kathmandu, Nepal', 'contact_number' => '', 'email' => 'support@cakezake.com',
            'preparation_time' => 60, 'status' => 1, 'created_at' => $now, 'updated_at' => $now,
        ]);

        // Kathmandu Valley delivery zone
        $poly = json_encode([['lat' => 27.55, 'lng' => 85.15], ['lat' => 27.55, 'lng' => 85.60], ['lat' => 27.85, 'lng' => 85.60], ['lat' => 27.85, 'lng' => 85.15]]);
        $zoneId = DB::table('zones')->where('slug', 'kathmandu-valley')->value('id') ?: DB::table('zones')->insertGetId([
            'name' => 'Kathmandu Valley', 'slug' => 'kathmandu-valley', 'city' => 'Kathmandu', 'state' => 'Bagmati', 'country_id' => 1,
            'status' => 1, 'sales_channel' => 'both', 'polygon_boundary_quick' => $poly, 'polygon_boundary_ecommerce' => $poly,
            'base_delivery_charge' => 150, 'free_delivery_above' => 3000, 'created_at' => $now, 'updated_at' => $now,
        ]);
        DB::table('branches')->where('id', $branchId)->update(['zone_id' => $zoneId, 'latitude' => '27.7172', 'longitude' => '85.3240']);

        // Categories (alcohol grouped under one parent)
        $order = ['Cakes', 'Flowers', 'Gift Hampers', 'Chocolates', 'Combos', 'Rakhi', 'Gifts', 'Personalised Gifts',
            'Personalised Frames', 'Celebration Packages', 'Party Props', 'Accessories', 'Whiskey', 'Vodka', 'Wine'];
        $firstImage = [];
        foreach ($data as $p) {
            if ($p['images'] && !isset($firstImage[$p['category']])) $firstImage[$p['category']] = 'products/' . $p['images'][0];
        }
        $catIds = [];
        DB::table('categories')->where('id', 1)->where('slug', 'cakes')->delete();
        $spiritsId = null;
        foreach ($order as $i => $name) {
            $parent = 0;
            if (in_array($name, ['Whiskey', 'Vodka', 'Wine'])) {
                $spiritsId ??= DB::table('categories')->where('slug', 'spirits-wine')->value('id')
                    ?: DB::table('categories')->insertGetId(['name' => 'Spirits & Wine', 'slug' => 'spirits-wine',
                        'image' => $firstImage['Whiskey'] ?? '', 'row_order' => 99, 'status' => 1, 'parent_id' => 0,
                        'created_at' => $now, 'updated_at' => $now]);
                $parent = $spiritsId;
            }
            $slug = Str::slug($name);
            $catIds[$name] = DB::table('categories')->where('slug', $slug)->value('id')
                ?: DB::table('categories')->insertGetId(['name' => $name, 'slug' => $slug,
                    'image' => $firstImage[$name] ?? '', 'row_order' => $i, 'status' => 1, 'parent_id' => $parent,
                    'created_at' => $now, 'updated_at' => $now]);
        }

        // Products
        $n = 0;
        foreach ($data as $p) {
            if (DB::table('products')->where('slug', $p['slug'])->exists()) continue;
            $price = $p['price']; $disc = null;
            if ($p['compare'] > $price) { $disc = $price; $price = $p['compare']; }
            $isAlcohol = in_array($p['category'], ['Whiskey', 'Vodka', 'Wine']);
            $pid = DB::table('products')->insertGetId([
                'name' => $p['name'], 'slug' => $p['slug'], 'category_id' => $catIds[$p['category']],
                'sales_channel' => 'both', 'is_food' => in_array($p['category'], ['Cakes', 'Chocolates']) ? 1 : 0,
                'image' => $p['images'][0] ?? '' ? 'products/' . $p['images'][0] : '',
                'description' => $p['description'], 'short_description' => Str::limit(strtok($p['description'], "\n"), 180),
                'status' => 1, 'is_draft' => 0, 'total_allowed_quantity' => 1, 'cancelable_status' => 1, 'return_status' => 0, 'return_days' => 0,
                'meta_title' => $p['seo_title'] ?: $p['name'] . ' | CakeZake',
                'meta_description' => $p['seo_desc'] ?: Str::limit(strtok($p['description'], "\n"), 155),
                'occasions' => json_encode($p['occasions']), 'relationships' => json_encode($p['relationships']),
                'delivery_types' => json_encode($p['delivery_types']), 'is_personalizable' => $p['personalizable'] ? 1 : 0,
                'is_featured' => $p['featured'] ? 1 : 0, 'created_at' => $now, 'updated_at' => $now,
            ]);
            foreach (array_slice($p['images'], 0) as $img) {
                DB::table('product_images')->insert(['product_id' => $pid, 'product_variant_id' => 0, 'image' => 'products/' . $img]);
            }
            $vid = DB::table('product_variants')->insertGetId([
                'product_id' => $pid, 'name' => $p['name'], 'sku' => 'CZ-' . str_pad((string) $pid, 5, '0', STR_PAD_LEFT),
                'hsn_code' => $p['hs'] ?: null, 'image' => $p['images'][0] ?? '' ? 'products/' . $p['images'][0] : '',
                'sort_order' => 0, 'created_at' => $now, 'updated_at' => $now,
            ]);
            if ($langId = app(\App\Services\LanguageService::class)->getDefaultLanguage()?->id) {
                DB::table('product_variant_translations')->insert(['product_variant_id' => $vid, 'language_id' => $langId,
                    'name' => $p['name'], 'created_at' => $now, 'updated_at' => $now]);
            }
            DB::table('product_variant_branch_stocks')->insert([
                'product_variant_id' => $vid, 'branch_id' => $branchId, 'is_listed' => 1, 'is_unlimited_stock' => 1,
                'stock_status' => 1, 'available' => 0, 'price' => $price, 'discounted_price' => $disc,
                'created_at' => $now, 'updated_at' => $now,
            ]);
            $n++;
        }
        // Content lives in the default language's translation rows, as the admin form saves it.
        $langId = app(\App\Services\LanguageService::class)->getDefaultLanguage()?->id;
        if ($langId) {
            DB::table('products')->orderBy('id')->chunk(200, function ($rows) use ($langId, $now) {
                foreach ($rows as $r) {
                    DB::table('product_translations')->updateOrInsert(['product_id' => $r->id, 'language_id' => $langId], [
                        'name' => $r->name, 'short_description' => $r->short_description, 'description' => $r->description,
                        'meta_title' => $r->meta_title, 'meta_description' => $r->meta_description,
                        'created_at' => $now, 'updated_at' => $now,
                    ]);
                }
            });
            foreach (DB::table('categories')->get() as $c) {
                DB::table('category_translations')->updateOrInsert(['category_id' => $c->id, 'language_id' => $langId], [
                    'name' => $c->name, 'created_at' => $now, 'updated_at' => $now,
                ]);
            }
        }
        $this->command?->info("Imported $n products.");
    }
}
