<template>
    <div class="list-surface p-3 mb-4 storage-panel">
        <div class="storage-head">
            <div class="storage-head-title">
                <span class="storage-head-icon"><HardDrive :size="18" /></span>
                <div>
                    <h5 class="mb-0">{{ __('storage_usage') }}</h5>
                    <div class="storage-head-sub">{{ __('storage_usage_sub') }}</div>
                </div>
            </div>
            <div class="storage-head-actions">
                <button type="button" class="btn btn-sm btn-outline-secondary d-inline-flex align-items-center gap-2"
                        :disabled="!info" @click="showFolders = true">
                    <FolderOpen :size="15" /> {{ __('folder_wise_usage') }}
                </button>
                <button type="button" class="btn btn-sm btn-primary d-inline-flex align-items-center gap-2"
                        :disabled="scanning" @click="scan()">
                    <b-spinner v-if="scanning" small /><SearchCheck v-else :size="15" />
                    {{ scanning ? __('scanning') : __('find_unused_images') }}
                </button>
                <button type="button" class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="loadInfo()">
                    <RefreshCw :class="{ 'is-spinning': loadingInfo }" />
                </button>
            </div>
        </div>

        <div v-if="info" class="storage-tiles">
            <div class="storage-tile">
                <span class="storage-tile-icon is-blue"><FolderClosed :size="18" /></span>
                <div class="storage-tile-body">
                    <div class="storage-tile-label">{{ __('uploads_folder') }}</div>
                    <div class="storage-tile-value"><RollingNumber :value="roll(formatBytes(info.uploads.size))" /></div>
                    <div class="storage-tile-sub"><span><RollingNumber :value="roll(info.uploads.files)" /> {{ __('files') }}</span></div>
                </div>
            </div>
            <div class="storage-tile">
                <span class="storage-tile-icon is-green"><ImageIcon :size="18" /></span>
                <div class="storage-tile-body">
                    <div class="storage-tile-label">{{ __('images') }}</div>
                    <div class="storage-tile-value"><RollingNumber :value="roll(formatBytes(info.uploads.image_size))" /></div>
                    <div class="storage-tile-sub"><span><RollingNumber :value="roll(info.uploads.image_files)" /> {{ __('files') }}</span></div>
                </div>
            </div>
            <div class="storage-tile">
                <span class="storage-tile-icon is-amber"><Trash2 :size="18" /></span>
                <div class="storage-tile-body">
                    <div class="storage-tile-label">{{ __('trash') }}</div>
                    <div class="storage-tile-value"><RollingNumber :value="roll(formatBytes(trashSize))" /></div>
                    <div class="storage-tile-sub">
                        <span><RollingNumber :value="roll(trashFiles)" /> {{ __('files') }}</span>
                        <button v-if="info.trash.length" type="button" class="storage-link" @click="openTrash()">
                            {{ __('manage') }}
                        </button>
                    </div>
                </div>
            </div>
            <div class="storage-tile">
                <span class="storage-tile-icon is-violet"><HardDrive :size="18" /></span>
                <div class="storage-tile-body">
                    <div class="storage-tile-label">{{ __('disk_space') }}</div>
                    <template v-if="info.disk">
                        <div class="storage-tile-value"><RollingNumber :value="roll(formatBytes(info.disk.free))" /> <small>{{ __('free') }}</small></div>
                        <div class="storage-bar" :title="diskPercent + '%'">
                            <div class="storage-bar-fill" :class="{ 'is-high': diskPercent >= 90 }" :style="{ width: diskPercent + '%' }"></div>
                        </div>
                        <div class="storage-tile-sub">
                            <span><RollingNumber :value="roll(formatBytes(info.disk.used))" /> {{ __('used') }} /
                            <RollingNumber :value="roll(formatBytes(info.disk.total))" /></span>
                        </div>
                    </template>
                    <div v-else class="storage-tile-sub">{{ __('disk_info_unavailable') }}</div>
                </div>
            </div>
        </div>
        <div v-else-if="loadingInfo" class="storage-tiles">
            <div v-for="n in 4" :key="n" class="storage-tile storage-tile-skeleton"></div>
        </div>

        <b-modal v-model="showFolders" :title="__('folder_wise_usage')" size="lg" scrollable centered>
            <table v-if="info" class="table table-sm align-middle mb-0 storage-folder-table">
                <thead>
                    <tr>
                        <th>{{ __('folder') }}</th>
                        <th class="text-end">{{ __('files') }}</th>
                        <th class="text-end">{{ __('size') }}</th>
                        <th class="storage-share-col">{{ __('share') }}</th>
                    </tr>
                </thead>
                <tbody>
                    <tr v-for="f in info.uploads.folders" :key="f.folder">
                        <td class="d-flex align-items-center gap-2"><FolderClosed :size="15" class="text-muted" /> {{ f.folder }}</td>
                        <td class="text-end tabular">{{ f.files }}</td>
                        <td class="text-end tabular">{{ formatBytes(f.size) }}</td>
                        <td>
                            <div class="d-flex align-items-center gap-2">
                                <div class="storage-bar flex-grow-1 mt-0">
                                    <div class="storage-bar-fill" :style="{ width: folderShare(f) + '%' }"></div>
                                </div>
                                <span class="storage-share-pct tabular">{{ folderShare(f) }}%</span>
                            </div>
                        </td>
                    </tr>
                </tbody>
                <tfoot>
                    <tr>
                        <th>{{ __('total') }}</th>
                        <th class="text-end tabular">{{ info.uploads.files }}</th>
                        <th class="text-end tabular">{{ formatBytes(info.uploads.size) }}</th>
                        <th></th>
                    </tr>
                </tfoot>
            </table>
            <template #footer>
                <button type="button" class="btn btn-light" @click="showFolders = false">{{ __('close') }}</button>
            </template>
        </b-modal>

        <b-modal v-model="showTrash" :title="__('trash')" size="xl" scrollable centered>
            <div v-if="loadingTrashFiles" class="text-center py-4"><b-spinner small /></div>
            <div v-else-if="!trashItems.length" class="text-center text-muted py-4">{{ __('trash_is_empty') }}</div>
            <template v-else>
                <div class="d-flex flex-wrap align-items-center gap-3 mb-2">
                    <strong>{{ trashItems.length }} {{ __('images') }} · {{ formatBytes(trashSize) }}</strong>
                    <label class="d-inline-flex align-items-center gap-2 mb-0">
                        <input type="checkbox" class="form-check-input mt-0" :checked="allTrashSelected"
                               @change="trashSelected = $event.target.checked ? trashItems.map(trashKey) : []">
                        {{ __('select_all') }}
                    </label>
                    <span class="text-muted">{{ trashSelected.length }} {{ __('selected') }}</span>
                </div>
                <div class="list-surface">
                    <div class="storage-result-grid">
                        <div v-for="item in trashPageItems" :key="trashKey(item)" class="storage-result-item"
                             :class="{ 'is-selected': trashSelectedSet.has(trashKey(item)) }">
                            <input type="checkbox" class="form-check-input storage-result-check"
                                   :checked="trashSelectedSet.has(trashKey(item))" @change="toggleTrash(item, $event.target.checked)">
                            <video v-if="isVideo(item.path)" :src="item.url" controls muted playsinline
                                   preload="metadata"></video>
                            <a v-else :href="item.url" target="_blank" rel="noopener"><img :src="item.url" loading="lazy" alt="" /></a>
                            <span class="storage-result-path" :title="item.path">{{ item.path }}</span>
                            <span class="storage-result-size">{{ formatBytes(item.size) }}</span>
                            <div class="storage-card-actions">
                                <button type="button" class="btn btn-sm btn-outline-primary" :disabled="busy"
                                        v-b-tooltip.hover :title="__('restore')" @click="restoreItems([item])">
                                    <RotateCcw :size="14" />
                                </button>
                                <button type="button" class="btn btn-sm btn-outline-danger" :disabled="busy"
                                        v-b-tooltip.hover :title="__('delete_permanently')" @click="deleteItems([item])">
                                    <Trash2 :size="14" />
                                </button>
                            </div>
                        </div>
                    </div>
                    <div class="list-footer">
                        <div class="list-perpage">
                            <span>{{ __('per_page') }}</span>
                            <b-form-select v-model="perPage" :options="pageOptions" size="sm" class="form-select"
                                           @change="trashPage = 1"></b-form-select>
                            <span class="list-range">{{ __('total_records') }} : {{ trashItems.length }}</span>
                        </div>
                        <b-pagination v-model="trashPage" :total-rows="trashItems.length" :per-page="perPage" size="sm"
                                      class="mb-0 list-pagination"></b-pagination>
                    </div>
                </div>
            </template>
            <template #footer>
                <button type="button" class="btn btn-light" @click="showTrash = false">{{ __('close') }}</button>
                <template v-if="trashItems.length">
                    <button type="button" class="btn btn-outline-primary d-inline-flex align-items-center gap-1"
                            :disabled="busy || !trashSelected.length" @click="restoreItems(selectedTrashItems)">
                        <RotateCcw :size="15" /> {{ __('restore_selected') }} ({{ trashSelected.length }})
                    </button>
                    <button type="button" class="btn btn-outline-danger d-inline-flex align-items-center gap-1"
                            :disabled="busy || !trashSelected.length" @click="deleteItems(selectedTrashItems)">
                        <Trash2 :size="15" /> {{ __('delete_selected') }} ({{ trashSelected.length }})
                    </button>
                    <button type="button" class="btn btn-danger" :disabled="busy" @click="emptyTrash()">
                        {{ __('empty_trash') }}
                    </button>
                </template>
            </template>
        </b-modal>

        <b-modal v-model="showResult" :title="__('unused_images')" size="xl" scrollable centered no-close-on-backdrop>
            <template v-if="result">
                <div class="alert alert-info py-2 storage-hint">{{ __('storage_cleanup_hint') }}</div>
                <div v-if="!result.unused.length" class="text-center py-4">{{ __('no_unused_images_found') }}</div>
                <template v-else>
                    <div class="d-flex flex-wrap align-items-center gap-3 mb-2">
                        <strong>{{ result.unused.length }} {{ __('unused_images_found') }} · {{ formatBytes(result.unused_size) }}</strong>
                        <label class="d-inline-flex align-items-center gap-2 mb-0">
                            <input type="checkbox" class="form-check-input mt-0" :checked="allSelected" @change="toggleAll($event.target.checked)">
                            {{ __('select_all') }}
                        </label>
                        <span class="text-muted">{{ selected.length }} {{ __('selected') }} · {{ formatBytes(selectedSize) }}</span>
                    </div>
                    <div v-if="manyUnused" class="alert alert-warning py-2">{{ __('unused_many_warning') }}</div>
                    <div class="list-surface">
                    <div class="storage-result-grid">
                        <label v-for="item in pageItems" :key="item.path" class="storage-result-item"
                               :class="{ 'is-selected': selectedSet.has(item.path) }">
                            <input type="checkbox" class="form-check-input storage-result-check"
                                   :checked="selectedSet.has(item.path)" @change="toggle(item.path, $event.target.checked)">
                            <!-- The scan covers clips as well as stills. -->
                            <video v-if="isVideo(item.path)" :src="$storageUrl + item.path" controls muted
                                   playsinline preload="metadata"></video>
                            <img v-else :src="$storageUrl + item.path" loading="lazy" alt="" />
                            <span class="storage-result-path" :title="item.path">{{ item.path }}</span>
                            <span class="storage-result-size">{{ formatBytes(item.size) }}</span>
                        </label>
                    </div>
                    <div class="list-footer">
                        <div class="list-perpage">
                            <span>{{ __('per_page') }}</span>
                            <b-form-select v-model="perPage" :options="pageOptions" size="sm" class="form-select"
                                           @change="page = 1"></b-form-select>
                            <span class="list-range">{{ __('total_records') }} : {{ result.unused.length }}</span>
                        </div>
                        <b-pagination v-model="page" :total-rows="result.unused.length" :per-page="perPage" size="sm"
                                      class="mb-0 list-pagination"></b-pagination>
                    </div>
                    </div>
                </template>
                <div class="storage-skipped mt-3">
                    <div v-if="result.skipped_recent">{{ result.skipped_recent }} {{ __('skipped_recent_files') }}</div>
                    <div v-if="result.skipped_unreadable_name">{{ result.skipped_unreadable_name }} {{ __('skipped_unreadable_names') }}</div>
                </div>
            </template>
            <template #footer>
                <button type="button" class="btn btn-light" @click="showResult = false">{{ __('cancel') }}</button>
                <button v-if="result && result.unused.length" type="button" class="btn btn-danger d-inline-flex align-items-center gap-2"
                        :disabled="!selected.length || busy" @click="moveToTrash()">
                    <b-spinner v-if="busy" small /><Trash2 v-else :size="16" />
                    {{ __('move_selected_to_trash') }} ({{ selected.length }})
                </button>
            </template>
        </b-modal>
    </div>
