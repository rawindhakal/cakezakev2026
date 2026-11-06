<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('activity_logs') }}</h3>
            <button class="btn btn-outline-danger ms-auto d-inline-flex align-items-center gap-1"
                @click="clearModal = true" v-if="$can('manage_activity_logs')">
                <Trash2 :size="16" /> {{ __('clear_logs') }}
            </button>
            <router-link to="/settings" class="btn btn-outline-secondary ms-2 d-inline-flex align-items-center gap-1">
                <ArrowLeft :size="16" /> {{ __('back') }}
            </router-link>
        </div>

        <div class="list-surface">
            <div class="list-toolbar flex-wrap gap-2">
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input v-model="filters.search" type="search" class="form-control"
                        :placeholder="__('search')" @input="onFilterChange">
                </div>

                <AppSelect class="form-select w-auto" v-model="filters.log_name" :options="logNameOptions"
                    @update:model-value="load(1)" />

                <AppSelect class="form-select w-auto" v-model="filters.event" :options="eventOptions"
                    @update:model-value="load(1)" />

                <AppSelect class="form-select w-auto" v-model="filters.subject_type" :options="subjectTypeOptions"
                    @update:model-value="load(1)" />

                <AppSelect class="form-select w-auto" v-model="filters.causer_id" :options="causerOptions"
                    @update:model-value="load(1)" />

                <div class="al-daterange">
                    <date-range-picker v-model="dateRange" :config="datePickerConfig" @update="load(1)" />
                </div>
                <button v-if="dateRange" class="list-icon-btn" v-b-tooltip.hover :title="__('clear')"
                    @click="dateRange = ''; load(1)">
                    <X :size="16" />
                </button>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="load(currentPage)">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable :items="logs" :fields="fields" :busy="isLoading" stacked="md" show-empty small>
                <template #cell(created_at)="row">
                    <span class="text-nowrap">{{ $filters.formatDateTime(row.item.created_at) }}</span>
                </template>

                <template #cell(event)="row">
                    <span class="badge" :class="eventBadge(row.item.event)">{{ eventLabel(row.item.event) }}</span>
                </template>

                <template #cell(subject)="row">
                    <div v-if="row.item.subject_type">
                        <strong>{{ row.item.subject_type }}</strong>
                        <span class="text-muted" v-if="row.item.subject_id"> #{{ row.item.subject_id }}</span>
                        <div class="small text-muted" v-if="row.item.subject_label">{{ row.item.subject_label }}</div>
                    </div>
                    <span class="text-muted" v-else>—</span>
                </template>

                <template #cell(causer)="row">
                    <div v-if="row.item.causer_name">
                        {{ row.item.causer_name }}
                        <div class="small text-muted" v-if="row.item.causer_role">{{ row.item.causer_role }}</div>
                    </div>
                    <span class="text-muted" v-else>{{ __('system') }}</span>
                </template>

                <template #cell(actions)="row">
                    <button class="list-action-btn" v-b-tooltip.hover :title="__('view')" @click="detail = row.item">
                        <Eye :size="15" />
                    </button>
                </template>
            </MazerDatatable>

            <div class="list-footer">
                <div class="list-perpage">
                    <span>{{ __('per_page') }}</span>
                    <b-form-select v-model="perPage" :options="pageOptions" size="sm" class="form-select" />
                    <span class="list-range">{{ __('total_records') }} : {{ totalRows }}</span>
                </div>
                <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage" size="sm"
                    class="mb-0 list-pagination" />
            </div>
        </div>

        <!-- Entry detail: what changed, and the request context it happened in. -->
        <b-modal :model-value="!!detail" @update:model-value="detail = null" :title="__('activity_detail')"
            size="lg" scrollable centered no-fade hide-footer>
            <div v-if="detail">
                <div class="row mb-3">
                    <div class="col-md-6"><strong>{{ __('event') }}:</strong> {{ eventLabel(detail.event) }}</div>
                    <div class="col-md-6"><strong>{{ __('date') }}:</strong> {{ $filters.formatDateTime(detail.created_at) }}</div>
                    <div class="col-md-6"><strong>{{ __('module') }}:</strong> {{ detail.subject_type || '—' }}
                        <span v-if="detail.subject_id">#{{ detail.subject_id }}</span></div>
                    <div class="col-md-6"><strong>{{ __('user') }}:</strong> {{ detail.causer_name || __('system') }}</div>
                    <div class="col-md-6"><strong>{{ __('ip_address') }}:</strong> {{ detail.ip_address || '—' }}</div>
                    <div class="col-md-6"><strong>{{ __('description') }}:</strong> {{ detail.description }}</div>
                    <div class="col-12 small text-muted mt-1" v-if="detail.url">{{ detail.method }} {{ detail.url }}</div>
                </div>

                <div v-if="detail.changes && detail.changes.length">
                    <label class="fw-bold">{{ __('changes') }}</label>
                    <div class="table-responsive">
                        <table class="table table-sm table-striped">
                            <thead>
                                <tr>
                                    <th>{{ __('field') }}</th>
                                    <th>{{ __('old_value') }}</th>
                                    <th>{{ __('new_value') }}</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr v-for="(c, i) in detail.changes" :key="i">
                                    <td class="fw-bold">{{ c.field }}</td>
                                    <td class="text-muted">{{ display(c.old) }}</td>
                                    <td>{{ display(c.new) }}</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
                <p class="text-muted mb-0" v-else>{{ __('no_field_changes_recorded') }}</p>
            </div>
        </b-modal>

        <!-- Pruning -->
        <b-modal v-model="clearModal" :title="__('clear_logs')" centered no-fade>
            <p>{{ __('clear_activity_logs_hint') }}</p>
            <div class="form-group">
                <label>{{ __('delete_entries_older_than') }}</label>
                <AppSelect class="form-select" v-model="clearDays" :options="clearDaysOptions" :searchable="false" />
            </div>
            <template #footer>
                <b-button variant="secondary" @click="clearModal = false">{{ __('cancel') }}</b-button>
                <b-button variant="danger" :disabled="clearing" @click="clearLogs">
                    <b-spinner small v-if="clearing" /> {{ __('delete') }}
                </b-button>
            </template>
        </b-modal>
    </div>
