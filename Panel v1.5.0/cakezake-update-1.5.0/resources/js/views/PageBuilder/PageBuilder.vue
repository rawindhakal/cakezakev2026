<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('manage_page_builder') }}</h3>
            <button class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                @click="openCreate" v-if="$can('page_builder_create')">
                <Plus :size="16" /><span>{{ __('new_page') }}</span>
            </button>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input type="search" v-model="filter" class="form-control" :placeholder="__('search')">
                </div>
                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="loadPages">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive :items="pages" :fields="fields" :filter="filter"
                :filter-included-fields="['name', 'slug']" :busy="isLoading"
                stacked="md" show-empty small :empty-text="__('no_records_found')">

                <template #cell(name)="row">
                    <span>{{ row.item.name }}</span>
                </template>
                <template #cell(slug)="row">
                    <code class="small">{{ row.item.slug }}</code>
                </template>
                <template #cell(status)="row">
                    <span class="status-pill" :class="row.item.status === 'published' ? 'is-active' : 'is-warning'">
                        {{ row.item.status === 'published' ? __('published') : __('draft') }}
                    </span>
                </template>
                <template #cell(published_at)="row">
                    <span>{{ formatLocal(row.item.published_at) || '-' }}</span>
                </template>
                <template #cell(active)="row">
                    <div class="form-check form-switch mb-0 d-flex justify-content-center">
                        <input class="form-check-input" type="checkbox" role="switch"
                            :checked="row.item.is_active"
                            :disabled="row.item.status !== 'published' || !$can('page_builder_update')"
                            :title="row.item.status !== 'published' ? __('only_published_page_can_be_activated') : ''"
                            @change="toggleActive(row.item, $event.target.checked)">
                    </div>
                </template>
                <template #cell(actions)="row">
                    <div class="list-actions">
                        <router-link :to="`/page_builder/edit/${row.item.id}`" class="list-action-btn is-edit"
                            v-if="$can('page_builder_update')" v-b-tooltip.hover :title="__('edit')">
                            <Pencil :size="15" />
                        </router-link>
                        <button class="list-action-btn is-edit" @click="clonePage(row.item)"
                            v-if="$can('page_builder_create')" v-b-tooltip.hover :title="__('clone')">
                            <Copy :size="15" />
                        </button>
                        <button class="list-action-btn is-delete" @click="confirmDelete(row.item)"
                            v-if="$can('page_builder_delete')" v-b-tooltip.hover :title="__('delete')">
                            <Trash2 :size="15" />
                        </button>
                    </div>
                </template>
            </MazerDatatable>
        </div>

        <!-- New page: only a name is needed; everything else lives in the editor. -->
        <b-modal v-model="create.show" :title="__('new_page')" centered :no-footer="true">
            <div class="form-group mb-3">
                <label class="form-label">{{ __('name') }}</label>
                <input type="text" class="form-control" v-model="create.name" :placeholder="__('enter_page_name')"
                    @keyup.enter="doCreate">
            </div>
            <div class="d-flex justify-content-end gap-2">
                <button class="btn btn-outline-secondary" @click="create.show = false">{{ __('cancel') }}</button>
                <button class="btn btn-primary" :disabled="!create.name.trim() || create.saving" @click="doCreate">
                    <b-spinner small v-if="create.saving"></b-spinner>
                    {{ __('save') }}
                </button>
            </div>
        </b-modal>
    </div>
</template>

<script>
import axios from 'axios';
import { Plus, Search, RefreshCw, Pencil, Trash2, Copy } from 'lucide-vue-next';

