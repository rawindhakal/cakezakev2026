<template>
    <div class="list-page">
        <div class="page-head d-flex align-items-center gap-2">
            <h3 class="page-head-title mb-0">Payment methods</h3>
            <span class="ms-auto small text-success" v-if="savedMsg">{{ savedMsg }}</span>
            <button class="btn btn-primary btn-sm" :disabled="saving || !cfg" @click="save">{{ saving ? 'Saving…' : 'Save changes' }}</button>
        </div>
        <p class="text-muted small">Online gateways are switched off. Customers can pay by cash on delivery, at the counter, or by eSewa / bank transfer / QR — those three need the customer to upload proof and are verified by your team on the order.</p>

        <div v-if="cfg" class="row g-3">
            <div class="col-12 col-lg-6">
                <div class="list-surface p-3 h-100">
                    <div class="d-flex align-items-center mb-2"><h5 class="mb-0">Cash on delivery</h5>
                        <div class="form-check form-switch ms-auto"><input class="form-check-input" type="checkbox" v-model="cfg.cod.enabled" :true-value="1" :false-value="0"></div></div>
                    <p class="small text-muted mb-0">Customer pays cash to the rider when the gift arrives.</p>
                </div>
            </div>

            <div class="col-12 col-lg-6">
                <div class="list-surface p-3 h-100">
                    <div class="d-flex align-items-center mb-2"><h5 class="mb-0">Pay at counter</h5>
                        <div class="form-check form-switch ms-auto"><input class="form-check-input" type="checkbox" v-model="cfg.counter.enabled" :true-value="1" :false-value="0"></div></div>
                    <label class="form-label small">Instructions shown to customer</label>
                    <input class="form-control" v-model="cfg.counter.instructions" placeholder="e.g. Pay when you collect from our Damak store">
                </div>
            </div>

            <div class="col-12 col-lg-6">
                <div class="list-surface p-3 h-100">
                    <div class="d-flex align-items-center mb-2"><h5 class="mb-0">eSewa</h5>
                        <div class="form-check form-switch ms-auto"><input class="form-check-input" type="checkbox" v-model="cfg.esewa.enabled" :true-value="1" :false-value="0"></div></div>
                    <div class="row g-2">
                        <div class="col-6"><label class="form-label small">eSewa ID / number</label><input class="form-control" v-model="cfg.esewa.esewa_id"></div>
                        <div class="col-6"><label class="form-label small">Account name</label><input class="form-control" v-model="cfg.esewa.account_name"></div>
                        <div class="col-12"><label class="form-label small">Instructions</label><input class="form-control" v-model="cfg.esewa.instructions" placeholder="Send the exact total and upload the screenshot"></div>
                        <div class="col-12">
                            <label class="form-label small">eSewa QR image</label>
                            <div class="d-flex align-items-center gap-2">
                                <img v-if="preview.esewa || cfg.esewa.qr_url" :src="preview.esewa || cfg.esewa.qr_url" class="qr-thumb" alt="eSewa QR">
                                <input type="file" accept="image/*" class="form-control" @change="pick('esewa', $event)">
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12 col-lg-6">
                <div class="list-surface p-3 h-100">
                    <div class="d-flex align-items-center mb-2"><h5 class="mb-0">Bank transfer</h5>
                        <div class="form-check form-switch ms-auto"><input class="form-check-input" type="checkbox" v-model="cfg.bank.enabled" :true-value="1" :false-value="0"></div></div>
                    <div class="row g-2">
                        <div class="col-6"><label class="form-label small">Bank name</label><input class="form-control" v-model="cfg.bank.bank_name"></div>
                        <div class="col-6"><label class="form-label small">Branch</label><input class="form-control" v-model="cfg.bank.branch"></div>
                        <div class="col-6"><label class="form-label small">Account name</label><input class="form-control" v-model="cfg.bank.account_name"></div>
                        <div class="col-6"><label class="form-label small">Account number</label><input class="form-control" v-model="cfg.bank.account_number"></div>
                        <div class="col-12"><label class="form-label small">Instructions</label><input class="form-control" v-model="cfg.bank.instructions" placeholder="Use your order number as the remark"></div>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="list-surface p-3">
                    <div class="d-flex align-items-center mb-2"><h5 class="mb-0">QR payment (bank / Fonepay QR)</h5>
                        <div class="form-check form-switch ms-auto"><input class="form-check-input" type="checkbox" v-model="cfg.qr.enabled" :true-value="1" :false-value="0"></div></div>
                    <div class="row g-2">
                        <div class="col-12 col-md-6">
                            <label class="form-label small">Your bank QR image</label>
                            <div class="d-flex align-items-center gap-2">
                                <img v-if="preview.qr || cfg.qr.qr_url" :src="preview.qr || cfg.qr.qr_url" class="qr-thumb" alt="QR">
                                <input type="file" accept="image/*" class="form-control" @change="pick('qr', $event)">
                            </div>
                        </div>
                        <div class="col-12 col-md-6"><label class="form-label small">Instructions</label><input class="form-control" v-model="cfg.qr.instructions" placeholder="Scan with any banking app, then upload the screenshot"></div>
                    </div>
                </div>
            </div>
        </div>
        <div v-else class="text-muted p-4">Loading…</div>
    </div>
</template>

<script>
import axios from 'axios';

export default {
    data() { return { cfg: null, files: {}, preview: {}, saving: false, savedMsg: '' }; },
    mounted() { this.load(); },
    methods: {
        api(p) { return this.$apiUrl + '/offline_payments/' + p; },
        load() { axios.get(this.api('settings')).then(r => { this.cfg = r.data.data; }); },
        pick(which, e) {
            const f = e.target.files[0];
            if (!f) return;
            this.files[which] = f;
            this.preview[which] = URL.createObjectURL(f);
        },
        save() {
            this.saving = true;
            const fd = new FormData();
            fd.append('config', JSON.stringify(this.cfg));
            if (this.files.esewa) fd.append('esewa_qr', this.files.esewa);
            if (this.files.qr) fd.append('qr_image', this.files.qr);
            axios.post(this.api('settings'), fd).then(r => {
                if (r.data.status === 0) { this.$swal.fire({ icon: 'error', title: r.data.message }); return; }
                this.cfg = r.data.data; this.files = {}; this.preview = {};
                this.savedMsg = 'Saved'; setTimeout(() => this.savedMsg = '', 2500);
            }).finally(() => { this.saving = false; });
        },
    },
};
</script>

<style scoped>
.qr-thumb { width: 84px; height: 84px; object-fit: contain; border: 1px solid var(--bs-border-color, #ddd); border-radius: 8px; background: #fff; }
</style>
