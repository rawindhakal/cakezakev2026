@php
    use Illuminate\Support\Facades\Crypt;

    $logo = '';
    $app_name = '';
    $admin_theme_color = '';
    $support_email = '';
    $support_number = '';
    $google_place_api_key = '';
    $google_map_api_key = '';
    $googleMapApiKey = '';
    $currency = '';
    $logo_full_path = '';
    $favicon_full_path = asset('images/favicon.png');
    // Empty unless Web Settings has one: the panel's fallback chain just skips it.
    $broken_image_full_path = '';
    $panel_login_background_img_full_path = asset('images/panel_login_background_img.png');
    $delivery_boy_bonus_settings = 0;
    $isDemoMode = 0;

    $clarity_config = ['project_id' => '', 'enabled' => false];
    $userPermissions = [];
    $userRole = '';

    $website_url = '';
    $copyright_details = '';

    // Firebase keys (only what FCM web push needs)
    $firebase_apiKey = '';
    $projectId = '';
    $messagingSenderId = '';
    $appId = '';
    $firebaseVapidKey = '';

    if (isInstalled()) {
        try {
            $app_name = \App\Models\Setting::get_value('app_name');
            if ($app_name == '' || $app_name == null) {
                $app_name = 'CakeZake';
            }
            $support_email = \App\Models\Setting::get_value('support_email');
            if ($support_email == '' || $support_email == null) {
                $support_email = '';
            }
            $support_number = \App\Models\Setting::get_value('support_number');
            if ($support_number == '' || $support_number == null) {
                $support_number = '';
            }

            $logo = \App\Models\Setting::get_value('logo') ?? '';
            if ($logo !== '') {
                $logo_full_path = url('/') . '/storage/' . $logo;
            } else {
                $logo_full_path = asset('images/favicon.png');
            }

            $broken_image = \App\Models\Setting::get_value('broken_image') ?? '';
            $broken_image_full_path = $broken_image !== '' ? url('/') . '/storage/' . $broken_image : '';

            $admin_favicon = \App\Models\Setting::get_value('admin_favicon') ?? '';
            if ($admin_favicon !== '') {
                $favicon_full_path = url('/') . '/storage/' . $admin_favicon;
            } else {
                $favicon_full_path = asset('images/favicon.png');
            }

            $panel_login_background_img = \App\Models\Setting::get_value('panel_login_background_img') ?? '';
            $panel_login_background_img_full_path = '';
            if ($panel_login_background_img !== '') {
                $panel_login_background_img_full_path = url('/') . '/storage/' . $panel_login_background_img;
            } else {
                $panel_login_background_img_full_path = asset('images/panel_login_background_img.png');
            }

            $google_place_api_key = \App\Models\Setting::get_value('google_place_api_key') ?? '';
            $google_map_api_key = \App\Models\Setting::get_value('google_map_api_key') ?? '';
            // The Firebase Settings form saves the web API key as `firebase_apiKey`.
            $firebase_apiKey = \App\Models\Setting::get_value('firebase_apiKey') ?? '';
            $googleMapApiKey = \App\Models\Setting::get_value('googleMapApiKey') ?? '';
            $currency = \App\Models\Setting::get_value('currency') ?? "$";

            $clarity_panel_id = trim((string) (\App\Models\Setting::get_value('clarity_project_id_panel') ?? ''));
            $clarity_panel_status = (string) (\App\Models\Setting::get_value('clarity_status_panel') ?? '0');
            $clarity_config = [
                'project_id' => $clarity_panel_id,
                'enabled' => $clarity_panel_id !== '' && in_array($clarity_panel_status, ['1', 'true', 'on'], true),
            ];

            $website_url = \App\Models\Setting::get_value('website_url') ?? '';
            $copyrightRaw = \App\Models\Setting::get_value('copyright_details') ?? '';

            $copyrightArr = json_decode($copyrightRaw, true);

            $currentLang = app()->getLocale();

            $copyright_details = is_array($copyrightArr)
                ? $copyrightArr[$currentLang] ?? ($copyrightArr['en'] ?? '')
                : $copyrightRaw;

            $delivery_boy_bonus_settings = \App\Models\Setting::get_value('delivery_boy_bonus_settings') ?? 0;

            // Firebase keys (only what FCM web push needs)
            $projectId = \App\Models\Setting::get_value('projectId') ?? '';
            $messagingSenderId = \App\Models\Setting::get_value('messagingSenderId') ?? '';
            $appId = \App\Models\Setting::get_value('appId') ?? '';
            $firebaseVapidKey = \App\Models\Setting::get_value('firebase_vapid_key') ?? '';
            $isDemoMode = isDemoMode() ? 1 : 0;

            $admin_theme_color = \App\Models\Setting::get_value('admin_theme_color') ?? '';
            if (!preg_match('/^#[0-9a-fA-F]{6}$/', $admin_theme_color)) {
                $admin_theme_color = '#FE3C5E';
            }

            if (auth()->check()) {
                $authUser = auth()->user();
                $userPermissions = $authUser->allPermissions ?? [];
                $userRole = $authUser->role->name ?? '';
            }
        } catch (\Throwable $e) {
            // above already has a safe default.
            \Illuminate\Support\Facades\Log::warning('welcome.blade: could not load settings - ' . $e->getMessage());
        }
    }
