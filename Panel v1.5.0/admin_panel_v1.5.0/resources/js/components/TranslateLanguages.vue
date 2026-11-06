<template>
    <!-- Only worth showing when there is somewhere to translate INTO. -->
    <div v-if="targetLanguages.length" class="d-inline-flex align-items-center">
        <button type="button" class="btn btn-sm btn-outline-primary d-inline-flex align-items-center gap-1"
            :disabled="busy" @click="open">
            <b-spinner v-if="busy" small></b-spinner>
            <Languages v-else :size="14" />
            <span>{{ busy && progress ? progress : __('translate') }}</span>
        </button>

        <b-modal v-model="show" :title="__('translate')" centered no-fade
            :no-close-on-backdrop="busy" :no-close-on-esc="busy" :hide-header-close="busy">
            <div class="form-group mb-0">
                <label class="form-label">{{ __('translate_into') }}</label>
                <AppSelect class="form-select" v-model="target" :options="targetLanguageOptions"
                    :allow-empty="false" :disabled="busy" />
                <small class="text-muted d-block mt-2">{{ __('translate_overwrite_hint') }}</small>
                <div v-if="busy && progress" class="text-primary small mt-2 d-flex align-items-center gap-2">
                    <b-spinner small></b-spinner> {{ progress }}
                </div>
            </div>

            <template #footer>
                <b-button size="sm" variant="secondary" :disabled="busy" @click="show = false">
                    {{ __('cancel') }}
                </b-button>
                <b-button size="sm" variant="primary" :disabled="busy" @click="confirm">
                    <b-spinner v-if="busy" small></b-spinner>
                    {{ __('translate') }}
                </b-button>
            </template>
        </b-modal>
    </div>
</template>

<script>
import { Languages } from 'lucide-vue-next';

/**
 * The single "Translate" control for every multi-language form.
 *
 * Sits in the language-tab row. Asks which language to translate into (or all),
 * then emits `translate` with the chosen language ids — the parent (via the
 * TranslationHelper mixin) does the work and drives `busy` / `progress`.
 */
export default {
    name: 'TranslateLanguages',
    components: { Languages },
    props: {
        // Active languages, each { id, code, name, display_name, is_default }.
        languages: { type: Array, default: () => [] },
        // Translating into the default language would be a no-op, so it's excluded.
        defaultLanguageId: { type: [Number, String], default: null },
        busy: { type: Boolean, default: false },
        progress: { type: String, default: '' },
    },
    emits: ['translate'],
    data() {
        return {
            show: false,
            target: 'all',
        };
    },
    computed: {
        targetLanguageOptions() {
            return [{ id: 'all', name: __('all_languages') }]
                .concat((this.targetLanguages || []).map(l => ({ id: l.id, name: l.display_name || l.name })));
        },
        targetLanguages() {
            return (this.languages || []).filter(l => !this.isDefault(l));
        },
    },
    watch: {
        // The parent owns the work; close once it reports it's finished.
        busy(now, before) {
            if (before && !now) this.show = false;
        },
    },
    methods: {
        isDefault(l) {
            if (this.defaultLanguageId != null && l.id != null) {
                return String(l.id) === String(this.defaultLanguageId);
            }
            return !!l.is_default;
        },
        open() {
            // Default to the only option when there's just one target language.
            this.target = this.targetLanguages.length === 1 ? this.targetLanguages[0].id : 'all';
            this.show = true;
        },
        confirm() {
            const ids = this.target === 'all'
                ? this.targetLanguages.map(l => l.id)
                : [this.target];
            this.$emit('translate', ids);
        },
    },
};
</script>
