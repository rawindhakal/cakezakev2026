<template>
    <!-- One box per digit. The boxes are cosmetic: a single value is emitted, so a
         parent treats this exactly like a text input bound with v-model. -->
    <div class="otp-boxes" :class="{ 'otp-boxes-error': hasError }">
        <input v-for="i in length" :key="i" ref="boxes" type="text" inputmode="numeric" autocomplete="one-time-code"
            class="otp-box" maxlength="1" :aria-label="`${__('verification_code')} ${i}`" :disabled="disabled"
            :value="digits[i - 1] || ''" @input="onInput(i - 1, $event)" @keydown="onKeydown(i - 1, $event)"
            @paste="onPaste" @focus="$event.target.select()" />
    </div>
</template>

<script>
export default {
    name: 'OtpInput',
    props: {
        modelValue: { type: String, default: '' },
        length: { type: Number, default: 6 },
        disabled: { type: Boolean, default: false },
        hasError: { type: Boolean, default: false },
    },
    emits: ['update:modelValue', 'complete'],
    computed: {
        digits() {
            return String(this.modelValue || '').slice(0, this.length).split('');
        },
    },
    mounted() {
        this.focusIndex(0);
    },
    methods: {
        focusIndex(i) {
            const box = this.$refs.boxes?.[i];
            if (box) {
                box.focus();
                box.select();
            }
        },
        emit(value) {
            this.$emit('update:modelValue', value);
            if (value.length === this.length) this.$emit('complete', value);
        },
        onInput(index, event) {
            // Strip anything that is not a digit, so a stray character never lands in a box.
            const typed = event.target.value.replace(/\D/g, '');
            const next = this.digits.slice();

            if (!typed) {
                next[index] = '';
                event.target.value = '';
                this.emit(next.join('').replace(/\s/g, ''));
                return;
            }

            /* Typing several digits at once — an autofill from the keyboard's OTP
               suggestion does this — fills from the current box onward rather than
               dropping everything but the first. */
            typed.split('').forEach((digit, offset) => {
                if (index + offset < this.length) next[index + offset] = digit;
            });

            const value = next.join('').slice(0, this.length);
            this.emit(value);
            this.$nextTick(() => this.focusIndex(Math.min(index + typed.length, this.length - 1)));
        },
        onKeydown(index, event) {
            if (event.key === 'Backspace') {
                event.preventDefault();
                const next = this.digits.slice();
                // Backspace on an empty box steps back and clears the one before it,
                // which is what every OTP field people have used already does.
                if (!next[index] && index > 0) {
                    next[index - 1] = '';
                    this.emit(next.join(''));
                    this.$nextTick(() => this.focusIndex(index - 1));
                } else {
                    next[index] = '';
                    this.emit(next.join('').replace(/\s/g, ''));
                }
                return;
            }
            if (event.key === 'ArrowLeft' && index > 0) {
                event.preventDefault();
                this.focusIndex(index - 1);
            }
            if (event.key === 'ArrowRight' && index < this.length - 1) {
                event.preventDefault();
                this.focusIndex(index + 1);
            }
        },
        onPaste(event) {
            event.preventDefault();
            const pasted = (event.clipboardData || window.clipboardData).getData('text').replace(/\D/g, '');
            if (!pasted) return;
            const value = pasted.slice(0, this.length);
            this.emit(value);
            this.$nextTick(() => this.focusIndex(Math.min(value.length, this.length - 1)));
        },
    },
};
</script>

<style>
/* Global, not scoped: the boxes are rendered inside the auth card whose .lg-* styling
   lives in public/assets/css/custom/common.css, and these follow the same tokens. */
.otp-boxes {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1rem;
}

.otp-box {
    flex: 1 1 0;
    min-width: 0;
    height: 52px;
    padding: 0;
    text-align: center;
    font-size: 1.25rem;
    font-weight: 600;
    letter-spacing: 0.02em;
    color: var(--app-ink);
    background-color: var(--app-card-bg);
    border: 1px solid var(--app-card-border);
    border-radius: 10px;
    transition: border-color .15s var(--app-ease), box-shadow .15s var(--app-ease);
}

.otp-box:focus {
    outline: none;
    /* Same tokens as .lg-input:focus, so the boxes pick up the install's own brand
       colour instead of a hardcoded blue. */
    border-color: var(--bs-primary);
    box-shadow: 0 0 0 3px rgba(var(--bs-primary-rgb), .15);
}

.otp-box:disabled {
    opacity: 0.6;
}

.otp-boxes-error .otp-box {
    border-color: var(--bs-danger, #dc3545);
}

@media (max-width: 420px) {
    .otp-boxes {
        gap: 0.35rem;
    }

    .otp-box {
        height: 46px;
        font-size: 1.05rem;
    }
}
</style>
