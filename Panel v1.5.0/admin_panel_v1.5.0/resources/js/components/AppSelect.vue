<template>
    <multiselect
        :model-value="selection"
        :options="mergedOptions"
        :multiple="multiple"
        :searchable="searchable"
        :allow-empty="allowEmpty"
        :close-on-select="!multiple"
        :clear-on-select="!multiple"
        :preserve-search="multiple"
        :taggable="taggable"
        :tag-placeholder="tagPlaceholder || __('press_enter_to_add')"
        :show-labels="false"
        :placeholder="placeholder || __('select')"
        :disabled="disabled"
        :label="labelKey"
        :track-by="trackBy"
        :class="{ 'multiselect--no-search': !searchable, 'multiselect--tags-only': tagsOnly }"
        :internal-search="internalSearch"
        :loading="loading"
        @tag="onTag"
        @search-change="$emit('search-change', $event)"
        @update:model-value="onChange">
        <template #tag="{ option, remove }">
            <span class="multiselect__tag">
                {{ option[labelKey] }}
                <i class="multiselect__tag-icon" @mousedown.prevent="remove(option)"></i>
            </span>
        </template>
        <!-- Forward vue-multiselect's option / selected-label slots so callers can
             render richer rows (e.g. a country flag). Fallback = the plain label. -->
        <template #singleLabel="{ option }">
            <slot name="singleLabel" :option="option">{{ option[labelKey] }}</slot>
        </template>
        <template #option="{ option }">
            <slot name="option" :option="option">{{ option[labelKey] }}</slot>
        </template>
        <template #noResult>{{ __('no_records_found') }}</template>
        <template #noOptions>{{ __('no_records_found') }}</template>
    </multiselect>
</template>

<script>
import Multiselect from 'vue-multiselect';

/**
 * Project-wide dropdown. Wraps vue-multiselect so callers bind plain ids
 * (`v-model="form.zone_id"`) instead of option objects.
 *
 *   <AppSelect v-model="form.zone_id" :options="zones" />                 searchable
 *   <AppSelect v-model="status" :options="opts" :searchable="false" />    short list
 *   <AppSelect v-model="ids" :options="users" multiple />                 tags
 *   <AppSelect v-model="tags" :options="tagOpts" multiple taggable />     free tags
 *   <AppSelect v-model="words" multiple taggable tags-only />             chips, no list
 */
export default {
    name: 'AppSelect',
    components: { Multiselect },
    props: {
        // Plain id (single) or array of ids (multiple).
        modelValue: { type: [Number, String, Array], default: '' },
        options: { type: Array, default: () => [] },
        placeholder: { type: String, default: '' },
        searchable: { type: Boolean, default: true },
        multiple: { type: Boolean, default: false },
        allowEmpty: { type: Boolean, default: true },
        disabled: { type: Boolean, default: false },
        // Let the user create new options by typing (tags). Emits the typed text
        // as the value, so the model holds a mix of ids and free strings.
        taggable: { type: Boolean, default: false },
        // Free-text only: no dropdown at all, just the chips inside the field.
        // For a field whose values the caller invents — there is nothing to pick
        // from, so a list that only repeats what is already chosen is noise.
        tagsOnly: { type: Boolean, default: false },
        tagPlaceholder: { type: String, default: '' },
        labelKey: { type: String, default: 'name' },
        trackBy: { type: String, default: 'id' },
        // Filter the given options in the browser (the default). Set false when the
        // caller answers @search-change by fetching matches itself, so a list longer
        // than one page is still fully searchable.
        internalSearch: { type: Boolean, default: true },
        loading: { type: Boolean, default: false },
    },
    emits: ['update:modelValue', 'search-change'],
    data() {
        // Tags created via @tag before the parent's option list catches up.
        return { addedOptions: [] };
    },
    computed: {
        // vue-multiselect needs an option object for every selected value, so a
        // taggable field must synthesise one for any model value the parent's
        // option list doesn't (yet) contain.
        mergedOptions() {
            // Nothing to offer: `selection` synthesises an option per chosen value.
            if (this.tagsOnly) return [];
            if (!this.taggable) return this.options;
            const seen = new Set(this.options.map(o => String(o[this.trackBy])));
            const extra = this.addedOptions.filter(o => !seen.has(String(o[this.trackBy])));
            return [...this.options, ...extra];
        },
        selection() {
            const pool = this.mergedOptions;
            if (this.multiple) {
                const ids = (Array.isArray(this.modelValue) ? this.modelValue : []).map(String);
                // Preserve any selected value missing from the pool (a freshly
                // typed tag) rather than silently dropping it.
                return ids.map(id =>
                    pool.find(o => String(o[this.trackBy]) === id)
                    || (this.taggable ? { [this.trackBy]: id, [this.labelKey]: id } : null)
                ).filter(Boolean);
            }
            const id = this.modelValue;
            if (id == null) return null;
            return pool.find(o => String(o[this.trackBy]) === String(id)) || null;
        },
    },
    methods: {
        onChange(picked) {
            if (this.multiple) {
                this.$emit('update:modelValue', (picked || []).map(o => o[this.trackBy]));
                return;
            }
            this.$emit('update:modelValue', picked ? picked[this.trackBy] : '');
        },
        onTag(query) {
            const val = String(query || '').trim();
            if (!val) return;
            if (!this.addedOptions.some(o => String(o[this.trackBy]) === val)) {
                this.addedOptions.push({ [this.trackBy]: val, [this.labelKey]: val });
            }
            const current = Array.isArray(this.modelValue) ? this.modelValue.slice() : [];
            if (!current.map(String).includes(val)) current.push(val);
            this.$emit('update:modelValue', current);
        },
    },
};
</script>
