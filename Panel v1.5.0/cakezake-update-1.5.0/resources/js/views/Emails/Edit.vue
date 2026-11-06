<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" size="lg" scrollable no-close-on-backdrop
        no-fade static id="mymodal">
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">{{ __('save') }}
                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord">

            <div v-if="emailError" class="alert alert-light-warning color-warning alert-dismissible fade show"
                role="alert">
                <strong><i class="bi bi-exclamation-triangle"></i> {{ __('warning') }}</strong>
                {{ emailErrorMessage }}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>

            <div class="row">

                <div class="form-group">
                    <label for="type">{{ __('type') }}</label>
                    <AppSelect v-model="type" :placeholder="__('select_type')" :options="type_options"
                        :allow-empty="false" />
                </div>

                <!-- Who will actually receive this, for the chosen type. -->
                <div class="alert alert-info py-2 small" v-if="typeNote">{{ typeNote }}</div>

                <div class="form-group" v-if="type === 'user'">
                    <label> {{ __('customer') }} </label>
                    <AppSelect multiple v-model="type_ids" :placeholder="__('select_customer')" :options="users_options" />

                </div>

                <div class="form-group" v-if="type === 'delivery_boy'">
                    <!-- Button OUTSIDE the label: a label click forwards to controls inside it. -->
                    <div class="d-flex align-items-center">
                        <label class="mb-0"> {{ __('delivery_boy') }} </label>
                        <button type="button" class="btn btn-sm btn-outline-primary ms-auto py-0"
                            @click="selectAllDeliveryBoys">
                            {{ allBoysSelected ? __('clear_all') : __('select_all') }}
                        </button>
                    </div>
                    <AppSelect multiple v-model="type_ids" :placeholder="__('select_delivery_boy')"
                        :options="delivery_boys_options" />
                </div>

                <div class="form-group">
                    <label for="title"> {{ __('title') }}</label>
                    <input type="text" name="title" id="title" required v-model="title" class="form-control"
                        :placeholder="__('title')">
                </div>

                <div class="form-group">
                    <label for="message"> {{ __('message') }}</label>

                    <!-- Clickable placeholders: insert into message at cursor (replaced on send). -->
                    <div v-if="emailPlaceholders.length" class="py-2 small">
                        <strong>{{ __('placeholders') }}:</strong>
                        {{ __('click_to_insert_at_cursor_location') }}
                        <div class="mt-1">
                            <button v-for="ph in emailPlaceholders" :key="ph" type="button"
                                class="btn btn-sm btn-primary me-1 mb-1" @click="insertPlaceholder(ph)">
                                {{ ph }}
                            </button>
                        </div>
                    </div>

                    <div class="form-floating mb-3">
                        <editor
                            v-if="tinymceReady"
                            ref="tinymceEditor"
                            :placeholder="__('enter_message_here')"
                            v-model="message"
                            :init="tinymceInit"
                            tinymce-script-src="/assets/js/tinymce/tinymce.min.js?v=7922"
                            license-key="gpl"
                        />
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
                    <FileUpload v-model="image" accept="image/*,application/pdf" :preview-url="image_url" />
                </div>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';
