<?php

use App\Http\Controllers\API\CountryApiController;
use App\Http\Controllers\API\FirebaseApiController;
use App\Http\Controllers\API\GeneralSettingsApiController;
use App\Http\Controllers\PluginWebhookController;
use App\Http\Controllers\Controller;
use App\Http\Controllers\PwaController;
use App\Http\Controllers\WebhookController;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/

// PWA manifest + icons, generated from settings (app name, theme colour, logo).
Route::get('manifest.webmanifest', [PwaController::class, 'manifest']);
Route::get('pwa/icon-{size}.png', fn ($size) => app(PwaController::class)->icon((int) $size))
    ->where('size', '[0-9]+');
Route::get('pwa/icon-maskable-{size}.png', fn ($size) => app(PwaController::class)->icon((int) $size, true))
    ->where('size', '[0-9]+');

Route::get('/', function () {
    return view('welcome');
});

Route::get('customer-privacy-policy', [CountryApiController::class, 'printPrivacyPolicy']);
Route::get('customer-terms-conditions', [CountryApiController::class, 'printTermsConditions']);

Route::middleware('auth')->group(function () {
    Route::get('customer-returns-and-exchanges-policy', [CountryApiController::class, 'printReturnsAndExchangesPolicy']);
    Route::get('customer-shipping-policy', [CountryApiController::class, 'printShippingPolicy']);
    Route::get('customer-cancellation-policy', [CountryApiController::class, 'printCancellationPolicy']);
    Route::get('delivery-boy-privacy-policy', [CountryApiController::class, 'printPrivacyPolicyDeliveryBoy']);
    Route::get('delivery-boy-terms-conditions', [CountryApiController::class, 'printTermsConditionsDeliveryBoy']);
    Route::get('about-us', [GeneralSettingsApiController::class, 'printAboutUs']);
    Route::get('contact-us', [GeneralSettingsApiController::class, 'printContactUs']);
    Route::get('logs', [\Rap2hpoutre\LaravelLogViewer\LogViewerController::class, 'index']);
    Route::get('/linkstorage', function () {
        Artisan::call('storage:link');
        return Artisan::output();
    });
    Route::get('/migration', function () {
        Artisan::call('migrate', ['--force' => true, '--no-interaction' => true]);
        // Artisan::call('db:seed', [
        //         '--class' => 'LanguageSeeder',
        //         '--force' => true,
        //         '--no-interaction' => true,
        //     ]);
        // Artisan::call('db:seed', [
        //         '--class' => 'NotificationTemplatesSeeder',
        //         '--force' => true,
        //         '--no-interaction' => true,
        //     ]);
        // Artisan::call('db:seed', [
        //         '--class' => 'SmsTemplatesSeeder',
        //         '--force' => true,
        //         '--no-interaction' => true,
        //     ]);
        // Artisan::call('db:seed', [
        //         '--class' => 'EmailTemplatesSeeder',
        //         '--force' => true,
        //         '--no-interaction' => true,
        //     ]);
        // Artisan::call('notifications:sync');

        // Artisan::call('db:seed', [
        //     '--class' => 'PermissionCategoriesSeeder',
        //     '--force' => true,
        //     '--no-interaction' => true,
        // ]);

        // Artisan::call('db:seed', [
        //     '--class' => 'PermissionSeeder',
        //     '--force' => true,
        //     '--no-interaction' => true,
        //     ]);

        return redirect('/dashboard');
    });
});

// Webhooks
Route::match(['get', 'post'], 'paypal/return', [WebhookController::class, 'paypalReturn'])->name('paypal.return');
Route::match(['get', 'post'], 'paypal/cancel', [WebhookController::class, 'paypalCancel'])->name('paypal.cancel');
Route::get('paypal/status', [WebhookController::class, 'paypalStatus'])->name('paypal.status');
Route::post('webhook/paypal', [WebhookController::class, 'paypalWebhook'])->name('paypal.webhook');

Route::post('midtrans/callback', [WebhookController::class, 'midtransWebhook']);

Route::post('webhook/stripe', [WebhookController::class, 'stripeWebhook']);

Route::post('cashfree/callback', [WebhookController::class, 'cashfreeWebhook'])->name('cashfree.callback');
Route::get('cashfree/redirect', [WebhookController::class, 'cashfreeRedirect'])->name('cashfree.redirect');

Route::post('paytabs/callback', [WebhookController::class, 'paytabsWebhook'])->name('paytabs.callback');
Route::match(['get', 'post'], 'paytabs/redirect', [WebhookController::class, 'paytabsRedirect'])->name('paytabs.redirect');


// Plugin webhooks — one door for every plugin (see PluginWebhookController). This MUST
// stay above the SPA catch-all below, whose lookahead excludes `plugin/` as well.
Route::match(['get', 'post'], 'plugin/{slug}/{action}', [PluginWebhookController::class, 'handle'])
    ->name('plugin.webhook');

//for localization in vuejs
Route::post('api/change_language', [Controller::class, 'doLanguageChange'])->name('change_language');

Route::get('firebase-messaging-sw.js', [FirebaseApiController::class, 'firebaseMessagingJsCode'])->name('assets.firebase-messaging-sw');

Route::get('delivery_boy/login', function () { return view('welcome'); });
Route::get('delivery_boy/register', function () { return view('welcome'); });

Route::get('{all}', function () {
    return view('welcome');
})->where('all', '^(?!customer|delivery_boy/|build/|storage/|plugin/).*$');
