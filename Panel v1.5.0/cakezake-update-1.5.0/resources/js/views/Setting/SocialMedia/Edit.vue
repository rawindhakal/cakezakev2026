<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" no-fade static centered>
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">
                {{ __('save') }} <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord">
            <div class="row">
                <div class="form-group">
                    <label for="icon">{{ __('icon') }}</label>
                    <div v-if="currentIconUrl && !iconFile" class="mb-2">
                        <img :src="currentIconUrl" alt="icon" style="width:40px;height:40px;object-fit:contain;">
                    </div>
                    <FileUpload v-model="iconFile" accept=".jpg,.jpeg,.png,.gif,.webp,.svg,image/*"
                        :recommended-text="__('supported_formats') + ': JPG, PNG, GIF, WEBP, SVG'" />
                </div>
                <div class="form-group ">
                    <label for="link">{{ __('link') }}</label>
                    <input type="url" name="link" id="link" v-model="socialMedia.link" :placeholder="__('link')" class="form-control">
                </div>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';
import UnsavedChanges from '../../../mixins/UnsavedChanges.js';

export default {
    props: ['record'],
    mixins: [UnsavedChanges],
    data : function(){
        return {
            isLoading: false,
            iconFile: null,
            currentIconUrl: this.record ? (this.record.icon_url || '') : '',
            socialMedia:{
                id: this.record ? this.record.id : null ,
                link: this.record ? this.record.link : "" ,
            },
        };
    },
    computed: {
        modal_title() {
            return (this.socialMedia.id ? __('edit') : __('add')) + ' ' + __('social_media');
        },
    },
    methods: {
        // Tracked state for the UnsavedChanges guard
        formState() {
            return {
                link: this.socialMedia.link,
                iconFile: this.iconFile,
            };
        },
        showModal() {
            this.$refs['my-modal'].show()
        },
        hideModal() {
            this.$refs['my-modal'].hide()
        },

        saveRecord: function(){
            let vm = this;
            // Icon file required when adding (update keeps the existing icon if none picked).
            if (!this.socialMedia.id && !this.iconFile) {
                this.showError(__('icon') + ' ' + __('is_required'));
                return;
            }
            this.isLoading = true;
            let formData = new FormData();
            if (this.socialMedia.id) formData.append('id', this.socialMedia.id);
            formData.append('link', this.socialMedia.link);
            if (this.iconFile) formData.append('icon', this.iconFile);
            let url = this.$apiUrl + '/social_media/save';
            if(this.socialMedia.id){
                url = this.$apiUrl + '/social_media/update';
            }
            axios.post(url, formData).then(res => {
                let data = res.data;
                if (data.status === 1) {
                    // Mark clean so closing the modal doesn't trip the unsaved-changes guard.
                    this.captureFormBaseline();
                    this.$eventBus.emit('socialMediaSaved', data.message);
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
        // Record data comes from the `record` prop synchronously; snapshot it as
        // the "clean" baseline for the guard.
        this.captureFormBaseline();
    }
}
</script>

<style scoped>

</style>
