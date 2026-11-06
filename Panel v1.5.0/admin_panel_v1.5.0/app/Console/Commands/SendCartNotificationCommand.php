<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Helpers\CommonHelper;
class SendCartNotificationCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'cart:notification';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Send Cart Notification';


    /**
     * Execute the console command.
     *
     * @return int
     */
    public function handle()
    {
       CommonHelper::SendCartNotification();

    }
}
