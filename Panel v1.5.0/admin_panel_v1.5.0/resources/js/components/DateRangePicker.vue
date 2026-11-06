<template>
    <div class="date-range-picker">
        <input
            ref="inputRef"
            type="text"
            class="form-control"
            :placeholder="placeholderText"
            readonly
        />
    </div>
</template>

<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, useAttrs, watch } from 'vue';
import flatpickr from 'flatpickr';
import 'flatpickr/dist/flatpickr.min.css';

const props = defineProps({
    modelValue: {
        type: String,
        default: ''
    },
    placeholder: {
        type: String,
        default: ''
    },
    config: {
        type: Object,
        default: () => ({})
    }
});

const emit = defineEmits(['update:modelValue', 'change', 'update']);
const attrs = useAttrs();
const inputRef = ref(null);
const flatpickrInstance = ref(null);
const isSyncingExternally = ref(false);

const defaultConfig = {
    dateFormat: 'd-m-Y',
    mode: 'range'
};

const placeholderText = computed(() => props.placeholder || __('select_date'));

const resolvedConfig = computed(() => ({
    ...defaultConfig,
    ...attrs,
    ...props.config
}));

const emitRange = async (value) => {
    emit('update:modelValue', value);
    await nextTick();
    emit('change', value);
    emit('update', value);
};

const syncPickerValue = (value) => {
    if (!flatpickrInstance.value) {
        return;
    }

    isSyncingExternally.value = true;

    if (!value) {
        flatpickrInstance.value.clear(false);
        flatpickrInstance.value.input.value = '';
        if (flatpickrInstance.value.altInput) {
            flatpickrInstance.value.altInput.value = '';
        }
        isSyncingExternally.value = false;
        return;
    }

    if (value !== flatpickrInstance.value.input.value) {
        flatpickrInstance.value.setDate(value, false, resolvedConfig.value.dateFormat);
    }

    isSyncingExternally.value = false;
};

onMounted(() => {
    flatpickrInstance.value = flatpickr(inputRef.value, {
        ...resolvedConfig.value,
        onChange: async (selectedDates, dateStr, instance) => {
            if (isSyncingExternally.value) {
                return;
            }

            if (selectedDates.length === 0) {
                await emitRange('');
                return;
            }

            if (selectedDates.length !== 2) {
                // Half a range: wait for the second click.
                return;
            }

            const [start, end] = selectedDates;
            if (start.toDateString() !== end.toDateString()) {
                await emitRange(dateStr);
                return;
            }

            const format = resolvedConfig.value.dateFormat || 'd-m-Y';
            const separator = instance.l10n?.rangeSeparator ?? ' to ';
            const day = instance.formatDate(start, format);
            const value = day + separator + day;

            // Show the full range in the field too, so it reads like any other range.
            instance.input.value = value;
            if (instance.altInput) {
                instance.altInput.value = value;
            }

            await emitRange(value);
        }
    });

    syncPickerValue(props.modelValue);
});

watch(
    () => props.modelValue,
    (value) => {
        syncPickerValue(value);
    }
);

watch(
    resolvedConfig,
    (value) => {
        if (!flatpickrInstance.value) {
            return;
        }

        Object.entries(value).forEach(([key, optionValue]) => {
            if (key === 'onChange') {
                return;
            }

            flatpickrInstance.value.set(key, optionValue);
        });
    },
    { deep: true }
);

onBeforeUnmount(() => {
    if (flatpickrInstance.value) {
        flatpickrInstance.value.destroy();
        flatpickrInstance.value = null;
    }
});
</script>

<style scoped>
.date-range-picker {
    width: 100%;
}

.date-range-picker :deep(.form-control[readonly]) {
    background-color: var(--app-card-bg) !important;
    color: var(--app-ink) !important;
    cursor: pointer;
}
</style>

<style>
/* Flatpickr calendar renders in body (portal) — must be unscoped */
.flatpickr-day.selected,
.flatpickr-day.startRange,
.flatpickr-day.endRange,
.flatpickr-day.selected.inRange,
.flatpickr-day.startRange.inRange,
.flatpickr-day.endRange.inRange,
.flatpickr-day.selected:focus,
.flatpickr-day.startRange:focus,
.flatpickr-day.endRange:focus,
.flatpickr-day.selected:hover,
.flatpickr-day.startRange:hover,
.flatpickr-day.endRange:hover,
.flatpickr-day.selected.prevMonthDay,
.flatpickr-day.startRange.prevMonthDay,
.flatpickr-day.endRange.prevMonthDay,
.flatpickr-day.selected.nextMonthDay,
.flatpickr-day.startRange.nextMonthDay,
.flatpickr-day.endRange.nextMonthDay {
    background: var(--bs-primary) !important;
    border-color: var(--bs-primary) !important;
    color: #fff !important;
    box-shadow: none !important;
}

.flatpickr-day.inRange,
.flatpickr-day.prevMonthDay.inRange,
.flatpickr-day.nextMonthDay.inRange,
.flatpickr-day.today.inRange,
.flatpickr-day.prevMonthDay.today.inRange,
.flatpickr-day.nextMonthDay.today.inRange,
.flatpickr-day:hover,
.flatpickr-day.prevMonthDay:hover,
.flatpickr-day.nextMonthDay:hover,
.flatpickr-day:focus,
.flatpickr-day.prevMonthDay:focus,
.flatpickr-day.nextMonthDay:focus {
    background: rgba(var(--bs-primary-rgb), 0.15) !important;
    border-color: rgba(var(--bs-primary-rgb), 0.15) !important;
    box-shadow: none !important;
}

.flatpickr-day.today {
    border-color: var(--bs-primary) !important;
}
.flatpickr-day.today:hover,
.flatpickr-day.today:focus {
    background: var(--bs-primary) !important;
    border-color: var(--bs-primary) !important;
    color: #fff !important;
}
</style>
