<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" no-fade centered static>
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading || (graterAmount === true) || (validationError !== null) ">{{ __('save') }}
                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord">
            <div class="row">
                <div class="form-group">
                    <label for="balance">{{ __('balance') }}</label>
                    <div class="input-group">
                        <span class="input-group-text">{{ currency }}</span>
                        <input type="number" name="balance" id="balance" :value="balance" class="form-control" step="any" readonly>
                    </div>
                </div>
                <div class="form-group">
                    <label for="amount">{{ __('amount') }}</label> <span class="text-danger">*</span>
                    <div class="input-group">
                        <span class="input-group-text">{{ currency }}</span>
                        <input type="number" name="amount" id="amount" v-model="withdrawalRequests.amount" v-on:keyup="checkAmount" required class="form-control" :placeholder="__('transfer_amount')"  @input="validateAmount" step="any">
                    </div>
                    <span class="text-danger" v-if="graterAmount === true">{{ __('requested_amount_should_not_greater_then_available_balance') }}</span>
                    <span v-if="validationError" class="error">{{ validationError }}</span>
                </div>
                <div class="form-group">
                    <label for="message">{{ __('message') }}</label> <span class="text-danger">*</span>
                    <textarea name="message" id="message" v-model="withdrawalRequests.message" class="form-control" rows="3" :placeholder="__('message')" required ></textarea>
                </div>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';

export default {
    props: ['record','balance','currency'],
    
    data : function(){
        return {
            isLoading: false,
            graterAmount:false,
            withdrawalRequests:{
                // type / type_id are resolved server-side from the authenticated actor.
                amount: this.record ? this.record.amount : "" ,
                message: this.record ? this.record.message : "" ,
            },
              validationError: null,

        };
    },
    computed: {
        modal_title: function(){
            // Delivery boys can only create a request, never edit one.
            return __('add') + " " + __('withdrawal_request');
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
            if (this.withdrawalRequests.amount < 0.01 ) {
                this.validationError =  __('requested_amount_should_equal_or_greater_then') + ' '+ this.$currency+'0.01';
            } else {
                this.validationError = null;
            }
        },
       
        checkAmount(){
            if(((this.withdrawalRequests.amount) > (this.balance))){
                this.graterAmount = true;
            }else{
                this.graterAmount = false;
            }
        },
        saveRecord: function(){
            let vm = this;
            this.isLoading = true;

            // A delivery boy can only CREATE a request (there is no update endpoint for
            // them). `type` / `type_id` are resolved server-side from the authenticated
            // actor, so the amount + message are the only parameters to send.
            const formData = new FormData();
            formData.append('amount', this.withdrawalRequests.amount);
            formData.append('message', this.withdrawalRequests.message);

            const url = this.$deliveryBoyApiUrl + '/withdrawal_requests/add';
            axios.post(url, formData).then(res => {
                let data = res.data;
                if (data.status === 1) {
                    this.$eventBus.emit('withdrawalRequestsSaved', data.message);
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
