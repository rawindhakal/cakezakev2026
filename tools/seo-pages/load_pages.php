<?php
// Run with: php artisan tinker --execute="include '/tmp/load_pages.php';"
$rows = json_decode(file_get_contents('/tmp/pages_seed.json'), true);
$made = 0; $skipped = 0;
foreach ($rows as $r) {
    if (DB::table('page_layouts')->where('slug', $r['slug'])->exists()) { $skipped++; continue; }
    DB::table('page_layouts')->insert([
        'name' => $r['name'], 'slug' => $r['slug'], 'title' => json_encode($r['title']),
        'header_color' => $r['header_color'], 'title_color' => $r['title_color'],
        'seo' => json_encode($r['seo']), 'status' => 'draft', 'is_active' => 1,
        'draft_json' => json_encode($r['draft_json']), 'published_json' => null,
        'created_at' => now(), 'updated_at' => now(),
    ]);
    $made++;
}
echo "created=$made skipped=$skipped\n";