</template>

<script>
import DateRangePicker from '../../components/DateRangePicker.vue';
import { buildDateRangeConfig, toApiDate } from '../../utils/dateRange.js';
import { ArrowLeft, RefreshCw, Search, Eye, Trash2, X } from 'lucide-vue-next';

export default {
    components: { DateRangePicker, ArrowLeft, RefreshCw, Search, Eye, Trash2, X },
    data() {
        return {
            fields: [
                { key: 'created_at', label: __('date'), class: 'text-left', thStyle: { width: '15%' } },
                { key: 'event', label: __('event'), class: 'text-left', thStyle: { width: '12%' } },
                { key: 'subject', label: __('module'), class: 'text-left', thStyle: { width: '22%' } },
                { key: 'description', label: __('description'), class: 'text-left' },
                { key: 'causer', label: __('user'), class: 'text-left', thStyle: { width: '15%' } },
                { key: 'actions', label: __('actions'), sortable: false, class: 'text-center', thStyle: { width: '8%' } },
            ],
            logs: [],
            options: { log_names: [], events: [], subject_types: [], causers: [] },
            filters: { search: '', log_name: '', event: '', subject_type: '', causer_id: '' },
            dateRange: '',
            // No future entries exist, so block forward dates.
            datePickerConfig: buildDateRangeConfig({ maxDate: new Date() }),
            detail: null,
            isLoading: false,
            totalRows: 0,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            clearModal: false,
            clearDays: 90,
            clearing: false,
            searchTimer: null,
        };
    },
    watch: {
        currentPage() { this.load(this.currentPage); },
        perPage() { this.load(1); },
    },
    created() {
        this.load(1);
        this.loadFilters();
    },
    computed: {
        // The API returns plain string lists; AppSelect works in { id, name }.
        logNameOptions() {
            return [{ id: '', name: __('all_log_types') }]
                .concat((this.options.log_names || []).map(n => ({ id: n, name: n })));
        },
        eventOptions() {
            return [{ id: '', name: __('all_events') }]
                .concat((this.options.events || []).map(e => ({ id: e, name: this.eventLabel(e) })));
        },
        subjectTypeOptions() {
            return [{ id: '', name: __('all_modules') }]
                .concat((this.options.subject_types || []).map(t => ({ id: t, name: t })));
        },
        causerOptions() {
            return [{ id: '', name: __('all_users') }].concat(this.options.causers || []);
        },
        // Fixed option set — no search box needed.
        clearDaysOptions() {
            return [
                { id: 90, name: '90' + ' ' + (__('days')) },
                { id: 30, name: '30' + ' ' + (__('days')) },
                { id: 7, name: '7' + ' ' + (__('days')) },
                { id: 0, name: (__('everything')) },
            ];
        },
    },
    methods: {
        load(page) {
            this.currentPage = page || this.currentPage;
            this.isLoading = true;
            const params = {
                ...this.filters,
                start_date: toApiDate(this.dateRange, 'start'),
                end_date: toApiDate(this.dateRange, 'end'),
                limit: this.perPage,
                offset: (this.currentPage - 1) * this.perPage,
            };
            axios.get(this.$apiUrl + '/activity_logs', { params })
                .then(r => {
                    this.logs = r.data.data || [];
                    this.totalRows = r.data.total || 0;
                })
                .catch(() => this.showError(__('something_went_wrong')))
                .finally(() => { this.isLoading = false; });
        },
        loadFilters() {
            axios.get(this.$apiUrl + '/activity_logs/filters')
                .then(r => { this.options = r.data.data || this.options; })
                .catch(() => {});
        },
        onFilterChange() {
            // Debounced so typing doesn't fire a request per keystroke.
            clearTimeout(this.searchTimer);
            this.searchTimer = setTimeout(() => this.load(1), 400);
        },
        clearLogs() {
            this.clearing = true;
            axios.post(this.$apiUrl + '/activity_logs/clear', { older_than_days: this.clearDays })
                .then(r => {
                    this.showMessage('success', r.data.message);
                    this.clearModal = false;
                    this.load(1);
                    this.loadFilters();
                })
                .catch(() => this.showError(__('something_went_wrong')))
                .finally(() => { this.clearing = false; });
        },
        eventLabel(e) {
            return __(e) !== e ? __(e) : String(e).replace(/_/g, ' ');
        },
        eventBadge(e) {
            switch (e) {
                case 'created': return 'bg-success';
                case 'updated': return 'bg-primary';
                case 'deleted': return 'bg-danger';
                case 'login': return 'bg-info';
                case 'logout': return 'bg-secondary';
                case 'failed_login':
                case 'lockout': return 'bg-warning';
                default: return 'bg-secondary';
            }
        },
        display(v) {
            if (v === null || v === undefined || v === '') return '—';
            if (typeof v === 'object') return JSON.stringify(v);
            return String(v);
        },
    },
};
</script>

<style scoped>
.al-daterange {
    min-width: 230px;
}
</style>
