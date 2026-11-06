<template>
    <div>
        <div class="page-heading">
            <div class="page-title">
            </div>
        </div>
        <section class="section">
            <div class="row">
                <div class="col-12 col-md-12 order-md-1 order-last">
                    <form method="post" enctype="multipart/form-data" @submit.prevent="saveRecord">
                        <div class="card">
                            <div class="card-header">
                                <h4 class="card-title">{{ __('popup_offer') }}</h4>
                                <span class="float-end">
                                    <button type="button" class="btn btn-primary btn_refresh" v-b-tooltip.hover
                                        :title="__('refresh')" @click="getPopupData()">
                                        <i class="fa fa-refresh" aria-hidden="true"></i>
                                    </button>
                                </span>
                            </div>
                            <div class="card-body">
                                <div class="row">

                                    <div class="form-group col-md-4 col-lg-3">
                                        <div class="form-group">
                                            <label class="control-label"> {{ __('popup_offer_enabled_on_off')
                                                }}</label><br>
                                            <div class="btn-group btn-group-toggle" role="group">
                                                <label class="btn btn-outline-primary" :class="{ active: popup_enabled == 1 }">
                                                    <input type="radio" :value="1" v-model.number="popup_enabled" autocomplete="off"> {{ __('ON') }}
                                                </label>
                                                <label class="btn btn-outline-primary" :class="{ active: popup_enabled == 0 }">
                                                    <input type="radio" :value="0" v-model.number="popup_enabled" autocomplete="off"> {{ __('OFF') }}
                                                </label>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="form-group col-md-4 col-lg-3">
                                        <label class="control-label"> {{ __('popup_mode') }}</label><br>
                                        <div class="btn-group btn-group-toggle" role="group">
                                            <label class="btn btn-outline-primary" :class="{ active: popup_mode == 'lifetime' }">
                                                <input type="radio" value="lifetime" v-model="popup_mode" autocomplete="off"> {{ __('lifetime') }}
                                            </label>
                                            <label class="btn btn-outline-primary" :class="{ active: popup_mode == 'scheduled' }">
                                                <input type="radio" value="scheduled" v-model="popup_mode" autocomplete="off"> {{ __('scheduled') }}
                                            </label>
                                        </div>
                                    </div>
                                    <div class="form-group col-md-4 col-lg-3" v-if="popup_mode == 'scheduled'">
                                        <label for="popup_start_at"> {{ __('turn_on_at') }}</label>
                                        <input type="datetime-local" id="popup_start_at" class="form-control"
                                            v-model="popup_start_at_local">
                                    </div>
                                    <div class="form-group col-md-4 col-lg-3" v-if="popup_mode == 'scheduled'">
                                        <label for="popup_end_at"> {{ __('turn_off_at') }}</label>
                                        <input type="datetime-local" id="popup_end_at" class="form-control"
                                            v-model="popup_end_at_local">
                                    </div>
                                    <div class="col-md-12" v-if="popup_mode == 'scheduled'">
                                        <div class="alert alert-info py-2 small mb-0">
                                            {{ __('popup_scheduled_note') }}
                                        </div>
                                    </div>

                                    <div class="form-group col-md-4">
                                        <label> {{ __('type') }}</label>
                                        <AppSelect class="form-control form-select" v-model="popup_type" :options="popup_typeOptions" :searchable="false" @update:model-value="popup_type_id = ''" />
                                    </div>
                                    <div class="col-md-6">
                                            <div class="form-group" v-if="popup_type == 'category'">
                                                <label>{{ __('category') }}</label>
                                                <AppSelect class="form-control form-select" v-model="popup_type_id"
                                                    :options="categories" :placeholder="__('select_category')" />
                                            </div>
                                            <div class="form-group" v-if="popup_type == 'product'">
                                                <label> {{ __('products') }}</label>
                                                <AppSelect class="form-control form-select" v-model="popup_type_id"
                                                    :options="products" :placeholder="__('select_product')" />
                                            </div>
                                            <div class="form-group" v-if="popup_type == 'brand'">
                                                <label> {{ __('brand') }}</label>
                                                <AppSelect class="form-control form-select" v-model="popup_type_id"
                                                    :options="brands" :placeholder="__('select_brand')" />
                                            </div>
                                            <div class="form-group" v-if="popup_type == 'popup_url'">
                                                <label> {{ __('link') }}</label>
                                                <input type="url" class="form-control" v-model="popup_url"
                                                    placeholder="Enter Link">
                                            </div>
                                        </div>
                                    <div class="col-md-12">
                                            <FileUpload v-model="image" :label="__('image')" accept="image/*"
                                                :recommended-text="__('please_choose_square_image_of_larger_than_500_500')"
                                                :max-size-mb="2" :preview-url="image_url" />
                                        </div>
                                    </div>
                                </div>
                            <div class="card-footer">
                                <b-button type="submit" variant="primary" :disabled="isLoading">{{ __('save') }}
                                    <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                                </b-button>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
        </section>
    </div>
</template>
<script>
import axios from "axios";

