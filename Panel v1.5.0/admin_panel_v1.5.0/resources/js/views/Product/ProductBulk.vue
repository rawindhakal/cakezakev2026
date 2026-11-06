<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ isUpdate ? __('bulk_update') : __('bulk_upload') }}</h3>
                <button class="btn btn-outline-primary ms-auto d-inline-flex align-items-center gap-1"
                    @click="showInstructions = true">
                    <Info :size="16" /> {{ __('instructions') }}
                </button>
                <router-link to="/products" class="btn btn-outline-secondary ms-2 d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <!-- Full step-by-step walkthrough -->
            <b-modal v-model="showInstructions" :title="__('bulk_instructions_title')" size="lg" scrollable
                centered no-fade hide-footer>
                <ol class="ps-3 mb-0 d-flex flex-column gap-2">
                    <li><strong>{{ __('bulk_step_1_title') }}</strong><br>{{ __('bulk_step_1_desc') }}</li>
                    <li><strong>{{ __('bulk_step_2_title') }}</strong><br>{{ isUpdate ? __('bulk_step_2_desc_update') : __('bulk_step_2_desc_upload') }}</li>
                    <li v-if="!isUpdate"><strong>{{ __('bulk_step_3_title') }}</strong><br>{{ __('bulk_step_3_desc') }}</li>
                    <li><strong>{{ __('bulk_step_images_title') }}</strong><br>{{ __('bulk_step_images_desc') }}</li>
                    <li><strong>{{ __('bulk_step_pricing_title') }}</strong><br>{{ __('bulk_step_pricing_desc') }}</li>
                    <li v-if="isUpdate"><strong>{{ __('bulk_step_merge_title') }}</strong><br>{{ __('bulk_step_merge_desc') }}</li>
                    <li><strong>{{ __('bulk_step_addons_title') }}</strong><br>{{ __('bulk_step_addons_desc') }}</li>
                    <li><strong>{{ __('bulk_step_upload_title') }}</strong><br>{{ __('bulk_step_upload_desc') }}</li>
                    <li><strong>{{ __('bulk_step_progress_title') }}</strong><br>{{ __('bulk_step_progress_desc') }}</li>
                </ol>
            </b-modal>

            <!-- Step 1: selection. The sheet's columns depend on this, so it comes first. -->
            <div class="card">
                <div class="card-header">
                    <h4 class="mb-0">1. {{ __('select_category_and_branches') }}</h4>
                </div>
                <div class="card-body">
                    <div class="alert alert-info mb-3">
                        {{ __('bulk_columns_depend_on_selection_hint') }}
                    </div>

                    <div class="row">
                        <div class="col-md-3 form-group">
                            <label>{{ __('sales_channel') }}</label>
                            <AppSelect class="form-select" v-model="salesChannel" :options="salesChannelOptions" :searchable="false" @update:model-value="onChannelChange" />
                        </div>

                        <div class="col-md-9 form-group">
                            <label>{{ __('category') }}</label>
                            <div class="d-flex flex-wrap gap-2">
                                <!-- Searchable: category lists get long. Clearing a level
                                     passes null so the child levels collapse. -->
                                <AppSelect v-for="(level, idx) in categoryLevels" :key="idx"
                                    class="form-select bulk-cat-select" :model-value="level.selectedId"
                                    :options="level.items" :placeholder="__('select_category')"
                                    @update:model-value="selectCategoryAt(idx, $event === '' ? null : Number($event))" />
                            </div>
                        </div>
                    </div>

                    <div class="form-group" v-if="branches.length">
                        <label>{{ __('branches') }} <small class="text-muted">({{ __('per_branch_pricing_columns_will_be_added') }})</small></label>
                        <div class="d-flex flex-wrap gap-2">
                            <label v-for="s in branches" :key="s.id"
                                class="border rounded px-3 py-2 d-inline-flex align-items-center gap-2"
                                :class="{ 'border-primary bg-light': branchIds.includes(s.id) }" style="cursor:pointer">
                                <input type="checkbox" class="form-check-input mt-0" :value="s.id" v-model="branchIds">
                                <span>{{ s.name }} <small class="text-muted" v-if="s.city">({{ s.city }})</small></span>
                            </label>
                        </div>
                    </div>

                    <div class="alert alert-warning mb-0" v-if="metaLoaded && !meta.has_attributes">
                        {{ __('this_category_has_no_attributes_add_attributes_first') }}
                    </div>

                    <!-- Column preview so the admin knows exactly what file they'll get.
                         A category with ten languages and a few branches runs past 140
                         columns, so they are folded into their groups: the required ones
                         are listed outright and the rest open a group at a time. -->
                    <div v-if="metaLoaded && meta.has_attributes" class="mt-2 col-preview">
                        <div class="col-preview-head">
                            <label class="fw-bold mb-0">{{ __('products_sheet') }} — {{ __('file_columns') }} ({{ meta.columns.length }})</label>
                            <button type="button" class="btn btn-link btn-sm p-0"
                                @click="toggleAllGroups('p', productGroups)">
                                {{ allOpen('p', productGroups) ? __('collapse_all') : __('expand_all') }}
                            </button>
                        </div>

                        <!-- The only columns that cannot be left blank: worth seeing
                             without opening anything. -->
                        <div v-if="requiredColumns(meta.columns).length" class="col-required">
                            <span class="text-muted small me-1">{{ __('must_be_filled') }}:</span>
                            <span v-for="(c, i) in requiredColumns(meta.columns)" :key="'pr' + i"
                                class="badge bg-primary">{{ c.label }}</span>
                        </div>

                        <div v-for="g in productGroups" :key="'pg-' + g.key" class="col-group">
                            <button type="button" class="col-group-head" @click="toggleGroup('p', g.key)">
                                <ChevronRight :size="14" class="col-group-caret"
                                    :class="{ 'is-open': isGroupOpen('p', g.key) }" />
                                <span class="col-group-name">{{ g.label }}</span>
                                <span class="col-group-count">{{ g.columns.length }}</span>
                            </button>
                            <div v-if="isGroupOpen('p', g.key)" class="d-flex flex-wrap gap-1 col-group-body">
                                <span v-for="(c, i) in g.columns" :key="'pc' + i" class="badge"
                                    :class="c.required ? 'bg-primary' : 'bg-secondary'">{{ c.label }}</span>
                            </div>
                        </div>
                    </div>

                    <!-- The second sheet. Shown separately because it is a different
                         shape: one row per addon option, not per variant. -->
                    <div v-if="metaLoaded && meta.has_attributes && (meta.addon_columns || []).length"
                        class="mt-3 col-preview">
                        <div class="col-preview-head">
                            <label class="fw-bold mb-0">{{ __('addons_sheet') }} ({{ meta.addon_columns.length }})</label>
                            <button type="button" class="btn btn-link btn-sm p-0"
                                @click="toggleAllGroups('a', addonGroups)">
                                {{ allOpen('a', addonGroups) ? __('collapse_all') : __('expand_all') }}
                            </button>
                        </div>
                        <p class="text-muted small mb-1">{{ __('addon_sheet_preview_hint') }}</p>

                        <div v-if="requiredColumns(meta.addon_columns).length" class="col-required">
                            <span class="text-muted small me-1">{{ __('must_be_filled') }}:</span>
                            <span v-for="(c, i) in requiredColumns(meta.addon_columns)" :key="'ar' + i"
                                class="badge bg-primary">{{ c.label }}</span>
                        </div>

                        <div v-for="g in addonGroups" :key="'ag-' + g.key" class="col-group">
                            <button type="button" class="col-group-head" @click="toggleGroup('a', g.key)">
                                <ChevronRight :size="14" class="col-group-caret"
                                    :class="{ 'is-open': isGroupOpen('a', g.key) }" />
                                <span class="col-group-name">{{ g.label }}</span>
                                <span class="col-group-count">{{ g.columns.length }}</span>
                            </button>
                            <div v-if="isGroupOpen('a', g.key)" class="d-flex flex-wrap gap-1 col-group-body">
                                <span v-for="(c, i) in g.columns" :key="'ac' + i" class="badge"
                                    :class="c.required ? 'bg-primary' : 'bg-secondary'">{{ c.label }}</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Step 2: file -->
            <div class="card">
                <div class="card-header">
                    <h4 class="mb-0">2. {{ isUpdate ? __('download_edit_and_reupload') : __('download_sample_fill_and_upload') }}</h4>
                </div>
                <div class="card-body">
                    <div class="alert alert-info">
                        <p class="mb-1" v-if="!isUpdate">{{ __('bulk_upload_hint_handle_groups_variants') }}</p>
                        <p class="mb-1" v-if="isUpdate">{{ __('bulk_update_hint_merge_only') }}</p>
                        <p class="mb-0">{{ __('always_download_and_use_new_sample_file_if_you_did_updated_admin_panel_version') }}</p>
                    </div>

                    <button class="btn btn-outline-primary mb-3" :disabled="!selectionReady || downloading" @click="downloadFile">
                        <b-spinner small v-if="downloading" />
                        <Download :size="15" v-else />
                        {{ isUpdate ? __('download_products_for_update') : __('download_sample_file') }}
                    </button>

                    <!-- Row-level validation errors -->
                    <div class="alert alert-danger" v-if="rowErrors.length">
                        <p class="mb-2">
                            {{ __('validation_failed_for_some_rows_please_fix_and_re_upload') }}
                            <strong v-if="errorCount > rowErrors.length">({{ errorCount }} {{ __('total') }})</strong>
                        </p>
                        <div class="table-responsive" style="max-height: 320px; overflow-y: auto;">
                            <table class="table table-sm table-striped mb-0">
                                <thead>
                                    <tr>
                                        <th style="width: 80px;">{{ __('row') }}</th>
                                        <th>{{ __('errors') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr v-for="(e, i) in rowErrors" :key="i">
                                        <td>{{ e.sheet ? e.sheet + ' · ' : '' }}{{ e.row }}</td>
                                        <td>{{ e.error }}</td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Progress of a dispatched run (polled from bulk/status). -->
                    <div v-if="job" class="mb-3">
                        <div class="d-flex justify-content-between mb-1">
                            <span>
                                {{ job.status === 'completed' ? __('import_finished') : (job.status === 'failed' ? __('import_failed') : __('importing_please_wait')) }}
                            </span>
                            <span>{{ job.processed_rows }} / {{ job.total_rows }}</span>
                        </div>
                        <div class="progress" style="height: 20px;">
                            <div class="progress-bar" role="progressbar"
                                :class="{ 'bg-success': job.status === 'completed' && !(job.errors || []).length,
                                          'bg-warning': job.status === 'completed' && (job.errors || []).length,
                                          'bg-danger': job.status === 'failed',
                                          'progress-bar-striped progress-bar-animated': job.status === 'processing' || job.status === 'pending' }"
                                :style="{ width: progressPct + '%' }">
                                {{ progressPct }}%
                            </div>
                        </div>
                        <div class="mt-2" v-if="job.status === 'completed'">
                            <span class="badge bg-success me-2">{{ __('successful') }}: {{ job.success_count }}</span>
                            <span class="badge bg-danger" v-if="(job.errors || []).length">{{ __('failed') }}: {{ job.errors.length }}</span>
                        </div>
                        <div class="alert alert-danger mt-2 mb-0" v-if="job.status === 'failed' && job.message">{{ job.message }}</div>
                        <!-- Runtime failures: rows that passed validation but failed to write. -->
                        <div class="alert alert-warning mt-2 mb-0" v-if="job.status === 'completed' && (job.errors || []).length">
                            <p class="mb-2">{{ __('some_rows_failed_during_processing') }}</p>
                            <div class="table-responsive" style="max-height: 240px; overflow-y: auto;">
                                <table class="table table-sm mb-0">
                                    <tbody>
                                        <tr v-for="(e, i) in job.errors" :key="i">
                                            <td style="width: 110px;">{{ e.sheet ? e.sheet + ' · ' : '' }}{{ e.row }}</td>
                                            <td>{{ e.error }}</td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>

                    <form @submit.prevent="submit" enctype="multipart/form-data">
                        <FileUpload v-model="file" :label="__('upload_file') + ' ' + __('excel_file')"
                            accept=".xlsx,.xls" :show-preview="false"
                            :recommended-text="__('supported_formats') + ': XLSX, XLS'"
                            @change="rowErrors = []" />

                        <button type="submit" class="btn btn-primary mt-2" :disabled="!selectionReady || !file || isLoading || polling">
                            <b-spinner small v-if="isLoading || polling" />
                            <Upload :size="15" v-else />
                            {{ isUpdate ? __('update') : __('upload') }}
                        </button>
                    </form>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import FileUpload from '../../components/FileUpload.vue';
import { ArrowLeft, ChevronRight, Download, Upload, Info } from 'lucide-vue-next';

export default {
    components: { FileUpload, ArrowLeft, ChevronRight, Download, Upload, Info },
    props: {
        // 'upload' creates products; 'update' merges edits into existing ones.
        mode: { type: String, default: 'upload' },
    },
    data() {
        return {
            salesChannel: 'both',
            categoryLevels: [],
            categoryId: null,
            branches: [],
            branchIds: [],
            meta: {},
            metaLoaded: false,
            file: null,
            rowErrors: [],
            errorCount: 0,
            isLoading: false,
            downloading: false,
            job: null,
            polling: false,
            pollTimer: null,
            showInstructions: false,
            openGroups: {},
        };
    },
    computed: {
        // Fixed option set — no search box needed.
        salesChannelOptions() {
            return [
                { id: 'both', name: (__('both')) },
                { id: 'quick', name: (__('quick')) },
                { id: 'ecommerce', name: (__('ecommerce')) },
            ];
        },
        isUpdate() {
            return this.mode === 'update';
        },
        selectionReady() {
            return !!this.categoryId && this.branchIds.length > 0 && this.metaLoaded && this.meta.has_attributes;
        },
        progressPct() {
            if (!this.job || !this.job.total_rows) {
                return 0;
            }
            return Math.round((this.job.processed_rows / this.job.total_rows) * 100);
        },
        productGroups() {
            return this.groupColumns(this.meta.columns);
        },
        addonGroups() {
            return this.groupColumns(this.meta.addon_columns);
        },
    },
    beforeUnmount() {
        if (this.pollTimer) {
            clearTimeout(this.pollTimer);
        }
    },
    watch: {
        branchIds() {
            this.fetchMeta();
        },
        // Same component backs both /bulk/upload and /bulk/update, so Vue reuses
        // the instance when switching routes — the previously selected file and
        // job state would otherwise leak across. Reset when the mode flips.
        mode() {
            this.resetState();
        },
    },
    created() {
        this.initCategoryLevels();
        this.fetchBranches();
    },
    methods: {
        groupColumns(columns) {
            const out = [];
            const byKey = {};

            (columns || []).forEach(c => {
                const key = c.group || 'other';
                if (!byKey[key]) {
                    byKey[key] = { key, label: this.groupLabel(key), columns: [] };
                    out.push(byKey[key]);
                }
                byKey[key].columns.push(c);
            });

            return out;
        },
        /** A group's own name, or the raw key when the schema grows one we have no string for. */
        groupLabel(key) {
            const labels = {
                key: __('bulk_group_identity'),
                variant: __('bulk_group_variant'),
                variant_translation: __('bulk_group_variant_names'),
                attribute: __('bulk_group_attributes'),
                product: __('bulk_group_product'),
                product_translation: __('bulk_group_product_text'),
                custom: __('bulk_group_custom_fields'),
                branch: __('bulk_group_branch'),
                addon_group: __('bulk_group_addon_group'),
                addon_group_translation: __('bulk_group_addon_group_names'),
                addon_option: __('bulk_group_addon_option'),
                addon_option_translation: __('bulk_group_addon_option_names'),
                addon_branch: __('bulk_group_addon_branch'),
            };

            return labels[key] || key;
        },
        /** The columns that cannot be left blank — listed outside the folds. */
        requiredColumns(columns) {
            return (columns || []).filter(c => c.required);
        },
        isGroupOpen(sheet, key) {
            return !!this.openGroups[sheet + ':' + key];
        },
        toggleGroup(sheet, key) {
            const id = sheet + ':' + key;
            this.openGroups = { ...this.openGroups, [id]: !this.openGroups[id] };
        },
        allOpen(sheet, groups) {
            return groups.length > 0 && groups.every(g => this.isGroupOpen(sheet, g.key));
        },
        toggleAllGroups(sheet, groups) {
            const open = !this.allOpen(sheet, groups);
            const next = { ...this.openGroups };
            groups.forEach(g => { next[sheet + ':' + g.key] = open; });
            this.openGroups = next;
        },
        resetState() {
            if (this.pollTimer) {
                clearTimeout(this.pollTimer);
                this.pollTimer = null;
            }
            this.salesChannel = 'both';
            this.categoryId = null;
            this.branchIds = [];
            this.meta = {};
            this.metaLoaded = false;
            this.file = null;
            this.rowErrors = [];
            this.errorCount = 0;
            this.isLoading = false;
            this.downloading = false;
            this.job = null;
            this.polling = false;
            this.showInstructions = false;
            this.initCategoryLevels();
            this.fetchBranches();
        },
        onChannelChange() {
            this.branchIds = [];
            this.fetchBranches();
        },
        fetchBranches() {
            axios.get(this.$apiUrl + '/products/bulk/meta', { params: { sales_channel: this.salesChannel } })
                .then(r => { this.branches = r.data.data?.branches || []; })
                .catch(() => { this.branches = []; });
        },
        initCategoryLevels() {
            axios.get(this.$apiUrl + '/categories/main').then(r => {
                const items = r.data.data || [];
                this.categoryLevels = [{ parentId: 0, items, selectedId: null }];
            }).catch(() => { this.categoryLevels = [{ parentId: 0, items: [], selectedId: null }]; });
        },
        selectCategoryAt(level, id) {
            this.categoryLevels = this.categoryLevels.slice(0, level + 1);
            this.categoryLevels[level] = { ...this.categoryLevels[level], selectedId: id };
            this.categoryId = id;
            this.metaLoaded = false;
            axios.get(this.$apiUrl + '/categories', { params: { parent_id: id } }).then(r => {
                const children = (Array.isArray(r.data.data) ? r.data.data : [])
                    .filter(c => Number(c.parent_id || 0) === Number(id));
                if (children.length > 0) {
                    // Not a leaf yet — products attach to leaf categories.
                    this.categoryId = null;
                    this.categoryLevels.push({ parentId: id, items: children, selectedId: null });
                } else {
                    this.fetchMeta();
                }
            }).catch(() => this.fetchMeta());
        },
        fetchMeta() {
            if (!this.categoryId || !this.branchIds.length) {
                this.metaLoaded = false;
                return;
            }
            axios.get(this.$apiUrl + '/products/bulk/meta', {
                params: {
                    category_id: this.categoryId,
                    branch_ids: this.branchIds.join(','),
                    sales_channel: this.salesChannel,
                    for_update: this.isUpdate ? 1 : 0,
                },
            }).then(r => {
                this.meta = r.data.data || {};
                this.metaLoaded = true;
            }).catch(() => { this.metaLoaded = false; });
        },
        downloadFile() {
            this.downloading = true;
            const endpoint = this.isUpdate ? '/products/bulk/export' : '/products/bulk/sample';
            axios.get(this.$apiUrl + endpoint, {
                params: { category_id: this.categoryId, branch_ids: this.branchIds.join(',') },
                responseType: 'blob',
            }).then(async (res) => {
                // An error response also arrives as a blob — detect JSON and surface it.
                if (res.data.type === 'application/json') {
                    const body = JSON.parse(await res.data.text());
                    this.showError(body.message || __('something_went_wrong'));
                    return;
                }
                const url = window.URL.createObjectURL(new Blob([res.data], {
                    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                }));
                const a = document.createElement('a');
                a.href = url;
                a.download = (this.isUpdate ? 'products_' : 'sample_') + this.categoryId + '.xlsx';
                document.body.appendChild(a);
                a.click();
                a.remove();
                window.URL.revokeObjectURL(url);
            }).catch(() => this.showError(__('something_went_wrong')))
                .finally(() => { this.downloading = false; });
        },
        submit() {
            this.isLoading = true;
            this.rowErrors = [];
            this.job = null;
            const fd = new FormData();
            fd.append('file', this.file);
            fd.append('category_id', this.categoryId);
            fd.append('branch_ids', this.branchIds.join(','));
            fd.append('sales_channel', this.salesChannel);
            const endpoint = this.isUpdate ? '/products/bulk/update' : '/products/bulk/upload';
            axios.post(this.$apiUrl + endpoint, fd, { headers: { 'Content-Type': 'multipart/form-data' } })
                .then(res => {
                    const data = res.data;
                    if (data.status === 1 && data.data && data.data.import_id) {
                        // Sync queue: this snapshot is already terminal. Async queue:
                        // it says pending/processing and we poll until done.
                        this.job = data.data;
                        this.file = null;
                        this.trackJob();
                    } else if (Array.isArray(data.errors)) {
                        this.rowErrors = data.errors;
                        this.errorCount = data.error_count || data.errors.length;
                        this.showError(data.message);
                    } else {
                        this.showError(data.message || __('something_went_wrong'));
                    }
                })
                .catch(() => this.showError(__('something_went_wrong')))
                .finally(() => { this.isLoading = false; });
        },
        trackJob() {
            if (!this.job) {
                return;
            }
            if (this.job.status === 'completed') {
                this.polling = false;
                const failed = (this.job.errors || []).length;
                if (failed) {
                    this.showError(__('some_rows_failed_during_processing'));
                } else {
                    this.showMessage('success', this.isUpdate ? __('products_updated_successfully') : __('products_imported_successfully'));
                }
                return;
            }
            if (this.job.status === 'failed') {
                this.polling = false;
                this.showError(this.job.message || __('something_went_wrong'));
                return;
            }
            // pending / processing -> poll
            this.polling = true;
            this.pollTimer = setTimeout(() => {
                axios.get(this.$apiUrl + '/products/bulk/status', { params: { id: this.job.import_id } })
                    .then(r => { this.job = r.data.data || this.job; })
                    .finally(() => this.trackJob());
            }, 1500);
        },
    },
};
</script>

<style scoped>
/* Cascading category levels sit in a flex row: wide enough to read a category
   name, narrow enough that several levels fit before wrapping. Overrides the
   global `.multiselect.form-select { width: 100% }`, which would put each level
   on its own line. */
.bulk-cat-select {
    width: 220px !important;
    flex: 0 0 auto;
}

/* Column preview. Each group is one collapsed line until it is asked for, so the
   block stays a few lines tall whatever the category's language count is. */
.col-preview-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: .5rem;
}

.col-required {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: .25rem;
    margin-bottom: .5rem;
}

.col-group + .col-group {
    border-top: 1px solid var(--bs-border-color);
}

.col-group-head {
    display: flex;
    align-items: center;
    gap: .4rem;
    width: 100%;
    padding: .35rem .25rem;
    border: 0;
    background: none;
    text-align: left;
    color: inherit;
}

.col-group-head:hover .col-group-name {
    color: var(--bs-primary);
}

.col-group-caret {
    flex: 0 0 auto;
    color: var(--app-muted, #6c757d);
    transition: transform .15s ease;
}

.col-group-caret.is-open {
    transform: rotate(90deg);
}

.col-group-name {
    font-size: .85rem;
    font-weight: 500;
}

.col-group-count {
    font-size: .72rem;
    color: var(--app-muted, #6c757d);
    background: var(--bs-secondary-bg, #e9ecef);
    border-radius: 999px;
    padding: 0 .45rem;
}

.col-group-body {
    padding: 0 .25rem .5rem 1.4rem;
}
</style>
