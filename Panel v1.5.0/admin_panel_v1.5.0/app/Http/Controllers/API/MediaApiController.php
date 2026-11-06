<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Media;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
class MediaApiController extends Controller
{

    private const ALLOWED_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'mp4'];

    private const ALLOWED_MIMES = [
        'image/jpeg', 'image/pjpeg', 'image/png', 'image/gif', 'image/webp',
        'image/svg+xml', 'image/svg', 'video/mp4',
    ];

    private const VIDEO_MAX_MB = 5;


    private function safeFileName(string $original): string
    {
        $ext = strtolower(pathinfo($original, PATHINFO_EXTENSION));
        $base = strtolower(pathinfo($original, PATHINFO_FILENAME));
        $base = trim(preg_replace('/[^a-z0-9._-]+/', '-', $base), '-.');
        $base = $base !== '' ? $base : 'file';

        return $base . ($ext !== '' ? '.' . $ext : '');
    }

    /** Keep the original (sanitized) name; on collision append _1, _2, ... so nothing is overwritten. */
    private function uniqueFileName(string $directory, string $fileName): string
    {
        $ext = pathinfo($fileName, PATHINFO_EXTENSION);
        $base = pathinfo($fileName, PATHINFO_FILENAME);
        $suffix = $ext !== '' ? '.' . $ext : '';

        $candidate = $fileName;
        $counter = 1;
        while (Storage::disk('public')->exists(rtrim($directory, '/') . '/' . $candidate)) {
            $candidate = $base . '_' . $counter . $suffix;
            $counter++;
        }

        return $candidate;
    }

    public function index()
    {
        $media = Media::select("media.*", "branches.name as branch_name")
            ->leftJoin('branches', 'media.branch_id', '=', 'branches.id')
            ->orderBy('id', 'DESC')->get();
        return CommonHelper::responseWithData($media);
    }
    public function save(Request $request)
    {
        if ($request->hasFile('files')) {
            $files = $request->file('files');
            foreach ($files as $file) {
                $ext = strtolower($file->getClientOriginalExtension());
                $mime = strtolower((string) $file->getClientMimeType());
                if (!in_array($ext, self::ALLOWED_EXTENSIONS, true) || !in_array($mime, self::ALLOWED_MIMES, true)) {
                    return CommonHelper::responseError('only_image_svg_and_mp4_files_are_allowed');
                }
                if (str_starts_with($mime, 'video/') && $file->getSize() > self::VIDEO_MAX_MB * 1024 * 1024) {
                    // Stated in MB rather than Laravel's kilobyte wording.
                    return CommonHelper::responseError(
                        str_replace('{size}', self::VIDEO_MAX_MB . ' MB', __('file_size_exceeds_limit_x'))
                    );
                }
            }
            foreach ($files as $key => $file) {
                $fileName = $this->safeFileName($file->getClientOriginalName());
                $extension = $file->getClientOriginalExtension();
                $type = $file->getClientMimeType();
                $size = $file->getSize();
                $precision = 2;
                $base = log($size, 1024);
                $suffixes = array('', 'KB', 'MB', 'GB', 'TB');
                $covertedSize = round(pow(1024, $base - floor($base)), $precision) . ' ' . $suffixes[floor($base)];
                $sub_directory = 'products/media/';
                $uploaedFileName = $this->uniqueFileName($sub_directory, $fileName);
                Storage::disk('public')->putFileAs($sub_directory, $file, $uploaedFileName);
                $media = new Media();
                $media->name = $uploaedFileName;
                $media->extension = $extension;
                $media->type = $type;
                $media->sub_directory = $sub_directory;
                $media->size = $covertedSize;
                $media->branch_id = 0;
                $media->save();
            }
            return CommonHelper::responseSuccess('media_image_uploaded_successfully');
        }
    }
    public function delete(Request $request)
    {
        if (isset($request->id)) {
            $media = Media::find($request->id);
            if ($media) {
                @Storage::disk('public')->delete($media->sub_directory . $media->name);
                $media->delete();
                return CommonHelper::responseSuccess('media_file_deleted_successfully');
            } else {
                return CommonHelper::responseSuccess('media_file_already_deleted');
            }
        }
    }

    public function multipleDelete(Request $request)
    {
        if (isset($request->ids)) {
            $ids = explode(',', $request->ids);

            $mediaFiles = Media::whereIn('id', $ids)->get();
            foreach ($mediaFiles as $media) {
                @Storage::disk('public')->delete($media->sub_directory . $media->name);
                $media->delete();
            }

            return CommonHelper::responseSuccess('selected_all_media_files_deleted_successfully');
        }
    }

    public function editorUpload(Request $request)
    {
        if ($request->hasFile('file')) {
            $file = $request->file('file');
            $fileName = $this->safeFileName($file->getClientOriginalName());
            $sub_directory = 'products/media/';
            $uploaedFileName = $this->uniqueFileName($sub_directory, $fileName);
            Storage::disk('public')->putFileAs($sub_directory, $file, $uploaedFileName);

            return response()->json([
                'location' => asset('storage/' . $sub_directory . $uploaedFileName)
            ]);
        }
        return response()->json(['error' => 'No file uploaded'], 400);
    }
}
