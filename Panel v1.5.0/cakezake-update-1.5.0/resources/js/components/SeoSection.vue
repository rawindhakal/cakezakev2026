<template>
    <div class="col-12 seo-section">
        <hr class="my-4" />
        <div class="d-flex justify-content-between align-items-center mb-2">
            <h5 class="mb-0">{{ __('seo') }}</h5>
            <button v-if="isDefault" type="button" class="btn btn-sm btn-outline-primary"
                :disabled="aiLoading" @click="generate">
                <b-spinner v-if="aiLoading" small></b-spinner>
                <Sparkles v-else :size="15" /> {{ __('generate_seo_with_ai') }}
            </button>
        </div>

        <div class="row">
            <div class="col-md-6">
                <div class="form-group">
                    <label>{{ __('meta_title') }}</label>
                    <div class="ai-wrap" :class="{ 'ai-generating': aiLoading }">
                        <input type="text" class="form-control ai-field"
                            v-model="translation.meta_title" :placeholder="__('enter_meta_title')" />
                    </div>
                </div>
            </div>

            <div class="col-md-6">
                <div class="form-group">
                    <label>{{ __('meta_keywords') }}</label>
                    <div class="ai-wrap" :class="{ 'ai-generating': aiLoading }">
                        <input type="text" class="form-control ai-field"
                            v-model="translation[keywordField]" :placeholder="__('enter_meta_keywords')" />
                    </div>
                </div>
            </div>

            <div class="col-md-6">
                <div class="form-group">
                    <label>{{ __('meta_description') }}</label>
                    <div class="ai-wrap" :class="{ 'ai-generating': aiLoading }">
                        <textarea class="form-control ai-field" rows="3"
                            v-model="translation.meta_description"
                            :placeholder="__('enter_meta_description')"></textarea>
                    </div>
                </div>
            </div>

            <!-- Schema markup stays last; excluded from AI generation. -->
            <div class="col-md-6" v-if="showSchema">
                <div class="form-group">
                    <label>{{ __('schema_markup') }}
                        <small :id="schemaId"
                            class="d-inline-flex px-2 py-1 text-muted bg-secondary bg-opacity-10 border border-secondary border-opacity-10 rounded-2">
                            <i class="fa fa-info-circle"></i>
                        </small>
                        <b-popover :target="schemaId" triggers="hover" placement="left">
                            <p>Schema markup, also known as structured data, is the language search engines use to
                                read and understand the content on your pages. Learn more and generate it using the
                                <a href="https://www.rankranger.com/schema-markup-generator" target="_blank">Rank
                                    Ranger Schema Markup Generator</a>.</p>
                        </b-popover>
                    </label>
                    <textarea class="form-control" rows="3" v-model="translation.schema_markup"
                        :placeholder="__('enter_schema_markup')"></textarea>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import { Sparkles } from 'lucide-vue-next';

let _seoUid = 0;

export default {
    name: 'SeoSection',
    components: { Sparkles },
    props: {
        // The per-language translation object; its keys are mutated in place,
        // exactly like the inline blocks did (translations[lang.id].meta_title).
        translation: { type: Object, required: true },
        // AI button + generation only on the default-language tab.
        isDefault: { type: Boolean, default: false },
        showSchema: { type: Boolean, default: true },
        // SEO Settings stores the singular `meta_keyword`; everything else plural.
        keywordField: { type: String, default: 'meta_keywords' },
        // { name, description, context } fed to the AI generator.
        context: { type: Object, default: () => ({}) },
        // Unique suffix for the schema popover target (pass language.id).
        uid: { type: [String, Number], default: '' },
    },
    data() {
        return {
            aiLoading: false,
            _localUid: ++_seoUid,
        };
    },
    computed: {
        schemaId() {
            return 'seo_schema_' + (this.uid !== '' ? this.uid : this._localUid);
        },
    },
    methods: {
        generate() {
            const name = String(this.context.name || '').trim();
            if (!name) {
                this.showError(__('please_enter_title_first') || 'Please enter a title/name first');
                return;
            }
            this.aiLoading = true;
            axios.post(this.$apiUrl + '/generate_seo', {
                name,
                description: this.context.description || '',
                context: this.context.context || '',
            }).then(r => {
                if (r.data.status === 1 || r.data.status === '1') {
                    const d = r.data.data || {};
                    if (d.meta_title) this.translation.meta_title = d.meta_title;
                    if (d.meta_description) this.translation.meta_description = d.meta_description;
                    if (d.meta_keywords) this.translation[this.keywordField] = d.meta_keywords;
                    this.showMessage('success', __('content_generated_successfully'));
                } else {
                    this.showError(r.data.message || __('ai_generation_failed'));
                }
            }).catch(err => {
                this.showError(err.response?.data?.message || __('ai_generation_failed'));
            }).finally(() => { this.aiLoading = false; });
        },
    },
};
</script>
