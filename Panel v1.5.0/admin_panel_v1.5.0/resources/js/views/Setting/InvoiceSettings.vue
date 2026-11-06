<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('invoice_settings') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <section class="section">
              <div class="row g-3">
                <div class="col-12 col-xl-7">
                <form method="post" enctype="multipart/form-data" @submit.prevent="save">
                    <!-- ============================== INVOICE ============================== -->
                    <div class="card">
                        <div class="card-header d-flex align-items-center gap-2">
                            <FileText :size="18" />
                            <h4 class="card-title mb-0">{{ __('invoice') }}</h4>
                        </div>
                        <div class="card-body">
                            <div class="row">
                                <div class="form-group col-12 col-md-6 col-lg-4">
                                    <label>{{ __('paper_size') }}</label>
                                    <AppSelect class="form-select" v-model="f.invoice_paper_size"
                                        :options="invoiceSizeOptions" />
                                    <small class="text-muted d-block">{{ __('invoice_paper_size_hint') }}</small>
                                </div>

                                <!-- Only meaningful for a roll nobody standard-sized. -->
                                <template v-if="f.invoice_paper_size === 'custom'">
                                    <div class="form-group col-6 col-md-3 col-lg-2">
                                        <label>{{ __('width') }} (mm)</label>
                                        <input type="number" min="40" max="400" class="form-control"
                                            v-model="f.invoice_custom_width">
                                    </div>
                                    <div class="form-group col-6 col-md-3 col-lg-2">
                                        <label>{{ __('height') }} (mm)</label>
                                        <input type="number" min="50" max="1200" class="form-control"
                                            v-model="f.invoice_custom_height">
                                    </div>
                                </template>

                                <div class="form-group col-6 col-md-3 col-lg-2">
                                    <label>{{ __('font_size') }} (px)</label>
                                    <input type="number" min="6" max="20" step="0.5" class="form-control"
                                        v-model="f.invoice_font_size">
                                </div>

                                <div class="form-group col-12 col-md-6 col-lg-3">
                                    <label>{{ __('colors') }}</label>
                                    <AppSelect class="form-select" v-model="f.invoice_color_mode" :options="colorModes" />
                                    <small class="text-muted d-block">{{ __('invoice_color_mode_hint') }}</small>
                                </div>

                                <div class="form-group col-12 col-md-6 col-lg-3">
                                    <label>{{ __('bold_text') }}</label>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            v-model="f.invoice_bold_text">
                                    </div>
                                    <small class="text-muted d-block">{{ __('bold_text_hint') }}</small>
                                </div>

                                <div class="col-12"><hr class="my-2"></div>

                                <div class="form-group col-12 col-md-6 col-lg-3">
                                    <label>{{ __('show_logo') }}</label>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            v-model="f.invoice_show_logo">
                                    </div>
                                </div>
                                <div class="form-group col-12 col-md-6 col-lg-5" v-if="f.invoice_show_logo == 1">
                                    <label>{{ __('invoice_logo') }}</label>
                                    <input type="file" class="form-control" accept="image/*"
                                        @change="pick('invoice_logo', $event)">
                                    <small class="text-muted d-block">{{ __('invoice_logo_hint') }} {{ __('doc_image_size_hint') }}</small>
                                    <div v-if="urls.invoice_logo" class="mt-2 d-flex align-items-center gap-2">
                                        <img :src="urls.invoice_logo" class="doc-prev">
                                        <button type="button" class="btn btn-sm btn-outline-danger"
                                            @click="remove('invoice_logo')">{{ __('remove') }}</button>
                                    </div>
                                </div>
                                <div class="form-group col-6 col-md-3 col-lg-2" v-if="f.invoice_show_logo == 1">
                                    <label>{{ __('logo_height') }} (px)</label>
                                    <input type="number" min="10" max="120" class="form-control"
                                        v-model="f.invoice_logo_height">
                                </div>

                                <div class="col-12"><hr class="my-2"></div>

                                <div class="form-group col-12 col-md-6">
                                    <label>{{ __('header_note') }}</label>
                                    <input type="text" class="form-control" maxlength="120"
                                        v-model="f.invoice_header_note" :placeholder="__('header_note_placeholder')">
                                    <small class="text-muted d-block">{{ __('header_note_hint') }}</small>
                                </div>
                                <div class="form-group col-12 col-md-6">
                                    <label>{{ __('footer_note') }}</label>
                                    <textarea class="form-control" rows="2" maxlength="300"
                                        v-model="f.invoice_footer_note"></textarea>
                                    <small class="text-muted d-block">{{ __('footer_note_hint') }}</small>
                                </div>

                                <div class="form-group col-12 col-md-6 col-lg-3">
                                    <label>{{ __('show_tax_summary') }}</label>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            v-model="f.invoice_show_tax_summary">
                                    </div>
                                </div>
                                <div class="form-group col-12 col-md-6 col-lg-3">
                                    <label>{{ __('show_thank_you_note') }}</label>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            v-model="f.invoice_show_thanks">
                                    </div>
                                </div>
                                <div class="form-group col-12 col-md-6" v-if="f.invoice_show_thanks == 1">
                                    <label>{{ __('thank_you_note') }}</label>
                                    <input type="text" class="form-control" maxlength="120"
                                        v-model="f.invoice_thanks_text">
                                </div>

                                <div class="col-12"><hr class="my-2"></div>

                                <div class="form-group col-12 col-md-6 col-lg-3">
                                    <label>{{ __('show_signature') }}</label>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            v-model="f.invoice_show_signature">
                                    </div>
                                    <small class="text-muted d-block">{{ __('show_signature_hint') }}</small>
                                </div>
                                <div class="form-group col-12 col-md-6 col-lg-5" v-if="f.invoice_show_signature == 1">
                                    <label>{{ __('signature_image') }}</label>
                                    <input type="file" class="form-control" accept="image/*"
                                        @change="pick('invoice_signature', $event)">
                                    <small class="text-muted d-block">{{ __('signature_image_hint') }} {{ __('doc_image_size_hint') }}</small>
                                    <div v-if="urls.invoice_signature" class="mt-2 d-flex align-items-center gap-2">
                                        <img :src="urls.invoice_signature" class="doc-prev">
                                        <button type="button" class="btn btn-sm btn-outline-danger"
                                            @click="remove('invoice_signature')">{{ __('remove') }}</button>
                                    </div>
                                </div>
                                <div class="form-group col-12 col-md-6 col-lg-4" v-if="f.invoice_show_signature == 1">
                                    <label>{{ __('signature_label') }}</label>
                                    <input type="text" class="form-control" maxlength="60"
                                        v-model="f.invoice_signature_label">
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- ========================= DELIVERY RECEIPT ========================= -->
                    <div class="card">
                        <div class="card-header d-flex align-items-center gap-2">
                            <Printer :size="18" />
                            <h4 class="card-title mb-0">{{ __('delivery_receipt_settings') }}</h4>
                        </div>
                        <div class="card-body">
                            <div class="row">
                                <div class="form-group col-12 col-md-6 col-lg-4">
                                    <label>{{ __('default_paper_size') }}</label>
                                    <AppSelect class="form-select" v-model="f.receipt_default_size"
                                        :options="receiptSizeOptions" />
                                    <small class="text-muted d-block">{{ __('receipt_default_size_hint') }}</small>
                                </div>
                                <div class="form-group col-6 col-md-3 col-lg-2">
                                    <label>{{ __('font_size') }} (px)</label>
                                    <input type="number" min="6" max="20" step="0.5" class="form-control"
                                        v-model="f.receipt_font_size">
                                </div>
                                <div class="form-group col-6 col-md-3 col-lg-2">
                                    <label>{{ __('bold_text') }}</label>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            v-model="f.receipt_bold_text">
                                    </div>
                                </div>
                                <div class="form-group col-6 col-md-3 col-lg-2">
                                    <label>{{ __('show_logo') }}</label>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            v-model="f.receipt_show_logo">
                                    </div>
                                    <small class="text-muted d-block">{{ __('receipt_logo_hint') }}</small>
                                </div>

                                <div class="col-12"><hr class="my-2"></div>

                                <div class="form-group col-6 col-md-3 col-lg-2">
                                    <label>{{ __('show_products') }}</label>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            v-model="f.receipt_show_products">
                                    </div>
                                    <small class="text-muted d-block">{{ __('receipt_show_products_hint') }}</small>
                                </div>
                                <div class="form-group col-12 col-md-6 col-lg-4">
                                    <label>{{ __('show_prices') }}</label>
                                    <AppSelect class="form-select" v-model="f.receipt_show_prices"
                                        :options="priceModes" />
                                    <small class="text-muted d-block">{{ __('receipt_show_prices_hint') }}</small>
                                </div>

                                <div class="col-12"><hr class="my-2"></div>

                                <div class="form-group col-6 col-md-3 col-lg-2">
                                    <label>{{ __('show_signature') }}</label>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            v-model="f.receipt_show_signature">
                                    </div>
                                    <small class="text-muted d-block">{{ __('receipt_signature_hint') }}</small>
                                </div>
                                <div class="form-group col-12 col-md-6 col-lg-4" v-if="f.receipt_show_signature == 1">
                                    <label>{{ __('signature_label') }}</label>
                                    <input type="text" class="form-control" maxlength="60"
                                        v-model="f.receipt_signature_label">
                                </div>
                                <div class="form-group col-12 col-md-6">
                                    <label>{{ __('footer_note') }}</label>
                                    <input type="text" class="form-control" maxlength="200"
                                        v-model="f.receipt_footer_note">
                                </div>
                            </div>
                        </div>
                        <!-- Save sits on the last card so it travels with the form. -->
                        <div class="card-footer d-flex justify-content-end">
                            <b-button type="submit" variant="primary" :disabled="isLoading"
                                v-if="$can('manage_invoice_settings')">{{ __('update') }}
                                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                            </b-button>
                        </div>
                    </div>
                </form>
                </div>

                <!-- ============================ LIVE PREVIEW ============================
                     The same blades the PDF uses, rendered for the screen and refreshed
                     shortly after any change, so the admin sees the paper before saving. -->
                <div class="col-12 col-xl-5">
                    <div class="card inv-prev-card">
                        <div class="card-header d-flex align-items-center gap-2 flex-wrap">
                            <Eye :size="18" />
                            <h4 class="card-title mb-0">{{ __('live_preview') }}</h4>
                            <b-spinner small v-if="previewLoading"></b-spinner>
                            <div class="btn-group btn-group-sm ms-auto">
                                <button type="button" class="btn"
                                    :class="previewDoc === 'invoice' ? 'btn-primary' : 'btn-outline-secondary'"
                                    @click="switchPreview('invoice')">{{ __('invoice') }}</button>
                                <button type="button" class="btn"
                                    :class="previewDoc === 'receipt' ? 'btn-primary' : 'btn-outline-secondary'"
                                    @click="switchPreview('receipt')">{{ __('delivery_receipt') }}</button>
                            </div>
                            <button type="button" class="btn btn-sm btn-outline-secondary"
                                :disabled="previewing === previewDoc" @click="preview(previewDoc)">
                                <b-spinner small v-if="previewing === previewDoc"></b-spinner>
                                <FileText v-else :size="15" /> {{ __('open_pdf') }}
                            </button>
                        </div>
                        <div class="card-body">
                            <div class="text-muted small mb-2">
                                {{ __('preview_paper_note', { w: Math.round(previewWidthMm) }) }}
                            </div>
                            <div ref="paperWrap" class="inv-prev-wrap">
                                <div v-if="previewError" class="text-muted text-center py-5">{{ previewError }}</div>
                                <iframe v-else ref="paperFrame" class="inv-prev-frame" :srcdoc="previewHtml"
                                    :style="frameStyle" @load="onFrameLoad"></iframe>
                            </div>
                        </div>
                    </div>
                </div>
              </div>
            </section>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import { ArrowLeft, Eye, FileText, Printer } from 'lucide-vue-next';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';

