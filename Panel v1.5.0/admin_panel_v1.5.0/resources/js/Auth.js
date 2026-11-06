import axios from 'axios';
import { bootClarityForUser, trackEvent } from './utils/clarity.js';

class Auth {
    constructor () {
        this.token = window.localStorage.getItem('token');
        let userData = window.localStorage.getItem('user');
        this.user = userData ? JSON.parse(userData) : null;

        if (this.token) {
            axios.defaults.headers.common['Authorization'] = 'Bearer ' + this.token;
        }

        this.restoreIdentity();

        // Existing session: start the Clarity project for this user's panel.
        if (this.user) {
            bootClarityForUser(this.user);
        }
    }

    restoreIdentity () {
        if (!this.user) return;

        if (!window.Role) {
            window.Role = (this.user.role && this.user.role.name) || '';
        }
        if (!window.UserPermissions || !window.UserPermissions.length) {
            window.UserPermissions = JSON.stringify(this.user.allPermissions || []);
        }
        window.BranchId = (this.user.branch && this.user.branch.id) ? Number(this.user.branch.id) : null;
        window.BranchName = (this.user.branch && this.user.branch.name) ? this.user.branch.name : '';
        window.BranchZoneId = (this.user.branch && this.user.branch.zone_id) ? Number(this.user.branch.zone_id) : null;
        window.BranchCountryId = (this.user.branch && this.user.branch.zone && this.user.branch.zone.country_id) ? Number(this.user.branch.zone.country_id) : null;
        window.IsBranchOwner = Number(this.user.is_branch_owner) === 1;
    }

    login (token, user) {
        window.localStorage.setItem('token', token);
        window.localStorage.setItem('user', JSON.stringify(user));
        axios.defaults.headers.common['Authorization'] = 'Bearer ' + token;

        this.token = token;
        this.user = user;

        window.UserPermissions = JSON.stringify(user.allPermissions || []); //Fix Login Issue for Permission
        window.Role = (user.role && user.role.name) || window.Role || ''; //Fix Login Issue for Permission
        window.BranchId = (user.branch && user.branch.id) ? Number(user.branch.id) : null;
        window.BranchName = (user.branch && user.branch.name) ? user.branch.name : '';
        window.BranchZoneId = (user.branch && user.branch.zone_id) ? Number(user.branch.zone_id) : null;
        window.BranchCountryId = (user.branch && user.branch.zone && user.branch.zone.country_id) ? Number(user.branch.zone.country_id) : null;
        window.IsBranchOwner = Number(user.is_branch_owner) === 1;

        bootClarityForUser(user);
        trackEvent(Number(user.role_id) === 3 ? 'db_login' : 'admin_login');
    }

    check () {
        return !! this.token;
    }

    logout () {
        let role_id = this.user.role_id;
        // Branch users belong to the dedicated branch login, not the admin login.
        const isBranchUser = !!(this.user && (this.user.branch_id || this.user.is_branch_owner || (this.user.branch && this.user.branch.id)));
        trackEvent(Number(role_id) === 3 ? 'db_logout' : 'admin_logout');
        const lang = window.localStorage.getItem('lang');
        const language = window.localStorage.getItem('language');
        window.localStorage.clear();
        if (lang !== null) window.localStorage.setItem('lang', lang);
        if (language !== null) window.localStorage.setItem('language', language);

        if (role_id === 3) {
            window.location.replace('/delivery_boy/login');
        } else if (isBranchUser) {
            window.location.replace('/branch/login');
        } else {
            window.location.replace('login');
        }
        this.user = null;
    }

}
export default new Auth();
