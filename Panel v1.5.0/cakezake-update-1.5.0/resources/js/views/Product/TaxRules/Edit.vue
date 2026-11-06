<template>
    <b-modal ref="my-modal" :title="modal_title" size="lg" @hide="onModalHide" @hidden="$emit('modalClose')" centered
        no-close-on-backdrop no-fade static>
        <template #footer>
            <div class="d-flex align-items-center justify-content-between w-100">
                <div class="rule-total">
                    {{ __('total_rate') }}:
                    <strong>{{ trimRate(totalRate) }}%</strong>
                </div>
                <div class="d-flex gap-2">
                    <b-button variant="primary" @click="saveRecord" :disabled="isLoading">{{ __('save') }}
                        <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                    </b-button>
                    <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
                </div>
            </div>
        </template>

        <form ref="my-form" @submit.prevent="saveRecord" novalidate>
            <div class="row">
                <div class="col-md-6 form-group">
                    <label>{{ __('country') }}<i class="text-danger">*</i></label>
                    <AppSelect class="form-select" v-model="country_id" :options="countryOptions" :searchable="true" />
                </div>

                <!-- Region narrows a rule to one state/province. Hidden entirely when the
                     country has none imported, so a country without subdivisions never
                     shows a control it cannot fill. -->
                <div class="col-md-6 form-group" v-if="regions.length">
                    <label>{{ __('state_region') }}</label>
                    <AppSelect class="form-select" v-model="region_id" :options="regionOptions" :searchable="true" />
                    <small class="text-muted">{{ __('tax_rule_region_hint') }}</small>
                </div>


                <div class="col-md-6 form-group">
                    <label>{{ __('tax_category') }}<i class="text-danger">*</i></label>
                    <AppSelect class="form-select" v-model="tax_category_id" :options="categoryOptions" :searchable="true" />
                    <small class="text-muted">{{ __('tax_rule_category_hint') }}</small>
                </div>

                <!-- Always shown, including before a country is chosen. "Any" is the right
                     answer wherever the country has no regions — there is nothing to cross
                     — so the hint says so rather than the field disappearing. -->
                <div class="col-md-6 form-group">
                    <label>{{ __('place_of_supply') }}<i class="text-danger">*</i></label>
                    <AppSelect class="form-select" v-model="place_of_supply" :options="supplyOptions" :searchable="false" />
                    <small class="text-muted">
                        {{ regions.length ? __('place_of_supply_hint') : __('place_of_supply_no_regions_hint') }}
                    </small>
                </div>

                <div class="col-md-6 form-group" v-if="id">
                    <label>{{ __('status') }}</label>
                    <div class="btn-group btn-group-toggle d-block mt-1" role="group">
                        <label class="btn btn-outline-primary" :class="{ active: status == 0 }">
                            <input type="radio" :value="0" v-model.number="status"> {{ __('deactivate') }}
                        </label>
                        <label class="btn btn-outline-primary" :class="{ active: status == 1 }">
                            <input type="radio" :value="1" v-model.number="status"> {{ __('activate') }}
                        </label>
                    </div>
                </div>
            </div>

            <hr>

            <!-- Components are the rate. Two rows named CGST and SGST at 9 each is exactly
                 how India's intra-state GST is expressed; one row named IGST at 18 is the
                 inter-state form. Nothing in the code knows those names. -->
            <div class="d-flex align-items-center justify-content-between mb-2">
                <div>
                    <label class="mb-0">{{ __('tax_components') }}<i class="text-danger">*</i></label>
                    <div class="text-muted small">{{ __('tax_components_hint') }}</div>
                </div>
                <button type="button" class="btn btn-sm btn-outline-primary" @click="addComponent">
                    <Plus :size="14" /> {{ __('add_component') }}
                </button>
            </div>

            <div v-for="(component, index) in components" :key="index" class="row align-items-end component-row">
                <div class="col-md-6 form-group mb-2">
                    <label v-if="index === 0">{{ __('component_name') }}</label>
                    <input type="text" class="form-control" v-model="component.name" placeholder="CGST">
                </div>
                <div class="col-md-4 form-group mb-2">
                    <label v-if="index === 0">{{ __('percentage') }}</label>
                    <input type="number" class="form-control" v-model.number="component.rate" step="0.001" min="0" max="100">
                </div>
                <div class="col-md-2 form-group mb-2">
                    <button type="button" class="list-action-btn is-delete" @click="removeComponent(index)"
                        :disabled="components.length <= 1">
                        <Trash2 :size="15" />
                    </button>
                </div>
            </div>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';
import UnsavedChanges from '../../../mixins/UnsavedChanges.js';
import { Plus, Trash2 } from 'lucide-vue-next';

