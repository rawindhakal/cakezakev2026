<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Audit trail for the admin panel.
 *
 * Rows are written by Laravel's own events — Eloquent model events (created /
 * updated / deleted / restored) via the LogsActivity trait, and the framework's
 * auth events (Login / Logout / Failed / PasswordReset) via listeners. No
 * third-party package is involved.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('activity_logs', function (Blueprint $table) {
            $table->id();

            // 'model' for Eloquent changes, 'auth' for sign-in activity, etc.
            $table->string('log_name', 50)->default('model')->index();
            // created | updated | deleted | restored | login | logout | failed_login ...
            $table->string('event', 50)->index();
            $table->string('description')->nullable();

            // What was acted on (morph, kept nullable for auth rows).
            $table->string('subject_type')->nullable();
            $table->unsignedBigInteger('subject_id')->nullable();
            // Human label snapshotted at write time — the row may later be deleted
            // or renamed, and an audit trail must still read correctly.
            $table->string('subject_label')->nullable();

            // Who did it. Admin (auth:api) or customer (auth:api-customers);
            // null when it happened in console/seeders.
            $table->string('causer_type')->nullable();
            $table->unsignedBigInteger('causer_id')->nullable();
            $table->string('causer_name')->nullable();
            $table->string('causer_role', 100)->nullable();

            // {"old": {...}, "attributes": {...}} — only the changed keys.
            $table->json('properties')->nullable();

            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->string('method', 10)->nullable();
            $table->text('url')->nullable();

            $table->timestamps();

            $table->index(['subject_type', 'subject_id']);
            $table->index(['causer_type', 'causer_id']);
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('activity_logs');
    }
};
