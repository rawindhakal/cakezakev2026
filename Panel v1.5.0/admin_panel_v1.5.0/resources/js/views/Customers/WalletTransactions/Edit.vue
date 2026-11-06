<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" no-fade static centered size="lg">
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading || !countryId">{{ __('save') }}
                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord">
            <div v-if="!countryId" class="alert alert-warning py-2">
                {{ __('select_a_country_in_the_header_to_credit_a_wallet') }}
            </div>
            <div v-else class="alert alert-info py-2">
                {{ __('amount_will_be_credited_to_the_selected_country_wallet') }} ({{ currency }})
            </div>

            <div class="row">
                <div class="form-group">
                    <label>{{ __('customer') }}</label>
                    <multiselect v-model="walletTransaction.customer"
                                 :options="customers || []"
                                 :placeholder="__('select_and_search_customer')"
                                 label="name"
                                 track-by="id" required>
                        <template #singleLabel="props">
                            <span class="option__desc">
                                <span class="option__title">{{ props.option.name }}</span>
                            </span>
                        </template>
                        <template #option="props">
                            <div class="option__desc">
                                <span class="option__title">{{ props.option.name }}</span>
                                <span class="option__small" v-if="props.option.mobile_full"> · {{ props.option.mobile_full }}</span>
                                <span class="option__small"> · {{ __('balance') }}: {{ currency }}{{ props.option.balance }}</span>
                            </div>
                        </template>
                    </multiselect>

                    <div class="border border-grey rounded p-2 mt-2" v-if="walletTransaction.customer">
                        <div class="row g-2 small">
                            <div class="col-6 col-md-3">
                                <div class="text-muted">{{ __('id') }}</div>
                                <div class="fw-bold">{{ walletTransaction.customer.id }}</div>
                            </div>
                            <div class="col-6 col-md-3">
                                <div class="text-muted">{{ __('name') }}</div>
                                <div class="fw-bold">{{ walletTransaction.customer.name || '—' }}</div>
                            </div>
                            <div class="col-6 col-md-3">
                                <div class="text-muted">{{ __('mobile') }}</div>
                                <div class="fw-bold">{{ walletTransaction.customer.mobile_full || '—' }}</div>
                            </div>
                            <div class="col-6 col-md-3">
                                <div class="text-muted">{{ __('balance') }}</div>
                                <div class="fw-bold">{{ currency }}{{ walletTransaction.customer.balance }}</div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="form-group">
                    <label for="amount">{{ __('amount') }} ({{ currency }})</label>
                    <input type="number" name="amount" id="amount" v-model="walletTransaction.amount" required class="form-control" :placeholder="__('transfer_amount')" min="0.01" step="0.01" @input="validateAmount">
                    <span v-if="validationError" class="error">{{ validationError }}</span>
                </div>
                <div class="form-group">
                    <label for="message">{{ __('message') }}</label>
                    <textarea name="message" id="message" v-model="walletTransaction.message" class="form-control" rows="3" :placeholder="__('message')" required ></textarea>
                </div>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';
import Multiselect from 'vue-multiselect'

export default {
    props: ['record', 'customers', 'countryId', 'currency'],
    components: {
        Multiselect
    },
    data : function(){
        return {
            isLoading: false,
            validationError: null,
            walletTransaction:{
                id: this.record ? this.record.id : null ,
                customer:null,
                amount: this.record ? this.record.amount : "" ,
                message: this.record ? this.record.message : "" ,
            },
        };
    },
    computed: {
        modal_title: function(){
            let title = this.walletTransaction.id ? __('edit') : __('add') ;
            title += ' ' + __('wallet_transactions');
            return title;
        },
    },
    methods: {
        showModal() {
            this.$refs['my-modal'].show()
        },
        hideModal() {
            this.$refs['my-modal'].hide()
        },
        validateAmount() {
            this.validationError = (parseFloat(this.walletTransaction.amount) > 0)
                ? null
                : __('amount_must_be_greater_than_zero');
        },
        saveRecord: function(){
            let vm = this;
            this.validateAmount();
            if (this.validationError) return;
            if (!this.countryId) {
                this.showError(__('select_a_country_in_the_header_to_credit_a_wallet'));
                return;
            }

            this.isLoading = true;
            let formData = new FormData();
            formData.append('customer', JSON.stringify(this.walletTransaction.customer));
            formData.append('amount', this.walletTransaction.amount);
            formData.append('message', this.walletTransaction.message ?? '');
            // Credit lands in the header-selected country's wallet.
            formData.append('country_id', this.countryId);

            axios.post(this.$apiUrl + '/wallet_transactions/save', formData).then(res => {
                let data = res.data;
                if (data.status === 1) {
                    this.$eventBus.emit('walletTransactionsSaved', data.message);
                    this.hideModal();
                }else{
                    vm.showError(data.message);
                    vm.isLoading = false;
                }
            }).catch(error => {
                vm.isLoading = false;
                if (error.request?.statusText) {
                    this.showError(error.request.statusText);
                }else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError(__('something_went_wrong'));
                }
            });
        }
    },
    mounted(){
        this.showModal();
    }
}
</script>