export default {
    mixins: [UnsavedChanges],
    components: { Plus, Trash2 },
    props: ['record'],
    data() {
        return {
            id: null,
            country_id: '',
            region_id: '',
            tax_category_id: '',
            place_of_supply: 'any',
            status: 1,
            components: [{ name: '', rate: 0 }],
            countries: [],
            regions: [],
            categories: [],
            isLoading: false,
        };
    },
    watch: {
        record: {
            immediate: true,
            deep: true,
            handler(newVal) {
                if (newVal && newVal !== true) {
                    this.id = newVal.id;
                    this.country_id = newVal.country_id ? String(newVal.country_id) : '';
                    this.region_id = newVal.region_id ? String(newVal.region_id) : '';
                    this.tax_category_id = newVal.tax_category_id ? String(newVal.tax_category_id) : '';
                    this.place_of_supply = newVal.place_of_supply || 'any';
                    this.status = newVal.status;
                    this.components = (newVal.components || []).length
                        ? newVal.components.map(c => ({ name: c.name, rate: Number(c.rate) }))
                        : [{ name: '', rate: 0 }];
                }
            },
        },
        country_id(value) {
            this.loadRegions(value);
        },
    },
    computed: {
        modal_title() {
            return this.id ? __('edit') + ' ' + __('tax_rule') : __('add') + ' ' + __('tax_rule');
        },
        countryOptions() {
            return [{ id: '', name: __('select_country') }].concat(
                this.countries.map(c => ({ id: String(c.id), name: c.name }))
            );
        },
        regionOptions() {
            return [{ id: '', name: __('whole_country') }].concat(
                this.regions.map(r => ({ id: String(r.id), name: r.name }))
            );
        },
        categoryOptions() {
            return [{ id: '', name: __('all_categories') }].concat(
                this.categories.map(c => ({ id: String(c.id), name: c.name }))
            );
        },
        supplyOptions() {
            return [
                { id: 'any', name: __('supply_any') },
                { id: 'intra', name: __('supply_intra') },
                { id: 'inter', name: __('supply_inter') },
            ];
        },
        totalRate() {
            return this.components.reduce((sum, c) => sum + (Number(c.rate) || 0), 0);
        },
    },
    methods: {
        trimRate(rate) {
            const n = Number(rate || 0);
            return Number.isInteger(n) ? String(n) : String(parseFloat(n.toFixed(3)));
        },
        formState() {
            return {
                country_id: this.country_id, region_id: this.region_id, tax_category_id: this.tax_category_id,
                place_of_supply: this.place_of_supply,
                status: this.status, components: this.components,
            };
        },
        onModalHide(bvEvt) {
            if (this._ucAllowClose) { this._ucAllowClose = false; return; }
            if (!this.isFormDirty) return;
            bvEvt.preventDefault();
            this._ucConfirmLeave().then(ok => {
                if (ok) { this._ucAllowClose = true; this.$refs['my-modal']?.hide(); }
            });
        },
        showModal() { this.$refs['my-modal'].show(); },
        hideModal() { this.$refs['my-modal'].hide(); },

        addComponent() { this.components.push({ name: '', rate: 0 }); },
        removeComponent(index) {
            if (this.components.length <= 1) return;
            this.components.splice(index, 1);
        },

        loadLookups() {
            const countries = axios.get(this.$apiUrl + '/countries').then(res => { this.countries = res.data.data || []; });
            // Only active categories are offered; a deactivated one must not be selectable.
            const categories = axios.get(this.$apiUrl + '/products/tax_categories', { params: { status: 1 } })
                .then(res => { this.categories = res.data.data || []; });
            return Promise.all([countries, categories]).then(() => this.loadRegions(this.country_id));
        },
        loadRegions(countryId) {
            if (!countryId) { this.regions = []; return Promise.resolve(); }
            return axios.get(this.$apiUrl + '/countries/regions', { params: { country_id: countryId, status: 1 } })
                .then(res => { this.regions = res.data.data || []; })
                .catch(() => { this.regions = []; });
        },

        saveRecord() {
            if (!this.country_id) { this.showError(__('select_country')); return; }
            if (!this.tax_category_id) { this.showError(__('select_tax_category')); return; }
            const valid = this.components.filter(c => c.name && String(c.name).trim() !== '');
            if (!valid.length) { this.showError(__('tax_components_required')); return; }

            this.isLoading = true;
            const fd = new FormData();
            if (this.id) fd.append('id', this.id);
            fd.append('country_id', this.country_id);
            if (this.region_id) fd.append('region_id', this.region_id);
            fd.append('tax_category_id', this.tax_category_id);
            // A country with no regions can only ever be 'any'.
            fd.append('place_of_supply', this.place_of_supply || 'any');
            fd.append('status', this.status != null ? this.status : 1);
            fd.append('components', JSON.stringify(valid.map(c => ({ name: c.name, rate: Number(c.rate) || 0 }))));

            axios.post(this.$apiUrl + '/products/tax_rules/save', fd).then(res => {
                if (res.data.status !== 1) throw new Error(res.data.message);
                this.captureFormBaseline();
                this.$eventBus.emit('recordSaved', __('tax_rule_saved_successfully'));
                this.hideModal();
            }).catch(err => {
                this.showError(err.response?.data?.message || err.message || __('something_went_wrong'));
            }).finally(() => { this.isLoading = false; });
        },
    },
    mounted() {
        Promise.resolve(this.loadLookups()).then(() => this.captureFormBaseline());
        this.showModal();
    },
};
</script>

<style scoped>
.component-row + .component-row { border-top: 1px dashed rgba(128, 128, 128, .25); padding-top: 6px; }
.rule-total { font-size: 14px; }
</style>
