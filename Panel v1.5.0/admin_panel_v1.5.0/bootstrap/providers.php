<?php

return [
    App\Providers\AppServiceProvider::class,
    App\Providers\AuthServiceProvider::class,
    // Last: plugin providers are registered from here, after core is bound.
    App\Providers\PluginServiceProvider::class,
];