export default {
    name: 'InvoiceSettings',
    mixins: [UnsavedChanges],
    components: { ArrowLeft, Eye, FileText, Printer },
    data() {
        return {
            isLoading: false,
            previewing: '',        // which doc is being exported as PDF
            previewDoc: 'invoice', // which doc the live panel shows
            previewHtml: '',
            previewWidthMm: 210,
            previewScale: 1,
            previewFrameHeight: 400,
            previewLoading: false,
            previewError: '',
            previewTimer: null,
            previewSeq: 0, // guards against an older response landing last
            // Same keys the API owns; values are replaced by what is stored.
            f: {
                invoice_paper_size: 'a4',
                invoice_custom_width: 80,
                invoice_custom_height: 297,
                invoice_font_size: 11,
                invoice_bold_text: 0,
                invoice_color_mode: 'color',
                invoice_show_logo: 1,
                invoice_logo_height: 30,
                invoice_header_note: '',
                invoice_footer_note: '',
                invoice_show_thanks: 1,
                invoice_thanks_text: '',
                invoice_show_tax_summary: 1,
                invoice_show_signature: 0,
                invoice_signature_label: '',

                receipt_default_size: 'a4',
                receipt_font_size: 11,
                receipt_bold_text: 0,
                receipt_show_logo: 1,
                receipt_show_products: 1,
                receipt_show_prices: 'auto',
                receipt_show_signature: 0,
                receipt_signature_label: '',
                receipt_footer_note: '',
            },
            // Uploads are handled outside `f`: a File to send, a URL to preview.
            files: { invoice_logo: null, invoice_signature: null },
            urls: { invoice_logo: '', invoice_signature: '' },
            removals: { invoice_logo: false, invoice_signature: false },
            invoiceSizes: [],
            receiptSizes: [],
        };
    },
    computed: {
        invoiceSizeOptions() {
            return this.invoiceSizes.map(s => ({ id: s.value, name: s.label }));
        },
        receiptSizeOptions() {
            return this.receiptSizes.map(s => ({ id: s.value, name: s.label }));
        },
        colorModes() {
            return [
                { id: 'color', name: __('theme_color') },
                { id: 'mono', name: __('black_and_white') },
            ];
        },
        /* The iframe is the sheet at its real width (96 dpi), scaled down to fit the
           column — so the layout reflows exactly as it will on paper. */
        frameStyle() {
            const px = Math.round(this.previewWidthMm * 3.7795);
            // A roll is narrower than the column, so centre it; a scaled-down sheet is
            // pinned top-left because the transform shrinks it from that corner.
            const centred = this.previewScale === 1;

            return {
                width: px + 'px',
                height: this.previewFrameHeight + 'px',
                transform: 'scale(' + this.previewScale + ')',
                transformOrigin: 'top left',
                marginInline: centred ? 'auto' : '0',
            };
        },
        priceModes() {
            return [
                { id: 'auto', name: __('only_when_cash_to_collect') },
                { id: 'always', name: __('always') },
                { id: 'never', name: __('never') },
            ];
        },
    },
    created() {
        this.load().then(() => {
            this.captureFormBaseline();
            this.refreshPreview();
        });
    },
    mounted() {
        this._onResize = () => this.fitPreview();
        window.addEventListener('resize', this._onResize);
    },
    beforeUnmount() {
        window.removeEventListener('resize', this._onResize);
        if (this.previewTimer) clearTimeout(this.previewTimer);
    },
    watch: {
        // Any field change re-renders, debounced so typing doesn't fire per keystroke.
        f: {
            deep: true,
            handler() { this.queuePreview(); },
        },
    },
    methods: {
        formState() {
            return this.f;
        },
        load() {
            return axios.get(this.$apiUrl + '/store_settings/invoice_setting')
                .then(res => {
                    const d = res.data?.data || {};
                    const s = d.settings || {};
                    Object.keys(this.f).forEach(k => {
                        if (s[k] !== undefined && s[k] !== null) this.f[k] = s[k];
                    });
                    this.urls.invoice_logo = s.invoice_logo_url || '';
                    this.urls.invoice_signature = s.invoice_signature_url || '';
                    this.invoiceSizes = d.invoice_sizes || [];
                    this.receiptSizes = d.receipt_sizes || [];
                })
                // Defaults stay in place, so the form still renders.
                .catch(() => {});
        },
        switchPreview(doc) {
            if (this.previewDoc === doc) return;
            this.previewDoc = doc;
            this.refreshPreview();
        },
        queuePreview() {
            if (this.previewTimer) clearTimeout(this.previewTimer);
            this.previewTimer = setTimeout(() => this.refreshPreview(), 450);
        },
        /** Render the current form as screen HTML (no PDF engine — this runs often). */
        refreshPreview() {
            const seq = ++this.previewSeq;
            this.previewLoading = true;
            const fd = this.formData();
            fd.append('doc', this.previewDoc);
            fd.append('mode', 'html');

            axios.post(this.$apiUrl + '/store_settings/invoice_setting_preview', fd)
                .then(res => {
                    if (seq !== this.previewSeq) return; // a newer change already fired
                    if (res.data.status !== 1) {
                        this.previewError = res.data.message || __('something_went_wrong');
                        return;
                    }
                    const d = res.data.data || {};
                    this.previewError = '';
                    this.previewWidthMm = Number(d.width_mm) || 210;
                    this.previewHtml = d.html || '';
                    this.fitPreview();
                })
                .catch(() => {
                    if (seq === this.previewSeq) this.previewError = __('something_went_wrong');
                })
                .finally(() => { if (seq === this.previewSeq) this.previewLoading = false; });
        },
        /** Scale the sheet to the column width (never up — a roll stays its own size). */
        fitPreview() {
            const wrap = this.$refs.paperWrap;
            if (!wrap) return;
            const px = this.previewWidthMm * 3.7795;
            const avail = wrap.clientWidth - 2;
            this.previewScale = px > avail ? Math.max(0.25, avail / px) : 1;
            this.$nextTick(() => this.sizeFrame());
        },
        /** srcdoc is same-origin, so the real content height can be read back. */
        onFrameLoad() {
            this.sizeFrame();
        },
        sizeFrame() {
            const frame = this.$refs.paperFrame;
            const wrap = this.$refs.paperWrap;
            if (!frame || !frame.contentDocument) return;
            const h = Math.max(300, frame.contentDocument.body.scrollHeight + 24);
            this.previewFrameHeight = h;
            // The wrapper only sees the scaled box, so it has to be told the height.
            if (wrap) wrap.style.height = Math.round(h * this.previewScale) + 'px';
        },
        pick(key, event) {
            const file = event.target.files && event.target.files[0];
            this.files[key] = file || null;
            this.removals[key] = false;
            if (file) this.urls[key] = URL.createObjectURL(file);
            this.queuePreview();
        },
        remove(key) {
            this.files[key] = null;
            this.urls[key] = '';
            this.removals[key] = true;
            this.queuePreview();
        },
        /** Build the payload both save and preview send. */
        formData() {
            const fd = new FormData();
            Object.entries(this.f).forEach(([k, v]) => fd.append(k, v ?? ''));
            Object.entries(this.files).forEach(([k, file]) => { if (file) fd.append(k, file); });
            Object.entries(this.removals).forEach(([k, on]) => { if (on) fd.append('remove_' + k, 1); });

            return fd;
        },
        /** Sample PDF of the current form, opened in a new tab. */
        preview(doc) {
            this.previewing = doc;
            const fd = this.formData();
            fd.append('doc', doc);

            // Opened before the request so the browser treats it as user-initiated.
            const tab = window.open('', '_blank');
            axios.post(this.$apiUrl + '/store_settings/invoice_setting_preview', fd, { responseType: 'blob' })
                .then(res => {
                    // An error comes back as JSON even though a blob was requested.
                    if (res.data.type === 'application/json') {
                        return res.data.text().then(t => {
                            if (tab) tab.close();
                            this.showError(JSON.parse(t).message || __('something_went_wrong'));
                        });
                    }
                    const url = window.URL.createObjectURL(new Blob([res.data], { type: 'application/pdf' }));
                    if (tab) tab.location.href = url;
                    else window.open(url, '_blank');
                })
                .catch(() => {
                    if (tab) tab.close();
                    this.showError(__('something_went_wrong'));
                })
                .finally(() => { this.previewing = ''; });
        },
        save() {
            this.isLoading = true;

            axios.post(this.$apiUrl + '/store_settings/save_invoice_setting', this.formData())
                .then(res => {
                    if (res.data.status === 1) {
                        this.showMessage('success', res.data.message);
                        this.files = { invoice_logo: null, invoice_signature: null };
                        this.removals = { invoice_logo: false, invoice_signature: false };
                        return this.load().then(() => this.captureFormBaseline());
                    }
                    this.showError(res.data.message);
                })
                .catch(error => {
                    this.showError(error?.response?.data?.message || error.message || __('something_went_wrong'));
                })
                .finally(() => { this.isLoading = false; });
        },
    },
};
</script>

<style scoped>
/* Preview column sticks while the long settings form scrolls. */
.inv-prev-card {
    position: sticky;
    top: calc(var(--app-header-h, 64px) + .75rem);
}
.inv-prev-wrap {
    position: relative;
    overflow: hidden;
    border: 1px solid var(--app-card-border);
    border-radius: .5rem;
    background: #f4f6fa;
}
.inv-prev-frame {
    border: 0;
    background: #fff;
    display: block;
    box-shadow: 0 1px 6px rgba(16, 24, 40, .08);
}
@media (max-width: 1199.98px) {
    /* Stacked layout: pinning the preview would cover the form. */
    .inv-prev-card { position: static; }
}
.doc-prev {
    height: 42px;
    max-width: 160px;
    object-fit: contain;
    border: 1px solid var(--app-card-border);
    border-radius: 6px;
    padding: 2px;
    background: #fff;
}
</style>
