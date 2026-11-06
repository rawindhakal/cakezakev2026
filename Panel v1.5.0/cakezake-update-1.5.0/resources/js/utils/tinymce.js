// Single source of truth for TinyMCE (self-hosted GPL v7). Import this everywhere
// instead of hand-writing an init config per component.
//
//   import { TINYMCE_SCRIPT_SRC, tinymceInit } from '@/utils/tinymce';
//   <editor :init="editorInit" tinymce-script-src="/assets/js/tinymce/tinymce.min.js?v=7922" license-key="gpl" />
//   data() { return { editorInit: tinymceInit() }; }
//
// Pass overrides for one-offs, e.g. a `setup` hook:
//   tinymceInit({ height: 300, setup: (ed) => ed.on('change', ...) })

export const TINYMCE_SCRIPT_SRC = '/assets/js/tinymce/tinymce.min.js?v=7922';

// Server-side image upload: file is stored on disk, its URL is written into the HTML.
// Posts to /api/media/editor_upload (MediaApiController@editorUpload).
function imageUploadOptions() {
    const apiUrl = (window.baseUrl || '') + '/api';
    const post = (fd, cfg) => window.axios.post(apiUrl + '/media/editor_upload', fd, cfg);

    return {
        automatic_uploads: true,
        file_picker_types: 'image',
        // Enables the "Upload" tab + drag/drop inside the Insert/Edit Image dialog.
        images_upload_handler: (blobInfo, progress) => new Promise((resolve, reject) => {
            const fd = new FormData();
            fd.append('file', blobInfo.blob(), blobInfo.filename());
            post(fd, {
                onUploadProgress: (e) => {
                    if (progress && e.lengthComputable) progress((e.loaded / e.total) * 100);
                },
            }).then((res) => {
                if (res.data && res.data.location) resolve(res.data.location);
                else reject('Invalid upload response');
            }).catch((err) => {
                reject((err.response && err.response.data && err.response.data.error) || err.message || 'Upload failed');
            });
        }),
        // File-picker button (e.g. the little browse icon next to the URL field).
        file_picker_callback: (callback, value, meta) => {
            if (meta.filetype !== 'image') return;
            const input = document.createElement('input');
            input.type = 'file';
            input.accept = 'image/*';
            input.onchange = () => {
                const file = input.files[0];
                if (!file) return;
                const fd = new FormData();
                fd.append('file', file);
                post(fd).then((res) => callback(res.data.location, { title: file.name }))
                    .catch((e) => console.error('Image upload failed:', e));
            };
            input.click();
        },
    };
}

// Base config shared by every editor. Merge overrides last so callers can tweak.
export function tinymceInit(overrides = {}) {
    return {
        height: 400,
        menubar: false,
        plugins: 'autolink lists link image table code charmap searchreplace visualblocks media wordcount',
        toolbar: 'undo redo | bold italic underline strikethrough | bullist numlist | link image media table | charmap | code | removeformat',
        branding: false,
        highlight_on_focus: false,
        license_key: 'gpl',
        ...imageUploadOptions(),
        ...overrides,
    };
}
