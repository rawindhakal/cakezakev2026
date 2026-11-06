<template>
    <div class="dataTable-wrapper datatable-table" :class="wrapperClasses">
        <div class="table-responsive" v-if="responsive">
            <table class="table dataTable-table" :class="tableClasses">
                <thead :class="headVariant ? 'table-' + headVariant : ''">
                    <tr>
                        <th v-for="field in normalizedFields" :key="field.key"
                            :class="[field.thClass, field.class, sortHeaderClass(field)]"
                            :style="field.thStyle"
                            @click="field.sortable !== false ? doSort(field.key) : null">
                            <slot :name="`head(${field.key})`" :field="field">{{ field.label }}</slot>
                            <component v-if="field.sortable !== false"
                                       :is="sortIcon(field)"
                                       class="dt-sort-icon"
                                       :class="{ 'is-active': internalSortBy === field.key }" />
                        </th>
                    </tr>
                </thead>
                <tbody v-if="busy">
                    <slot name="table-busy">
                        <tr v-for="r in skeletonRows" :key="'skrow-' + r" class="skel-tr">
                            <td :colspan="normalizedFields.length">
                                <span class="skel skel-row"></span>
                            </td>
                        </tr>
                    </slot>
                </tbody>
                <tbody v-else-if="paginatedItems.length === 0 && showEmpty && seenData">
                    <tr>
                        <td :colspan="normalizedFields.length">
                            <slot name="empty">
                                <div class="dt-empty">
                                    <component :is="icons.empty" :size="30" />
                                    <span>{{ emptyText || __('no_records_matching_your_request') || 'There are no records to show' }}</span>
                                </div>
                            </slot>
                        </td>
                    </tr>
                </tbody>
                <tbody v-else>
                    <template v-for="(item, idx) in paginatedItems" :key="absoluteIndex(idx)">
                        <tr :class="resolveRowClass(item, idx)">
                            <td v-for="field in normalizedFields" :key="field.key"
                                :class="[field.tdClass, field.class]">
                                <slot :name="`cell(${field.key})`"
                                      :item="item"
                                      :index="idx"
                                      :field="field"
                                      :value="item[field.key]"
                                      :detailsShowing="isExpanded(absoluteIndex(idx))"
                                      :toggleDetails="() => toggleDetails(absoluteIndex(idx))">
                                    {{ formatCell(field, item) }}
                                </slot>
                            </td>
                        </tr>
                        <tr v-if="showDetails && isExpanded(absoluteIndex(idx))"
                            :class="['b-table-details', detailsTdClass]">
                            <td :colspan="normalizedFields.length" :class="detailsTdClass">
                                <slot name="row-details"
                                      :item="item"
                                      :detailsShowing="true"
                                      :toggleDetails="() => toggleDetails(absoluteIndex(idx))" />
                            </td>
                        </tr>
                    </template>
                </tbody>
                <tfoot v-if="footClone">
                    <tr>
                        <th v-for="field in normalizedFields" :key="field.key">
                            <slot :name="`foot(${field.key})`" :data="{ items: sortedItems, field }">
                                <slot :name="`head(${field.key})`" :field="field">{{ field.label }}</slot>
                            </slot>
                        </th>
                    </tr>
                </tfoot>
            </table>
        </div>
        <table v-else class="table dataTable-table" :class="tableClasses">
            <thead :class="headVariant ? 'table-' + headVariant : ''">
                <tr>
                    <th v-for="field in normalizedFields" :key="field.key"
                        :class="[field.thClass, field.class, sortHeaderClass(field)]"
                        :style="field.thStyle"
                        @click="field.sortable !== false ? doSort(field.key) : null">
                        <slot :name="`head(${field.key})`" :field="field">{{ field.label }}</slot>
                        <component v-if="field.sortable !== false"
                                   :is="sortIcon(field)"
                                   class="dt-sort-icon"
                                   :class="{ 'is-active': internalSortBy === field.key }" />
                    </th>
                </tr>
            </thead>
            <tbody v-if="busy">
                <slot name="table-busy">
                    <tr v-for="r in skeletonRows" :key="'skrow2-' + r" class="skel-tr">
                        <td :colspan="normalizedFields.length">
                            <span class="skel skel-row"></span>
                        </td>
                    </tr>
                </slot>
            </tbody>
            <tbody v-else-if="paginatedItems.length === 0 && showEmpty && seenData">
                <tr>
                    <td :colspan="normalizedFields.length">
                        <slot name="empty">
                            <div class="dt-empty">
                                <component :is="icons.empty" :size="30" />
                                <span>{{ emptyText || __('no_records_matching_your_request') || 'There are no records to show' }}</span>
                            </div>
                        </slot>
                    </td>
                </tr>
            </tbody>
            <tbody v-else>
                <template v-for="(item, idx) in paginatedItems" :key="absoluteIndex(idx)">
                    <tr :class="resolveRowClass(item, idx)">
                        <td v-for="field in normalizedFields" :key="field.key"
                            :class="[field.tdClass, field.class]">
                            <slot :name="`cell(${field.key})`"
                                  :item="item"
                                  :index="idx"
                                  :field="field"
                                  :value="item[field.key]"
                                  :detailsShowing="isExpanded(absoluteIndex(idx))"
                                  :toggleDetails="() => toggleDetails(absoluteIndex(idx))">
                                {{ formatCell(field, item) }}
                            </slot>
                        </td>
                    </tr>
                    <tr v-if="showDetails && isExpanded(absoluteIndex(idx))"
                        :class="['b-table-details', detailsTdClass]">
                        <td :colspan="normalizedFields.length" :class="detailsTdClass">
                            <slot name="row-details"
                                  :item="item"
                                  :detailsShowing="true"
                                  :toggleDetails="() => toggleDetails(absoluteIndex(idx))" />
                        </td>
                    </tr>
                </template>
            </tbody>
            <tfoot v-if="footClone">
                <tr>
                    <th v-for="field in normalizedFields" :key="field.key">
                        <slot :name="`foot(${field.key})`" :data="{ items: sortedItems, field }">
                            <slot :name="`head(${field.key})`" :field="field">{{ field.label }}</slot>
                        </slot>
                    </th>
                </tr>
            </tfoot>
        </table>
    </div>
