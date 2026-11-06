/**
 * The second step of a panel login.
 *
 * Both login screens (admin and branch) post to the same endpoint and get the same
 * answer, so the challenge state, the countdowns and the resend rules live here once
 * rather than being written twice and drifting apart.
 *
 * A screen using this mixin needs to:
 *   - call `beginTwoFactor(data)` when a login reply carries `two_factor_required`
 *   - render the code step while `twoFactor.active` is true
 *   - call `finishTwoFactor()` on submit, and `onVerified(data)` is called back with
 *     the same payload a one-step login would have returned
 */
import axios from 'axios';

export default {
    data() {
        return {
            twoFactor: {
                active: false,
                token: '',
                code: '',
                emailHint: '',
                sendsLeft: 0,
                // Seconds until the code dies and until the resend button unlocks.
                expiresIn: 0,
                resendIn: 0,
                verifying: false,
                resending: false,
                error: '',
            },
            twoFactorTimer: null,
        };
    },
    beforeUnmount() {
        this.stopTwoFactorTimer();
    },
    methods: {
        /** Switch the card over to the code step. */
        beginTwoFactor(data) {
            this.twoFactor.active = true;
            this.twoFactor.token = data.challenge_token || '';
            this.twoFactor.code = '';
            this.twoFactor.emailHint = data.email_hint || '';
            this.twoFactor.sendsLeft = Number(data.sends_left || 0);
            this.twoFactor.expiresIn = Number(data.expires_in || 0);
            this.twoFactor.resendIn = Number(data.resend_after || 60);
            this.twoFactor.error = '';
            this.startTwoFactorTimer();
        },

        /** Back to the password screen, abandoning the challenge. */
        cancelTwoFactor() {
            this.stopTwoFactorTimer();
            this.twoFactor.active = false;
            this.twoFactor.token = '';
            this.twoFactor.code = '';
            this.twoFactor.error = '';
        },

        startTwoFactorTimer() {
            this.stopTwoFactorTimer();
            this.twoFactorTimer = setInterval(() => {
                if (this.twoFactor.expiresIn > 0) this.twoFactor.expiresIn -= 1;
                if (this.twoFactor.resendIn > 0) this.twoFactor.resendIn -= 1;
                // An expired code cannot be verified, so say so here rather than letting
                // the user type six digits and be told afterwards.
                if (this.twoFactor.expiresIn === 0 && !this.twoFactor.error) {
                    this.twoFactor.error = this.__('login_session_expired_please_sign_in_again');
                }
            }, 1000);
        },

        stopTwoFactorTimer() {
            if (this.twoFactorTimer) {
                clearInterval(this.twoFactorTimer);
                this.twoFactorTimer = null;
            }
        },

        /** mm:ss for the expiry countdown. */
        twoFactorCountdown() {
            const total = Math.max(this.twoFactor.expiresIn, 0);
            const m = Math.floor(total / 60);
            const s = total % 60;
            return `${m}:${String(s).padStart(2, '0')}`;
        },

        finishTwoFactor() {
            if (this.twoFactor.code.length < 6 || this.twoFactor.verifying) return;

            this.twoFactor.verifying = true;
            this.twoFactor.error = '';

            axios.post(this.$apiUrl + '/login/verify_otp', {
                challenge_token: this.twoFactor.token,
                code: this.twoFactor.code,
            }).then(res => {
                const data = res.data;
                if (data.status === 1) {
                    this.stopTwoFactorTimer();
                    this.onVerified(data.data);
                    return;
                }

                this.twoFactor.error = data.message;
                this.twoFactor.code = '';
                /* A burned challenge cannot be retried — send them back to the password
                   screen instead of leaving them typing into a dead form. */
                if (data.data && data.data.restart) {
                    this.showError(data.message);
                    this.cancelTwoFactor();
                }
            }).catch(error => {
                this.twoFactor.error = error.response?.data?.message || error.message || this.__('something_went_wrong');
            }).finally(() => {
                this.twoFactor.verifying = false;
            });
        },

        resendTwoFactorCode() {
            if (this.twoFactor.resendIn > 0 || this.twoFactor.resending) return;

            this.twoFactor.resending = true;

            axios.post(this.$apiUrl + '/login/resend_otp', {
                challenge_token: this.twoFactor.token,
            }).then(res => {
                const data = res.data;
                if (data.status === 1) {
                    this.showMessage('success', data.message);
                    this.twoFactor.code = '';
                    this.twoFactor.error = '';
                    this.twoFactor.sendsLeft = Number(data.data?.sends_left ?? 0);
                    this.twoFactor.resendIn = Number(data.data?.resend_after ?? 60);
                    // The server restarts the clock on a resend, so mirror that here.
                    this.twoFactor.expiresIn = Math.max(this.twoFactor.expiresIn, 60);
                    return;
                }

                this.showError(data.message);
                if (data.data && data.data.restart) {
                    this.cancelTwoFactor();
                } else if (data.data && data.data.retry_after) {
                    this.twoFactor.resendIn = Number(data.data.retry_after);
                }
            }).catch(error => {
                this.showError(error.response?.data?.message || error.message || this.__('something_went_wrong'));
            }).finally(() => {
                this.twoFactor.resending = false;
            });
        },
    },
};
