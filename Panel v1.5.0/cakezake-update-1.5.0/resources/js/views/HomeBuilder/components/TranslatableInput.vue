<template>
    <div class="hb-translatable">
        <label v-if="label" class="form-label small text-muted mb-1 d-flex justify-content-between">
            <span>{{ label }}</span>
            <span class="badge bg-light-secondary text-secondary" v-if="languages.length > 1">
                {{ activeLangName }}
            </span>
        </label>
        <textarea v-if="type === 'textarea'" class="form-control form-control-sm" rows="2"
            :value="currentValue" :placeholder="placeholder" @input="onInput"></textarea>
        <input v-else type="text" class="form-control form-control-sm"
            :value="currentValue" :placeholder="placeholder" @input="onInput">
    </div>
</template>

<script>
export default {
    name: 'TranslatableInput',
    props: {
        // {langId: text} map
        modelValue: { type: Object, default: () => ({}) },
        languages: { type: Array, default: () => [] },
        activeLang: { type: [Number, String], default: null },
        label: { type: String, default: '' },
        placeholder: { type: String, default: '' },
        type: { type: String, default: 'input' },
    },
    emits: ['update:modelValue'],
    computed: {
        currentValue() {
            const map = this.modelValue || {};
            return map[this.activeLang] || '';
        },
        activeLangName() {
            const l = this.languages.find(x => x.id === this.activeLang);
            return l ? l.name : '';
        },
    },
    methods: {
        onInput(e) {
            const map = { ...(this.modelValue || {}) };
            map[this.activeLang] = e.target.value;
            this.$emit('update:modelValue', map);
        },
    },
};
</script>