</template>

<script>
import axios from "axios";
import RollingNumber from '../../components/RollingNumber.vue';
import { HardDrive, RefreshCw, SearchCheck, Trash2, RotateCcw, FolderOpen, FolderClosed, Image as ImageIcon } from 'lucide-vue-next';

export default {
    components: { RollingNumber, HardDrive, RefreshCw, SearchCheck, Trash2, RotateCcw, FolderOpen, FolderClosed, ImageIcon },
    emits: ['changed'],
    data() {
        return {
            info: null,
            rolled: true,
            loadingInfo: false,
            showFolders: false,
            showTrash: false,
            trashItems: [],
            trashSelected: [],
            trashPage: 1,
            loadingTrashFiles: false,
            scanning: false,
            busy: false,
            showResult: false,
            result: null,
            selected: [],
            page: 1,
            // The grid fits 7 cards a row on a desktop modal, so pages are whole rows.
            perPage: 14,
            pageOptions: [14, 28, 56, 98],
        };
    },
    computed: {
        trashSize() {
            return (this.info?.trash || []).reduce((s, b) => s + b.size, 0);
        },
        trashFiles() {
            return (this.info?.trash || []).reduce((s, b) => s + b.files, 0);
        },
        diskPercent() {
            const d = this.info?.disk;
            return d && d.total ? Math.round((d.used / d.total) * 100) : 0;
        },
        selectedSet() {
            return new Set(this.selected);
        },
        selectedSize() {
            if (!this.result) return 0;
            const set = this.selectedSet;
            return this.result.unused.reduce((s, i) => s + (set.has(i.path) ? i.size : 0), 0);
        },
        allSelected() {
            return !!this.result && this.result.unused.length > 0 && this.selected.length === this.result.unused.length;
        },
        trashSelectedSet() {
            return new Set(this.trashSelected);
        },
        allTrashSelected() {
            return this.trashItems.length > 0 && this.trashSelected.length === this.trashItems.length;
        },
        selectedTrashItems() {
            const set = this.trashSelectedSet;
            return this.trashItems.filter(i => set.has(this.trashKey(i)));
        },
        trashPageItems() {
            const start = (this.trashPage - 1) * this.perPage;
            return this.trashItems.slice(start, start + this.perPage);
        },
        pageItems() {
            if (!this.result) return [];
            const start = (this.page - 1) * this.perPage;
            return this.result.unused.slice(start, start + this.perPage);
        },
        // More than half of all images unused is unusual enough to ask for a closer look.
        manyUnused() {
            return !!this.result && this.result.image_files > 0
                && this.result.unused.length / this.result.image_files > 0.5;
        },
    },
    created() {
        this.loadInfo();
    },
    methods: {
        /** Scan rows carry a storage path, so the extension is all there is to go on. */
        isVideo(path) {
            return /\.(mp4|m4v|mov|webm)$/i.test(String(path || ''));
        },
        loadInfo() {
            this.loadingInfo = true;
            axios.get(this.$apiUrl + '/storage_cleanup/info')
                .then((res) => {
                    if (res.data.status === 1) {
                        this.info = res.data.data;
                        this.startRoll();
                    }
                })
                .finally(() => { this.loadingInfo = false; });
        },
        /** Same load animation as the Dashboard cards: digits read 0, then roll to the value. */
        startRoll() {
            if (this._rollRaf) cancelAnimationFrame(this._rollRaf);
            this.rolled = false;
            this._rollRaf = requestAnimationFrame(() => {
                this._rollRaf = requestAnimationFrame(() => {
                    this.rolled = true;
                    this._rollRaf = null;
                });
            });
        },
        roll(v) {
            const s = String(v ?? '');
            return this.rolled ? s : s.replace(/\d/g, '0');
        },
        scan() {
            this.scanning = true;
            axios.post(this.$apiUrl + '/storage_cleanup/scan')
                .then((res) => {
                    if (res.data.status !== 1) {
                        this.showError(res.data.message);
                        return;
                    }
                    this.result = res.data.data;
                    this.selected = [];
                    this.page = 1;
                    this.showResult = true;
                })
                .catch((e) => this.showError(e.response?.data?.message || __('storage_scan_failed')))
                .finally(() => { this.scanning = false; });
        },
        toggle(path, on) {
            if (on) {
                if (!this.selectedSet.has(path)) this.selected.push(path);
            } else {
                this.selected = this.selected.filter(p => p !== path);
            }
        },
        toggleAll(on) {
            this.selected = on ? this.result.unused.map(i => i.path) : [];
        },
        confirm(text, danger = true) {
            return this.$swal.fire({
                title: __('are_you_sure'),
                text,
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('yes'),
                cancelButtonText: __('cancel'),
                confirmButtonColor: danger ? '#d33' : (window.adminThemeColor || '#435ebe'),
            }).then(r => !!r.value);
        },
        async moveToTrash() {
            if (!this.selected.length || !(await this.confirm(__('move_to_trash_confirm'), false))) return;
            this.busy = true;
            axios.post(this.$apiUrl + '/storage_cleanup/trash', { scan_id: this.result.scan_id, paths: this.selected })
                .then((res) => {
                    if (res.data.status !== 1) {
                        this.showError(res.data.message);
                        return;
                    }
                    const d = res.data.data;
                    this.showMessage('success', res.data.message + ` (${d.moved} · ${this.formatBytes(d.size)})`);
                    if (d.kept) {
                        this.showWarning(d.kept + ' ' + __('moved_files_kept_note'));
                    }
                    this.showResult = false;
                    this.result = null;
                    this.loadInfo();
                    this.$emit('changed');
                })
                .catch((e) => this.showError(e.response?.data?.message || __('storage_scan_failed')))
                .finally(() => { this.busy = false; });
        },
        trashKey(item) {
            return item.batch + '/' + item.path;
        },
        toggleTrash(item, on) {
            const key = this.trashKey(item);
            this.trashSelected = on
                ? [...new Set([...this.trashSelected, key])]
                : this.trashSelected.filter(k => k !== key);
        },
        openTrash() {
            this.showTrash = true;
            this.loadTrash();
        },
        loadTrash() {
            this.loadingTrashFiles = true;
            axios.get(this.$apiUrl + '/storage_cleanup/trash_files')
                .then((res) => {
                    if (res.data.status === 1) {
                        this.trashItems = res.data.data;
                        const keys = new Set(this.trashItems.map(this.trashKey));
                        this.trashSelected = this.trashSelected.filter(k => keys.has(k));
                        const pages = Math.max(1, Math.ceil(this.trashItems.length / this.perPage));
                        if (this.trashPage > pages) this.trashPage = pages;
                    } else {
                        this.showError(res.data.message);
                    }
                })
                .finally(() => { this.loadingTrashFiles = false; });
        },
        afterTrashChange(res) {
            res.data.status === 1 ? this.showMessage('success', res.data.message) : this.showError(res.data.message);
            this.loadInfo();
            this.loadTrash();
        },
        restoreItems(items) {
            if (!items.length) return;
            this.busy = true;
            axios.post(this.$apiUrl + '/storage_cleanup/restore', { items: items.map(i => ({ batch: i.batch, path: i.path })) })
                .then((res) => {
                    this.afterTrashChange(res);
                    this.$emit('changed');
                })
                .finally(() => { this.busy = false; });
        },
        async deleteItems(items) {
            if (!items.length || !(await this.confirm(__('delete_permanently_confirm')))) return;
            this.busy = true;
            axios.post(this.$apiUrl + '/storage_cleanup/empty_trash', { items: items.map(i => ({ batch: i.batch, path: i.path })) })
                .then((res) => this.afterTrashChange(res))
                .finally(() => { this.busy = false; });
        },
        async emptyTrash() {
            if (!(await this.confirm(__('delete_permanently_confirm')))) return;
            this.busy = true;
            axios.post(this.$apiUrl + '/storage_cleanup/empty_trash')
                .then((res) => {
                    this.trashSelected = [];
                    this.afterTrashChange(res);
                })
                .finally(() => { this.busy = false; });
        },
        folderShare(f) {
            const total = this.info.uploads.size || 1;
            return Math.round((f.size / total) * 1000) / 10;
        },
        formatBytes(bytes) {
            bytes = Number(bytes) || 0;
            if (!bytes) return '0 KB';
            const names = ['B', 'KB', 'MB', 'GB', 'TB'];
            const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), names.length - 1);
            let decimals = 1;
            if (i === 0) decimals = 0;
            else if (i >= 3) decimals = 2;
            return (bytes / (1024 ** i)).toFixed(decimals) + ' ' + names[i];
        },
        formatDate(iso) {
            if (!iso) return '';
            const d = new Date(iso);
            return Number.isNaN(d.getTime()) ? iso : d.toLocaleString();
        },
    },
};
</script>

