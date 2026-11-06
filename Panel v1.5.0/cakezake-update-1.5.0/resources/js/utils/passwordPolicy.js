import axios from 'axios';

// Mirrors CommonHelper::validatePasswordPolicy so forms can validate inline.
// Fetch the policy once, then call passwordPolicyError(password, policy) on input.

const DEFAULT_POLICY = {
    min_length: 5,
    max_length: 0,
    require_uppercase: 0,
    require_lowercase: 0,
    require_number: 0,
    require_special: 0,
};

export function fetchPasswordPolicy() {
    return axios.get(window.baseUrl + '/api/password_policy')
        .then(res => ({ ...DEFAULT_POLICY, ...(res.data && res.data.data ? res.data.data : {}) }))
        .catch(() => ({ ...DEFAULT_POLICY }));
}

// Returns an inline error string, or '' when the password satisfies the policy.
export function passwordPolicyError(password, policy) {
    const p = { ...DEFAULT_POLICY, ...(policy || {}) };
    const pwd = password == null ? '' : String(password);
    const len = pwd.length;
    const min = Number(p.min_length) > 0 ? Number(p.min_length) : 5;

    if (len < min) return __('password_must_be_at_least_x_characters').replace(':count', min);
    if (Number(p.max_length) > 0 && len > Number(p.max_length)) {
        return __('password_must_not_exceed_x_characters').replace(':count', Number(p.max_length));
    }
    if (Number(p.require_uppercase) === 1 && !/[A-Z]/.test(pwd)) return __('password_must_contain_an_uppercase_letter');
    if (Number(p.require_lowercase) === 1 && !/[a-z]/.test(pwd)) return __('password_must_contain_a_lowercase_letter');
    if (Number(p.require_number) === 1 && !/[0-9]/.test(pwd)) return __('password_must_contain_a_number');
    if (Number(p.require_special) === 1 && !/[^A-Za-z0-9]/.test(pwd)) return __('password_must_contain_a_special_character');
    return '';
}
