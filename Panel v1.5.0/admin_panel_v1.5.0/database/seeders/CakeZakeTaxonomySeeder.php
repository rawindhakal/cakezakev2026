<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Gifting taxonomy modelled on giftmandu.com (Nepal), igp.com and fnp.com: category tree, filterable attributes
 * (flavour, egg type, weight, shape, flower type...), occasions (incl. Nepali festivals) and recipient/relationship
 * lists. Idempotent: everything is matched on slug, existing products are only re-filed when confident.
 */
class CakeZakeTaxonomySeeder extends Seeder
{
    private $now;
    private ?int $langId = null;

    public function run(): void
    {
        $this->now = now();
        $this->langId = app(\App\Services\LanguageService::class)->getDefaultLanguage()?->id;

        $this->occasions();
        $this->relationships();
        $catIds = $this->categories();
        $attrs = $this->attributes($catIds);
        $this->fileProducts($catIds);
        $this->tagProducts($attrs);
        $this->command?->info('Taxonomy loaded.');
    }

    // ── Occasions ────────────────────────────────────────────────────────────
    private function occasions(): void
    {
        // slug => [name, date note]. Existing slugs from the product import are kept.
        $list = [
            'birthday' => ['Birthday', ''], 'anniversary' => ['Anniversary', ''], 'wedding-&-engagement' => ['Wedding & Engagement', ''],
            'baby-shower' => ['Baby Shower', ''], 'new-baby' => ['New Baby', ''], 'housewarming' => ['Housewarming', ''],
            'congratulations' => ['Congratulations', ''], 'graduation' => ['Graduation', ''], 'get-well-soon' => ['Get Well Soon', ''],
            'sorry' => ['Sorry', ''], 'thank-you' => ['Thank You', ''], 'best-wishes' => ['Best Wishes', ''],
            'sympathy' => ['Sympathy & Condolence', ''], 'farewell' => ['Farewell', ''], 'promotion' => ['Promotion', ''],
            'bride-to-be' => ['Bride to Be', ''], 'valentines-day' => ["Valentine's Day", '14th Feb'], 'mothers-day' => ["Mother's Day", 'May'],
            'fathers-day' => ["Father's Day", 'June'], 'womens-day' => ["Women's Day", '8th Mar'], 'friendship-day' => ['Friendship Day', 'Aug'],
            'teachers-day' => ["Teacher's Day", '5th Sep'], 'childrens-day' => ["Children's Day", '14th Nov'], 'boss-day' => ["Boss's Day", '16th Oct'],
            'grandparents-day' => ["Grandparents' Day", 'Sep'], 'girlfriends-day' => ["Girlfriend's Day", '1st Aug'], 'sisters-day' => ["Sister's Day", 'Aug'],
            'rakhi' => ['Raksha Bandhan (Rakhi)', 'Aug'], 'bhai-tika' => ['Bhai Tika (Tihar)', 'Oct/Nov'], 'tihar' => ['Tihar / Deepawali', 'Oct/Nov'],
            'dashain' => ['Dashain', 'Sep/Oct'], 'teej' => ['Teej', 'Aug/Sep'], 'holi' => ['Holi', 'Mar'], 'christmas' => ['Christmas', '25th Dec'],
            'new-year' => ['New Year', '1st Jan'], 'nepali-new-year' => ['Nepali New Year (Navavarsha)', 'Apr'], 'eid' => ['Eid', ''],
            'chhath' => ['Chhath', 'Nov'], 'easter' => ['Easter', ''], 'corporate' => ['Corporate & Client Gifts', ''],
            'first-birthday' => ['1st Birthday', ''], 'sweet-sixteen' => ['16th Birthday', ''], 'eighteenth-birthday' => ['18th Birthday', ''],
            'twenty-first-birthday' => ['21st Birthday', ''], 'twenty-fifth-birthday' => ['25th Birthday', ''], 'fiftieth-birthday' => ['50th Birthday', ''],
            'silver-anniversary' => ['25th Anniversary', ''], 'golden-anniversary' => ['50th Anniversary', ''],
        ];
        $i = 0;
        foreach ($list as $slug => [$name, $date]) {
            DB::table('occasions')->updateOrInsert(['slug' => $slug], ['name' => $name, 'occasion_date' => $date ?: null,
                'sort_order' => $i++, 'status' => 1, 'created_at' => $this->now, 'updated_at' => $this->now]);
        }
        // Retire near-duplicate slugs from the import ("ramadan-&-eid", "eid-al-adha") but keep them usable.
        DB::table('occasions')->whereIn('slug', ['ramadan-&-eid', 'eid-al-adha', 'valentines-day'])->update(['status' => 1]);
    }

