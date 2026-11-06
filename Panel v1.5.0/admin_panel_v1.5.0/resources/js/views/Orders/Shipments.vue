<template>
  <div>
    <div class="list-page">
      <div class="page-head">
        <h3 class="page-head-title">{{ __('shipments') }}</h3>
        <!-- The carrier's prepaid balance, where it has one: the desk sees it is running
             low before a morning's worth of bookings start failing. -->
        <span v-if="providerBalanceText" class="badge rounded-pill ms-2"
          :class="providerBalanceEmpty ? 'bg-danger' : 'bg-light text-dark'">
          {{ __('courier_account_balance') }}: {{ providerBalanceText }}
        </span>
        <span v-if="provider" class="badge rounded-pill bg-light text-dark ms-2">
          <img v-if="providerIcon" :src="providerIcon" alt="" class="sh-provider-icon me-1" />{{ provider.label }}
        </span>
        <button class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1"
          :disabled="isLoading" @click="load()">
          <RefreshCcw :size="16" /> {{ __('refresh') }}
        </button>
      </div>

      <!-- The questions a dispatch desk actually asks each morning, with counts so the
           pile is visible before anything is clicked. -->
      <div class="sh-tabs mb-3">
        <button v-for="state in states" :key="state" type="button" class="sh-tab"
          :class="{ 'is-active': filters.state === state }"
          :style="filters.state === state ? activeTabStyle : {}" @click="setState(state)">
          {{ __('shipment_state_' + state) }}
          <!-- The count carries its own colours rather than Bootstrap's utilities: the
               active tab paints itself from the theme inline, and a utility class cannot
               know whether that colour is light or dark. -->
          <span class="badge sh-count">{{ counts[state] ?? 0 }}</span>
        </button>
        <button type="button" class="sh-tab" :class="{ 'is-active': filters.state === '' }"
          :style="filters.state === '' ? activeTabStyle : {}" @click="setState('')">
          {{ __('all') }}
        </button>
      </div>

      <div class="list-surface">
        <div class="sh-filters">
          <div class="row g-2">
            <div class="col-12 col-md-4">
              <input type="search" class="form-control" v-model.trim="filters.search"
                :placeholder="__('search_by_order_awb_product_or_customer')"
                @input="debouncedLoad" @keyup.enter="load()">
            </div>
            <div class="col-12 col-md-3">
              <div class="sh-date-filter">
                <DateRangePicker class="sh-date-input" v-model="dateRange" :config="datePickerConfig"
                  @update="load()" />
                <button v-if="dateRange" class="list-icon-btn" v-b-tooltip.hover :title="__('clear')"
                  @click="clearDates()">
                  <X :size="15" />
                </button>
              </div>
            </div>
            <div class="col-12 col-md-3">
              <AppSelect v-model="filters.branch_id" :options="branchOptions" :placeholder="__('all_branches')"
                @update:model-value="load()" />
            </div>
            <div class="col-12 col-md-2">
              <b-button variant="outline-secondary" class="w-100" :disabled="isLoading" @click="resetFilters">
                {{ __('reset') }}
              </b-button>
            </div>
          </div>
        </div>

        <!-- Actions on a selection. Receipts are always available, because plenty of
               branches dispatch without any courier plugin at all; the courier actions
               appear only for parcels a courier actually holds. -->
          <div v-if="selected.length" class="sh-actions mb-3">
            <span class="fw-bold small">
              {{ selectedRows.length }} {{ selectedRows.length === 1 ? __('parcel_selected') : __('parcels_selected') }}
              <span class="text-muted">({{ selected.length }} {{ __('items') }})</span>
            </span>
            <button type="button" class="btn btn-link btn-sm p-0 text-decoration-none" @click="selected = []">
              {{ __('clear_selection') }}
            </button>

            <b-button size="sm" variant="primary" :disabled="!!busy" @click="printReceipts">
              <b-spinner v-if="busy === 'receipts'" small></b-spinner>
              <Printer :size="14" class="me-1" />{{ __('print_delivery_receipts') }}
            </b-button>

            <template v-if="selectedWithShipment.length">
              <b-button size="sm" variant="outline-secondary" :disabled="!!busy" @click="courierAction('labels')">
                <b-spinner v-if="busy === 'labels'" small></b-spinner>{{ __('print_labels') }}
              </b-button>
              <b-button size="sm" variant="outline-secondary" :disabled="!!busy" @click="courierAction('manifest')">
                <b-spinner v-if="busy === 'manifest'" small></b-spinner>{{ __('print_manifest') }}
              </b-button>
              <b-button size="sm" variant="outline-secondary" :disabled="!!busy" @click="courierAction('schedule_pickup')">
                <b-spinner v-if="busy === 'schedule_pickup'" small></b-spinner>{{ __('schedule_pickup') }}
              </b-button>
              <b-button size="sm" variant="outline-secondary" :disabled="!!busy" @click="courierAction('track')">
                <b-spinner v-if="busy === 'track'" small></b-spinner>{{ __('refresh_tracking') }}
              </b-button>
            </template>
          </div>

          <MazerDatatable responsive :items="rows" :fields="fields" :per-page="0"
            :busy="isLoading" stacked="md" show-empty small
            :tbody-tr-class="row => row && row.exception ? 'table-danger' : ''">

            <template #head(select)>
              <input type="checkbox" class="form-check-input" :checked="allSelected" @change="toggleAll">
            </template>

            <template #cell(select)="row">
              <!-- A parcel is ticked whole: every line in it goes to the same label, the
                   same manifest and the same pickup. -->
              <input type="checkbox" class="form-check-input"
                :checked="isRowSelected(row.item)" @change="toggleRow(row.item)">
            </template>

            <template #cell(order_number)="row">
              <div class="fw-bold sh-order-no" role="button" tabindex="0"
                @click="openOrder(row.item)" @keyup.enter="openOrder(row.item)">
                {{ row.item.order_number }}
              </div>
              <div class="text-muted small">{{ $filters.formatDateTime(row.item.created_at) }}</div>
            </template>

            <template #cell(item)="row">
              <!-- Everything in the box, so the desk packs from this row alone. -->
              <div v-for="line in visibleLines(row.item)" :key="line.id">
                {{ line.name }}
                <span class="text-muted small">&times; {{ line.quantity }}</span>
              </div>
              <button v-if="hiddenLineCount(row.item)" type="button"
                class="btn btn-link btn-sm p-0 text-decoration-none"
                @click="expanded[row.item.group_key] = true">
                + {{ hiddenLineCount(row.item) }} {{ __('more') }}
              </button>
              <div class="text-muted small">
                {{ row.item.item_count }} {{ row.item.item_count === 1 ? __('item') : __('items') }},
                {{ __('qty') }}: {{ row.item.quantity }}
              </div>
            </template>

            <template #cell(customer)="row">
              {{ row.item.customer_name }}
              <div class="text-muted small">{{ row.item.city }} {{ row.item.pincode }}</div>
            </template>

            <template #cell(branch_name)="row">{{ row.item.branch_name }}</template>

            <template #cell(courier)="row">
              <template v-if="row.item.awb">
                <a v-if="row.item.tracking_url" :href="row.item.tracking_url" target="_blank"
                  rel="noopener">{{ row.item.awb }}</a>
                <span v-else>{{ row.item.awb }}</span>
                <div class="text-muted small">{{ row.item.courier }}</div>
              </template>
              <template v-else-if="row.item.shipment_id">
                <span class="badge bg-warning text-dark">{{ __('waybill_pending') }}</span>
                <div class="text-muted small">{{ row.item.courier }}</div>
              </template>
              <span v-else-if="row.item.delivery_boy" class="text-muted small">{{ row.item.delivery_boy }}</span>
              <span v-else class="text-muted small">—</span>
            </template>

            <template #cell(state)="row">
              <span class="badge" :class="stateClass(row.item.state)">
                {{ __('shipment_state_' + row.item.state) }}
              </span>
              <div v-if="row.item.exception" class="text-danger small mt-1">{{ row.item.exception }}</div>
            </template>

            <template #cell(final_total)="row">
              {{ row.item.currency }}{{ row.item.final_total }}
              <div class="text-muted small">{{ row.item.payment_method }}</div>
            </template>

            <template #empty>
              <div class="text-center py-5 text-muted">
                <div class="d-flex justify-content-center mb-2">
                  <PackageOpen :size="36" />
                </div>
                <div>{{ __('nothing_to_dispatch_here') }}</div>
              </div>
            </template>
          </MazerDatatable>

          <!-- The shared footer: per-page on the left, pagination on the right. Both
               drive the server, since the rows above are one page of many. -->
          <div class="list-footer">
            <div class="list-perpage">
              <span>{{ __('per_page') }}</span>
              <b-form-select id="shipments-per-page" v-model="perPage" :options="pageOptions"
                size="sm" class="form-select"></b-form-select>
            </div>

            <b-pagination v-model="currentPage" :total-rows="total" :per-page="perPage"
              size="sm" class="mb-0 list-pagination"></b-pagination>
          </div>
      </div>
    </div>

    <OrderDetailSlider v-model="orderDrawer" :order-id="activeOrderId" :nav-list="orderNavList"
      @navigate="onOrderNavigate" @updated="load()" />
  </div>
