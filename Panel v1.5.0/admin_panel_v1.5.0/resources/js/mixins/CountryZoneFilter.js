import axios from 'axios';

export default {
    data() {
        return {
            czAllowAll: false,     // page overrides to true where a currency total isn't computed
            czShowZone: true,      // page can disable the zone dropdown entirely
            czCountries: [],
            czZones: [],
            czCountryId: 0,        // 0 = All Countries sentinel
            czZoneId: '',          // '' = All Zones
            czCurrency: '',        // selected country's currency symbol (for money display)
        };
    },
    computed: {
        czIsAll() {
            return this.czAllowAll && Number(this.czCountryId) === 0;
        },
        czCountryOptions() {
            const opts = this.czCountries.map(c => ({
                id: Number(c.id),
                label: this.czName(c.name),
                logo_url: c.logo_url || null,
                currency: c.currency || '',
                currency_code: c.currency_code || '',
            }));
            if (this.czAllowAll) {
                opts.unshift({ id: 0, label: __('all_countries'), logo_url: null, currency: '', currency_code: '' });
            }
            return opts;
        },
        czZoneOptions() {
            const list = this.czZones
                .filter(z => Number(z.country_id) === Number(this.czCountryId))
                .map(z => ({ id: Number(z.id), label: this.czName(z.name) }));
            return [{ id: '', label: __('all_zones') }, ...list];
        },
        // A branch user is fixed to its own branch's zone (the server force-scopes
        // every request), so the country/zone dropdowns are hidden for them.
        czIsBranch() {
            return typeof this.$isBranchUser === 'function' ? this.$isBranchUser() : (window.BranchZoneId != null);
        },
        czShowCountry() {
            return !this.czIsBranch && this.czCountries.length > 1;
        },
        czShowZoneDropdown() {
            return !this.czIsBranch && this.czShowZone && !this.czIsAll && this.czZoneOptions.length > 2;
        },
        // API params: '' when "All" is picked, so the server omits the filter.
        czCountryParam() {
            return this.czIsAll || this.czCountryId == null ? '' : this.czCountryId;
        },
        czZoneParam() {
            return this.czZoneId === '' ? '' : this.czZoneId;
        },
    },
    methods: {
        czName(name) {
            if (name == null) return '';
            if (typeof name === 'string') return name;
            if (typeof name === 'object' && !Array.isArray(name)) {
                const loc = window.appLocale || window.localStorage.getItem('lang') || 'en';
                return String(name[loc] || Object.values(name).find(x => x && String(x).trim() !== '') || '').trim();
            }
            return '';
        },
        czLoad() {
            axios.get(this.$apiUrl + '/countries/active').then(r => {
                this.czCountries = r.data?.data || [];
                if (this.czAllowAll) {
                    this.czCountryId = 0;
                } else {
                    const def = this.czCountries.find(c => Number(c.is_default) === 1) || this.czCountries[0];
                    this.czCountryId = def ? Number(def.id) : 0;
                }
                this.czSyncMeta();
                if (this.czOnFilter) this.czOnFilter();
            }).catch(() => { if (this.czOnFilter) this.czOnFilter(); });
            axios.get(this.$apiUrl + '/zones').then(r => { this.czZones = r.data?.data || []; }).catch(() => {});
        },
        // Keep the selected country's currency + date/time formats current (display only).
        czSyncMeta() {
            const c = this.czCountries.find(x => Number(x.id) === Number(this.czCountryId));
            if (c) {
                if (c.currency) this.czCurrency = c.currency;
                window.localStorage.setItem('country_date_format', c.date_format || 'd-m-Y');
                window.localStorage.setItem('country_time_format', c.time_format || 'h:i A');
            }
        },
        czOnCountry(id) {
            this.czCountryId = (id === '' || id == null) ? (this.czAllowAll ? 0 : null) : Number(id);
            if (this.czZoneId && !this.czZoneOptions.some(z => String(z.id) === String(this.czZoneId))) {
                this.czZoneId = '';
            }
            this.czSyncMeta();
            if (this.czOnFilter) this.czOnFilter();
        },
        czOnZone(id) {
            this.czZoneId = (id === '' || id == null) ? '' : Number(id);
            if (this.czOnFilter) this.czOnFilter();
        },
    },
};
