<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('category_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('category_id');
            $table->unsignedBigInteger('language_id');
            $table->string('name')->nullable();
            $table->string('meta_title')->nullable();
            $table->text('meta_keywords')->nullable();
            $table->text('schema_markup')->nullable();
            $table->text('meta_description')->nullable();
            $table->timestamps();

            $table->foreign('category_id')->references('id')->on('categories')->onDelete('cascade');
            $table->foreign('language_id')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['category_id', 'language_id']);
        });

        Schema::create('store_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('store_id');
            $table->unsignedBigInteger('language_id');
            $table->string('name')->nullable();
            $table->string('provider')->nullable();
            $table->text('address')->nullable();
            $table->timestamps();

            $table->foreign('store_id')->references('id')->on('stores')->onDelete('cascade');
            $table->foreign('language_id')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['store_id', 'language_id']);
        });

        Schema::create('promo_code_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('promo_code_id');
            $table->unsignedBigInteger('language_id');
            $table->string('title')->nullable();
            $table->text('description')->nullable();
            $table->timestamps();

            $table->foreign('promo_code_id')->references('id')->on('promo_codes')->onDelete('cascade');
            $table->foreign('language_id')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['promo_code_id', 'language_id']);
        });

        Schema::create('tax_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('tax_id');
            $table->unsignedBigInteger('language_id');
            $table->string('title')->nullable();
            $table->timestamps();

            $table->foreign('tax_id')->references('id')->on('taxes')->onDelete('cascade');
            $table->foreign('language_id')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['tax_id', 'language_id']);
        });

        Schema::create('brand_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('brand_id');
            $table->unsignedBigInteger('language_id');
            $table->string('name')->nullable();
            $table->timestamps();

            $table->foreign('brand_id')->references('id')->on('brands')->onDelete('cascade');
            $table->foreign('language_id')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['brand_id', 'language_id']);
        });

        Schema::create('product_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('product_id');
            $table->unsignedBigInteger('language_id');
            $table->string('name')->nullable();
            $table->text('tags')->nullable();
            $table->string('manufacturer')->nullable();
            $table->string('made_in')->nullable();
            $table->text('short_description')->nullable();
            $table->longText('description')->nullable();
            $table->string('meta_title')->nullable();
            $table->text('meta_keywords')->nullable();
            $table->text('schema_markup')->nullable();
            $table->text('meta_description')->nullable();
            $table->timestamps();

            $table->foreign('product_id')->references('id')->on('products')->onDelete('cascade');
            $table->foreign('language_id')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['product_id', 'language_id']);
        });

        Schema::create('product_variant_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('product_variant_id');
            $table->unsignedBigInteger('language_id');
            $table->string('name')->nullable();
            $table->timestamps();

            $table->foreign('product_variant_id', 'pvt_variant_fk')
                ->references('id')->on('product_variants')->onDelete('cascade');
            $table->foreign('language_id', 'pvt_lang_fk')
                ->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['product_variant_id', 'language_id'], 'pvt_variant_lang_unique');
        });

        Schema::create('delivery_boy_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('delivery_boy_id');
            $table->unsignedBigInteger('language_id');
            $table->string('name');
            $table->text('address')->nullable();
            $table->text('other_payment_information')->nullable();

            $table->foreign('delivery_boy_id')->references('id')->on('delivery_boys')->onDelete('cascade');
            $table->foreign('language_id')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['delivery_boy_id', 'language_id'], 'delivery_boy_language_unique');
        });

        Schema::create('blog_category_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('blog_category_id');
            $table->unsignedBigInteger('language_id');
            $table->string('name');
            $table->string('meta_title')->nullable();
            $table->text('meta_keywords')->nullable();
            $table->text('meta_description')->nullable();
            $table->text('schema_markup')->nullable();
            $table->timestamps();

            $table->foreign('blog_category_id')->references('id')->on('blog_categories')->onDelete('cascade');
            $table->foreign('language_id')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['blog_category_id', 'language_id'], 'blog_category_language_unique');
        });

        Schema::create('blog_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('blog_id');
            $table->unsignedBigInteger('language_id');
            $table->string('title')->nullable();
            $table->longText('description')->nullable();
            $table->text('short_description')->nullable();
            $table->string('meta_title')->nullable();
            $table->text('meta_keywords')->nullable();
            $table->text('meta_description')->nullable();
            $table->text('schema_markup')->nullable();
            $table->timestamps();

            $table->foreign('blog_id')->references('id')->on('blogs')->onDelete('cascade');
            $table->foreign('language_id')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['blog_id', 'language_id']);
        });

        Schema::create('seo_setting_translations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('seo_setting_id')->constrained('web_seo_pages')->onDelete('cascade');
            $table->foreignId('language_id')->constrained('languages')->onDelete('cascade');
            $table->string('meta_title')->nullable();
            $table->text('meta_keyword')->nullable();
            $table->longText('schema_markup')->nullable();
            $table->text('meta_description')->nullable();
            $table->timestamps();
            $table->unique(['seo_setting_id', 'language_id']);
        });

        Schema::create('country_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('country_id');
            $table->unsignedBigInteger('language_id');
            $table->string('name')->nullable();
            $table->longText('privacy_policy')->nullable();
            $table->longText('return_policy')->nullable();
            $table->longText('shipping_policy')->nullable();
            $table->longText('cancellation_policy')->nullable();
            $table->longText('terms_conditions')->nullable();
            $table->longText('privacy_policy_delivery_boy')->nullable();
            $table->longText('terms_conditions_delivery_boy')->nullable();
            $table->timestamps();

            $table->foreign('country_id')->references('id')->on('countries')->onDelete('cascade');
            $table->foreign('language_id', 'country_trans_lang_fk')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['country_id', 'language_id']);
        });

        Schema::create('faq_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('faq_id');
            $table->unsignedBigInteger('language_id');
            $table->string('question')->nullable();
            $table->text('answer')->nullable();
            $table->timestamps();

            $table->foreign('faq_id')->references('id')->on('faqs')->onDelete('cascade');
            $table->foreign('language_id')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['faq_id', 'language_id']);
        });

        Schema::create('notification_template_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('notification_template_id');
            $table->unsignedBigInteger('language_id');
            $table->string('title');
            $table->text('message')->nullable();
            $table->timestamps();

            $table->foreign('notification_template_id', 'notif_tpl_trans_tpl_fk')->references('id')->on('notification_templates')->onDelete('cascade');
            $table->foreign('language_id', 'notif_tpl_trans_lang_fk')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['notification_template_id', 'language_id'], 'notif_tpl_trans_tpl_lang_unique');
        });

        Schema::create('zone_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('zone_id');
            $table->unsignedBigInteger('language_id');
            $table->json('surge_labels')->nullable();
            $table->json('additional_charge_names_quick')->nullable();
            $table->json('additional_charge_names_ecommerce')->nullable();
            $table->timestamps();

            $table->foreign('zone_id')->references('id')->on('zones')->onDelete('cascade');
            $table->foreign('language_id')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['zone_id', 'language_id']);
        });

        Schema::create('sms_template_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('sms_template_id');
            $table->unsignedBigInteger('language_id');
            $table->text('message')->nullable();
            $table->json('gateway_template_ids')->nullable();
            $table->timestamps();

            $table->unique(['sms_template_id', 'language_id'], 'sms_tpl_trans_unique');
            $table->index('sms_template_id');
        });

        Schema::create('email_template_translations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('email_template_id');
            $table->unsignedBigInteger('language_id');
            $table->string('title');
            $table->text('message')->nullable();
            $table->timestamps();

            $table->foreign('email_template_id', 'email_tpl_trans_tpl_fk')->references('id')->on('email_templates')->onDelete('cascade');
            $table->foreign('language_id', 'email_tpl_trans_lang_fk')->references('id')->on('languages')->onDelete('cascade');
            $table->unique(['email_template_id', 'language_id'], 'email_tpl_trans_tpl_lang_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('zone_translations');
        Schema::dropIfExists('notification_template_translations');
        Schema::dropIfExists('faq_translations');
        Schema::dropIfExists('country_translations');
        Schema::dropIfExists('seo_setting_translations');
        Schema::dropIfExists('blog_translations');
        Schema::dropIfExists('blog_category_translations');
        Schema::dropIfExists('delivery_boy_translations');
        Schema::dropIfExists('product_variant_translations');
        Schema::dropIfExists('product_translations');
        Schema::dropIfExists('brand_translations');
        Schema::dropIfExists('tax_translations');
        Schema::dropIfExists('promo_code_translations');
        Schema::dropIfExists('store_translations');
        Schema::dropIfExists('category_translations');
        Schema::dropIfExists('email_template_translations');
    }
};
