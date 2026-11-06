<template>
    <input ref="inp" type="text" class="form-control" :placeholder="placeholder" autocomplete="off" />
</template>

<script>
import flatpickr from 'flatpickr';
import 'flatpickr/dist/flatpickr.min.css';

export default {
    name: 'DatePicker',
    props: {
        modelValue: { type: [String, Number, Date], default: '' },
        placeholder: { type: String, default: '' },
        // Stored value format (matches the legacy <input type="date"> => Y-m-d).
        valueFormat: { type: String, default: 'Y-m-d' },
        // Format shown to the user.
        displayFormat: { type: String, default: 'd-m-Y' },
    },
    emits: ['update:modelValue'],
    mounted() {
        this.fp = flatpickr(this.$refs.inp, {
            dateFormat: this.valueFormat,
            altInput: true,
            altFormat: this.displayFormat,
            allowInput: true,
            defaultDate: this.modelValue || null,
            onChange: (dates, str) => this.$emit('update:modelValue', str || null),
        });
    },
    watch: {
        modelValue(val) {
            if (this.fp && (val || '') !== (this.fp.input.value || '')) {
                this.fp.setDate(val || null, false);
            }
        },
    },
    beforeUnmount() {
        if (this.fp) this.fp.destroy();
    },
};
</script>

<style>
/* Flatpickr calendar renders in body (portal) — must be unscoped. Mirrors the
   DateRangePicker theming so single-date pickers match the admin theme color
   on every page that loads this component (incl. the register page). */
.flatpickr-day.selected,
.flatpickr-day.selected:focus,
.flatpickr-day.selected:hover,
.flatpickr-day.selected.prevMonthDay,
.flatpickr-day.selected.nextMonthDay {
    background: var(--bs-primary) !important;
    border-color: var(--bs-primary) !important;
    color: #fff !important;
    box-shadow: none !important;
}
.flatpickr-day.today {
    border-color: var(--bs-primary) !important;
}
.flatpickr-months .flatpickr-prev-month:hover svg,
.flatpickr-months .flatpickr-next-month:hover svg {
    fill: var(--bs-primary) !important;
}
</style>
