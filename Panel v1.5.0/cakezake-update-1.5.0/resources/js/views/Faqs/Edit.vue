<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" no-close-on-backdrop no-fade
        static centered>
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">{{ __('save') }}
                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <!-- Loading -->
        <div v-if="isLoadingData" class="text-center p-5">
            <b-spinner></b-spinner>
        </div>
        <form ref="my-form" @submit.prevent="saveRecord">
            <!-- Language Tabs with lazy rendering -->
            <b-tabs v-model="activeLanguageTab" content-class="mt-3" v-if="!isLoadingData && languages.length > 0" :nav-class="languages.length <= 1 ? 'd-none' : null">
                <b-tab v-for="language in languages" :key="language.id" :title="language.name" lazy>
                    <template #title>
                        <span :class="{ 'text-primary font-weight-bold': language.is_default }">
                            {{ language.name }}
                        </span>
                    </template>

                    <div class="row">
                        <div class="form-group">
                            <label for="question">{{ __('query') }}</label>
                            <i v-if="language.is_default" class="text-danger">*</i>
                            <input class="form-control" name="query" id="question"
                                :required="language.is_default ? true : undefined"
                                v-model="getTranslation(language.id).question" :placeholder="__('query')">
                        </div>
                        <div class="form-group ">
                            <label for="answer">{{ __('answer') }}</label>
                            <i v-if="language.is_default" class="text-danger">*</i>
                            <textarea class="form-control" name="answer" id="answer"
                                :required="language.is_default ? true : undefined"
                                v-model="getTranslation(language.id).answer" :placeholder="__('answer')"
                                rows="5"></textarea>
                        </div>
                    </div>
                </b-tab>

                <!-- Translate control, inline with the language tabs. -->
                <template #tabs-end>
                    <li class="nav-item ms-auto d-flex align-items-center">
                        <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId"
                            :busy="translating" :progress="translateProgress" @translate="runTranslate" />
                    </li>
                </template>
            </b-tabs>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';
import TranslationHelper from '../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';

export default {
    props: ['record'],
    emits: ['saved', 'modalClose'],
    mixins: [TranslationHelper, UnsavedChanges],
    data: function () {
        return {
            isLoading: false,
            isLoadingData: true,
            languages: [],
            translations: {},
            defaultLanguageId: null,
            activeLanguageTab: 0,
            faq: {
                id: this.record ? this.record.id : null,

            },
            translatableFields: ['question', 'answer'],
        };
    },
    computed: {
        modal_title: function () {
            let title = this.faq.id ? __('edit') : __('add');
            title += " ";
            title += __('frequently_asked_questions');
            return title;
        },
    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return this.translations;
        },
        showModal() {
            this.$refs['my-modal'].show()
        },
        hideModal() {
            this.$refs['my-modal'].hide()
        },
        fetchLanguages() {
            return axios.get(this.$apiUrl + '/active_languages')
                .then(res => {
                    this.languages = res.data.data;
                });
        },

        initializeTranslations() {
            const obj = {};
            this.languages.forEach(lang => {
                obj[lang.id] = {
                    question: '',
                    answer: ''
                };
            });
            this.translations = obj;
        },
        getTranslation(languageId) {
            if (!this.translations[languageId]) {
                this.translations[languageId] = {
                    question: '',
                    answer: ''
                };
            }

            return this.translations[languageId];
        },
        loadFaqWithTranslations() {
            return axios.get(this.$apiUrl + '/faqs', {
                params: { id: this.faq.id }
            })
                .then(res => {

                    const faq = res.data.data;
                    if (!faq) return;

                    const updated = { ...this.translations };

                    // Fill translation table data
                    if (faq.translations) {
                        faq.translations.forEach(trans => {
                            updated[trans.language_id] = {
                                question: trans.question || '',
                                answer: trans.answer || ''
                            };
                        });
                    }

                    // IMPORTANT: Fill default language from base table
                    updated[this.defaultLanguageId] = {
                        question: faq.question || '',
                        answer: faq.answer || ''
                    };

                    this.translations = updated;
                });
        },


        validateDefaultLanguage() {
            const defaultData = this.getTranslation(this.defaultLanguageId);

            if (!defaultData.question || defaultData.question.trim() === '') {
                this.showError(__('please_fill_default_language_required_fields'));
                this.switchToDefaultTab();
                return false;
            }

            return true;
        },

        validateDefaultLanguageForTranslation() {
            const form = this.$refs['my-form'];
            if (form && !form.reportValidity()) {
                this.$nextTick(() => this.switchToDefaultTab());
                return false;
            }
            return this.validateDefaultLanguage();
        },

        switchToDefaultTab() {
            const index = this.languages.findIndex(
                lang => lang.id === this.defaultLanguageId
            );
            if (index !== -1) {
                this.activeLanguageTab = index;
            }
        },

        async saveRecord() {

            if (!this.validateDefaultLanguage()) return;

            this.isLoading = true;

            const isEditMode = this.faq.id ? true : false;
            let faqId = this.faq.id;

            const defaultLang = this.languages.find(l => l.is_default);

            const languagesToSave = [];

            // default first
            if (defaultLang) {
                languagesToSave.push(defaultLang);
            }

            // others only if have data
            this.languages.forEach(lang => {
                if (lang.is_default) return;

                const data = this.getTranslation(lang.id);
                if (data.question && data.question.trim() !== '') {
                    languagesToSave.push(lang);
                }
            });

            try {

                for (let language of languagesToSave) {

                    const formData = new FormData();

                    if (faqId) {
                        formData.append('id', faqId);
                    }

                    formData.append('language_id', language.id);
                    const translation = this.getTranslation(language.id);
                    formData.append('question', translation.question);
                    formData.append('answer', translation.answer);

                    let url = this.$apiUrl + '/faqs/save';
                    if (faqId) {
                        url = this.$apiUrl + '/faqs/update';
                    }

                    const response = await axios.post(url, formData);
                    if (!faqId && response.data.data?.id) {
                        faqId = response.data.data.id;
                        this.faq.id = faqId;
                    }
                }
                if (isEditMode) {
                    this.$emit('saved', __('faq_updated_successfully') || 'FAQ updated successfully');
                } else {
                    this.$emit('saved', __('faq_saved_successfully') || 'FAQ saved successfully');
                }

                // Mark clean so closing the modal doesn't trip the guard.
                this.captureFormBaseline();
                this.hideModal();

            } catch (error) {
                this.showError(error.response?.data?.message || __('something_went_wrong'));
            }

            this.isLoading = false;
        },


    },

    mounted() {
        this.showModal();

        Promise.all([
            this.fetchLanguages()
        ])
            .then(() => {

                const defaultLang = this.languages.find(l => l.is_default);
                if (defaultLang) {
                    this.defaultLanguageId = defaultLang.id;
                }

                this.initializeTranslations();

                if (this.faq.id) {

                    return this.loadFaqWithTranslations();
                }
            })
            .finally(() => {
                this.isLoadingData = false;
                // Baseline the loaded translations for the UnsavedChanges guard.
                this.captureFormBaseline();
            });
    }
}
</script>

<style scoped></style>
