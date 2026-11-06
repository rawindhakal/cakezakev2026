<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Admin master switch: per (event, audience, channel) — is this allowed to send?
        if (!Schema::hasTable('notification_admin_settings')) {
            Schema::create('notification_admin_settings', function (Blueprint $t) {
                $t->id();
                $t->string('event_key', 100);
                $t->string('audience', 20);
                $t->string('channel', 10); // mail | sms | push
                $t->boolean('is_enabled')->default(1);
                $t->timestamps();
                $t->unique(['event_key', 'audience', 'channel'], 'nas_event_aud_chan_unique');
            });
        }

        // Row present = explicit choice; row absent = default ON (when admin-enabled).
        if (!Schema::hasTable('notification_preferences')) {
            Schema::create('notification_preferences', function (Blueprint $t) {
                $t->id();
                $t->unsignedTinyInteger('user_type')->comment('0 = customer, 3 = delivery boy');
                $t->unsignedBigInteger('user_id');
                $t->string('event_key', 100);
                $t->string('channel', 10);
                $t->boolean('is_enabled')->default(1);
                $t->timestamps();
                $t->unique(['user_type', 'user_id', 'event_key', 'channel'], 'np_user_event_chan_unique');
                $t->index(['user_type', 'user_id']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_preferences');
        Schema::dropIfExists('notification_admin_settings');
    }
};
