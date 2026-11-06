import axios from 'axios';

/**
 * Shared plumbing for the individual Settings pages.
 *
 * Every one of them does the same two things: read the settings table into a local
 * `store_settings` object, and POST a whitelisted subset of it back to its own
 * endpoint. Each page declares the fields it owns; this mixin does the rest.
 */
export default {
    data() {
        return {
            isLoading: false,
        };
    },
    methods: {
        /** Pull the settings table in, assigning only the keys this page declares. */
        loadStoreSettings() {
            return axios.get(this.$apiUrl + '/store_settings')
                .then(res => {
                    const rows = res.data?.data?.store_settings || [];
                    rows.forEach(row => {
                        if (row.variable in this.store_settings) {
                            this.store_settings[row.variable] = row.value;
                        }
                    });
                })
                // Leave the defaults in place — the form still renders.
                .catch(() => {});
        },

        /**
         * POST the given fields to `endpoint`, then re-read so the form shows what
         * was actually stored.
         */
        postStoreSettings(endpoint, fields, extra = {}) {
            this.isLoading = true;

            const formData = new FormData();
            fields.forEach(field => {
                if (this.store_settings[field] !== undefined && this.store_settings[field] !== null) {
                    formData.append(field, this.store_settings[field]);
                }
            });
            Object.entries(extra).forEach(([k, v]) => formData.append(k, v));

            return axios.post(this.$apiUrl + endpoint, formData)
                .then(res => {
                    if (res.data.status === 1) {
                        this.showMessage('success', res.data.message);
                        return this.loadStoreSettings();
                    }
                    this.showError(res.data.message);
                })
                .catch(error => {
                    this.showError(
                        error?.response?.data?.message || error.message || __('something_went_wrong')
                    );
                })
                .finally(() => { this.isLoading = false; });
        },
    },
};