import Editor from '@tinymce/tinymce-vue';
import { tinymceInit as buildTinymceInit } from '../../utils/tinymce.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';
export default {
    props: ['record', 'users', 'delivery_boys'],
    mixins: [UnsavedChanges],
    components: { 'editor': Editor },
    data: function () {
        return {
            isLoading: false,
            id: this.record ? this.record.id : null,
            type: this.record ? this.record.type : "",
            type_ids: this.record ? this.record.type_id : [],
            type_id: this.record ? this.record.type_id : 0,
            title: this.record ? this.record.title : "",
            message: this.record ? this.record.message : "",
            include_image: false,
            image: null,
            image_url: this.record ? this.record.image : "",

            emailError: false,
            emailErrorMessage: "",
            tinymceReady: false,
            // Shared TinyMCE config (utils/tinymce.js).
            tinymceInit: buildTinymceInit(),
        };
    },
    computed: {
        modal_title: function () {
            let title = this.id ? __('edit') : __('add');
            title += " ";
            title += __('email');
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
            return (this.delivery_boys || []).map(b => ({ id: b.id, name: b.name }));
        },
        allBoysSelected() {
            const ids = Array.isArray(this.type_ids) ? this.type_ids : [];
            return this.delivery_boys_options.length > 0 && ids.length === this.delivery_boys_options.length;
        },
        typeNote() {
            switch (this.type) {
                case 'default': return __('email_note_default');
                case 'user': return __('email_note_user');
                case 'cart': return __('email_note_cart');
                case 'delivery_boy': return __('email_note_delivery_boy');
                default: return '';
            }
        },
        type_options() {
            // Branch users may only email their own delivery boys.
            if (this.$isBranchUser && this.$isBranchUser()) {
                return [{ id: 'delivery_boy', name: __('delivery_boy') }];
            }
            return [
                { id: 'default', name: __('default') },
                { id: 'user', name: __('customer') },
                { id: 'cart', name: __('cart') },
                { id: 'delivery_boy', name: __('delivery_boy') },
            ];
        },
        // Placeholders the send-mail controller (EmailsApiController@save) replaces
        // in title + message before sending.
        emailPlaceholders() {
            const base = ['[Customer Name]', '[Customer Email]', '[App Name]', '[Support Email]'];
            // Only the cart audience has a cart to render, so the token is offered there.
            return this.type === 'cart' ? [...base, '[Cart Products]'] : base;
        },
    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return {
                type: this.type,
                type_ids: this.type_ids,
                type_id: this.type_id,
                title: this.title,
                message: this.message,
                include_image: this.include_image,
                image: this.image,
            };
        },
        selectAllDeliveryBoys() {
            this.type_ids = this.allBoysSelected ? [] : this.delivery_boys_options.map(o => o.id);
        },
        // Ensure window.tinymce exists before the <editor> mounts (single script load).
        loadTinymce() {
            if (window.tinymce) { this.tinymceReady = true; return; }
            const src = '/assets/js/tinymce/tinymce.min.js?v=7922';
            let s = document.querySelector('script[data-tinymce-loader]');
            if (!s) {
                s = document.createElement('script');
                s.src = src;
                s.setAttribute('data-tinymce-loader', '1');
                s.referrerPolicy = 'origin';
                document.head.appendChild(s);
            }
            const done = () => { this.tinymceReady = true; };
            if (window.tinymce) { done(); return; }
            s.addEventListener('load', done);
            s.addEventListener('error', done);
        },
        showModal() {
            this.$refs['my-modal'].show()
        },
        hideModal() {
            this.$refs['my-modal'].hide()
        },
        // Insert a placeholder token into the TinyMCE editor at the cursor.
        insertPlaceholder(ph) {
            const editorCmp = this.$refs && this.$refs.tinymceEditor;
            const ed = editorCmp && typeof editorCmp.getEditor === 'function' ? editorCmp.getEditor() : null;
            if (ed && typeof ed.insertContent === 'function') {
                ed.insertContent(ph + ' ');
                this.message = ed.getContent();
            } else {
                this.message = (this.message || '') + ph + ' ';
            }
        },

        // Ensure we always POST the latest TinyMCE content (sometimes v-model lags until blur).
        syncEditorMessage() {
            const editorCmp = this.$refs && this.$refs.tinymceEditor;
            if (!editorCmp || typeof editorCmp.getEditor !== 'function') return;
            const tinymceEditor = editorCmp.getEditor();
            if (tinymceEditor && typeof tinymceEditor.getContent === 'function') {
                this.message = tinymceEditor.getContent();
            }
        },
        // Per-type required checks: the recipients the chosen type uses must exist.
        validate() {
            if (!this.type) { this.showError(__('please_select_type')); return false; }

            const ids = Array.isArray(this.type_ids) ? this.type_ids : [];
            if (this.type === 'user' && ids.length === 0) {
                this.showError(__('please_select_at_least_one_customer')); return false;
            }
            if (this.type === 'delivery_boy' && ids.length === 0) {
                this.showError(__('please_select_at_least_one_delivery_boy')); return false;
            }
            if (!String(this.title || '').trim()) { this.showError(__('please_enter_title')); return false; }
            if (!String(this.message || '').trim()) { this.showError(__('please_enter_message')); return false; }
            return true;
        },
        saveRecord: function () {
            // Sync the editor first so message validation sees the latest HTML.
            this.syncEditorMessage();
            if (!this.validate()) return;
            let vm = this;
            this.isLoading = true;
            let formData = new FormData();
            if (this.id) {
                formData.append('id', this.id);
            }
            formData.append('type', this.type);
            formData.append('type_ids', this.type_ids);
            formData.append('type_id', this.type_id);
            formData.append('type_link', this.type_link);
            formData.append('title', this.title);
            formData.append('message', this.message);
            formData.append('include_image', this.include_image);
            formData.append('image', this.image || '');
            let url = this.$apiUrl + '/emails/save';
            if (this.id) {
                url = this.$apiUrl + '/emails/update';
            }
            axios.post(url, formData, {
                headers: {
                    'Content-Type': 'multipart/form-data'
                }
            }).then(res => {
                let data = res.data;
                if (data.status === 1) {
                    let email = data.data;

                    if (email && email?.status === 0) {
                        this.emailError = true;
                        this.emailErrorMessage = email.message;
                    }

                    // Mark clean so the post-save redirect doesn't trip the guard.
                    vm.captureFormBaseline();
                    setTimeout(function () {
                        vm.$eventBus.emit('emailSaved', data.message);
                        vm.hideModal();
                        vm.$swal.close();
                        vm.$router.push({ path: '/emails' });
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
        this.loadTinymce();
        this.showModal();
        // Baseline the prop-populated form for the UnsavedChanges guard.
        this.captureFormBaseline();
    }
}
</script>

<style scoped></style>
