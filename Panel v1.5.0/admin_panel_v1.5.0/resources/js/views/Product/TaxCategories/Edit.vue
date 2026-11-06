<template>
    <b-modal ref="my-modal" :title="modal_title" @hide="onModalHide" @hidden="$emit('modalClose')" centered
        no-close-on-backdrop no-fade static>
        <template #footer>
            <b-button variant="primary" @click="saveRecord" :disabled="isLoading">{{ __('save') }}
                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord" novalidate>
            <div class="row">
                <div class="form-group">
                    <label>{{ __('name') }}<i class="text-danger">*</i></label>
                    <input type="text" class="form-control" v-model="name" :placeholder="__('eg_standard_rate')" required>
                    <small class="text-muted">{{ __('tax_category_name_hint') }}</small>
                </div>

                <div class="form-group">
                    <label>{{ __('code') }}<i class="text-danger">*</i></label>
                    <input type="text" class="form-control" v-model="code" placeholder="GST_5" required>
                    <small class="text-muted">{{ __('tax_category_code_hint') }}</small>
                </div>

                <div class="form-group">
                    <label>{{ __('description') }}</label>
                    <input type="text" class="form-control" v-model="description">
                </div>

                <div class="form-group" v-if="id">
                    <label>{{ __('status') }}</label>
                    <div class="col-md-9 text-left mt-1">
                        <div class="btn-group btn-group-toggle" role="group">
                            <label class="btn btn-outline-primary" :class="{ active: status == 0 }">
                                <input type="radio" :value="0" v-model.number="status"> {{ __('deactivate') }}
                            </label>
                            <label class="btn btn-outline-primary" :class="{ active: status == 1 }">
                                <input type="radio" :value="1" v-model.number="status"> {{ __('activate') }}
                            </label>
                        </div>
                    </div>
                </div>
            </div>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';
import UnsavedChanges from '../../../mixins/UnsavedChanges.js';

export default {
    mixins: [UnsavedChanges],
    props: ['record'],
    data() {
        return {
            id: null,
            name: '',
            code: '',
            description: '',
            status: 1,
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
                    this.name = newVal.name || '';
                    this.code = newVal.code || '';
                    this.description = newVal.description || '';
                    this.status = newVal.status;
                } else {
                    this.id = null;
                    this.name = '';
                    this.code = '';
                    this.description = '';
                    this.status = 1;
                }
            },
        },
    },
    computed: {
        modal_title() {
            return this.id ? __('edit') + ' ' + __('tax_category') : __('add') + ' ' + __('tax_category');
        },
    },
    methods: {
        formState() {
            return { name: this.name, code: this.code, description: this.description, status: this.status };
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

        saveRecord() {
            if (!this.name.trim() || !this.code.trim()) {
                this.showError(__('please_fill_all_required_fields'));
                return;
            }
            this.isLoading = true;

            const fd = new FormData();
            if (this.id) fd.append('id', this.id);
            fd.append('name', this.name);
            fd.append('code', this.code);
            fd.append('description', this.description || '');
            fd.append('status', this.status != null ? this.status : 1);

            axios.post(this.$apiUrl + '/products/tax_categories/save', fd).then(res => {
                if (res.data.status !== 1) throw new Error(res.data.message);
                this.captureFormBaseline();
                this.$eventBus.emit('recordSaved', __('tax_category_saved_successfully'));
                this.hideModal();
            }).catch(err => {
                this.showError(err.response?.data?.message || err.message || __('something_went_wrong'));
            }).finally(() => { this.isLoading = false; });
        },
    },
    mounted() {
        this.captureFormBaseline();
        this.showModal();
    },
};
</script>