export default {
    name: 'PageBuilder',
    components: { Plus, Search, RefreshCw, Pencil, Trash2, Copy },
    data() {
        return {
            pages: [],
            isLoading: false,
            filter: '',
            create: { show: false, name: '', saving: false },
            fields: [
                { key: 'name', label: __('name'), sortable: false },
                { key: 'slug', label: __('slug'), sortable: false },
                { key: 'status', label: __('status'), class: 'text-center', sortable: false },
                { key: 'published_at', label: __('published_at'), class: 'text-center', sortable: false },
                { key: 'active', label: __('active'), class: 'text-center', sortable: false },
                { key: 'actions', label: __('actions'), class: 'text-center', sortable: false },
            ],
        };
    },
    created() {
        this.loadPages();
    },
    methods: {
        formatLocal(iso) {
            if (!iso) return '';
            const d = new Date(iso);
            return isNaN(d.getTime()) ? '' : d.toLocaleString();
        },
        loadPages() {
            this.isLoading = true;
            axios.get(this.$apiUrl + '/page_layouts')
                .then(res => { this.pages = res.data?.data || []; })
                .catch(() => { this.pages = []; })
                .finally(() => { this.isLoading = false; });
        },
        openCreate() {
            this.create = { show: true, name: '', saving: false };
        },
        doCreate() {
            const name = this.create.name.trim();
            if (!name || this.create.saving) return;
            this.create.saving = true;
            axios.post(this.$apiUrl + '/page_layouts/save', { name })
                .then(res => {
                    if (res.data?.status === 0) {
                        this.showError(res.data?.message || __('something_went_wrong'));
                        return;
                    }
                    this.create.show = false;
                    const id = res.data?.data?.id;
                    if (id) this.$router.push(`/page_builder/edit/${id}`);
                    else this.loadPages();
                })
                .catch(err => { this.showError(err.response?.data?.message || __('something_went_wrong')); })
                .finally(() => { this.create.saving = false; });
        },
        clonePage(page) {
            const form = new FormData();
            form.append('id', page.id);
            axios.post(this.$apiUrl + '/page_layouts/clone', form)
                .then(res => {
                    if (res.data?.status === 0) {
                        this.showError(res.data?.message || __('something_went_wrong'));
                        return;
                    }
                    this.showMessage('success', __('page_cloned_successfully'));
                    const id = res.data?.data?.id;
                    if (id) this.$router.push(`/page_builder/edit/${id}`);
                    else this.loadPages();
                })
                .catch(err => { this.showError(err.response?.data?.message || __('something_went_wrong')); });
        },
        toggleActive(page, checked) {
            const form = new FormData();
            form.append('id', page.id);
            form.append('is_active', checked ? 1 : 0);
            axios.post(this.$apiUrl + '/page_layouts/toggle_active', form)
                .then(res => {
                    if (res.data?.status === 0) {
                        this.showError(res.data.message || __('something_went_wrong'));
                        page.is_active = !checked; // revert UI
                        return;
                    }
                    page.is_active = checked;
                    this.showMessage('success', res.data?.message || __('page_status_updated'));
                })
                .catch(err => {
                    page.is_active = !checked; // revert UI
                    this.showError(err.response?.data?.message || __('something_went_wrong'));
                });
        },
        confirmDelete(page) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('this_page_will_be_deleted'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('yes_delete'),
                cancelButtonText: __('cancel'),
            }).then(result => {
                if (result.isConfirmed) this.deletePage(page, false);
            });
        },
        // First pass reports who still redirects to the page; a second confirm forces it.
        deletePage(page, force) {
            const form = new FormData();
            form.append('id', page.id);
            if (force) form.append('force', 1);
            axios.post(this.$apiUrl + '/page_layouts/delete', form)
                .then(res => {
                    if (res.data?.status === 0) {
                        this.showError(res.data.message || __('something_went_wrong'));
                        return;
                    }
                    if (res.data?.data?.in_use) {
                        this.confirmForceDelete(page, res.data.data.used_by || []);
                        return;
                    }
                    this.showMessage('success', res.data?.message || __('page_deleted_successfully'));
                    this.loadPages();
                })
                .catch(err => { this.showError(err.response?.data?.message || __('something_went_wrong')); });
        },
        confirmForceDelete(page, usedBy) {
            this.$swal.fire({
                title: __('page_in_use'),
                html: '<p>' + __('page_in_use_by') + '</p><p><b>' + usedBy.map(n => this.escapeHtml(n)).join('</b>, <b>') + '</b></p><p>' + __('page_in_use_delete_anyway') + '</p>',
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('yes_delete'),
                cancelButtonText: __('cancel'),
                confirmButtonColor: '#d33',
            }).then(result => {
                if (result.isConfirmed) this.deletePage(page, true);
            });
        },
        escapeHtml(s) {
            return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
        },
    },
};
</script>