    // ── Recipients / relationships ──────────────────────────────────────────
    private function relationships(): void
    {
        $list = [
            'for-her' => 'For Her', 'for-him' => 'For Him', 'for-wife' => 'For Wife', 'for-husband' => 'For Husband',
            'for-girlfriend' => 'For Girlfriend', 'for-boyfriend' => 'For Boyfriend', 'mother' => 'Mother', 'father' => 'Father',
            'sister' => 'Sister', 'brother' => 'Brother', 'daughter' => 'Daughter', 'son' => 'Son', 'for-friend' => 'For Friend',
            'grandmother' => 'Grandmother', 'grandfather' => 'Grandfather', 'parents' => 'Parents', 'couples' => 'Couples',
            'fiancee' => 'Fiancée', 'fiance' => 'Fiancé', 'in-laws' => 'In-Laws', 'boss' => 'Boss', 'colleague' => 'Colleague',
            'teacher' => 'Teacher', 'for-kids' => 'Kids', 'newborn' => 'Newborn & Babies', 'teens' => 'Teens', 'women' => 'Women',
        ];
        $i = 0;
        foreach ($list as $slug => $name) {
            DB::table('relationships')->updateOrInsert(['slug' => $slug], ['name' => $name, 'sort_order' => $i++, 'status' => 1,
                'created_at' => $this->now, 'updated_at' => $this->now]);
        }
    }

    // ── Categories ───────────────────────────────────────────────────────────
    private function cat(string $name, int $parent, int $order, bool $active = true): int
    {
        $slug = Str::slug($name);
        $id = DB::table('categories')->where('slug', $slug)->value('id');
        if (!$id) {
            $id = DB::table('categories')->insertGetId(['name' => $name, 'slug' => $slug, 'image' => '', 'row_order' => $order,
                'status' => $active ? 1 : 0, 'parent_id' => $parent, 'created_at' => $this->now, 'updated_at' => $this->now]);
        }
        if ($this->langId) {
            DB::table('category_translations')->updateOrInsert(['category_id' => $id, 'language_id' => $this->langId],
                ['name' => $name, 'created_at' => $this->now, 'updated_at' => $this->now]);
        }
        return $id;
    }

