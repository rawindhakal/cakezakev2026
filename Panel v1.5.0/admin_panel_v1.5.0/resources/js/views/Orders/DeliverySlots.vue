<template>
    <div class="list-page">
        <div class="page-head d-flex align-items-center gap-2">
            <h3 class="page-head-title mb-0">Delivery slots &amp; rules</h3>
            <router-link :to="{ name: 'DeliverySchedule' }" class="btn btn-outline-primary btn-sm ms-auto">📅 Delivery planner</router-link>
        </div>

        <ul class="nav nav-pills mb-3 gap-1">
            <li class="nav-item" v-for="t in tabs" :key="t.key"><a class="nav-link" href="#" :class="{ active: tab === t.key }" @click.prevent="tab = t.key">{{ t.label }}</a></li>
        </ul>

        <!-- Slots -->
        <div v-if="tab === 'slots'" class="list-surface p-3">
            <div class="d-flex mb-3"><button class="btn btn-primary btn-sm ms-auto" @click="editSlot()">+ Add time slot</button></div>
            <table class="table align-middle">
                <thead><tr><th>Slot</th><th>Hours</th><th>Capacity / day</th><th>Extra charge</th><th>Upcoming orders</th><th>Status</th><th></th></tr></thead>
                <tbody>
                    <tr v-if="!slots.length"><td colspan="7" class="text-center text-muted py-3">No slots yet.</td></tr>
                    <tr v-for="s in slots" :key="s.id">
                        <td class="fw-semibold">{{ s.label }}</td>
                        <td>{{ s.start_time }} – {{ s.end_time }}</td>
                        <td>{{ s.capacity ?? 'Unlimited' }}</td>
                        <td>{{ Number(s.extra_charge) ? currency + Number(s.extra_charge) : '—' }}</td>
                        <td>{{ s.upcoming_orders }}</td>
                        <td><span class="status-pill" :class="s.status == 1 ? 'is-active' : 'is-inactive'">{{ s.status == 1 ? 'Active' : 'Off' }}</span></td>
                        <td class="text-end text-nowrap">
                            <button class="btn btn-sm btn-outline-primary me-1" @click="editSlot(s)">Edit</button>
                            <button class="btn btn-sm btn-outline-danger" @click="removeSlot(s)">Delete</button>
                        </td>
                    </tr>
                </tbody>
            </table>
            <p class="small text-muted mb-0">Capacity is the number of orders a slot accepts for one date; when it is reached customers see the slot as full. Slots whose start time is closer than the minimum lead time are hidden automatically.</p>
        </div>

        <!-- Closed dates -->
        <div v-if="tab === 'closed'" class="list-surface p-3">
            <form class="row g-2 align-items-end mb-3" @submit.prevent="addClosed">
                <div class="col-6 col-md-2"><label class="form-label small">From</label><input type="date" class="form-control" v-model="cd.date" required></div>
                <div class="col-6 col-md-2"><label class="form-label small">To (optional)</label><input type="date" class="form-control" v-model="cd.date_to"></div>
                <div class="col-6 col-md-3"><label class="form-label small">Slot</label>
                    <select class="form-select" v-model="cd.slot_id"><option value="">Whole day</option><option v-for="s in slots" :key="s.id" :value="s.id">{{ s.label }}</option></select></div>
                <div class="col-6 col-md-3"><label class="form-label small">Reason</label><input class="form-control" v-model="cd.reason" placeholder="e.g. Festival holiday"></div>
                <div class="col-12 col-md-2"><button class="btn btn-primary w-100">Close</button></div>
            </form>
            <table class="table align-middle">
                <thead><tr><th>Date</th><th>Closed</th><th>Reason</th><th></th></tr></thead>
                <tbody>
                    <tr v-if="!closed.length"><td colspan="4" class="text-center text-muted py-3">No closed dates.</td></tr>
                    <tr v-for="c in closed" :key="c.id">
                        <td class="fw-semibold">{{ pretty(c.date) }}</td>
                        <td>{{ c.slot_label || 'Whole day' }}</td>
                        <td>{{ c.reason || '—' }}</td>
                        <td class="text-end"><button class="btn btn-sm btn-outline-danger" @click="removeClosed(c)">Reopen</button></td>
                    </tr>
                </tbody>
            </table>
        </div>

        <!-- Rules -->
        <div v-if="tab === 'rules'" class="list-surface p-3" style="max-width:560px">
            <form @submit.prevent="saveRules" class="d-grid gap-3">
                <div class="form-check form-switch"><input id="req" class="form-check-input" type="checkbox" v-model="rules.required"><label for="req" class="form-check-label">Customers must choose a delivery date and time</label></div>
                <div><label class="form-label">How far ahead customers can order (days)</label><input type="number" min="1" max="365" class="form-control" v-model.number="rules.max_advance_days"></div>
                <div><label class="form-label">Minimum lead time before a slot starts (minutes)</label><input type="number" min="0" max="1440" class="form-control" v-model.number="rules.min_lead_minutes">
                    <div class="form-text">e.g. 60 hides today's slots that start within the next hour.</div></div>
                <div><button class="btn btn-primary" :disabled="saving">Save rules</button> <span v-if="savedMsg" class="text-success ms-2">{{ savedMsg }}</span></div>
            </form>
        </div>

        <!-- Slot modal -->
        <div v-if="form" class="modal d-block" style="background:rgba(0,0,0,.45)" @click.self="form = null">
            <div class="modal-dialog modal-dialog-centered"><form class="modal-content" @submit.prevent="saveSlot">
                <div class="modal-header"><h5 class="modal-title">{{ form.id ? 'Edit' : 'Add' }} time slot</h5><button type="button" class="btn-close" @click="form = null"></button></div>
                <div class="modal-body d-grid gap-3">
                    <div class="row g-2"><div class="col"><label class="form-label">Starts</label><input type="time" class="form-control" v-model="form.start_time" required></div>
                        <div class="col"><label class="form-label">Ends</label><input type="time" class="form-control" v-model="form.end_time" required></div></div>
                    <div><label class="form-label">Label <small class="text-muted">(auto from hours if empty)</small></label><input class="form-control" v-model="form.label"></div>
                    <div class="row g-2"><div class="col"><label class="form-label">Capacity per day</label><input type="number" min="0" class="form-control" v-model="form.capacity" placeholder="Unlimited"></div>
                        <div class="col"><label class="form-label">Extra charge</label><input type="number" min="0" step="0.01" class="form-control" v-model="form.extra_charge"></div></div>
                    <div class="row g-2"><div class="col"><label class="form-label">Sort order</label><input type="number" min="0" class="form-control" v-model.number="form.sort_order"></div>
                        <div class="col"><label class="form-label">Status</label><select class="form-select" v-model.number="form.status"><option :value="1">Active</option><option :value="0">Off</option></select></div></div>
                    <div v-if="err" class="text-danger small">{{ err }}</div>
                </div>
                <div class="modal-footer"><button type="button" class="btn btn-light" @click="form = null">Cancel</button><button class="btn btn-primary" :disabled="saving">Save</button></div>
            </form></div>
        </div>
    </div>