export default {
    data: function () {
        return {
            isLoading: false,
            categories: [],
            products: [],
            brands: [],

            popup_enabled: 0,
            popup_type: 'default',
            popup_type_id: "",
            popup_mode: 'lifetime',
            popup_start_at_local: "",
            popup_end_at_local: "",
            popup_slug: "",
            image: "",
            image_url: "",
            popup_url: "",
        };
    },

    created: function () {
        this.getCategories();
        this.getProducts();
        this.getBrands();
        this.getPopupData();
    },
    computed: {
        // Fixed option set — no search box needed.
        popup_typeOptions() {
            return [
                { id: 'default', name: (__('default')) },
                { id: 'category', name: (__('category')) },
                { id: 'product', name: (__('product')) },
                { id: 'brand', name: (__('brand')) },
                { id: 'popup_url', name: (__('popup_url')) },
            ];
        },
    },
    methods: {
        getPopupData() {
            axios.get(this.$apiUrl + '/popup').then((response) => {
                if (response.data.data) {
                    this.record = response.data.data;
                    this.popup_enabled = this.record.popup_enabled ?? 0;
                    this.popup_type = this.record.popup_type;
                    this.popup_type_id = this.record.popup_type_id;
                    this.popup_slug = this.record.popup_slug || "";
                    this.popup_url = this.record.popup_url;
                    this.image_url = this.record.popup_image ?? "";
                    this.popup_mode = this.record.popup_mode === 'scheduled' ? 'scheduled' : 'lifetime';
                    this.popup_start_at_local = this.toInput(this.record.popup_start_at);
                    this.popup_end_at_local = this.toInput(this.record.popup_end_at);

                    this.record.map((item, index) => {
                        if (item.value === '0' || item.value === '1') {
                            this.firebase[item.variable] = (item.value === '0') ? 0 : 1;
                        } else {
                            this.firebase[item.variable] = item.value;
                        }
                    });

                }
            }).catch(error => {
                if (error.request.statusText) {
                    this.showError(error.request.statusText);
                } else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError(__('something_went_wrong'));
                }
            });
        },

        pad(n) { return String(n).padStart(2, '0'); },
        // Stored UTC -> local "YYYY-MM-DDTHH:mm" for the datetime-local input.
        toInput(v) {
            if (!v) return '';
            const d = new Date(String(v).replace(' ', 'T') + 'Z'); // parse as UTC
            if (isNaN(d.getTime())) return '';
            return `${d.getFullYear()}-${this.pad(d.getMonth() + 1)}-${this.pad(d.getDate())}T${this.pad(d.getHours())}:${this.pad(d.getMinutes())}`;
        },
        // Local "YYYY-MM-DDTHH:mm" -> UTC "YYYY-MM-DD HH:mm:ss" for storage.
        toServer(v) {
            if (!v) return '';
            const d = new Date(v); // interprets the value as LOCAL time
            if (isNaN(d.getTime())) return '';
            return `${d.getUTCFullYear()}-${this.pad(d.getUTCMonth() + 1)}-${this.pad(d.getUTCDate())} ${this.pad(d.getUTCHours())}:${this.pad(d.getUTCMinutes())}:00`;
        },
        getCategories() {
            this.isLoading = true
            axios.get(this.$apiUrl + '/categories/active')
                .then((response) => {
                    this.isLoading = false
                    this.categories = response.data.data;
                }).catch(error => {
                    if (error.request.statusText) {
                        this.showError(error.request.statusText);
                    } else if (error.message) {
                        this.showError(error.message);
                    } else {
                        this.showError(__('something_went_wrong'));
                    }
                    this.isLoading = false;
                });
        },
        getProducts() {
            this.isLoading = true
            axios.get(this.$apiUrl + '/products/active')
                .then((response) => {
                    this.isLoading = false
                    this.products = response.data.data;
                }).catch(error => {
                    if (error.request.statusText) {
                        this.showError(error.request.statusText);
                    } else if (error.message) {
                        this.showError(error.message);
                    } else {
                        this.showError(__('something_went_wrong'));
                    }
                    this.isLoading = false;
                });
        },
        getBrands() {
            axios.get(this.$apiUrl + '/products/brands/get')
                .then((response) => {
                    this.brands = (response.data.data || []).map(b => ({ id: b.id, name: b.name }));
                }).catch(() => { this.brands = []; });
        },

        saveRecord: function () {
            this.isLoading = true;

            // Resolve slug from selected category/product before sending payload
            let slug = "";
            if (this.popup_type === "category" && this.popup_type_id) {
                const cat = this.categories.find(c => String(c.id) === String(this.popup_type_id));
                slug = cat && cat.slug ? cat.slug : "";
            } else if (this.popup_type === "product" && this.popup_type_id) {
                const prod = this.products.find(p => String(p.id) === String(this.popup_type_id));
                slug = prod && prod.slug ? prod.slug : "";
            }
            if (this.popup_type === "default" || this.popup_type === "popup_url" || this.popup_type === "brand") {
                slug = "";
            }
            this.popup_slug = slug;

            let formData = new FormData();
            formData.append('popup_enabled', this.popup_enabled);
            formData.append('popup_type', this.popup_type);
            formData.append('popup_type_id', this.popup_type_id);
            formData.append('popup_slug', this.popup_slug || "");
            formData.append('popup_image', this.image);
            formData.append('popup_url', this.popup_url);
            formData.append('popup_mode', this.popup_mode);
            formData.append('popup_start_at', this.popup_mode === 'scheduled' ? this.toServer(this.popup_start_at_local) : '');
            formData.append('popup_end_at', this.popup_mode === 'scheduled' ? this.toServer(this.popup_end_at_local) : '');

            let url = this.$apiUrl + '/popup/save';
            let vm = this;

            axios.post(url, formData).then(res => {

                let data = res.data;
                if (data.status === 1) {
                    //this.showSuccess(data.message);
                    this.showMessage("success", data.message);
                    setTimeout(
                        function () {
                            vm.$swal.close();
                            vm.$router.push({ path: '/popup' });
                            vm.getPopupData();
                            vm.isLoading = false;

                        }, 1000);
                } else {
                    vm.showError(data.message);
                    vm.isLoading = false;
                }

            }).catch(error => {
                if (error.request.statusText) {
                    this.showError(error.request.statusText);
                } else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError(__('something_went_wrong'));
                }
                vm.isLoading = false;
            });

        }
    }
}
</script>