</template>

<script>
import axios from 'axios';
import { PackageOpen, Printer, RefreshCcw, X } from 'lucide-vue-next';
import DateRangePicker from '../../components/DateRangePicker.vue';
import OrderDetailSlider from './OrderDetailSlider.vue';
import { buildDateRangeConfig, toApiDate } from '../../utils/dateRange.js';

/**
 * The dispatch desk.
 *
 * The order drawer decides how one order ships; this decides what goes out today. It
 * covers parcels with no courier plugin involved too, because a branch handing over to its
 * own rider still needs a stack of delivery receipts.
 */
export default {
  name: 'Shipments',
  components: { PackageOpen, Printer, RefreshCcw, X, DateRangePicker, OrderDetailSlider },
  data() {
    return {
      isLoading: false,
      busy: '',
      rows: [],
      total: 0,
      currentPage: 1,
      perPage: this.$perPage,
      pageOptions: this.$pageOptions,
      fields: [
        { key: 'select', label: '', sortable: false, class: 'sh-select-col' },
        { key: 'order_number', label: __('order_no'), sortable: false },
        { key: 'item', label: __('item'), sortable: false },
        { key: 'customer', label: __('customer'), sortable: false },
        { key: 'branch_name', label: __('branch'), sortable: false },
        { key: 'courier', label: __('courier'), sortable: false },
        { key: 'state', label: __('status'), sortable: false, class: 'text-center' },
        { key: 'final_total', label: __('amount'), sortable: false, class: 'text-end' },
      ],
      counts: {},
      states: [],
      provider: null,
      providerIcon: null,
      providerBalance: null,
      providerBalanceCurrency: '',
      canPrintBulk: false,
      selected: [],
      // Parcels whose full item list the desk asked to see.
      expanded: {},
      orderDrawer: false,
      activeOrderId: null,
      branches: [],
      filters: { state: 'to_dispatch', search: '', branch_id: '' },
      // One range field, same component and date format as the other list pages.
      dateRange: '',
      datePickerConfig: buildDateRangeConfig({ maxDate: new Date() }),
      searchTimer: null,
    };
  },
  watch: {
    currentPage() {
      this.load();
    },
    perPage() {
      if (this.currentPage !== 1) {
        this.currentPage = 1;   // the watcher above reloads
        return;
      }
      this.load();
    },
  },
  created() {
    this.loadBranches();
    this.load();
  },
  computed: {
    /** The panel's own theme colour, so the tabs match the rest of the install. */
    primaryColor() {
      return window.adminThemeColor || '#FE3C5E';
    },
    activeTabStyle() {
      return { backgroundColor: this.primaryColor, borderColor: this.primaryColor, color: '#fff' };
    },
    orderNavList() {
      const seen = new Set();

      return this.rows.filter(r => {
        if (seen.has(r.order_id)) return false;
        seen.add(r.order_id);
        return true;
      }).map(r => ({ id: r.order_id }));
    },
    providerBalanceText() {
      if (this.providerBalance === null || this.providerBalance === undefined) return '';
      return this.providerBalanceCurrency + Number(this.providerBalance).toFixed(2);
    },
    providerBalanceEmpty() {
      return this.providerBalance !== null && this.providerBalance !== undefined
        && Number(this.providerBalance) <= 0;
    },
    allSelected() {
      return this.rows.length > 0 && this.rows.every(r => this.isRowSelected(r));
    },
    /** Only these can be labelled, manifested, picked up or tracked. */
    selectedWithShipment() {
      return this.rows.filter(r => this.isRowSelected(r) && r.shipment_id);
    },
    /** Parcels ticked, which is what the action bar counts. */
    selectedRows() {
      return this.rows.filter(r => this.isRowSelected(r));
    },
    branchOptions() {
      return [{ id: '', name: __('all_branches') }].concat(
        this.branches.map(s => ({ id: s.id, name: s.name }))
      );
    },
  },
  methods: {
    load() {
      this.isLoading = true;
      axios.get(this.$apiUrl + '/shipments', {
        params: {
          ...this.filters,
          from: this.dateRange ? toApiDate(this.dateRange, 'start') : '',
          to: this.dateRange ? toApiDate(this.dateRange, 'end') : '',
          offset: (Math.max(1, this.currentPage) - 1) * this.perPage,
          per_page: this.perPage,
        },
      }).then(res => {
        const d = res.data;
        if (d.status !== 1) { this.showError(d.message); return; }
        this.rows = d.data.rows || [];
        this.total = d.data.total || 0;
        this.counts = d.data.counts || {};
        this.states = d.data.states || [];
        if (this.filters.state && !this.states.includes(this.filters.state)) {
          this.filters.state = 'to_dispatch';
          this.currentPage = 1;
          this.load();
          return;
        }
        this.provider = d.data.provider;
        this.canPrintBulk = !!d.data.can_print_bulk;
        // Keep only selections still on screen — a refresh moves rows between states.
        this.selected = this.selected.filter(id => this.rows.some(r => (r.order_item_ids || []).includes(id)));
      }).catch(err => {
        this.showError(err?.response?.data?.message || __('something_went_wrong'));
      }).finally(() => { this.isLoading = false; });
    },
    loadBranches() {
      axios.get(this.$apiUrl + '/branches', { params: { limit: 200 } })
        .then(res => {
          const d = res.data;
          this.branches = (d.data || []).map(s => ({ id: s.id, name: s.name }));
          if (this.provider && this.provider.key) this.loadProviderIcon();
        })
        .catch(() => { /* the branch filter is a convenience, not a requirement */ });
    },
    loadProviderIcon() {
      axios.get(this.$apiUrl + '/orders/shipping/providers')
        .then(res => {
          if (res.data.status !== 1) return;
          const match = (res.data.data.providers || []).find(p => p.key === this.provider.key);
          this.providerIcon = match && match.icon ? match.icon : null;
          // Same call carries the carrier's balance; null when it has none or was unreachable.
          this.providerBalance = match && match.balance !== undefined ? match.balance : null;
          this.providerBalanceCurrency = (match && match.balance_currency) || '';
        })
        .catch(() => { /* the icon is decoration */ });
    },
    /* Typing fires once the desk stops, not per keystroke. */
    debouncedLoad() {
      clearTimeout(this.searchTimer);
      this.searchTimer = setTimeout(() => {
        this.currentPage = 1;
        this.load();
      }, 400);
    },
    clearDates() {
      this.dateRange = '';
      this.currentPage = 1;
      this.load();
    },
    openOrder(row) {
      this.activeOrderId = row.order_id;
      this.orderDrawer = true;
    },
    onOrderNavigate(entry) {
      this.activeOrderId = entry && entry.id ? entry.id : this.activeOrderId;
    },
    setState(state) {
      this.filters.state = state;
      this.currentPage = 1;
      this.load();
    },
    resetFilters() {
      this.filters = { state: this.filters.state, search: '', branch_id: '' };
      this.dateRange = '';
      this.currentPage = 1;
      this.load();
    },
    toggleAll(e) {
      this.selected = e.target.checked ? this.rows.flatMap(r => r.order_item_ids) : [];
    },
    /** A parcel counts as selected only when every line of it is. */
    isRowSelected(row) {
      const ids = row.order_item_ids || [];
      return ids.length > 0 && ids.every(id => this.selected.includes(id));
    },
    toggleRow(row) {
      const ids = row.order_item_ids || [];
      this.selected = this.isRowSelected(row)
        ? this.selected.filter(id => !ids.includes(id))
        : this.selected.concat(ids.filter(id => !this.selected.includes(id)));
    },
    /* Long parcels are folded to the first few lines until asked for the rest. */
    visibleLines(row) {
      const lines = row.items || [];
      return (this.expanded[row.group_key] || lines.length <= 3) ? lines : lines.slice(0, 2);
    },
    hiddenLineCount(row) {
      return (row.items || []).length - this.visibleLines(row).length;
    },
    stateClass(state) {
      return {
        to_dispatch: 'bg-secondary',
        awaiting_waybill: 'bg-warning text-dark',
        ready_to_ship: 'bg-info',
        in_transit: 'bg-primary',
        delivered: 'bg-success',
        exception: 'bg-danger',
      }[state] || 'bg-secondary';
    },

    /**
     * Delivery receipts for everything selected.
     *
     * Posted as a form so the browser treats the response as a document: the endpoint
     * streams one PDF with a receipt per page, which goes straight to the printer.
     */
    printReceipts() {
      if (!this.selected.length) return;
      this.busy = 'receipts';

      axios.post(this.$apiUrl + '/shipments/receipts',
        { order_item_ids: this.selected.join(',') },
        { responseType: 'blob' })
        .then(res => {
          // A failure comes back as JSON even though a blob was asked for.
          if (res.data.type === 'application/json') {
            res.data.text().then(t => {
              let message = __('something_went_wrong');
              try { message = JSON.parse(t).message || message; } catch (e) { /* keep default */ }
              this.showError(message);
            });
            return;
          }
          const url = URL.createObjectURL(res.data);
          window.open(url, '_blank', 'noopener');
          // Give the new tab time to take the blob before it is revoked.
          setTimeout(() => URL.revokeObjectURL(url), 60000);
        })
        .catch(err => {
          this.showError(err?.response?.data?.message || __('something_went_wrong'));
        })
        .finally(() => { this.busy = ''; });
    },

    /** Labels, manifest, pickup and tracking — courier parcels only. */
    courierAction(action) {
      const ids = this.selectedWithShipment.flatMap(r => r.order_item_ids);
      if (!ids.length) return;

      this.busy = action;
      axios.post(this.$apiUrl + '/shipments/' + action, { order_item_ids: ids.join(',') })
        .then(res => {
          const d = res.data;
          if (d.status !== 1) { this.showError(d.message); return; }

          const documents = (d.data && d.data.documents) || [];
          documents.forEach(doc => window.open(doc.url, '_blank', 'noopener'));

          // Partial success is normal: one order's label can fail while the rest print,
          // and a desk needs to know which before walking to the printer.
          const failures = (d.data && d.data.failures) || [];
          if (failures.length) {
            this.showError(failures.join(' '));
          } else if (!documents.length) {
            this.showMessage('success', d.message);
          }

          if (action === 'track' || action === 'schedule_pickup') this.load();
        })
        .catch(err => {
          this.showError(err?.response?.data?.message || __('something_went_wrong'));
        })
        .finally(() => { this.busy = ''; });
    },
  },
};
</script>

