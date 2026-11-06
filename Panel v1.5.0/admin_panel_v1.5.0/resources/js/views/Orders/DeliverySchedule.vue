<template>
    <div class="list-page">
        <div class="page-head d-flex flex-wrap align-items-center gap-2">
            <h3 class="page-head-title mb-0">Delivery planner</h3>
            <div class="ms-auto d-flex flex-wrap gap-2 align-items-center">
                <button class="btn btn-outline-primary btn-sm" @click="shift(-14)">‹ Previous 2 weeks</button>
                <input type="date" class="form-control form-control-sm" style="width:auto" v-model="from" @change="load">
                <button class="btn btn-outline-primary btn-sm" @click="shift(14)">Next 2 weeks ›</button>
                <button class="btn btn-primary btn-sm" @click="goToday">Today</button>
                <router-link :to="{ name: 'DeliverySlots' }" class="btn btn-outline-secondary btn-sm">⚙ Slots &amp; closed dates</router-link>
            </div>
        </div>

        <div class="row g-3 mb-3" v-if="data">
            <div class="col-6 col-md-3"><div class="plan-stat"><div class="n">{{ totals.orders }}</div><div class="l">Orders in range</div></div></div>
            <div class="col-6 col-md-3"><div class="plan-stat"><div class="n">{{ totals.pending }}</div><div class="l">To deliver</div></div></div>
            <div class="col-6 col-md-3"><div class="plan-stat"><div class="n">{{ currency }}{{ totals.amount.toFixed(0) }}</div><div class="l">Order value</div></div></div>
            <div class="col-6 col-md-3">
                <router-link :to="{ name: 'Orders', query: { delivery_when: 'unscheduled' } }" class="plan-stat d-block text-decoration-none">
                    <div class="n">{{ data.unscheduled }}</div><div class="l">Open orders without a date</div>
                </router-link>
            </div>
        </div>

        <div class="list-surface">
            <div class="table-responsive">
                <table class="table plan-table align-middle mb-0">
                    <thead>
                        <tr>
                            <th>Date</th>
                            <th v-for="s in slots" :key="s.id" class="text-center">{{ s.label }}<div class="small text-muted fw-normal">cap {{ s.capacity ?? '∞' }}</div></th>
                            <th class="text-center">Other</th>
                            <th class="text-center">Total</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-if="loading"><td :colspan="slots.length + 3" class="text-center py-4"><b-spinner small /></td></tr>
                        <tr v-for="d in days" :key="d.date" :class="{ 'is-today': d.date === today, 'is-closed': d.closed }">
                            <td class="text-nowrap">
                                <div class="fw-semibold">{{ d.weekday }}, {{ pretty(d.date) }}</div>
                                <small v-if="d.date === today" class="badge bg-warning text-dark">Today</small>
                                <small v-if="d.closed" class="badge bg-secondary">Closed{{ d.closed_reason ? ': ' + d.closed_reason : '' }}</small>
                            </td>
                            <td v-for="s in slots" :key="s.id" class="text-center">
                                <router-link v-if="d.slots[s.id]" class="cell" :class="cellClass(d.slots[s.id], s.capacity)"
                                    :to="{ name: 'Orders', query: { delivery_date: d.date, delivery_slot_id: s.id } }">
                                    {{ d.slots[s.id] }}<span v-if="s.capacity">/{{ s.capacity }}</span>
                                </router-link>
                                <span v-else class="text-muted">·</span>
                            </td>
                            <td class="text-center">
                                <router-link v-if="other(d)" class="cell" :to="{ name: 'Orders', query: { delivery_date: d.date } }">{{ other(d) }}</router-link>
                                <span v-else class="text-muted">·</span>
                            </td>
                            <td class="text-center">
                                <router-link v-if="d.total" class="cell cell-total" :to="{ name: 'Orders', query: { delivery_date: d.date } }">{{ d.total }}</router-link>
                                <span v-else class="text-muted">0</span>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
            <div class="p-3 small text-muted">
                Cell colour shows how full a slot is (green &lt; 70%, amber &lt; 100%, red = full). Click any number to open those orders.
                "Other" covers express and midnight orders that don't use a fixed slot.
            </div>
        </div>
    </div>
</template>

<script>
import axios from 'axios';

const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

export default {
    data() { return { from: iso(new Date()), data: null, loading: false }; },
    computed: {
        currency() { return this.$currency || 'Rs'; },
        today() { return iso(new Date()); },
        slots() { return (this.data?.slots || []).filter(s => s.status == 1); },
        days() { return this.data?.days || []; },
        totals() {
            const t = { orders: 0, pending: 0, amount: 0 };
            this.days.forEach(d => { t.orders += d.total; t.pending += d.pending; t.amount += d.amount; });
            return t;
        },
    },
    mounted() { this.load(); },
    methods: {
        load() {
            this.loading = true;
            const to = new Date(this.from + 'T00:00:00'); to.setDate(to.getDate() + 13);
            axios.get(this.$apiUrl + '/orders/delivery_schedule', { params: { from: this.from, to: iso(to) } })
                .then(r => { this.data = r.data.data; }).finally(() => { this.loading = false; });
        },
        shift(n) { const d = new Date(this.from + 'T00:00:00'); d.setDate(d.getDate() + n); this.from = iso(d); this.load(); },
        goToday() { this.from = iso(new Date()); this.load(); },
        pretty(d) { return new Date(d + 'T00:00:00').toLocaleDateString(undefined, { day: '2-digit', month: 'short' }); },
        other(d) {
            const known = new Set(this.slots.map(s => String(s.id)));
            return Object.entries(d.slots).filter(([k]) => !known.has(k)).reduce((a, [, v]) => a + v, 0);
        },
        cellClass(n, cap) {
            if (!cap) return 'cell-ok';
            const r = n / cap;
            return r >= 1 ? 'cell-full' : r >= 0.7 ? 'cell-warn' : 'cell-ok';
        },
    },
};
</script>

<style scoped>
.plan-stat { background: #fff; border: 1px solid #e5e7eb; border-radius: 12px; padding: .9rem 1rem; }
.plan-stat .n { font-size: 1.5rem; font-weight: 800; color: #111827; }
.plan-stat .l { font-size: .8rem; color: #6b7280; }
.plan-table th { font-size: .8rem; white-space: nowrap; }
.plan-table tr.is-today td { background: #fff8e1; }
.plan-table tr.is-closed td { background: #f3f4f6; }
.cell { display: inline-block; min-width: 44px; padding: .2rem .55rem; border-radius: 8px; font-weight: 700; text-decoration: none; }
.cell-ok { background: #e7f6ec; color: #1e7c39; }
.cell-warn { background: #fff1d6; color: #9a6700; }
.cell-full { background: #fde2e2; color: #b42318; }
.cell-total { background: #eef2ff; color: #3730a3; }
.cell:not([class*='cell-']) { background: #eef2ff; color: #3730a3; }
</style>
