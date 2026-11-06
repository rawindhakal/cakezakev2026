<?php

namespace App\Console\Commands;

use App\Services\BranchCatalogSync;
use Illuminate\Console\Command;

class SyncBranchCatalog extends Command
{
    protected $signature = 'catalog:sync-branches';
    protected $description = 'List every product in every branch (copies missing branch rows from each variant\'s first branch)';

    public function handle(BranchCatalogSync $sync): int
    {
        $this->info('Added ' . $sync->syncAll() . ' branch listings.');
        return self::SUCCESS;
    }
}
