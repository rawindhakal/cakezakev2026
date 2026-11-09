<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** SEO content for Page Builder pages: meta tags, intro copy and FAQs (JSON). */
return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasColumn('page_layouts', 'seo')) {
            Schema::table('page_layouts', function (Blueprint $table) {
                $table->json('seo')->nullable()->after('title_color');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('page_layouts', 'seo')) {
            Schema::table('page_layouts', fn (Blueprint $t) => $t->dropColumn('seo'));
        }
    }
};
