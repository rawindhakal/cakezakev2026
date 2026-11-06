/**
 * UnsavedChanges mixin
 * ---------------------------------------------------------------------------
 * Reusable guard for create/edit forms. Warns the user before they lose
 * unsaved edits via:
 *   - in-app route navigation (cancel button, sidebar link, router push) -> beforeRouteLeave
 *   - browser Back / Refresh / Tab-close / external nav               -> beforeunload
 *
 * How to use in a form component (route-level component):
 *
 *   import UnsavedChanges from '@/mixins/UnsavedChanges';
 *
 *   export default {
 *       mixins: [UnsavedChanges],
 *
 *       methods: {
 *           // 1) REQUIRED: return the object whose changes should be tracked.
 *           //    Return your reactive form model (or a plain object built from it).
 *           formState() {
 *               return this.form;            // or { name: this.name, price: this.price, ... }
 *           },
 *
 *           // 2) OPTIONAL: enables a "Save changes" button in the leave dialog.
 *           //    Return a Promise that resolves true on a successful save,
 *           //    false (or throw) if it failed / validation blocked it.
 *           async submitForm() {
 *               return await this.save();    // your existing save method
 *           },
 *       },
 *
 *       // 3) After the form's initial data is loaded, mark it clean:
 *       async mounted() {
 *           await this.loadData();
 *           this.captureFormBaseline();      // baseline = "clean" snapshot
 *       },
 *
 *       // 4) After a successful save, mark it clean again so leaving won't warn:
 *       //    this.captureFormBaseline();  (call inside your save success handler)
 *   };
 *
 * Notes:
 *   - File objects are serialized as a stable marker, so picking then removing
 *     the same file won't falsely read as dirty; picking a NEW file will.
 *   - If a component does not define formState(), the guard stays inert (never dirty).
 */
export default {
    data() {
        return {
            _ucBaseline: null, // JSON snapshot taken when form is "clean"
        };
    },

    computed: {
        isFormDirty() {
            if (this._ucBaseline === null) return false;
            if (typeof this.formState !== 'function') return false;
            return this._ucSerialize(this.formState()) !== this._ucBaseline;
        },
    },

    mounted() {
        this._ucBeforeUnload = (e) => {
            if (!this.isFormDirty) return undefined;
            // Browsers ignore custom text now, but returnValue must be set to prompt.
            e.preventDefault();
            e.returnValue = '';
            return '';
        };
        window.addEventListener('beforeunload', this._ucBeforeUnload);

        // In-app navigation guard.
        // NOTE: Vue Router does NOT pick up `beforeRouteLeave` when it's provided by a
        // mixin (it reads that guard off the raw component object, not merged options),
        // so we register a scoped global guard here and tear it down on unmount instead.
        if (this.$router) {
            this._ucRemoveGuard = this.$router.beforeEach(() => this._ucConfirmLeave());
        }
    },

    beforeUnmount() {
        window.removeEventListener('beforeunload', this._ucBeforeUnload);
        if (this._ucRemoveGuard) this._ucRemoveGuard();
    },

    methods: {
        // Returns true to allow navigation, false to block it (Vue Router beforeEach
        // contract). Async so we can await the user's dialog choice / a save.
        async _ucConfirmLeave() {
            if (!this.isFormDirty) return true;

            const hasSave = typeof this.submitForm === 'function';
            const Swal = window.Swal;

            const result = await Swal.fire({
                title: __('unsaved_changes') || 'Unsaved changes',
                text:
                    __('unsaved_changes_message') ||
                    'You have unsaved changes. What would you like to do?',
                icon: 'warning',
                showCancelButton: true, // "Stay"
                showDenyButton: hasSave, // "Leave without saving" (only when Save exists)
                confirmButtonText: hasSave
                    ? __('save_changes') || 'Save changes'
                    : __('leave_without_saving') || 'Leave without saving',
                denyButtonText: __('leave_without_saving') || 'Leave without saving',
                cancelButtonText: __('stay_on_page') || 'Stay on page',
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                denyButtonColor: '#d33',
                cancelButtonColor: '#6c757d',
                reverseButtons: true,
            });

            // "Stay" (cancel / dismiss) -> block navigation.
            if (result.dismiss) return false;

            // No Save button: confirm == "Leave without saving".
            if (!hasSave) return result.isConfirmed;

            // "Leave without saving" (deny) -> allow, discard edits.
            if (result.isDenied) return true;

            // "Save changes" (confirm) -> save; leave only if it succeeds.
            if (result.isConfirmed) {
                try {
                    const ok = await this.submitForm();
                    if (ok === false) return false; // save failed / validation blocked -> stay
                    this.captureFormBaseline();
                    return true;
                } catch (e) {
                    return false; // exception during save -> stay
                }
            }

            return false;
        },

        _ucSerialize(obj) {
            try {
                return JSON.stringify(obj, (_key, value) => {
                    if (value instanceof File) {
                        return `__file__:${value.name}:${value.size}:${value.lastModified}`;
                    }
                    return value;
                });
            } catch (e) {
                // Non-serializable state (circular, etc.) -> treat as always-changed
                // so we err on the side of warning rather than silently losing edits.
                return null;
            }
        },

        /**
         * Snapshot the current form state as the "clean" baseline.
         * Call after initial data load and after each successful save.
         */
        captureFormBaseline() {
            const snap = () => {
                this._ucBaseline =
                    typeof this.formState === 'function'
                        ? this._ucSerialize(this.formState())
                        : null;
            };
            // Capture synchronously so a save that redirects immediately
            // (this.captureFormBaseline() then this.$router.push()) is already
            // "clean" before the navigation guard runs...
            snap();
            // ...and again on nextTick to absorb any reactive updates that land
            // in the same tick as the initial data load.
            this.$nextTick(snap);
        },

        /** Alias: force the form back to a clean state without re-snapshotting logic elsewhere. */
        clearFormDirty() {
            this.captureFormBaseline();
        },
    },
};