@endphp

<!DOCTYPE html>
<html class="{{ app()->isLocale('ar') ? 'rtl' : '' }}">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}" />
    {{-- Admin panel must never be indexed by search engines. --}}
    <meta name="robots" content="noindex, nofollow">
    <meta name="googlebot" content="noindex, nofollow">
    @php
        $appNameArr = json_decode($app_name ?? '', true);
        $currentLang = app()->getLocale();
        $appTitle = is_array($appNameArr)
            ? $appNameArr[$currentLang] ?? ($appNameArr['en'] ?? 'CakeZake')
            : ($app_name ?:
            'CakeZake');
    @endphp

    <title>{{ $appTitle }}</title>

    <link rel="shortcut icon" href="{{ $favicon_full_path }}">

    <!-- Fonts: Instrument Sans — self-hosted, bundled locally via vite (@fontsource/instrument-sans) -->

    <link rel="stylesheet" href="{{ asset('assets/css/bootstrap.css') }}">
    @if (app()->isLocale('ar'))
        <link rel="stylesheet" href="{{ asset('assets/css/bootstrap.rtl.css') }}">
    @endif

    <link rel="stylesheet" href="{{ asset('assets/vendors/perfect-scrollbar/perfect-scrollbar.css') }}">
    {{-- PWA: manifest is generated from settings, so a rebranded install installs
         under its own name and logo. --}}
    @if(isInstalled())
        <link rel="manifest" href="{{ url('manifest.webmanifest') }}">
    @endif
    
    <meta name="theme-color" content="{{ $admin_theme_color ?: '#435ebe' }}">
    <meta name="mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="default">
    <meta name="apple-mobile-web-app-title" content="{{ $appTitle }}">
    {{-- iOS ignores manifest icons; it reads this one. --}}
    <link rel="apple-touch-icon" href="{{ $favicon_full_path }}">

    <link rel="stylesheet" href="{{ asset('assets/css/app.css') }}">
    @vite(['resources/sass/app.scss'])
    <link rel="stylesheet" href="{{ asset('assets/css/style.css') }}">
    <link rel="stylesheet" href="{{ asset('assets/css/pages/form-element-select.css') }}">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css" rel="stylesheet"
        integrity="sha512-SnH5WK+bZxgPHs44uWIX+LLJAJ9/2PkPKZ5QiAj6Ta86w+fsb2TkcmfRyVX3pBnMFcV7oQPJkl9QevSCWr3W6A=="
        crossorigin="anonymous" referrerpolicy="no-referrer">
    <!-- Auth -->
    <link rel="stylesheet" href="{{ asset('assets/css/pages/auth.css') }}">
    <link rel="stylesheet" href="{{ asset('assets/css/pages/error.css') }}">
    <!-- Styles -->
    <link rel="stylesheet"
        href="{{ asset('assets/css/custom/common.css') }}?v={{ @filemtime(public_path('assets/css/custom/common.css')) }}">
    <link rel="stylesheet"
        href="{{ asset('assets/dark-mode/app-dark.css') }}?v={{ @filemtime(public_path('assets/dark-mode/app-dark.css')) }}">

    {{-- Bootstrap 5 ships its own .toast (white card) which overrides toastr's colored
         toasts, making them white-on-white. Force toastr's palette back. --}}
    <style>
        #toast-container>div {
            opacity: 1 !important;
            box-shadow: 0 0 12px rgba(0, 0, 0, .3) !important;
        }

        #toast-container>.toast-info {
            background-color: #2f96b4 !important;
            color: #fff !important;
        }

        #toast-container>.toast-success {
            background-color: #51a351 !important;
            color: #fff !important;
        }

        #toast-container>.toast-error {
            background-color: #bd362f !important;
            color: #fff !important;
        }

        #toast-container>.toast-warning {
            background-color: #f89406 !important;
            color: #fff !important;
        }

        #toast-container>div .toast-title,
        #toast-container>div .toast-message {
            color: #fff !important;
        }
    </style>

    @if (isDemoMode())
        <!-- Google tag (gtag.js) -->
        <script async src="https://www.googletagmanager.com/gtag/js?id=G-CZZ7MV8RBB"></script>
        <script>
            window.dataLayer = window.dataLayer || [];

            function gtag() {
                dataLayer.push(arguments);
            }
            gtag('js', new Date());

            gtag('config', 'G-CZZ7MV8RBB');
        </script>
    @endif

