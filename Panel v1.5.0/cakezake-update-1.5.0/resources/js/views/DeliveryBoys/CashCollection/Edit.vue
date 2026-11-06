<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" centered no-close-on-backdrop no-fade static>
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading || (graterAmount === true) ">{{ __('save') }}
                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord">
            <div class="row">
                <div class="form-group">
                    <label>{{ __('delivery_boy') }}</label>
                    <multiselect v-model="transactions.deliveryBoy"
                                 :options="deliveryBoys"
                                 :custom-label="customLabelOption"
                                 @close="checkAmount"
                                 :placeholder="__('delivery_boy')"
                                 label="name"
                                 track-by="name" required>
                    </multiselect>
                    <div class="border border-grey rounded p-2 mt-2" v-if="transactions.deliveryBoy">
                        <div class="d-flex justify-content-between align-items-center text-left">
                            <span>{{ __('name') }}:&nbsp;<strong>{{ transactions.deliveryBoy.name }}</strong></span>
                            <span>{{ __('mobile') }}:&nbsp;<strong>{{ (transactions.deliveryBoy.country_code ? transactions.deliveryBoy.country_code + ' ' : '') + $filters.mobileMask(transactions.deliveryBoy.mobile) }}</strong></span>
                        </div>
                        <div class="d-flex justify-content-between align-items-center text-left mt-1">
                            <span>{{ __('cash_in_hand') }}:&nbsp;<strong class="text-danger">{{ transactions.deliveryBoy.cash_received }}</strong></span>
                            <span>{{ __('wallet_balance') }}:&nbsp;<strong class="text-success">{{ transactions.deliveryBoy.balance }}</strong></span>
                        </div>
                    </div>
                </div>
                <div class="form-group">
                    <label class="d-block">{{ __('collection_mode') }}</label>
                    <div class="btn-group btn-group-toggle d-block" role="group">
                        <label class="btn btn-outline-primary" :class="{ active: transactions.payment_mode === 'cash' }">
                            <input type="radio" value="cash" v-model="transactions.payment_mode" @change="checkAmount"> {{ __('cash') }}
                        </label>
                        <label class="btn btn-outline-primary" :class="{ active: transactions.payment_mode === 'wallet' }">
                            <input type="radio" value="wallet" v-model="transactions.payment_mode" @change="checkAmount"> {{ __('wallet') }}
                        </label>
                    </div>
                    <small class="text-muted d-block mt-1" v-if="transactions.payment_mode === 'wallet'">
                        {{ __('amount_will_be_debited_from_delivery_boy_wallet') }}
                    </small>
                </div>
                <div class="form-group">
                    <label for="amount">{{ __('transfer_amount') }}</label>
                    <input type="number" name="amount" id="amount" v-model="transactions.amount" v-on:keyup="checkAmount" required class="form-control" :placeholder="__('transfer_amount')" @input="validateFundTransfer" step="0.01">
                    <span class="text-danger" v-if="graterAmount === true">{{ limitMessage }}</span>
                    <span v-if="validationErrorFundTransfer" class="error">{{ validationErrorFundTransfer }}</span>
                </div>
                <div class="form-group">
                    <label for="transaction_date"> {{ __('date_time') }}</label>
                    <input type="datetime-local" name="transaction_date" id="transaction_date" v-model="transactions.transaction_date" required class="form-control" :placeholder="__('select_date_and_time')" >
                </div>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';
import Multiselect from 'vue-multiselect'
import dayjs from '../../../utils/dayjs';
export default {
    props: ['record','deliveryBoys','preselectBoy'],
    components: {
        Multiselect
    },
    data : function(){
        return {
            isLoading: false,
            graterAmount:false,
            limitMessage: '',
            transactions:{
                id: this.record ? this.record.id : null ,
                deliveryBoy: this.preselectBoy || null,
                payment_mode: 'cash',
                amount: this.record ? this.record.amount : "" ,

                transaction_date: this.record
                    ? dayjs.utc(this.record.transaction_date).local().format('YYYY-MM-DDTHH:mm')
                    : dayjs().format('YYYY-MM-DDTHH:mm'),
            },
            validationErrorFundTransfer : null,

        };
    },
    computed: {
        modal_title: function(){
            let title = this.id ?  __('edit') :__('add') ;
            title +=' ' ;
            title += __('cash_collection') ;
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
        validateFundTransfer() {
            if (this.transactions.amount < 0) {
                this.validationErrorFundTransfer = "Amount must be greater than 0.";
                this.transactions.amount = null;
            } else {
                this.validationErrorFundTransfer = null;
            }
        },
        customLabelOption({id, name, mobile, cash_received, balance}){
            return `${name}  Cash: ${cash_received}  Wallet: ${balance}`
        },
        // Amount can never exceed the cash the boy is holding; wallet mode is
        // additionally capped by the boy's wallet balance.
        checkAmount(){
            const boy = this.transactions.deliveryBoy;
            if (!boy) { this.graterAmount = false; return; }
            const amount = parseFloat(this.transactions.amount) || 0;
            if (amount > parseFloat(boy.cash_received)) {
                this.graterAmount = true;
                this.limitMessage = __('you_can_not_enter_amount_greater_than_cash_in_hand');
            } else if (this.transactions.payment_mode === 'wallet' && amount > parseFloat(boy.balance)) {
                this.graterAmount = true;
                this.limitMessage = __('you_can_not_enter_amount_greater_than_wallet_balance');
            } else {
                this.graterAmount = false;
                this.limitMessage = '';
            }
        },

        saveRecord: function(){
            let vm = this;
            this.isLoading = true;
            let formObject = this.transactions;
            let formData = new FormData();
            for(let key in formObject){
                if (key === 'deliveryBoy'){
                    formData.append(key, JSON.stringify(formObject[key]));
                }
                else if (key === 'transaction_date'){
                    // The input value is in the browser's local tz — persist it as UTC.
                    formData.append(key, dayjs(formObject[key]).utc().format('YYYY-MM-DD HH:mm:ss'));
                }
                else{
                    formData.append(key, formObject[key]);
                }
            }
            let url = this.$apiUrl + '/cash_collection/save';
            if(this.transactions.id){
                url = this.$apiUrl + '/cash_collection/update';
            }
            axios.post(url, formData).then(res => {
                let data = res.data;
                if (data.status === 1) {
                    this.$eventBus.emit('transactionsSaved', data.message);
                    this.hideModal();
                }else{
                    vm.showError(data.message);
                    vm.isLoading = false;
                }
            }).catch(error => {
                vm.isLoading = false;
                if (error.request.statusText) {
                    this.showError(error.request.statusText);
                }else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError("Something went wrong!");
                }
            });
        }
    },
    mounted(){
        this.showModal();
    }
}
</script>

<style scoped>
</style>