    private function categories(): array
    {
        $tree = [
            'Cakes' => ['Birthday Cakes', 'Anniversary Cakes', 'Photo Cakes', 'Bento Cakes', 'Designer Cakes', 'Eggless Cakes', 'Chocolate Cakes',
                'Red Velvet Cakes', 'Cheesecakes', 'Fruit Cakes', 'Tier Cakes', 'Kids Cakes', 'Wedding Cakes', 'Cupcakes & Pastries'],
            'Flowers' => ['Roses', 'Orchids', 'Lilies', 'Carnations', 'Gerberas', 'Sunflowers', 'Mixed Bouquets', 'Flower Boxes & Baskets', 'Preserved & Artificial Flowers'],
            'Plants' => ['Indoor Plants', 'Money Plants', 'Lucky Bamboo', 'Succulents & Cactus', 'Plant Gift Sets'],
            'Gift Hampers' => ['Chocolate Hampers', 'Food & Snack Hampers', 'Tea & Coffee Hampers', 'Dry Fruit Hampers', 'Beauty & Wellness Hampers',
                'Festive Hampers', 'Luxury Hampers', 'Corporate Hampers'],
            'Chocolates' => ['Chocolate Bouquets', 'Chocolate Boxes', 'Imported Chocolates', 'Truffles & Pralines'],
            'Sweets & Dry Fruits' => ['Mithai & Sweets', 'Dry Fruits & Nuts', 'Cookies & Biscuits', 'Festive Sweet Boxes'],
            'Combos' => ['Cake & Flowers', 'Cake & Chocolates', 'Flowers & Chocolates', 'Teddy Combos', 'Birthday Combos', 'Anniversary Combos'],
            'Personalised Gifts' => ['Personalised Mugs', 'Personalised Cushions', 'Photo Gifts', 'LED & Acrylic Lamps', 'Personalised T-Shirts',
                'Personalised Bottles', 'Keychains & Keepsakes', 'Canvas & Prints', 'Engraved Gifts'],
            'Soft Toys & Teddy' => ['Teddy Bears', 'Soft Toys'],
            'Greeting Cards' => ['Birthday Cards', 'Anniversary & Love Cards', 'Festive Cards'],
            'Corporate Gifts' => ['Employee Recognition', 'Client Appreciation', 'Bulk & Branded Gifts'],
            'Gift Vouchers & Experiences' => ['Spa & Wellness', 'Restaurant Vouchers', 'Gift Cards'],
            'Party Props' => ['Balloons & Decor', 'Candles & Toppers', 'Party Supplies'],
            'Rakhi' => ['Rakhi Combos', 'Rakhi Hampers', 'Designer Rakhis'],
        ];
        $ids = [];
        $order = 20;
        foreach ($tree as $parentName => $children) {
            $pid = $this->cat($parentName, 0, $order++);
            $ids[$parentName] = $pid;
            foreach ($children as $i => $child) {
                // Sub-categories start switched off until they hold products (activated by fileProducts()).
                $ids[$child] = $this->cat($child, $pid, $i, false);
            }
        }
        foreach (['Soft Toys & Teddy', 'Plants', 'Sweets & Dry Fruits', 'Greeting Cards', 'Corporate Gifts', 'Gift Vouchers & Experiences'] as $topEmpty) {
            DB::table('categories')->where('id', $ids[$topEmpty])->update(['status' => 0]); // top-level ones with no products yet
        }
        return $ids;
    }

