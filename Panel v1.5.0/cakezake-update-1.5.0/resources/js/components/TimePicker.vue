<template>
    <!-- Time-only flatpickr. The popup gets its own footer with Clear / Done, the way the
         browser's datetime popup has, since a bare time picker cannot empty the field. -->
    <input ref="inp" type="text" class="form-control" :placeholder="placeholder || '--:--'"
        autocomplete="off" :disabled="disabled" :aria-label="ariaLabel" />
</template>

<script>
import flatpickr from 'flatpickr';
import 'flatpickr/dist/flatpickr.min.css';

export default {
    name: 'TimePicker',
    props: {
        // Stored as "HH:MM" 24h — what the native time input produced, so nothing
        // downstream changes.
        modelValue: { type: String, default: '' },
        placeholder: { type: String, default: '' },
        disabled: { type: Boolean, default: false },
        ariaLabel: { type: String, default: '' },
        twelveHour: { type: Boolean, default: true },
        minuteStep: { type: Number, default: 5 },
    },
    emits: ['update:modelValue'],
    mounted() {
        this.fp = flatpickr(this.$refs.inp, {
            enableTime: true,
            noCalendar: true,
            dateFormat: 'H:i',
            altInput: true,
            altFormat: this.twelveHour ? 'h:i K' : 'H:i',
            time_24hr: !this.twelveHour,
            minuteIncrement: this.minuteStep,
            allowInput: false,
            defaultDate: this.modelValue || null,
            onChange: (dates, str) => this.sync(str),
            onClose: (dates, str) => this.sync(str),
            onReady: (dates, str, fp) => this.addFooter(fp),
        });
        if (this.fp.altInput) this.fp.altInput.classList.add('form-control');
    },
    watch: {
        modelValue(val) {
            if (!this.fp) return;
            const cur = this.fp.selectedDates.length ? this.fp.formatDate(this.fp.selectedDates[0], 'H:i') : '';
            if ((val || '') !== cur) this.fp.setDate(val || null, false);
        },
    },
    methods: {
        sync(str) {
            if ((str || '') !== (this.modelValue || '')) this.$emit('update:modelValue', str || '');
        },
        addFooter(fp) {
            const bar = document.createElement('div');
            bar.className = 'tp-footer';
            const clear = document.createElement('button');
            clear.type = 'button';
            clear.className = 'tp-btn tp-btn-clear';
            clear.textContent = __('clear');
            clear.addEventListener('click', () => { fp.clear(false); this.$emit('update:modelValue', ''); fp.close(); });
            const done = document.createElement('button');
            done.type = 'button';
            done.className = 'tp-btn tp-btn-done';
            done.textContent = __('done');
            done.addEventListener('click', () => fp.close());
            bar.append(clear, done);
            fp.calendarContainer.appendChild(bar);
        },
    },
    beforeUnmount() {
        if (this.fp) this.fp.destroy();
    },
};
</script>

<style>
/* Popup renders in <body>, so this stays unscoped. */
.flatpickr-calendar.noCalendar .tp-footer {
    display: flex; justify-content: space-between; gap: .5rem;
    padding: .4rem .6rem .5rem; border-top: 1px solid rgba(0, 0, 0, .08);
}
.tp-btn { border: 0; background: transparent; font-size: .8rem; font-weight: 600; padding: .25rem .5rem; border-radius: 6px; cursor: pointer; }
.tp-btn-clear { color: #dc3545; }
.tp-btn-done { color: var(--bs-primary); }
.tp-btn:hover { background: rgba(0, 0, 0, .05); }
</style>
