<template>
    <div class="hb-image-upload">
        <label v-if="label" class="form-label small text-muted mb-1">{{ label }}</label>

        <input type="file" accept="image/*" class="file-input" style="display:none;"
            ref="fileEl" @change="onFile">

        <div class="file-input-div bg-gray-100"
            @click="triggerInput"
            @drop="onDrop"
            @dragover="onDragOver"
            @dragleave="onDragLeave">
            <template v-if="uploading">
                <b-spinner small></b-spinner>
                <label class="ms-2">{{ __('uploading') }}…</label>
            </template>
            <template v-else-if="modelValue">
                <img :src="previewSrc" class="hb-thumb" alt="">
                <label class="text-truncate small text-muted">{{ shortName }}</label>
            </template>
            <template v-else>
                <label><UploadCloud :size="28" /></label>
                <label class="small">{{ __('drop_files_here_or_click_to_upload') }}</label>
            </template>
        </div>

        <!-- The limit is stated before the upload, not only after one is refused. -->
        <small class="text-muted d-block mt-1">{{ uploadHint }}</small>

        <div class="text-end mt-1" v-if="modelValue && !uploading">
            <button type="button" class="btn btn-xs btn-link text-danger p-0"
                @click.stop="$emit('update:modelValue', '')">
                <X :size="14" /> {{ __('remove') }}
            </button>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import { resolveImageUrl } from '../homeBuilderHelpers.js';
import { UploadCloud, X } from 'lucide-vue-next';

export default {
    components: { UploadCloud, X },
    name: 'HbImageUpload',
    props: {
        modelValue: { type: String, default: '' },
        label: { type: String, default: '' },
        endpoint: { type: String, default: '/home_layouts/upload_image' },
        // Must match the server rule on home_layouts/upload_image (max:10240 KB).
        maxSizeMb: { type: Number, default: 10 },
    },
    // An editor that keeps its uploads elsewhere (Page Builder) provides this once
    // instead of threading an endpoint through every block/item component.
    inject: { hbUploadEndpoint: { default: null } },
    emits: ['update:modelValue'],
    data() {
        return { uploading: false };
    },
    computed: {
        previewSrc() {
            return resolveImageUrl(this.modelValue);
        },
        shortName() {
            if (!this.modelValue) return '';
            const parts = this.modelValue.split('/');
            return parts[parts.length - 1] || this.modelValue;
        },
        maxSizeText() {
            return `${this.maxSizeMb} MB`;
        },
        uploadHint() {
            return __('allowed_types_and_max_size', {
                types: 'JPG, PNG, GIF, WEBP, SVG',
                size: this.maxSizeText,
            });
        },
    },
    methods: {
        elRef() {
            const r = this.$refs.fileEl;
            return Array.isArray(r) ? r[0] : r;
        },
        triggerInput() {
            this.$nextTick(() => {
                const el = this.elRef();
                if (el && el.click) el.click();
            });
        },
        onDragOver(e) {
            e.preventDefault();
            e.currentTarget.classList.add('bg-green-300');
            e.currentTarget.classList.remove('bg-gray-100');
        },
        onDragLeave(e) {
            e.preventDefault();
            e.currentTarget.classList.add('bg-gray-100');
            e.currentTarget.classList.remove('bg-green-300');
        },
        onDrop(e) {
            e.preventDefault();
            e.currentTarget.classList.add('bg-gray-100');
            e.currentTarget.classList.remove('bg-green-300');
            const el = this.elRef();
            if (el && e.dataTransfer && e.dataTransfer.files.length) {
                el.files = e.dataTransfer.files;
                this.uploadFile(el.files[0]);
            }
        },
        onFile(e) {
            const file = e.target.files && e.target.files[0];
            if (!file) return;
            this.uploadFile(file);
            e.target.value = '';
        },
        uploadFile(file) {
            const valid = ['image/jpeg', 'image/png', 'image/jpg', 'image/gif', 'image/webp', 'image/svg+xml'];
            if (!valid.includes(file.type)) {
                this.showError(__('invalid_file_type'));
                return;
            }
            if (this.maxSizeMb > 0 && file.size > this.maxSizeMb * 1024 * 1024) {
                this.showError(__('file_size_exceeds_limit_x', { size: this.maxSizeText }));
                return;
            }
            this.uploading = true;
            const form = new FormData();
            form.append('image', file);
            axios.post(this.$apiUrl + (this.hbUploadEndpoint || this.endpoint), form)
                .then(res => {
                    // Store the storage-relative path — URLs are resolved at display time.
                    const path = res.data?.data?.path || res.data?.data?.url;
                    if (path) this.$emit('update:modelValue', path);
                })
                .catch(err => {
                    this.showError(err.response?.data?.message || __('something_went_wrong'));
                })
                .finally(() => { this.uploading = false; });
        },
    },
};
</script>

<style scoped>
.hb-thumb {
    max-width: 64px;
    max-height: 48px;
    border-radius: 4px;
    object-fit: cover;
    margin-right: 6px;
}
.btn-xs {
    font-size: .7rem;
    line-height: 1.2;
}
</style>