    // ── Attributes ───────────────────────────────────────────────────────────
    private function attributes(array $catIds): array
    {
        $defs = [
            'Flavour' => ['Chocolate', 'Chocolate Truffle', 'Vanilla', 'Red Velvet', 'Butterscotch', 'Pineapple', 'Black Forest', 'Strawberry', 'Mango',
                'Blueberry', 'Rasmalai', 'Coffee & Mocha', 'Oreo', 'Fruit', 'Lemon', 'Biscoff', 'Tiramisu', 'Kit Kat', 'Ferrero Rocher', 'Caramel', 'Honey', 'Mixed Fruit'],
            'Egg Type' => ['Eggless', 'Contains Egg'],
            'Weight' => ['Bento (300 g)', '500 g', '1 lb (450 g)', '1 kg', '1.5 kg', '2 kg', '3 kg', '5 kg+'],
            'Shape' => ['Round', 'Square', 'Heart', 'Rectangle', 'Number / Letter', 'Custom'],
            'Cake Type' => ['Bento', 'Photo Cake', 'Designer', 'Tier', 'Cheesecake', 'Cupcake / Pastry', 'Cream Cake', 'Fondant', 'Dry Cake'],
            'Dietary' => ['Sugar Free', 'Vegan', 'Gluten Free', 'Low Sugar'],
            'Flower Type' => ['Roses', 'Orchids', 'Lilies', 'Carnations', 'Gerberas', 'Sunflowers', 'Tulips', 'Mixed Flowers', 'Marigold', 'Chrysanthemum'],
            'Colour' => ['Red', 'Pink', 'White', 'Yellow', 'Purple', 'Orange', 'Blue', 'Peach', 'Mixed', 'Black'],
            'Arrangement' => ['Hand-tied Bouquet', 'Flower Box', 'Basket', 'Vase', 'Heart Shape', 'Single Stem'],
            'Number of Stems' => ['1', '6', '10', '12', '18', '24', '36', '50', '100'],
            'Hamper Type' => ['Chocolate', 'Snacks & Food', 'Tea & Coffee', 'Dry Fruits', 'Beauty & Wellness', 'Festive', 'Luxury', 'Corporate'],
            'Gift For' => ['Personalised', 'Ready-made', 'Customisable'],
        ];
        $perCategory = [
            'Cakes' => ['Flavour', 'Egg Type', 'Weight', 'Shape', 'Cake Type', 'Dietary'],
            'Flowers' => ['Flower Type', 'Colour', 'Arrangement', 'Number of Stems'],
            'Gift Hampers' => ['Hamper Type'],
            'Personalised Gifts' => ['Gift For'],
        ];
        $attrIds = []; $valIds = [];
        foreach ($defs as $name => $values) {
            $slug = Str::slug($name);
            $aid = DB::table('attributes')->where('slug', $slug)->value('id')
                ?: DB::table('attributes')->insertGetId(['name' => $name, 'slug' => $slug, 'status' => 1, 'created_at' => $this->now, 'updated_at' => $this->now]);
            $attrIds[$name] = $aid;
            if ($this->langId && \Illuminate\Support\Facades\Schema::hasTable('attribute_translations')) {
                DB::table('attribute_translations')->updateOrInsert(['attribute_id' => $aid, 'language_id' => $this->langId], ['name' => $name, 'created_at' => $this->now, 'updated_at' => $this->now]);
            }
            foreach ($values as $v) {
                $vid = DB::table('attribute_values')->where('attribute_id', $aid)->where('value', $v)->value('id')
                    ?: DB::table('attribute_values')->insertGetId(['attribute_id' => $aid, 'value' => $v, 'created_at' => $this->now, 'updated_at' => $this->now]);
                $valIds[$name][$v] = $vid;
                if ($this->langId && \Illuminate\Support\Facades\Schema::hasTable('attribute_value_translations')) {
                    DB::table('attribute_value_translations')->updateOrInsert(['attribute_value_id' => $vid, 'language_id' => $this->langId], ['value' => $v, 'created_at' => $this->now, 'updated_at' => $this->now]);
                }
            }
        }
        foreach ($perCategory as $cat => $names) {
            foreach ($names as $n) {
                DB::table('category_attribute')->updateOrInsert(['category_id' => $catIds[$cat], 'attribute_id' => $attrIds[$n]],
                    ['is_overridden_off' => 0, 'created_at' => $this->now, 'updated_at' => $this->now]);
            }
        }
        return ['attrs' => $attrIds, 'vals' => $valIds];
    }

