<?php

namespace App\Console\Commands;

use App\Models\HomeLayout;
use Carbon\Carbon;
use Illuminate\Console\Command;

/**
 * Publishes any home layout whose scheduled_publish_at (UTC) has arrived. The
 * draft trees are promoted to published and the schedule is cleared.
 */
class HomeLayoutPublishScheduledCommand extends Command
{
    protected $signature = 'home-layout:publish-scheduled';

    protected $description = 'Publish home layouts whose scheduled publish time has passed';

    public function handle(): int
    {
        $now = Carbon::now('UTC');

        $due = HomeLayout::whereNotNull('scheduled_publish_at')
            ->where('scheduled_publish_at', '<=', $now)
            ->get();

        foreach ($due as $layout) {
            $layout->publishDraft();
            $this->info("Published home layout #{$layout->id} ({$layout->name})");
        }

        return self::SUCCESS;
    }
}
