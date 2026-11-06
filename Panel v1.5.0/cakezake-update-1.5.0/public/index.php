<?php

use Illuminate\Http\Request;

ini_set('max_execution_time', 180000);
ini_set('upload_max_filesize', 180000);
ini_set('post_max_size', 180000);

define('LARAVEL_START', microtime(true));

if (file_exists($maintenance = __DIR__.'/../storage/framework/maintenance.php')) {
    require $maintenance;
}

if (!file_exists(__DIR__.'/../vendor/autoload.php')) {
    http_response_code(503);
    header('Content-Type: text/html; charset=utf-8');
    $missing = ['vendor'];
    if (!file_exists(__DIR__.'/../.env')) {
        $missing[] = 'env';
    }
    if (!file_exists(__DIR__.'/build/manifest.json') && !file_exists(__DIR__.'/build/.vite/manifest.json')) {
        $missing[] = 'build';
    }
    require __DIR__.'/../resources/views/setup-required.php';
    exit;
}

require __DIR__.'/../vendor/autoload.php';

(require_once __DIR__.'/../bootstrap/app.php')
    ->handleRequest(Request::capture());