    // ── File existing products into sub-categories (keyword based, confident matches only) ──
    private function fileProducts(array $catIds): void
    {
        $rules = [
            'Cakes' => [
                'Bento Cakes' => '/\bbento\b/i', 'Photo Cakes' => '/photo\s*cake|photo\b/i', 'Cheesecakes' => '/cheese\s*cake/i',
                'Tier Cakes' => '/\b(2|3|two|three)\s*tier|tier(ed)?\s*cake/i', 'Cupcakes & Pastries' => '/cup\s*cake|pastr(y|ies)|brownie/i',
                'Red Velvet Cakes' => '/red\s*velvet/i', 'Wedding Cakes' => '/wedding|engagement/i', 'Kids Cakes' => '/\bkids?\b|cartoon|barbie|spider|unicorn|teddy cake/i',
                'Chocolate Cakes' => '/chocolate|truffle|choco\b|oreo|ferrero|kit\s*kat/i', 'Fruit Cakes' => '/fruit\s*cake|mixed fruit|pineapple|mango|blueberry|strawberry/i',
                'Anniversary Cakes' => '/anniversary/i', 'Designer Cakes' => '/design|theme|fondant/i',
            ],
            'Flowers' => [
                'Roses' => '/\brose/i', 'Orchids' => '/orchid/i', 'Lilies' => '/\blil(y|ies)/i', 'Carnations' => '/carnation/i', 'Gerberas' => '/gerbera/i',
                'Sunflowers' => '/sunflower/i', 'Flower Boxes & Baskets' => '/\b(box|basket)\b/i', 'Mixed Bouquets' => '/bouquet|mixed|arrangement/i',
            ],
            'Gift Hampers' => [
                'Chocolate Hampers' => '/chocolate|ferrero|truffle/i', 'Dry Fruit Hampers' => '/dry\s*fruit|nuts?\b|almond|cashew|kaju/i',
                'Tea & Coffee Hampers' => '/\btea\b|coffee/i', 'Festive Hampers' => '/rakhi|diwali|tihar|dashain|festive|bhai/i',
                'Beauty & Wellness Hampers' => '/beauty|spa|skin|perfume|wellness/i', 'Luxury Hampers' => '/luxury|premium|deluxe/i',
            ],
            'Combos' => [
                'Cake & Flowers' => '/cake.*(flower|rose|bouquet)|(flower|rose|bouquet).*cake/i', 'Cake & Chocolates' => '/cake.*chocolate|chocolate.*cake/i',
                'Teddy Combos' => '/teddy/i', 'Flowers & Chocolates' => '/(flower|rose|bouquet).*chocolate|chocolate.*(flower|rose|bouquet)/i',
            ],
            'Rakhi' => ['Rakhi Hampers' => '/hamper|gift set/i', 'Rakhi Combos' => '/combo|with/i'],
        ];
        $moved = 0;
        foreach ($rules as $parent => $subs) {
            $pid = $catIds[$parent];
            foreach (DB::table('products')->where('category_id', $pid)->get(['id', 'name']) as $p) {
                foreach ($subs as $sub => $re) {
                    if (preg_match($re, $p->name)) {
                        DB::table('products')->where('id', $p->id)->update(['category_id' => $catIds[$sub]]);
                        $moved++;
                        break;
                    }
                }
            }
        }
        // Activate any sub-category that now holds products (and its parent).
        foreach (DB::table('categories')->where('parent_id', '>', 0)->get(['id', 'parent_id']) as $c) {
            if (DB::table('products')->where('category_id', $c->id)->exists()) {
                DB::table('categories')->whereIn('id', [$c->id, $c->parent_id])->update(['status' => 1]);
            }
        }
        // Use the first product image as the sub-category image.
        foreach (DB::table('categories')->where('image', '')->get(['id']) as $c) {
            $img = DB::table('products')->where('category_id', $c->id)->where('image', '!=', '')->value('image');
            if ($img) DB::table('categories')->where('id', $c->id)->update(['image' => $img]);
        }
        $this->command?->info("Filed $moved products into sub-categories.");
    }

