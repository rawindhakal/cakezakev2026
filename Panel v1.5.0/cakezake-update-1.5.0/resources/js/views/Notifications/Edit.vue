<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" size="lg" centered scrollable no-close-on-backdrop
        no-fade static id="mymodal">
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">{{ __('save') }}
                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord">

            <div v-if="notificationError" class="alert alert-light-warning color-warning alert-dismissible fade show"
                role="alert">
                <strong><i class="bi bi-exclamation-triangle"></i> {{ __('warning') }}</strong>
                {{ notificationErrorMessage }}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>

            <div class="row">

                <div class="form-group">
                    <label for="type">{{ __('type') }}</label> <i class="text-danger">*</i>
                    <AppSelect v-model="type" :placeholder="__('select_type')" :options="type_options"
                        :allow-empty="false" />
                </div>

                <!-- Who receives it and what tapping it opens, for the chosen type. -->
                <div class="alert alert-info py-2 small" v-if="typeNote">{{ typeNote }}</div>

                <div class="form-group" v-if="type === 'url'">
                    <label> {{ __('type_link') }}</label> <i class="text-danger">*</i>
                    <input type="url" class="form-control" v-model="type_link" placeholder="Enter Link">
                </div>
                <!--customer-->
                <div class="form-group" v-if="type === 'user'">
                    <label> {{ __('customer') }} </label>
                    <i class="text-danger">*</i>
                    <AppSelect multiple v-model="type_ids" :placeholder="__('select_customer')" :options="users_options" />
                </div>
                <!--delivery boys-->
                <div class="form-group" v-if="type === 'delivery_boy'">
                    <!-- Button OUTSIDE the label: a label click forwards to controls inside it. -->
                    <div class="d-flex align-items-center">
                        <label class="mb-0">{{ __('delivery_boys') }} <i class="text-danger">*</i></label>
                        <button type="button" class="btn btn-sm btn-outline-primary ms-auto py-0"
                            @click="selectAllDeliveryBoys">
                            {{ allBoysSelected ? __('clear_all') : __('select_all') }}
                        </button>
                    </div>
                    <AppSelect multiple v-model="type_ids" :placeholder="__('select_delivery_boy')"
                        :options="delivery_boys_options" />
                </div>

                <div class="form-group" v-if="type === 'category'">
                    <label for="category"> {{ __('categories') }}</label> <i class="text-danger">*</i>
                    <AppSelect v-model="type_id" :placeholder="__('select_category')" :options="categories_options" />
                </div>
                <div class="form-group" v-if="type === 'product'">
                    <label for="product"> {{ __('products') }}</label> <i class="text-danger">*</i>
                    <AppSelect v-model="type_id" :placeholder="__('select_product')" :options="products_options" />
                </div>
                <div class="form-group">
                    <label for="title"> {{ __('title') }}</label> <i class="text-danger">*</i>
                    <input type="text" name="title" id="title" required v-model="title" class="form-control"
                        :placeholder="__('title')" >
                </div>

                <div class="form-group">
                    <label for="message"> {{ __('message') }}</label> <i class="text-danger">*</i>
                    <div class="mb-3">
                        <textarea name="message" id="message" v-model="message" cols="5" class="form-control"
                            :placeholder="__('enter_message_here')" ></textarea>
                    </div>
                </div>

                <div class="form-group">
                    <div class="form-check form-switch">
                        <input name="include_image" id="include_image" v-model="include_image" type="checkbox"
                            class="form-check-input" role="switch">
                        <label class="form-check-label" for="include_image">{{ __('include_image') }}</label>
                    </div>
                </div>
                <div v-if="(include_image === true && id) || include_image === true">
                    <FileUpload v-model="image" accept="image/*"
                        recommended-size="1024x512px" :preview-url="image_url" />
                </div>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';
