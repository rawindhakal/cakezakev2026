<?php

function isInstalled()
{
    if (!file_exists(storage_path('installed'))) {
        return false;
    }
    return true;
}

function isDemoMode()
{
    return (bool) config('app.demo_mode');
}

function shouldDemoMask()
{
    if (!isDemoMode()) {
        return false;
    }
    $userId = (int) (auth('api')->id() ?? auth()->id() ?? 0);
    return $userId !== 1;
}


function currentVersion()
{
    $versionFilePath = base_path('version.txt');
    $version = file_get_contents($versionFilePath);
    $version = trim($version);
    if ($version == "") {
        $version = "1.5.0";
    }
    return $version;
}