</head>

<body>
    {{-- Sync body.rtl with html.rtl on first paint so sidebar/layout don't flicker (right→left→right) when switching to RTL --}}
    <script>
        document.body.classList.toggle('rtl', document.documentElement.classList.contains('rtl'));
    </script>
    <div id="app">
        <router-view></router-view>
    </div>

    <script src="{{ asset('assets/vendors/perfect-scrollbar/perfect-scrollbar.min.js') }}"></script>
    <script src="{{ asset('assets/js/bootstrap.bundle.min.js') }}"></script>
    <script src="{{ asset('assets/js/mazer.js') }}"></script>
    <script src="{{ asset('assets/js/extensions/form-element-select.js') }}"></script>

    <script>
        window.baseUrl = window.location.origin;
        window.appName = "{{ $app_name }}";
        window.adminThemeColor = "{{ $admin_theme_color }}";

        // Realtime (chat) config injected at runtime — change it in Settings, no rebuild needed.
        window.broadcastConfig = {
            driver: @json(\App\Helpers\CommonHelper::getBroadcastDriver()),
            config: @json(\App\Helpers\CommonHelper::getBroadcastClientConfig()),
        };

        window.supportEmail = "{{ $support_email }}";
        window.supportNumber = "{{ $support_number }}";
        window.MapApiKey = "{{ $google_place_api_key }}";
        window.GoogleMapApiKey = "{{ $googleMapApiKey }}";
        window.appLogo = "{{ $logo }}";
        window.appFavicon = "{{ $favicon_full_path ?? '' }}";
        window.appBrokenImage = "{{ $broken_image_full_path ?? '' }}";
        window.panelLoginBackgroundImg = "{{ $panel_login_background_img_full_path ?? '' }}";
        window.currency = "{{ $currency }}";
        window.clarityConfig = {!! json_encode($clarity_config) !!};
        window.isInstalled = "{{ isInstalled() }}";

        window.websiteUrl = "{{ $website_url }}";
        window.copyrightDetails =
            @json($copyright_details);

        window.deliveryBoyBonusSettings = "{{ $delivery_boy_bonus_settings }}";
        window.isDemo = "{{ $isDemoMode }}";
        window.currentVersion = "{{ currentVersion() }}";

        // Placeholder so the login form can read it before getToken() resolves (fcm.js sets it).
        window.panelFcmToken = '';
        {{-- FCM config for the bundled fcm.js. Only the fields web push needs. --}}
        @if ($firebase_apiKey != '' && $projectId != '' && $messagingSenderId != '' && $appId != '')
            window.firebaseConfig = {
                apiKey: "{{ $firebase_apiKey }}",
                projectId: "{{ $projectId }}",
                messagingSenderId: "{{ $messagingSenderId }}",
                appId: "{{ $appId }}",
            };
            window.firebaseVapidKey = "{{ $firebaseVapidKey }}";
        @endif

        window.UserPermissions = {!! json_encode($userPermissions) !!};
        window.Role = {!! json_encode($userRole) !!};
    </script>
    @vite(['resources/js/app.js'])

    @php
        $lang = app()->getLocale();
        session(['app_locale' => $lang]);
        $langPath = resource_path('lang/' . $lang . '.json');
        if (!is_file($langPath)) {
            $defaultLang = \App\Models\Language::where('system_type', 4)
                ->where('is_default', 1)->first();
            $defaultPath = $defaultLang
                ? \App\Services\LanguageFileService::pathForLanguage($defaultLang)
                : null;
            $langPath = ($defaultPath && is_file($defaultPath))
                ? $defaultPath
                : resource_path('lang/en.json');
        }
        $file = is_file($langPath) ? file_get_contents($langPath) : '{}';
    @endphp

    <script>
        window.appLocale = "{{ $lang }}";
        let lang = JSON.stringify(<?php echo $file; ?>);
        localStorage.setItem('language', lang);
    </script>

</body>

</html>