export default {
    props: ['record', 'users', 'delivery_boys', 'categories', 'products'],
    mixins: [UnsavedChanges],
    data: function () {
        return {
            isLoading: false,
            id: this.record ? this.record.id : null,
            type: this.record ? this.record.type : "",
            type_ids: this.record ? this.record.type_id : [],
            type_id: this.record ? this.record.type_id : 0,
            type_link: this.record ? this.record.type_link : "",
            title: this.record ? this.record.title : "",
            message: this.record ? this.record.message : "",
            include_image: false,
            image: null,
            image_url: this.record ? this.record.image : "",

            notificationError: false,
            notificationErrorMessage: "",
        };
    },
    computed: {
        allBoysSelected() {
            const ids = Array.isArray(this.type_ids) ? this.type_ids : [];
            return this.delivery_boys_options.length > 0 && ids.length === this.delivery_boys_options.length;
        },
        typeNote() {
            switch (this.type) {
                case 'default': return __('notif_note_default');
                case 'category': return __('notif_note_category');
                case 'product': return __('notif_note_product');
                case 'url': return __('notif_note_url');
                case 'user': return __('notif_note_user');
                case 'delivery_boy': return __('notif_note_delivery_boy');
                default: return '';
            }
        },
        modal_title: function () {
            let title = this.id ? __('edit') : __('add');
            title += " ";
            title += __('notification');
            return title;
        },
        users_options: function () {
            var temp = [];
            this.users.forEach(user => {
                temp.push({ id: user.id, name: user.name })
            });
            return temp;
        },

        delivery_boys_options: function () {
            var temp = [];
            this.delivery_boys.forEach(delivery_boy => {
                temp.push({ id: delivery_boy.id, name: delivery_boy.name })
            });
            return temp;
        },
        categories_options: function () {
            return this.categories.map(c => ({ id: c.id, name: c.name }));
        },
        products_options: function () {
            return this.products.map(p => ({ id: p.id, name: p.name }));
        },
        type_options: function () {
            // Branch users may only push to their own delivery boys.
            if (this.$isBranchUser && this.$isBranchUser()) {
                return [{ id: 'delivery_boy', name: __('delivery_boy') }];
            }
            return [
                { id: 'default', name: __('default') },
                { id: 'category', name: __('category') },
                { id: 'product', name: __('product') },
                { id: 'user', name: __('customer') },
                { id: 'delivery_boy', name: __('delivery_boy') },
                { id: 'url', name: __('url') },
            ];
        },

    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return {
                type: this.type,
                type_ids: this.type_ids,
                type_id: this.type_id,
                type_link: this.type_link,
                title: this.title,
                message: this.message,
                include_image: this.include_image,
                image: this.image,
            };
        },
        selectAllDeliveryBoys() {
            this.type_ids = this.allBoysSelected ? [] : this.delivery_boys_options.map(o => o.id);
        },
        showModal() {
            this.$refs['my-modal'].show()
        },
        hideModal() {
            this.$refs['my-modal'].hide()
        },
        // Per-type required checks: the target (customer / delivery boy / category
        // / product / link) that the chosen type actually uses must be filled.
        validate() {
            if (!this.type) { this.showError(__('please_select_type')); return false; }

            const ids = Array.isArray(this.type_ids) ? this.type_ids : [];
            switch (this.type) {
                case 'user':
                    if (ids.length === 0) { this.showError(__('please_select_at_least_one_customer')); return false; }
                    break;
                case 'delivery_boy':
                    if (ids.length === 0) { this.showError(__('please_select_at_least_one_delivery_boy')); return false; }
                    break;
                case 'category':
                    if (!this.type_id) { this.showError(__('please_select_a_category')); return false; }
                    break;
                case 'product':
                    if (!this.type_id) { this.showError(__('please_select_a_product')); return false; }
                    break;
                case 'url':
                    if (!String(this.type_link || '').trim()) { this.showError(__('please_enter_link')); return false; }
                    break;
            }

            if (!String(this.title || '').trim()) { this.showError(__('please_enter_title')); return false; }
            if (!String(this.message || '').trim()) { this.showError(__('please_enter_message')); return false; }
            return true;
        },
        saveRecord: function () {
            if (!this.validate()) return;
            let vm = this;
            this.isLoading = true;
            let formData = new FormData();
            if (this.id) {
                formData.append('id', this.id);
            }
            formData.append('type', this.type);
            const typeIds = Array.isArray(this.type_ids) ? this.type_ids.join(',') : (this.type_ids || '');
            formData.append('type_ids', typeIds);
            formData.append('type_id', this.type_id);
            formData.append('type_link', this.type_link);
            formData.append('title', this.title);
            formData.append('message', this.message);
            formData.append('include_image', this.include_image);
            formData.append('image', this.image ? this.image : (this.image_url || ''));
            let url = this.$apiUrl + '/notifications/save';
            if (this.id) {
                url = this.$apiUrl + '/notifications/update';
            }
            axios.post(url, formData, {
                headers: {
                    'Content-Type': 'multipart/form-data'
                }
            }).then(res => {
                let data = res.data;
                if (data.status === 1) {
                    let notification = data.data;

                    if (notification && notification?.status === 0) {
                        this.notificationError = true;
                        this.notificationErrorMessage = notification.message;
                    }

                    // Mark clean so the post-save redirect doesn't trip the guard.
                    vm.captureFormBaseline();
                    setTimeout(function () {
                        vm.$eventBus.emit('notificationSaved', data.message);
                        vm.hideModal();
                        vm.$swal.close();
                        vm.$router.push({ path: '/notifications' });
                    }, 2000);
                } else {
                    vm.showError(data.message);
                    vm.isLoading = false;
                }
            }).catch(error => {
                vm.isLoading = false;

                if (error.message) {
                    this.showError(error.message);
                } else if (error.request.statusText && error.request.statusText !== "" && typeof error.request.statusText !== 'undefined') {
                    this.showError(error.request.statusText);
                } else {
                    this.showError("Something went wrong!");
                }
            });
        }
    },
    mounted() {
        this.showModal();
        // Baseline the prop-populated form for the UnsavedChanges guard.
        this.captureFormBaseline();
    }
}
</script>

<style scoped></style>
