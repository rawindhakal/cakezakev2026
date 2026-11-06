<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" scrollable centered no-fade static>
        <template #footer>
            <b-button variant="primary" @click="saveRecord" :disabled="isLoading">
                {{ __('save') }}
                <b-spinner v-if="isLoading" small></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>

        <form @submit.prevent="saveRecord" novalidate>
            <div class="form-group mb-3">
                <label>{{ __('delivery_boy') }} <i class="text-danger">*</i></label>
                <AppSelect class="form-select" v-model="delivery_boy_id" :options="deliveryBoyOptions"
                    :placeholder="__('select_delivery_boy')" />
                <small v-if="!deliveryBoys.length && !loadingBoys" class="text-muted">{{ __('no_delivery_boys_for_selected_country') }}</small>
            </div>

            <div class="form-group mb-3">
                <label>{{ __('amount') }} <i class="text-danger">*</i></label>
                <div class="input-group">
                    <span class="input-group-text">{{ displayCurrency }}</span>
                    <input type="number" min="0" step="0.01" class="form-control" v-model.number="amount">
                </div>
            </div>

            <div class="form-group mb-3">
                <label>{{ __('paid_on') }} <i class="text-danger">*</i></label>
                <date-picker v-model="paid_on" :placeholder="__('select_date')" />
            </div>

            <div class="form-group mb-1">
                <label>{{ __('note') }}</label>
                <textarea class="form-control" rows="3" v-model="note" :placeholder="__('note')"></textarea>
            </div>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';
import DatePicker from '../../../components/DatePicker.vue';

export default {
    components: { DatePicker },
    props: ['record', 'currency'],
    data() {
        return {
            isLoading: false,
            loadingBoys: false,
            deliveryBoys: [],
            id: this.record ? this.record.id : null,
            delivery_boy_id: this.record ? this.record.delivery_boy_id : null,
            amount: this.record ? this.record.amount : '',
            paid_on: this.record ? (this.record.paid_on ? String(this.record.paid_on).substring(0, 10) : '') : '',
            note: this.record ? this.record.note : '',
        };
    },
    computed: {
        // The mobile number used to be markup inside the option; fold it into the label.
        deliveryBoyOptions() {
            return (this.deliveryBoys || []).map(b => ({
                id: b.id,
                name: b.mobile
                    ? `${b.name} (${(b.country_code ? b.country_code + ' ' : '') + this.$filters.mobileMask(b.mobile)})`
                    : b.name,
            }));
        },
        modal_title() {
            return (this.id ? __('edit') : __('add')) + ' ' + __('salary_transaction');
        },
        displayCurrency() {
            const boy = (this.deliveryBoys || []).find(b => b.id === this.delivery_boy_id);
            return (boy && boy.currency) || this.currency || this.$currency;
        },
    },
    mounted() {
        this.$refs['my-modal'].show();
        this.fetchDeliveryBoys();
    },
    methods: {
        hideModal() { this.$refs['my-modal'].hide(); },
        fetchDeliveryBoys() {
            this.loadingBoys = true;
            axios.get(this.$apiUrl + '/delivery_boys', {
                params: {
                    country_id: '',
                    filterStatus: 1,
                },
            }).then(r => {
                this.deliveryBoys = (r.data.data || []).map(b => ({
                    id: b.id,
                    name: b.name,
                    mobile: b.mobile,
                    country_code: b.country_code,
                    currency: (b.country && b.country.currency) || b.currency || null,
                }));
            }).catch(() => { this.deliveryBoys = []; })
                .finally(() => { this.loadingBoys = false; });
        },
        saveRecord() {
            if (!this.delivery_boy_id) { this.showError(__('please_select_delivery_boy')); return; }
            if (!(Number(this.amount) >= 0) || this.amount === '') { this.showError(__('please_enter_valid_amount')); return; }
            if (!this.paid_on) { this.showError(__('please_select_paid_on_date')); return; }

            this.isLoading = true;
            const payload = {
                delivery_boy_id: this.delivery_boy_id,
                amount: this.amount,
                paid_on: this.paid_on,
                note: this.note || '',
            };
            if (this.id) payload.id = this.id;
            const url = this.$apiUrl + (this.id ? '/salary_transactions/update' : '/salary_transactions/add');
            axios.post(url, payload).then(res => {
                const data = res.data;
                if (data.status === 1) {
                    this.$eventBus.emit('salaryTransactionSaved', data.message);
                    this.hideModal();
                } else {
                    this.showError(data.message);
                    this.isLoading = false;
                }
            }).catch(err => {
                this.isLoading = false;
                this.showError(err.response?.data?.message || err.message || __('something_went_wrong'));
            });
        },
    },
};
</script>
