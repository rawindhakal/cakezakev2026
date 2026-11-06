<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tracks a product bulk upload/update run so the admin panel can poll progress.
 * The job increments processed_rows as it works; with QUEUE_CONNECTION=sync the
 * whole run happens inside the request and the row is already terminal when the
 * response returns — the polling UI handles both identically.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_bulk_imports', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('admin_id')->default(0);
            $table->string('type', 10); // upload | update
            $table->unsignedBigInteger('category_id');
            $table->json('store_ids');
            $table->string('file_path');
            $table->string('status', 20)->default('pending'); // pending|processing|completed|failed
            $table->unsignedInteger('total_rows')->default(0);
            $table->unsignedInteger('processed_rows')->default(0);
            $table->unsignedInteger('success_count')->default(0);
            // Row-level runtime failures (validation passed but the write failed);
            // the job records them and keeps going rather than aborting the batch.
            $table->json('errors')->nullable();
            $table->text('message')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_bulk_imports');
    }
};
