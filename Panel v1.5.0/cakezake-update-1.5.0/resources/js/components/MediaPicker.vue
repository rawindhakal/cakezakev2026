<template>
    <b-modal :model-value="show" @update:model-value="$emit('close')" :title="__('choose_from_media')"
        size="xl" scrollable no-fade static centered @hidden="$emit('close')">
        <template #footer>
            <b-button variant="secondary" @click="$emit('close')">{{ __('cancel') }}</b-button>
            <b-button variant="primary" :disabled="!selected.length" @click="confirm">
                {{ __('use_selected') }} <span v-if="multiple && selected.length">({{ selected.length }})</span>
            </b-button>
        </template>

        <div class="d-flex align-items-center gap-2 mb-3">
            <input type="search" class="form-control" v-model="search" :placeholder="__('search')">
            <button class="btn btn-outline-secondary" @click="load" :title="__('refresh')">
                <RefreshCw :size="15" :class="{ 'is-spinning': loading }" />
            </button>
        </div>

        <div class="text-center py-4" v-if="loading"><b-spinner /></div>
        <div class="text-muted text-center py-4" v-else-if="!filtered.length">{{ __('no_media_found') }}</div>

        <div class="d-flex flex-wrap gap-2" v-else>
            <div v-for="m in filtered" :key="m.id" class="border rounded p-1 position-relative"
                :class="{ 'border-primary border-2': isSelected(m) }"
                style="width: 110px; cursor: pointer;" @click="toggle(m)">
                <video v-if="isVideo(m)" :src="$storageUrl + m.sub_directory + m.name" class="w-100"
                    style="height: 90px; object-fit: contain; background: #000;" muted playsinline
                    preload="metadata"></video>
                <img v-else :src="$storageUrl + m.sub_directory + m.name" class="w-100"
                    style="height: 90px; object-fit: cover;" loading="lazy" />
                <div class="small text-truncate" :title="m.name">{{ m.name }}</div>
                <CheckCircle2 v-if="isSelected(m)" :size="20"
                    class="position-absolute top-0 end-0 text-primary bg-white rounded-circle" />
            </div>
        </div>
    </b-modal>
</template>

<script>
import { RefreshCw, CheckCircle2 } from 'lucide-vue-next';

/**
 * Media-library picker. Emits `select` with an array of storage paths
 * (e.g. products/media/169..._x.jpg) — the same paths the bulk import accepts.
 */
export default {
    components: { RefreshCw, CheckCircle2 },
    props: {
        show: { type: Boolean, default: false },
        multiple: { type: Boolean, default: false },
        // Clips belong in a product gallery, never in a slot that renders one image.
        allowVideo: { type: Boolean, default: false },
    },
    emits: ['select', 'close'],
    data() {
        return { media: [], selected: [], search: '', loading: false, loadedOnce: false };
    },
    computed: {
        filtered() {
            const q = this.search.trim().toLowerCase();
            const imgs = this.media.filter(m => (m.type || '').startsWith('image/')
                || (this.allowVideo && this.isVideo(m)));
            return q ? imgs.filter(m => (m.name || '').toLowerCase().includes(q)) : imgs;
        },
    },
    watch: {
        show(v) {
            if (v) {
                this.selected = [];
                if (!this.loadedOnce) this.load();
            }
        },
    },
    methods: {
        isVideo(m) {
            return String(m && m.type || '').startsWith('video/');
        },
        load() {
            this.loading = true;
            axios.get(this.$apiUrl + '/media')
                .then(r => { this.media = r.data.data || []; this.loadedOnce = true; })
                .finally(() => { this.loading = false; });
        },
        isSelected(m) {
            return this.selected.some(s => s.id === m.id);
        },
        toggle(m) {
            if (this.isSelected(m)) {
                this.selected = this.selected.filter(s => s.id !== m.id);
            } else {
                this.selected = this.multiple ? [...this.selected, m] : [m];
            }
        },
        confirm() {
            this.$emit('select', this.selected.map(m => ({
                path: m.sub_directory + m.name,
                url: this.$storageUrl + m.sub_directory + m.name,
            })));
            this.$emit('close');
        },
    },
};
</script>
