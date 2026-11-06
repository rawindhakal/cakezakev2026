<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" scrollable centered no-fade static>
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">
                {{ __('save') }}
                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord" novalidate>
            <div class="row">
                <div class="col-md-12">
                    <div class="form-group">
                        <label for="status" >{{ __('status') }}</label><br>
                        <input name="amount" id="amount" type="number" v-model="amount" hidden>
                        <div id="status" class="form-group btn-group" role="group">
                            <label class="btn" :class="status == 0 ? 'btn-warning active' : 'btn-outline-warning'">
                                <input type="radio" v-model="status" value="0" class="d-none"> {{ __('pending') }}
                            </label>
                            <label class="btn" :class="status == 1 ? 'btn-success active' : 'btn-outline-success'">
                                <input type="radio" v-model="status" value="1" class="d-none"> {{ __('approved') }}
                            </label>
                            <label class="btn" :class="status == 2 ? 'btn-danger active' : 'btn-outline-danger'">
                                <input type="radio" v-model="status" value="2" class="d-none"> {{ __('rejected') }}
                            </label>
                        </div>
                       
                        <div v-if="status == 1">
                            <FileUpload v-model="image" :label="__('upload_receipt_image')" required accept="image/*"
                                :max-size-mb="2" :preview-url="receipt_image_url" />
                        </div>
                        <div class="form-group">
                            <label for="remark">{{ __('remark') }}</label><i class="text-danger" v-if="status == 2">*</i>
                            <textarea  v-model="remark" class="form-control" :placeholder="__('remark')" :required="status == 2">
                            </textarea>
                        </div>
                    </div>  
                </div>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';

export default {
    props: ['record'],
    data : function(){
        return {
            isLoading: false,
       
            id: this.record ? this.record.id : null ,
            status: this.record ? this.record.status : "" ,
            receipt_image: this.record ? this.record.receipt_image : null,
            receipt_image_url: this.record ? this.record.receipt_image_url : '',
            remark: this.record ? this.record.remark : "" ,
            amount: this.record ? this.record.amount : "" ,
            image: null

        };
    },
    computed: {
        modal_title: function(){
            let title = this.id ? __('edit') : __('add') ;
            title += ' ' + __('withdrawal_requests');
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
        saveRecord: function(){
            let vm = this;
            
            if (this.status == 2 && (!this.remark || this.remark.trim() === '')) {
                this.showError(__('remark_is_required_when_status_is_rejected'));
                return;
            }
            
            this.isLoading = true;
            let formData = new FormData();
             if (this.id) {
                formData.append('id', this.id);
            }
            formData.append('status', this.status);
            formData.append('receipt_image', this.image || '');
            formData.append('remark', this.remark);
            formData.append('amount', this.amount);
            let url = this.$apiUrl + '/withdrawal_requests/save';
            if(this.id){
                url = this.$apiUrl + '/withdrawal_requests/update';
            }
            axios.post(url, formData).then(res => {
                let data = res.data;
                if (data.status === 1) {
                    this.$eventBus.emit('withdrawalRequestSaved', data.message);
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
