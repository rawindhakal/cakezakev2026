<?php

namespace App\Jobs;

use App\Models\ProductBulkImport;
use App\Services\ProductBulkSchema;
use App\Services\ProductBulkService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * Runs a validated product bulk upload/update and reports progress on its
 * ProductBulkImport row (polled by the admin panel's progress bar).
 *
 * The file was fully validated before dispatch, so failures here are runtime ones
 * (e.g. an SKU taken between validation and processing). Each product/row commits in
 * its own transaction: one bad group is recorded and skipped instead of rolling back
 * two thousand finished rows — with a queue, "all-or-nothing across the whole file"
 * would also mean holding one giant transaction open for the entire run.
 */
class ProcessProductBulkJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /** Long files take a while; one attempt, generous timeout. */
    public $timeout = 3600;
    public $tries = 1;

    private int $importId;

    public function __construct(int $importId)
    {
        $this->importId = $importId;
    }

    public function handle(): void
    {
        $import = ProductBulkImport::find($this->importId);
        if (!$import || $import->status !== 'pending') {
            return;
        }

        $import->update(['status' => 'processing']);

        try {
            $service = app(ProductBulkService::class);
            $schema = ProductBulkSchema::make(
                (int) $import->category_id,
                array_map('intval', $import->branch_ids ?? []),
                $import->type === 'update',
                $import->sales_channel
            );

            $both = $service->readAll(
                Storage::disk('local')->path($import->file_path),
                $schema->columns(),
                $schema->addonColumns()
            );
            $read = $both['products'];
            if (!empty($read['errors'])) {
                $import->update(['status' => 'failed', 'message' => $read['errors'][0]]);
                return;
            }
            if (!empty($both['addons']['errors'])) {
                $import->update(['status' => 'failed', 'message' => $both['addons']['errors'][0]]);
                return;
            }

            $errors = [];
            $success = 0;
            $processed = 0;

            $addonDishes = $service->groupAddonRows($both['addons']['rows'], $schema)['dishes'];
            /** @var array<string,int> handle => product id, for linking a dish's menu in phase 2 */
            $productIdByHandle = [];
            /** @var array<string,int> sku => variant id, for an option linking a variant born in this file */
            $variantIdBySku = [];

            if ($import->type === 'update') {
                $import->update(['total_rows' => count($read['rows']) + count($addonDishes)]);
                foreach ($read['rows'] as $row) {
                    try {
                        DB::transaction(fn () => $service->updateRow($row, $schema));
                        $success++;
                    } catch (\Throwable $e) {
                        $errors[] = ['row' => $row['__row'] ?? 0, 'error' => $e->getMessage()];
                    }
                    $processed++;
                    $import->update(['processed_rows' => $processed]);
                }
            } else {
                $groups = $service->groupByHandle($read['rows']);
                $import->update(['total_rows' => count($groups) + count($addonDishes)]);
                foreach ($groups as $handle => $group) {
                    try {
                        $written = null;
                        DB::transaction(function () use ($service, $handle, $group, $schema, &$written) {
                            $written = $service->createProduct((string) $handle, $group, $schema);
                            if ($written['error'] !== null) {
                                throw new \RuntimeException($written['error']);
                            }
                        });
                        // Collected only after the commit: a rolled-back product must
                        // not hand phase 2 an id that no longer exists.
                        if ($written && $written['product_id']) {
                            $productIdByHandle[mb_strtolower((string) $handle)] = (int) $written['product_id'];
                            $variantIdBySku += $written['variants'];
                        }
                        $success++;
                    } catch (\Throwable $e) {
                        $errors[] = ['row' => $group[0]['__row'] ?? 0, 'error' => $handle . ': ' . $e->getMessage()];
                    }
                    $processed++;
                    $import->update(['processed_rows' => $processed]);
                }
            }

            /* Phase 2 — each dish's addon setup, replacing whatever it had. It runs
               after the products so a create-mode file can describe a dish and its
               menu at once. */
            foreach ($addonDishes as $dish) {
                $productId = (int) ($dish['product_id'] ?? 0);
                $row = (int) ($dish['first_row'] ?? 0);

                if ($productId <= 0) {
                    $handle = mb_strtolower((string) $dish['handle']);
                    $productId = $productIdByHandle[$handle] ?? 0;
                    if ($productId <= 0) {
                        // Its product failed earlier. Never fall back to a lookup by
                        // name — that would hang a menu off the wrong dish.
                        $errors[] = ['sheet' => 'Addons', 'row' => $row, 'error' => __('addon_dish_was_not_created') . ': ' . $dish['handle']];
                        $processed++;
                        $import->update(['processed_rows' => $processed]);
                        continue;
                    }
                }

                try {
                    DB::transaction(function () use ($service, $productId, $dish, $schema, $variantIdBySku) {
                        $err = $service->saveAddonsForDish($productId, $dish, $schema, $variantIdBySku);
                        if ($err !== null) {
                            throw new \RuntimeException($err);
                        }
                    });
                    $success++;
                } catch (\Throwable $e) {
                    $errors[] = ['sheet' => 'Addons', 'row' => $row, 'error' => $e->getMessage()];
                }
                $processed++;
                $import->update(['processed_rows' => $processed]);
            }

            $import->update([
                'status' => 'completed',
                'success_count' => $success,
                'errors' => $errors ? array_slice($errors, 0, 200) : null,
            ]);
        } catch (\Throwable $e) {
            Log::error('Product bulk job ' . $this->importId . ' failed: ' . $e->getMessage());
            $import->update(['status' => 'failed', 'message' => $e->getMessage()]);
        } finally {
            Storage::disk('local')->delete($import->file_path);
        }
    }

    public function failed(\Throwable $e): void
    {
        ProductBulkImport::where('id', $this->importId)
            ->update(['status' => 'failed', 'message' => $e->getMessage()]);
    }
}
