<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Services\StorageCleanupService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;

/**
 * Storage usage and unused-image cleanup on the Media page.
 *
 * Admin panel only: the `storage_cleanup` prefix is not on the branch-user allow list,
 * so EnsureBranchScope refuses it for branch users, and each action here also requires
 * the super admin or the `manage_media` permission.
 *
 * Moving files is a two-step flow: `scan` returns the candidates under a scan id, and
 * `trash` only accepts paths from that scan, re-checking each one before it moves.
 */
class StorageCleanupApiController extends Controller
{
    private const SCAN_TTL_SECONDS = 3600;

    public function __construct(private StorageCleanupService $cleanup)
    {
    }

    public function info()
    {
        if ($denied = $this->denied()) {
            return $denied;
        }

        return CommonHelper::responseWithData($this->cleanup->usage());
    }

    public function scan()
    {
        if ($denied = $this->denied()) {
            return $denied;
        }
        @set_time_limit(600);

        try {
            $result = $this->cleanup->scan();
        } catch (\Throwable $e) {
            Log::warning('[StorageCleanup] scan stopped: ' . $e->getMessage());

            return CommonHelper::responseError('storage_scan_failed');
        }

        $scanId = Str::random(32);
        Cache::put('storage_cleanup_scan:' . $scanId, array_column($result['unused'], 'path'), self::SCAN_TTL_SECONDS);

        return CommonHelper::responseWithData($result + ['scan_id' => $scanId]);
    }

    public function trash(Request $request)
    {
        if ($denied = $this->denied()) {
            return $denied;
        }
        @set_time_limit(600);

        $scanned = Cache::get('storage_cleanup_scan:' . (string) $request->input('scan_id'));
        if (!is_array($scanned)) {
            return CommonHelper::responseError('storage_scan_expired');
        }

        // Only paths the admin was shown; anything else sent along is ignored.
        $wanted = $request->input('paths');
        $paths = is_array($wanted) ? array_values(array_intersect($scanned, $wanted)) : $scanned;
        if ($paths === []) {
            return CommonHelper::responseError('select_at_least_one_image');
        }

        try {
            $result = $this->cleanup->moveToTrash($paths, auth()->id());
        } catch (\Throwable $e) {
            Log::warning('[StorageCleanup] trash stopped: ' . $e->getMessage());

            return CommonHelper::responseError('storage_scan_failed');
        }

        Cache::forget('storage_cleanup_scan:' . $request->input('scan_id'));
        Log::info('[StorageCleanup] moved to trash', $result + ['admin_id' => auth()->id()]);

        return CommonHelper::responseSuccessWithData('unused_images_moved_to_trash', $result);
    }

    public function restore(Request $request)
    {
        if ($denied = $this->denied()) {
            return $denied;
        }

        try {
            $items = $request->input('items');
            $result = is_array($items)
                ? $this->cleanup->restoreItems($items)
                : $this->cleanup->restore((string) $request->input('batch'));
        } catch (\Throwable) {
            return CommonHelper::responseError('trash_batch_not_found');
        }

        Log::info('[StorageCleanup] restored', $result + ['batch' => $request->input('batch'), 'admin_id' => auth()->id()]);

        return CommonHelper::responseSuccessWithData('trash_restored_successfully', $result);
    }

    public function emptyTrash(Request $request)
    {
        if ($denied = $this->denied()) {
            return $denied;
        }

        try {
            $items = $request->input('items');
            if (is_array($items)) {
                $result = $this->cleanup->deleteItems($items);
            } else {
                $result = $this->cleanup->emptyTrash($request->filled('batch') ? (string) $request->input('batch') : null);
            }
        } catch (\Throwable) {
            return CommonHelper::responseError('trash_batch_not_found');
        }

        Log::info('[StorageCleanup] trash emptied', $result + ['admin_id' => auth()->id()]);

        return CommonHelper::responseSuccessWithData('trash_emptied_successfully', $result);
    }

    /**
     * The images in one trash batch, each with a short-lived signed preview link.
     * Trash sits outside the public folder, and an <img> cannot send the panel's
     * bearer token, so the signature is what lets the browser load it.
     */
    public function trashFiles(Request $request)
    {
        if ($denied = $this->denied()) {
            return $denied;
        }

        $batch = (string) $request->input('batch', '');
        try {
            $files = $batch === ''
                ? $this->cleanup->allTrashFiles()
                : array_map(fn ($f) => ['batch' => $batch] + $f, $this->cleanup->trashFiles($batch));
        } catch (\Throwable) {
            return CommonHelper::responseError('trash_batch_not_found');
        }

        $expires = now()->addMinutes(30);
        foreach ($files as &$file) {
            $file['url'] = URL::temporarySignedRoute('storage_cleanup.trash_preview', $expires, [
                'batch' => $file['batch'],
                'path'  => $file['path'],
            ]);
        }
        unset($file);

        return CommonHelper::responseWithData($files);
    }

    /** Serves one trashed image; reachable only through a valid signed link. */
    public function trashPreview(string $batch, string $path)
    {
        $abs = $this->cleanup->trashFilePath($batch, $path);
        abort_if($abs === null, 404);

        return response()->file($abs, [
            'Cache-Control'           => 'private, max-age=1800',
            'X-Content-Type-Options'  => 'nosniff',
            // An SVG opened from this link must not run script on the panel's origin.
            'Content-Security-Policy' => "default-src 'none'; style-src 'unsafe-inline'; sandbox",
        ]);
    }

    /** Super admin, or an admin-panel user holding `manage_media`. */
    private function denied()
    {
        $user = auth()->user();
        if (!$user || !empty($user->branch_id)) {
            return CommonHelper::responseError('permission_denied');
        }
        if ((int) $user->role_id === Role::$roleSuperAdmin) {
            return null;
        }

        return in_array('manage_media', (array) $user->all_permissions, true)
            ? null
            : CommonHelper::responseError('permission_denied');
    }
}
