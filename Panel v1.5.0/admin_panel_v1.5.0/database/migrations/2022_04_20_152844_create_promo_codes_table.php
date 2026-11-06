<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreatePromoCodesTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('promo_codes', function (Blueprint $table) {
            $table->id();

            // 1. Basic info
            $table->string('title')->nullable();
            $table->string('promo_code');
            $table->text('description')->nullable(); // translatable -> promo_code_translations.description

            // 2. Discount
            $table->string('discount_type'); // percentage | flat | free_delivery
            $table->decimal('discount', 10, 2)->default(0);
            $table->enum('discount_apply_type', ['instant', 'wallet'])->default('instant');
            $table->decimal('max_discount_amount', 10, 2)->default(0);

            // 3. Applicability
            $table->enum('applicability', ['all', 'categories', 'products', 'brands'])->default('all');
            $table->json('applicability_ids')->nullable();

            // 4. Cart conditions
            $table->decimal('minimum_order_amount', 10, 2)->default(0);
            $table->integer('min_product_quantity')->default(0);

            // 5. Usage restrictions
            $table->integer('total_usage_limit')->default(0);      // 0 = unlimited
            $table->integer('per_user_usage_limit')->default(0);   // 0 = unlimited

            // 6. Scheduling
            $table->tinyInteger('is_permanent')->default(0);
            $table->date('start_date')->nullable();
            $table->date('end_date')->nullable();
            $table->tinyInteger('full_day_promotion')->default(1);
            $table->time('start_time')->nullable();
            $table->time('end_time')->nullable();
            $table->json('weekday_recurrence')->nullable(); // [0..6]

            // 7. Audience ('new' = customers with no prior orders)
            $table->enum('audience_type', ['all', 'new', 'specific'])->default('all');
            $table->json('audience_ids')->nullable();

            // 9. Platform & visibility
            $table->enum('visibility', ['public', 'hidden'])->default('public');
            $table->enum('platform', ['all', 'app', 'web'])->default('all');

            // 10. Sales channel + country/zone restriction (1 zone = 1 store)
            $table->enum('channel', ['quick', 'ecommerce', 'both'])->default('both');
            $table->json('country_ids')->nullable();
            $table->json('zone_ids')->nullable();

            $table->tinyInteger('status')->default(1)->comment('1-active, 0-deactive');
            $table->string('image')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('promo_codes');
    }
}
