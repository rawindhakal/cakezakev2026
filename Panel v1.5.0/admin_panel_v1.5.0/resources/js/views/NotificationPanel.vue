<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('notifications') }}</h3>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input id="filter-input" v-model="filter" type="search" class="form-control"
                        :placeholder="__('search')">
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getNotifications()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive :items="notifications" :fields="fields"
                v-model:sort-by="sortBy" v-model:sort-desc="sortDesc"
                :sort-direction="sortDirection" :busy="isLoading" stacked="md" show-empty
                small>
                <template #cell(title)="row">
                    <button type="button" class="notif-row" :class="{ 'is-unread': !row.item.read_at }"
                        @click="openNotification(row.item)">
                        <span class="notif-row-icon"
                            v-b-tooltip.hover :title="row.item.read_at ? __('read') : __('unread')">
                            <component :is="row.item.read_at ? Bell : BellDot" :size="15" />
                        </span>
                        <span class="notif-row-text">{{ row.item.data.text }}</span>
                    </button>
                </template>

                <template #cell(created_at)="row">
                    <span v-b-tooltip.hover :title="$filters.formatDateTime(row.item.created_at)">
                        {{ timeAgo(row.item.created_at) }}
                    </span>
                </template>

                <template #cell(actions)="row">
                    <div class="list-actions">
                        <button class="list-action-btn is-delete" @click="deleteNotification(row.item)"
                            v-b-tooltip.hover :title="__('delete')">
                            <Trash2 :size="15" />
                        </button>
                    </div>
                </template>
            </MazerDatatable>

            <div class="list-footer">
                <div class="list-perpage">
                    <span>{{ __('per_page') }}</span>
                    <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions" size="sm"
                        class="form-select"></b-form-select>
                    <span class="list-range">{{ __('total_records') }} : {{ totalRows }}</span>
                </div>

                <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage" size="sm"
                    class="mb-0 list-pagination"></b-pagination>
            </div>
        </div>

        <!-- Notifications open their record in place rather than navigating away. -->
        <OrderDetailSlider v-model="orderSliderShow" :order-id="activeOrderId" @updated="getNotifications" />
        <ReturnDetailSlider v-model="returnSliderShow" :record="activeReturn" @updated="getNotifications" />
    </div>
</template>
<script>
import { markRaw } from 'vue';
import { Search, RefreshCw, Trash2, Bell, BellDot } from 'lucide-vue-next';
import OrderDetailSlider from './Orders/OrderDetailSlider.vue';
import ReturnDetailSlider from './ReturnRequests/ReturnDetailSlider.vue';

