<template>
    <div class="form-group">
        <template v-if="label">
            <label>{{ label }}</label><i v-if="required" class="text-danger">*</i>
        </template>
        <span v-if="displayError" class="error">{{ displayError }}</span>

        <input type="file" class="file-input" ref="fileEl" :accept="accept" :multiple="multiple"
            @change="onInputChange">

        <div class="file-input-div bg-gray-100" @click="triggerFileInput" @drop="onDrop"
            @dragover="$dragoverFile" @dragleave="$dragleaveFile">
            <template v-if="selectedNames">
                <label>{{ __('selected_file_name') }} {{ selectedNames }}</label>
            </template>
            <template v-else>
                <label><UploadCloud :size="32" /></label>
                <label>{{ __('drop_files_here_or_click_to_upload') }}</label>
            </template>
        </div>

        <small v-if="recommendationText" class="text-muted d-block mt-1">{{ recommendationText }}</small>

        <div class="text-end mt-1" v-if="hasFiles">
            <button type="button" class="btn btn-sm btn-link text-danger p-0" @click="clear">
                <X :size="14" /> {{ __('remove') }}
            </button>
        </div>

        <div class="row" v-if="showPreview && previewSrc">
            <div class="col-md-4">
                <img class="custom-image mt-2" :src="previewSrc" :alt="label || 'preview'">
            </div>
        </div>
    </div>
</template>

<script>
import { UploadCloud, X } from 'lucide-vue-next';

export default {
    name: 'FileUpload',
    components: { UploadCloud, X },
    props: {
        // v-model: File (single) or Array<File> (multiple)
        modelValue: { type: [Object, File, Array], default: null },
        label: { type: String, default: '' },
        required: { type: Boolean, default: false },
        accept: { type: String, default: 'image/*' },
        multiple: { type: Boolean, default: false },
        // e.g. "350x350px" → "Recommended size: 350x350px"
        recommendedSize: { type: String, default: '' },
        // full custom hint text; overrides recommendedSize
        recommendedText: { type: String, default: '' },
        // 0 = no client-side size limit
        maxSizeMb: { type: Number, default: 0 },
        // existing image URL shown on edit forms until a new file is picked
        previewUrl: { type: String, default: '' },
        showPreview: { type: Boolean, default: true },
        // server-side / parent validation error to display
        error: { type: String, default: '' },
    },
    emits: ['update:modelValue', 'error', 'change'],
    data() {
        return {
            localError: '',
            objectUrl: null,
        };
    },
    computed: {
        files() {
            if (!this.modelValue) return [];
            return Array.isArray(this.modelValue) ? this.modelValue : [this.modelValue];
        },
        hasFiles() {
            return this.files.length > 0;
        },
        selectedNames() {
            return this.files.map(f => f.name).join(', ');
        },
        recommendationText() {
            if (this.recommendedText) return this.recommendedText;
            if (this.recommendedSize) return __('recommended_size', { size: this.recommendedSize });
            return '';
        },
        displayError() {
            return this.localError || this.error;
        },
        previewSrc() {
            if (this.hasFiles) {
                const first = this.files[0];
                if (first && first.type && first.type.startsWith('image/')) {
                    return this.objectUrl;
                }
                return null;
            }
            return this.previewUrl || null;
        },
    },
    watch: {
        modelValue() {
            this.refreshObjectUrl();
        },
    },
    beforeUnmount() {
        this.revokeObjectUrl();
    },
    methods: {
        elRef() {
            const r = this.$refs.fileEl;
            return Array.isArray(r) ? r[0] : r;
        },
        triggerFileInput() {
            const el = this.elRef();
            if (el) el.click();
        },
        onInputChange(e) {
            this.handleFiles(e.target.files);
            e.target.value = '';
        },
        onDrop(e) {
            e.preventDefault();
            this.$dragleaveFile(e);
            if (e.dataTransfer && e.dataTransfer.files.length) {
                this.handleFiles(e.dataTransfer.files);
            }
        },
        handleFiles(fileList) {
            const files = Array.from(fileList || []);
            if (!files.length) return;
            this.localError = '';
            for (const file of files) {
                const err = this.validate(file);
                if (err) {
                    this.localError = err;
                    this.$emit('error', err);
                    return;
                }
            }
            const value = this.multiple ? files : files[0];
            this.$emit('update:modelValue', value);
            this.$emit('change', value);
        },
        validate(file) {
            if (!this.matchesAccept(file)) {
                return __('invalid_file_type');
            }
            if (this.maxSizeMb > 0 && file.size > this.maxSizeMb * 1024 * 1024) {
                return __('file_size_exceeds_limit_x', { size: this.maxSizeMb + ' MB' });
            }
            return '';
        },
        matchesAccept(file) {
            const accept = (this.accept || '').trim();
            if (!accept || accept === '*' || accept === '*/*') return true;
            const ext = '.' + (file.name.split('.').pop() || '').toLowerCase();
            return accept.split(',').some(raw => {
                const rule = raw.trim().toLowerCase();
                if (!rule) return false;
                if (rule.startsWith('.')) return ext === rule;
                if (rule.endsWith('/*')) return (file.type || '').startsWith(rule.slice(0, -1));
                return (file.type || '').toLowerCase() === rule;
            });
        },
        clear() {
            this.localError = '';
            this.$emit('update:modelValue', this.multiple ? [] : null);
            this.$emit('change', this.multiple ? [] : null);
        },
        refreshObjectUrl() {
            this.revokeObjectUrl();
            const first = this.files[0];
            if (first && first.type && first.type.startsWith('image/')) {
                this.objectUrl = URL.createObjectURL(first);
            }
        },
        revokeObjectUrl() {
            if (this.objectUrl) {
                URL.revokeObjectURL(this.objectUrl);
                this.objectUrl = null;
            }
        },
    },
    mounted() {
        this.refreshObjectUrl();
    },
};
</script>
