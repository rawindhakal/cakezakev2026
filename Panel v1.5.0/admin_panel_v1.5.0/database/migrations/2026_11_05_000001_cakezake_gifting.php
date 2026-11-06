<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** CakeZake gifting platform: occasions, relationships, delivery types, personalisation and recipient/order gift data. */
return new class extends Migration {
    public function up(): void
    {
        foreach (['occasions', 'relationships', 'gift_delivery_types'] as $t) {
            Schema::create($t, function (Blueprint $table) use ($t) {
                $table->id();
                $table->string('name');
                $table->string('slug')->unique();
                $table->string('image')->nullable();
                if ($t === 'occasions') {
                    $table->string('occasion_date')->nullable()->comment('Free-text, e.g. 11th May');
                }
                if ($t === 'gift_delivery_types') {
                    $table->unsignedInteger('lead_minutes')->nullable()->comment('Minimum notice; express = minutes to deliver');
                    $table->decimal('extra_charge', 10, 2)->default(0);
                    $table->string('time_window')->nullable()->comment('e.g. 23:00-23:59 for midnight');
                    $table->text('description')->nullable();
                }
                $table->unsignedInteger('sort_order')->default(0);
                $table->boolean('status')->default(true);
                $table->timestamps();
            });
        }

        Schema::table('products', function (Blueprint $table) {
            $table->json('occasions')->nullable()->after('tags');
            $table->json('relationships')->nullable()->after('occasions');
            $table->json('delivery_types')->nullable()->after('relationships');
            $table->boolean('is_personalizable')->default(false)->after('delivery_types')
                ->comment('Customer may add a name/photo/message on the item');
            $table->boolean('is_featured')->default(false)->after('is_personalizable');
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->string('recipient_name')->nullable();
            $table->string('recipient_phone')->nullable();
            $table->string('recipient_relationship')->nullable();
            $table->string('occasion')->nullable();
            $table->date('delivery_date')->nullable();
            $table->string('delivery_slot')->nullable();
            $table->string('gift_delivery_type')->nullable();
            $table->text('gift_message')->nullable();
            $table->string('sender_name')->nullable();
            $table->boolean('is_surprise')->default(false)->comment('Hide sender / price on the delivery');
            $table->text('personalization')->nullable()->comment('Name/text to print on the item');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['recipient_name', 'recipient_phone', 'recipient_relationship', 'occasion', 'delivery_date',
                'delivery_slot', 'gift_delivery_type', 'gift_message', 'sender_name', 'is_surprise', 'personalization']);
        });
        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn(['occasions', 'relationships', 'delivery_types', 'is_personalizable', 'is_featured']);
        });
        Schema::dropIfExists('gift_delivery_types');
        Schema::dropIfExists('relationships');
        Schema::dropIfExists('occasions');
    }
};