export default {
    components: {
        Search,
        RefreshCw,
        Trash2,
        OrderDetailSlider,
        ReturnDetailSlider,
    },
    data: function () {
        return {
            // Icons used inside <component :is>, so keep them out of the reactive proxy.
            Bell: markRaw(Bell),
            BellDot: markRaw(BellDot),
            fields: [
                { key: 'title', label: __('title'), sortable: false, class: 'text-center' },
                { key: 'created_at', label: __('time'), sortable: false, class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false, class: 'text-center' },
            ],
            totalRows: 1,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            sortBy: '',
            sortDesc: false,
            sortDirection: 'asc',
            filter: '',
            page: 1,
            _searchTimer: null,
            isLoading: false,
            notifications: [],

            orderSliderShow: false,
            activeOrderId: null,
            returnSliderShow: false,
            activeReturn: null,
        }
    },
    created: function () {
        this.getNotifications();
    },
    watch: {
        currentPage() {
            this.getNotifications();
        },
        perPage() {
            this.currentPage = 1;
            this.getNotifications();
        },
        // Search runs server-side; debounce so typing doesn't fire a request per key.
        filter() {
            clearTimeout(this._searchTimer);
            this._searchTimer = setTimeout(() => {
                this.currentPage = 1;
                this.getNotifications();
            }, 350);
        },
    },
    beforeUnmount() {
        clearTimeout(this._searchTimer);
    },
    methods: {
        getNotifications() {
            this.isLoading = true
            let param = {
                page: this.currentPage,
                per_page: this.perPage,
                search: this.filter || '',
            }
            axios.get(this.$apiUrl + '/panel_notification', {
                params: param
            }).then((response) => {
                this.isLoading = false;
                let data = response.data;
                this.notifications = data.data;
                this.totalRows = response.data.total
            }).catch(() => { this.isLoading = false; });
        },

        /** Return-flow notifications carry the return request they belong to. */
        isReturn(item) {
            return !!(item.data && item.data.return_request_id);
        },

        // "23h ago" / "5d ago" — the exact timestamp is on the tooltip.
        timeAgo(value) {
            if (!value) return '';
            let s = String(value).replace(' ', 'T');
            if (!/[zZ]|[+-]\d{2}:?\d{2}$/.test(s)) s += 'Z';
            const then = new Date(s);
            if (isNaN(then)) return '';

            const secs = Math.max(0, Math.floor((Date.now() - then.getTime()) / 1000));
            if (secs < 60) return __('just_now');
            const mins = Math.floor(secs / 60);
            if (mins < 60) return `${mins}m ${__('ago')}`;
            const hours = Math.floor(mins / 60);
            if (hours < 24) return `${hours}h ${__('ago')}`;
            const days = Math.floor(hours / 24);
            if (days < 30) return `${days}d ${__('ago')}`;
            const months = Math.floor(days / 30);
            if (months < 12) return `${months}mo ${__('ago')}`;
            return `${Math.floor(months / 12)}y ${__('ago')}`;
        },

        openNotification(item) {
            this.markAsRead(item);

            if (this.isReturn(item)) {
                this.openReturn(item.data.return_request_id);
                return;
            }

            this.activeOrderId = item.data.order_id;
            this.orderSliderShow = true;
        },

        // The slider wants the whole record, and there is no fetch-one endpoint —
        // pull the list and pick the row out of it.
        openReturn(returnId) {
            axios.get(this.$apiUrl + '/return_requests')
                .then(res => {
                    const rows = res.data?.data || [];
                    const record = rows.find(r => Number(r.id) === Number(returnId));
                    if (!record) {
                        this.showError(__('return_request_not_found'));
                        return;
                    }
                    this.activeReturn = record;
                    this.returnSliderShow = true;
                })
                .catch(() => this.showError(__('something_went_wrong')));
        },

        markAsRead(item) {
            if (item.read_at) return;
            axios.get(this.$apiUrl + '/notification_read?id=' + item.id)
                .then(() => {
                    item.read_at = new Date().toISOString();
                    window.dispatchEvent(new Event('chat:refresh-unread'));
                })
                .catch(() => { /* reading is best-effort; don't block the slider */ });
        },

        deleteNotification(item) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('you_will_not_be_able_to_revert_this'),
                confirmButtonText: __('yes_sure'),
                cancelButtonText: __('cancel'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (!result.value) return;
                axios.post(this.$apiUrl + '/panel_notification/delete', { id: item.id })
                    .then(res => {
                        if (res.data.status === 1) {
                            this.showMessage('success', res.data.message);
                            this.getNotifications();
                        } else {
                            this.showError(res.data.message);
                        }
                    })
                    .catch(() => this.showError(__('something_went_wrong')));
            });
        },
    }
};
</script>

<style scoped>
/* Row reads like the header dropdown: icon chip + message, bold while unread. */
.notif-row {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    width: 100%;
    padding: 0;
    border: none;
    background: transparent;
    text-align: start;
    cursor: pointer;
    color: var(--app-ink);
}
.notif-row-icon {
    flex-shrink: 0;
    width: 30px;
    height: 30px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 8px;
    background-color: rgba(var(--bs-primary-rgb), 0.1);
    color: var(--bs-primary);
}
.notif-row-text {
    font-size: 0.82rem;
    line-height: 1.35;
    white-space: normal;
    word-break: break-word;
}
.notif-row:hover .notif-row-text {
    color: var(--bs-primary);
}
/* Unread: the bell keeps its dot and the chip stays in the primary tint.
   Read: a plain bell, muted, so the row recedes. */
.notif-row:not(.is-unread) .notif-row-icon {
    background-color: var(--app-hover);
    color: var(--app-muted);
}
</style>