</template>

<script>
import axios from 'axios';

export default {
    data() {
        return {
            tab: 'slots', tabs: [{ key: 'slots', label: 'Time slots' }, { key: 'closed', label: 'Closed dates' }, { key: 'rules', label: 'Booking rules' }],
            slots: [], closed: [], rules: { required: true, max_advance_days: 60, min_lead_minutes: 60 },
            form: null, err: '', saving: false, savedMsg: '', cd: { date: '', date_to: '', slot_id: '', reason: '' },
        };
    },
    computed: { currency() { return this.$currency || 'Rs'; } },
    mounted() { this.loadAll(); },
    methods: {
        api(p) { return this.$apiUrl + '/delivery_schedule/' + p; },
        loadAll() {
            axios.get(this.api('slots')).then(r => { this.slots = r.data.data || []; });
            axios.get(this.api('blackouts')).then(r => { this.closed = r.data.data || []; });
            axios.get(this.api('settings')).then(r => { this.rules = r.data.data; });
        },
        pretty(d) { return new Date(String(d).substring(0, 10) + 'T00:00:00').toLocaleDateString(undefined, { weekday: 'short', day: '2-digit', month: 'short', year: 'numeric' }); },
        editSlot(s) { this.err = ''; this.form = s ? { ...s } : { label: '', start_time: '09:00', end_time: '12:00', capacity: '', extra_charge: 0, sort_order: this.slots.length, status: 1 }; },
        saveSlot() {
            this.saving = true; this.err = '';
            axios.post(this.api('slots/save'), this.form).then(r => {
                if (r.data.status === 0) { this.err = r.data.message; return; }
                this.form = null; this.loadAll();
            }).catch(e => { this.err = e.response?.data?.message || 'Could not save'; }).finally(() => { this.saving = false; });
        },
        removeSlot(s) {
            this.$swal.fire({ title: `Delete ${s.label}?`, text: 'Slots with orders are deactivated instead.', icon: 'warning', showCancelButton: true })
                .then(res => { if (res.isConfirmed) axios.post(this.api('slots/delete'), { id: s.id }).then(this.loadAll); });
        },
        addClosed() {
            axios.post(this.api('blackouts/save'), this.cd).then(r => {
                if (r.data.status === 0) { this.$swal.fire({ icon: 'error', title: r.data.message }); return; }
                this.cd = { date: '', date_to: '', slot_id: '', reason: '' }; this.loadAll();
            });
        },
        removeClosed(c) { axios.post(this.api('blackouts/delete'), { id: c.id }).then(this.loadAll); },
        saveRules() {
            this.saving = true;
            axios.post(this.api('settings'), { required: this.rules.required ? 1 : 0, max_advance_days: this.rules.max_advance_days, min_lead_minutes: this.rules.min_lead_minutes })
                .then(r => { if (r.data.status === 0) { this.$swal.fire({ icon: 'error', title: r.data.message }); return; } this.savedMsg = 'Saved'; setTimeout(() => this.savedMsg = '', 2500); })
                .finally(() => { this.saving = false; });
        },
    },
};
</script>