<style>
.sh-order-no {
    color: inherit;
    cursor: pointer;
}

.sh-order-no:hover {
    text-decoration: underline;
}

.sh-select-col {
    width: 36px;
    padding-inline: .6rem;
    text-align: center;
}
</style>

<style scoped>
/* Same shape as the other list pages' range filter: the field with a clear button
   beside it. */
.sh-date-filter {
    display: flex;
    align-items: center;
    gap: .4rem;
}

.sh-date-input {
    flex: 1 1 auto;
    min-width: 0;
}

/* The filter row sits on the surface, above the table, like a toolbar. */
.sh-filters {
    padding: .75rem 1rem;
    border-bottom: 1px solid var(--app-card-border);
}

.sh-actions {
    margin: .75rem 1rem 0;
}

.page-content {
  padding-bottom: 2rem;
}

.sh-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: .5rem;
}

.sh-tab {
  display: inline-flex;
  align-items: center;
  gap: .4rem;
  border: 1px solid var(--bs-border-color, #dee2e6);
  background: var(--app-card-bg, #fff);
  border-radius: 999px;
  padding: .35rem .85rem;
  font-size: .85rem;
  cursor: pointer;
}

.sh-tab.is-active {
  /* Colour comes from the theme, bound inline — this only carries the weight. */
  font-weight: 600;
}

.sh-count {
  background: rgba(0, 0, 0, .08);
  color: inherit;
  font-weight: 600;
  font-size: .72rem;
  line-height: 1;
  padding: .3em .55em;
}

/* On the themed tab the pill is a hole punched in the colour, so it reads at any
   theme colour instead of guessing at a light or dark utility class. */
.sh-tab.is-active .sh-count {
  background: rgba(255, 255, 255, .28);
  color: #fff;
}

.sh-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: .5rem;
  padding: .6rem .75rem;
  border: 1px solid var(--bs-border-color, #dee2e6);
  border-radius: .5rem;
  background: rgba(0, 0, 0, .03);
}

.sh-provider-icon {
  height: 13px;
  width: auto;
  max-width: 80px;
  object-fit: contain;
  vertical-align: -2px;
}
</style>