<style scoped>
.storage-head {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    margin-bottom: 16px;
}
.storage-head-title {
    display: flex;
    align-items: center;
    gap: 12px;
}
.storage-head-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 38px;
    height: 38px;
    border-radius: 10px;
    background: rgba(var(--bs-primary-rgb, 67, 94, 190), .1);
    color: var(--bs-primary, #435ebe);
}
.storage-head-sub {
    font-size: 12px;
    opacity: .65;
    margin-top: 2px;
}
.storage-head-actions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px;
}
.storage-tiles {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
    gap: 12px;
}
.storage-tile {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    border: 1px solid var(--bs-border-color, #e5e7eb);
    border-radius: 10px;
    padding: 14px 16px;
    min-height: 96px;
}
.storage-tile-skeleton {
    background: var(--bs-secondary-bg, #f3f4f6);
    animation: storage-pulse 1.2s ease-in-out infinite;
}
@keyframes storage-pulse {
    50% { opacity: .5; }
}
.storage-tile-icon {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
    border-radius: 9px;
}
.storage-tile-icon.is-blue { background: rgba(37, 99, 235, .1); color: #2563eb; }
.storage-tile-icon.is-green { background: rgba(22, 163, 74, .1); color: #16a34a; }
.storage-tile-icon.is-amber { background: rgba(217, 119, 6, .12); color: #d97706; }
.storage-tile-icon.is-violet { background: rgba(124, 58, 237, .1); color: #7c3aed; }
.storage-tile-body {
    flex: 1;
    min-width: 0;
}
.storage-tile-label {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: .05em;
    opacity: .6;
}
.storage-tile-value {
    font-size: 20px;
    font-weight: 700;
    line-height: 1.25;
    margin-top: 4px;
}
.storage-tile-value small {
    font-size: 12px;
    font-weight: 500;
    opacity: .7;
}
.storage-tile-sub {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
    opacity: .75;
    margin-top: 4px;
}
.storage-link {
    border: 0;
    background: none;
    padding: 0;
    font-size: 12px;
    font-weight: 600;
    color: var(--bs-primary, #435ebe);
    cursor: pointer;
}
.storage-link:hover {
    text-decoration: underline;
}
.storage-bar {
    height: 6px;
    border-radius: 3px;
    background: var(--bs-secondary-bg, #eef0f3);
    overflow: hidden;
    margin-top: 8px;
}
.storage-bar-fill {
    height: 100%;
    background: var(--bs-primary, #435ebe);
    border-radius: 3px;
}
.storage-bar-fill.is-high {
    background: var(--bs-danger, #dc3545);
}
.storage-folder-table th {
    font-size: 12px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: .04em;
    opacity: .75;
}
.storage-share-col {
    width: 38%;
}
.storage-share-pct {
    width: 48px;
    text-align: right;
    font-size: 12px;
}
.tabular {
    font-variant-numeric: tabular-nums;
}
.storage-hint {
    font-size: 13px;
}
.storage-result-grid {
    padding: 12px;
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
    gap: 10px;
}
.storage-result-item {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: 4px;
    border: 1px solid var(--bs-border-color, #e5e7eb);
    border-radius: 8px;
    padding: 6px;
    cursor: pointer;
    margin: 0;
}
.storage-card-actions {
    display: flex;
    gap: 6px;
    margin-top: 2px;
}
.storage-card-actions .btn {
    flex: 1;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 3px 0;
}
.storage-result-item.is-selected {
    border-color: var(--bs-danger, #dc3545);
    box-shadow: 0 0 0 1px var(--bs-danger, #dc3545);
}
.storage-result-item img,
.storage-result-item video {
    width: 100%;
    aspect-ratio: 1;
    object-fit: contain;
    background: var(--bs-secondary-bg, #f5f6f8);
    border-radius: 4px;
}
.storage-result-item video {
    background: #000;
}
.storage-result-check {
    position: absolute;
    top: 10px;
    left: 10px;
    margin: 0;
}
.storage-result-path {
    font-size: 11px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}
.storage-result-size {
    font-size: 11px;
    opacity: .7;
}
.storage-skipped {
    font-size: 12px;
    opacity: .75;
}
@media (max-width: 576px) {
    .storage-head-actions {
        width: 100%;
    }
    .storage-head-actions .btn {
        flex: 1;
        justify-content: center;
    }
}
</style>
