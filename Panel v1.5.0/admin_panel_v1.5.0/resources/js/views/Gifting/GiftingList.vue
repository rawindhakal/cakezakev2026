<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ cfg.title }}</h3>
            <button v-if="$can('brand_create')" class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2"
                @click="openForm()">
                <Plus :size="16" /><span>Add {{ cfg.single }}</span>
            </button>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input v-model="filter" type="search" class="form-control" :placeholder="__('search')">
                </div>
                <button class="list-icon-btn" @click="load"><RefreshCw :class="{ 'is-spinning': loading }" /></button>
            </div>

            <div class="table-responsive">
                <table class="table align-middle">
                    <thead>
                        <tr>
                            <th>#</th><th>Name</th><th>Slug</th>
                            <th v-for="c in cfg.cols" :key="c.key">{{ c.label }}</th>
                            <th>Products</th><th>Status</th><th class="text-end">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-if="!rows.length"><td :colspan="6 + cfg.cols.length" class="text-center text-muted py-4">{{ __('no_records_found') }}</td></tr>
                        <tr v-for="r in rows" :key="r.id">
                            <td>{{ r.sort_order }}</td>
                            <td class="fw-semibold">{{ r.name }}</td>
                            <td class="text-muted">{{ r.slug }}</td>
                            <td v-for="c in cfg.cols" :key="c.key">{{ r[c.key] ?? '—' }}</td>
                            <td>{{ r.products_count }}</td>
                            <td><span class="status-pill" :class="r.status == 1 ? 'is-active' : 'is-inactive'">{{ r.status == 1 ? __('active') : __('deactive') }}</span></td>
                            <td class="text-end">
                                <div class="list-actions justify-content-end">
                                    <button v-if="$can('brand_update')" class="list-action-btn is-edit" @click="openForm(r)"><Pencil :size="15" /></button>
                                    <button v-if="$can('brand_delete')" class="list-action-btn is-delete" @click="remove(r)"><Trash2 :size="15" /></button>
                                </div>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>

        <div v-if="form" class="modal d-block" style="background:rgba(0,0,0,.45)" @click.self="form = null">
            <div class="modal-dialog modal-dialog-centered">
                <form class="modal-content" @submit.prevent="save">
                    <div class="modal-header">
                        <h5 class="modal-title">{{ form.id ? 'Edit' : 'Add' }} {{ cfg.single }}</h5>
                        <button type="button" class="btn-close" @click="form = null"></button>
                    </div>
                    <div class="modal-body d-grid gap-3">
                        <div><label class="form-label">Name</label><input v-model="form.name" class="form-control" required></div>
                        <div><label class="form-label">Slug <small class="text-muted">(auto from name if empty)</small></label><input v-model="form.slug" class="form-control"></div>
                        <div v-for="c in cfg.cols" :key="c.key">
                            <label class="form-label">{{ c.label }}</label>
                            <textarea v-if="c.type === 'text'" v-model="form[c.key]" class="form-control" rows="2"></textarea>
                            <input v-else v-model="form[c.key]" :type="c.type || 'text'" class="form-control" :placeholder="c.hint">
                        </div>
                        <div class="row">
                            <div class="col"><label class="form-label">Sort order</label><input v-model.number="form.sort_order" type="number" min="0" class="form-control"></div>
                            <div class="col"><label class="form-label">Status</label>
                                <select v-model.number="form.status" class="form-select"><option :value="1">{{ __('active') }}</option><option :value="0">{{ __('deactive') }}</option></select>
                            </div>
                        </div>
                        <div><label class="form-label">Image (optional)</label><input type="file" accept="image/*" class="form-control" @change="file = $event.target.files[0]"></div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-light" @click="form = null">{{ __('cancel') }}</button>
                        <button class="btn btn-primary" :disabled="saving">{{ __('save') }}</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import { Plus, Search, RefreshCw, Pencil, Trash2 } from 'lucide-vue-next';

const CONFIG = {
    occasions: { title: 'Occasions', single: 'occasion', cols: [{ key: 'occasion_date', label: 'Date note', hint: 'e.g. 11th May' }] },
    relationships: { title: 'Shop by Relationship', single: 'relationship', cols: [] },
    delivery_types: {
        title: 'Delivery Types', single: 'delivery type',
        cols: [
            { key: 'lead_minutes', label: 'Lead time (min)', type: 'number', hint: 'Minimum notice / delivery time' },
            { key: 'extra_charge', label: 'Extra charge', type: 'number' },
            { key: 'time_window', label: 'Time window', hint: 'e.g. 23:00-23:59' },
            { key: 'description', label: 'Description', type: 'text' },
        ],
    },
};

export default {
    components: { Plus, Search, RefreshCw, Pencil, Trash2 },
    props: { type: { type: String, required: true } },
    data() { return { all: [], filter: '', loading: false, form: null, file: null, saving: false }; },
    computed: {
        cfg() { return CONFIG[this.type]; },
        rows() {
            const q = this.filter.toLowerCase();
            return this.all.filter(r => !q || r.name.toLowerCase().includes(q) || r.slug.includes(q));
        },
    },
    watch: { type() { this.load(); } },
    mounted() { this.load(); },
    methods: {
        load() {
            this.loading = true;
            axios.get(`${this.$apiUrl}/gifting/${this.type}`).then(r => { this.all = r.data.data || []; }).finally(() => { this.loading = false; });
        },
        openForm(r) { this.file = null; this.form = r ? { ...r } : { name: '', slug: '', sort_order: 0, status: 1 }; },
        save() {
            const fd = new FormData();
            Object.entries(this.form).forEach(([k, v]) => { if (v !== null && v !== undefined && k !== 'products_count' && k !== 'image') fd.append(k, v); });
            if (this.file) fd.append('image', this.file);
            this.saving = true;
            axios.post(`${this.$apiUrl}/gifting/${this.type}/${this.form.id ? 'update' : 'save'}`, fd)
                .then(r => {
                    if (r.data.status === 0) { this.$toastr?.error?.(r.data.message); return; }
                    this.form = null; this.load();
                })
                .catch(e => this.$toastr?.error?.(e.response?.data?.message || 'Error'))
                .finally(() => { this.saving = false; });
        },
        remove(r) {
            this.$swal.fire({ title: `Delete ${r.name}?`, icon: 'warning', showCancelButton: true }).then(res => {
                if (res.isConfirmed) axios.post(`${this.$apiUrl}/gifting/${this.type}/delete`, { id: r.id }).then(this.load);
            });
        },
    },
};
</script>