    // ── Attribute values on products (read from name / description) ──────────
    private function tagProducts(array $a): void
    {
        $vals = $a['vals']; $attrs = $a['attrs'];
        $flavours = ['Chocolate Truffle' => '/truffle/i', 'Red Velvet' => '/red\s*velvet/i', 'Butterscotch' => '/butter\s*scotch/i', 'Black Forest' => '/black\s*forest/i',
            'Pineapple' => '/pineapple/i', 'Strawberry' => '/strawberr/i', 'Mango' => '/mango/i', 'Blueberry' => '/blueberr/i', 'Rasmalai' => '/rasmalai/i',
            'Coffee & Mocha' => '/coffee|mocha/i', 'Oreo' => '/oreo/i', 'Biscoff' => '/biscoff/i', 'Tiramisu' => '/tiramisu/i', 'Kit Kat' => '/kit\s*kat/i',
            'Ferrero Rocher' => '/ferrero/i', 'Caramel' => '/caramel/i', 'Lemon' => '/lemon/i', 'Vanilla' => '/vanilla/i', 'Chocolate' => '/chocolate|choco\b/i',
            'Mixed Fruit' => '/mixed fruit|fruit\s*cake/i'];
        $shapes = ['Heart' => '/heart/i', 'Square' => '/square/i', 'Rectangle' => '/rectang/i', 'Number / Letter' => '/number|alphabet|letter/i', 'Round' => '/round/i'];
        $cakeTypes = ['Bento' => '/bento/i', 'Photo Cake' => '/photo/i', 'Cheesecake' => '/cheese\s*cake/i', 'Tier' => '/tier/i', 'Cupcake / Pastry' => '/cup\s*cake|pastr/i',
            'Designer' => '/design|theme|fondant/i'];
        $flowerTypes = ['Roses' => '/\brose/i', 'Orchids' => '/orchid/i', 'Lilies' => '/\blil(y|ies)/i', 'Carnations' => '/carnation/i', 'Gerberas' => '/gerbera/i',
            'Sunflowers' => '/sunflower/i', 'Tulips' => '/tulip/i', 'Marigold' => '/marigold/i', 'Mixed Flowers' => '/mixed|assorted/i'];
        $colours = ['Red' => '/\bred\b/i', 'Pink' => '/\bpink\b/i', 'White' => '/\bwhite\b/i', 'Yellow' => '/\byellow\b/i', 'Purple' => '/purple|lavender/i',
            'Orange' => '/orange/i', 'Blue' => '/\bblue\b/i', 'Peach' => '/peach/i'];
        $arrangements = ['Flower Box' => '/\bbox\b/i', 'Basket' => '/basket/i', 'Vase' => '/\bvase\b/i', 'Hand-tied Bouquet' => '/bouquet|hand.?tied/i'];

        $cakeIds = $this->descendantIds('cakes'); $flowerIds = $this->descendantIds('flowers');
        $pick = function (array $map, string $text) { foreach ($map as $label => $re) if (preg_match($re, $text)) return $label; return null; };
        $n = 0;
        $products = DB::table('products as p')->join('product_variants as v', 'v.product_id', '=', 'p.id')
            ->select('p.id', 'p.name', 'p.description', 'p.category_id', 'v.id as vid')->get();
        foreach ($products as $p) {
            $text = $p->name . ' ' . $p->description;
            $set = [];
            if (in_array($p->category_id, $cakeIds)) {
                if ($f = $pick($flavours, $p->name) ?? $pick($flavours, $text)) $set['Flavour'] = $f;
                if (preg_match('/eggless|egg\s*free/i', $text)) $set['Egg Type'] = 'Eggless';
                if (preg_match('/(\d+(?:\.\d+)?)\s*(kg|kgs)\b/i', $text, $m)) {
                    $kg = (float) $m[1];
                    $set['Weight'] = $kg <= 1 ? '1 kg' : ($kg <= 1.5 ? '1.5 kg' : ($kg <= 2 ? '2 kg' : ($kg <= 3 ? '3 kg' : '5 kg+')));
                } elseif (preg_match('/\bhalf\s*kg\b|500\s*(g|gm|grams?)\b/i', $text)) $set['Weight'] = '500 g';
                elseif (preg_match('/\b1\s*(lb|pound)s?\b/i', $text)) $set['Weight'] = '1 lb (450 g)';
                elseif (preg_match('/bento/i', $p->name)) $set['Weight'] = 'Bento (300 g)';
                if ($s = $pick($shapes, $text)) $set['Shape'] = $s;
                if ($t = $pick($cakeTypes, $p->name)) $set['Cake Type'] = $t;
                if (preg_match('/sugar\s*free/i', $text)) $set['Dietary'] = 'Sugar Free';
            } elseif (in_array($p->category_id, $flowerIds)) {
                if ($t = $pick($flowerTypes, $p->name)) $set['Flower Type'] = $t;
                if ($c = $pick($colours, $p->name)) $set['Colour'] = $c;
                if ($ar = $pick($arrangements, $p->name)) $set['Arrangement'] = $ar;
                if (preg_match('/\b(\d{1,3})\s*(stems?|roses?|flowers?|carnations?|gerberas?|lil(?:y|ies))\b/i', $p->name, $m) && isset($vals['Number of Stems'][(string) (int) $m[1]])) {
                    $set['Number of Stems'] = (string) (int) $m[1];
                }
            }
            foreach ($set as $attr => $label) {
                $vid = $vals[$attr][$label] ?? null;
                if (!$vid) continue;
                DB::table('product_variant_attribute_values')->updateOrInsert(['product_variant_id' => $p->vid, 'attribute_id' => $attrs[$attr]],
                    ['attribute_value_id' => $vid, 'created_at' => $this->now, 'updated_at' => $this->now]);
                $n++;
            }
        }
        $this->command?->info("Tagged $n attribute values on products.");
    }

    private function descendantIds(string $slug): array
    {
        $root = DB::table('categories')->where('slug', $slug)->value('id');
        if (!$root) return [];
        $ids = [(int) $root];
        foreach (DB::table('categories')->where('parent_id', $root)->pluck('id') as $c) $ids[] = (int) $c;
        return $ids;
    }
}