</template>

<script>
import { markRaw } from 'vue';
import { ChevronsUpDown, ChevronUp, ChevronDown, Inbox } from 'lucide-vue-next';

export default {
    name: 'MazerDatatable',
    props: {
        items: { type: Array, default: () => [] },
        fields: { type: Array, default: () => [] },
        busy: { type: Boolean, default: false },
        filter: { type: [String, Object, Function], default: '' },
        filterIncludedFields: { type: Array, default: null },
        showEmpty: { type: Boolean, default: false },
        emptyText: { type: String, default: '' },
        bordered: { type: Boolean, default: false },
        striped: { type: Boolean, default: true },
        hover: { type: Boolean, default: false },
        small: { type: Boolean, default: false },
        stacked: { type: [Boolean, String], default: false },
        responsive: { type: [Boolean, String], default: false },
        currentPage: { type: Number, default: 1 },
        perPage: { type: Number, default: 0 },
        totalRows: { type: Number, default: null },
        sortBy: { type: String, default: '' },
        sortDesc: { type: Boolean, default: false },
        sortDirection: { type: String, default: 'asc' },
        showDetails: { type: Boolean, default: false },
        footClone: { type: Boolean, default: false },
        noFooterSorting: { type: Boolean, default: false },
        noBorderCollapse: { type: Boolean, default: false },
        tbodyTrClass: { type: [String, Function, Array], default: '' },
        detailsTdClass: { type: [String, Array], default: '' },
        stickyHeader: { type: [Boolean, String], default: false },
        primaryKey: { type: String, default: '' },
        headVariant: { type: String, default: 'light' },
    },
    emits: [
        'update:currentPage',
        'update:perPage',
        'update:sortBy',
        'update:sortDesc',
        'row-clicked',
        'sort-changed',
        'filtered',
    ],
    data() {
        return {
            internalSortBy: this.sortBy,
            internalSortDesc: this.sortDesc,
            expandedRows: new Set(),
            // Suppress the "no records" empty state until a real load has finished,
            // so it never flashes before the skeleton on first mount.
            seenData: false,
            icons: {
                unsorted: markRaw(ChevronsUpDown),
                asc: markRaw(ChevronUp),
                desc: markRaw(ChevronDown),
                empty: markRaw(Inbox),
            },
        };
    },
    computed: {
        // Fixed 10 placeholder rows while busy.
        skeletonRows() {
            return 10;
        },
        normalizedFields() {
            return (this.fields || []).map(f => {
                if (typeof f === 'string') {
                    return { key: f, label: this.prettify(f), sortable: true };
                }
                return {
                    sortable: true,
                    ...f,
                    label: f.label !== undefined ? f.label : this.prettify(f.key),
                };
            });
        },
        filteredItems() {
            const items = Array.isArray(this.items) ? this.items : [];
            const f = this.filter;
            if (!f || (typeof f === 'string' && !f.trim())) {
                return items;
            }
            if (typeof f === 'function') {
                return items.filter(item => f(item));
            }
            const needle = String(f).toLowerCase();
            const keys = (this.filterIncludedFields && this.filterIncludedFields.length)
                ? this.filterIncludedFields
                : this.normalizedFields.map(x => x.key);
            return items.filter(item => {
                for (const k of keys) {
                    const v = item?.[k];
                    if (v == null) continue;
                    if (String(v).toLowerCase().includes(needle)) return true;
                }
                return false;
            });
        },
        sortedItems() {
            const items = [...this.filteredItems];
            const key = this.internalSortBy;
            if (!key) return items;
            const desc = this.internalSortDesc;
            items.sort((a, b) => {
                const av = a?.[key];
                const bv = b?.[key];
                if (av == null && bv == null) return 0;
                if (av == null) return 1;
                if (bv == null) return -1;
                if (typeof av === 'number' && typeof bv === 'number') {
                    return desc ? bv - av : av - bv;
                }
                const as = String(av).toLowerCase();
                const bs = String(bv).toLowerCase();
                if (as < bs) return desc ? 1 : -1;
                if (as > bs) return desc ? -1 : 1;
                return 0;
            });
            return items;
        },
        paginatedItems() {
            const per = Number(this.perPage) || 0;
            if (per <= 0) return this.sortedItems;
            const page = Math.max(1, Number(this.currentPage) || 1);
            const start = (page - 1) * per;
            return this.sortedItems.slice(start, start + per);
        },
        wrapperClasses() {
            return {
                'table-responsive': this.responsive && typeof this.responsive !== 'string',
                [`table-responsive-${this.responsive}`]: typeof this.responsive === 'string' && this.responsive,
                'b-table-sticky-header': !!this.stickyHeader,
            };
        },
        tableClasses() {
            return {
                'table-bordered': this.bordered,
                'table-striped': this.striped,
                'table-hover': this.hover,
                'table-sm': this.small,
                [`b-table-stacked-${this.stacked}`]: typeof this.stacked === 'string' && this.stacked,
                'b-table-stacked': this.stacked === true,
            };
        },
    },
    watch: {
        sortBy(v) { this.internalSortBy = v; },
        sortDesc(v) { this.internalSortDesc = v; },
        internalSortBy(v) { this.$emit('update:sortBy', v); this.$emit('sort-changed', { sortBy: v, sortDesc: this.internalSortDesc }); },
        internalSortDesc(v) { this.$emit('update:sortDesc', v); this.$emit('sort-changed', { sortBy: this.internalSortBy, sortDesc: v }); },
        filteredItems(v) { this.$emit('filtered', v, v.length); },
        // Suppress the "no records" empty state until a real load finishes, so it
        // never flashes before the skeleton on first mount.
        busy: {
            immediate: true,
            handler(v) {
                if (!v && (this._wasBusy || (this.items && this.items.length))) this.seenData = true;
                if (v) this._wasBusy = true;
            },
        },
        items(v) {
            if (v && v.length) this.seenData = true;
        },
    },
    methods: {
        prettify(key) {
            if (!key) return '';
            return String(key).replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
        },
        absoluteIndex(idx) {
            const per = Number(this.perPage) || 0;
            const page = Math.max(1, Number(this.currentPage) || 1);
            return per > 0 ? (page - 1) * per + idx : idx;
        },
        isExpanded(absIdx) {
            return this.expandedRows.has(absIdx);
        },
        toggleDetails(absIdx) {
            const s = new Set(this.expandedRows);
            if (s.has(absIdx)) s.delete(absIdx);
            else s.add(absIdx);
            this.expandedRows = s;
        },
        doSort(key) {
            if (this.internalSortBy !== key) {
                this.internalSortBy = key;
                this.internalSortDesc = this.sortDirection === 'desc';
                return;
            }
            if (!this.internalSortDesc) {
                this.internalSortDesc = true;
            } else {
                this.internalSortBy = '';
                this.internalSortDesc = false;
            }
        },
        // Unsorted columns show a neutral up/down affordance; the active one shows
        // the direction actually applied.
        sortIcon(field) {
            if (this.internalSortBy !== field.key) return this.icons.unsorted;
            return this.internalSortDesc ? this.icons.desc : this.icons.asc;
        },
        sortHeaderClass(field) {
            if (field.sortable === false) return '';
            return 'sortable-header';
        },
        formatCell(field, item) {
            const v = item?.[field.key];
            if (typeof field.formatter === 'function') {
                return field.formatter(v, field.key, item);
            }
            return v == null ? '' : v;
        },
        resolveRowClass(item, idx) {
            const c = this.tbodyTrClass;
            if (typeof c === 'function') return c(item, idx) || '';
            return c || '';
        },
        refresh() {
            // no-op: client-side, items are reactive
        },
    },
};
</script>

<style scoped>
.sortable-header {
    cursor: pointer;
    user-select: none;
    white-space: nowrap;
}
/* Header label keeps its own colour on hover — only the sort icon reacts. */

/* Sort affordance: dim until the column is the one actually sorted. */
.dt-sort-icon {
    /* style.css sets a global `svg { display: block }`, which would drop the icon
       onto its own line under the column label. */
    display: inline-block !important;
    width: 14px;
    height: 14px;
    margin-inline-start: 5px;
    vertical-align: -3px;
    stroke-width: 2.25px;
    opacity: 0.55;
    transition: opacity 0.15s ease, color 0.15s ease;
}
.sortable-header:hover .dt-sort-icon {
    opacity: 0.9;
}
.dt-sort-icon.is-active {
    opacity: 1;
    color: var(--bs-primary);
}

.dt-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 2.5rem 1rem;
    color: var(--app-muted);
    font-size: 0.8125rem;
}
.dt-empty svg {
    opacity: 0.45;
}

.b-table-details > td {
    padding: 0.5rem 0.75rem;
}
</style>
