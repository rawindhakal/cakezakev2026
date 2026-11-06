import React, { useState, useEffect } from "react";
import { Dialog, DialogContent, DialogHeader } from "@/components/ui/dialog";
import { RiCloseFill } from "react-icons/ri";
import { t } from "@/utils/translation";
import { FaEye, FaEyeSlash } from "react-icons/fa";
import * as api from "@/api/apiRoutes";
import { toast } from "react-toastify";
import PhoneNumberInput from "../phonenumberinput/PhoneNumberInput";
import { useSelector } from "react-redux";
import PasswordRules from "../passwordrules/PasswordRules";
import { useValidatePassword } from "@/utils/passwordValidation";
import { loadFirebaseAuth } from "@/utils/lazyFirebaseAuth";
import { getRecaptchaVerifier, clearRecaptchaVerifier } from "@/utils/recaptchaVerifier";

interface ForgetPasswordModalProps {
  showForgetPassword: boolean;
  setShowForgetPassword: (value: boolean) => void;
  forgotPasswordType: string;
  isErrorMessage: boolean | string;
}

interface PhoneChangePayload {
  dialCode: string;
  rawPhone: string;
  fullNumber: string;
  lengthError?: string | null;
}

interface CountryReadyPayload {
  dial_code?: string;
}

const ForgetPasswordModal = ({
  showForgetPassword,
  setShowForgetPassword,
  forgotPasswordType,
  isErrorMessage,
}: ForgetPasswordModalProps) => {
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  const setting = useSelector((state: any) => state.Setting.setting);
  const [stage, setStage] = useState(0);
  const [email, setEmail] = useState<string | null>("");
  const [otp, setOtp] = useState<string | null>("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPass, setShowConfirmPass] = useState(false);
  // Password policy error derived from input value
  const passwordPolicyError = useValidatePassword(password);
  const [loading, setLoading] = useState(false);
  const [phoneNumber, setPhoneNumber] = useState<string | null>("");
  const [countryCode, setCountryCode] = useState<string | null>(null);
  const [phoneNumberWithoutCountryCode, setPhoneNumberWithoutCountryCode] =
    useState("");

  // Clear reCAPTCHA verifier when modal closes
  useEffect(() => {
    if (!showForgetPassword) clearRecaptchaVerifier();
  }, [showForgetPassword]);

  const handleOtpChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    if (/^\d{0,6}$/.test(value)) {
      setOtp(value);
    }
  };

  const handlePasswordChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setPassword(e.target.value);
  };

  const handleEmailChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setEmail(e.target.value);
  };

  const handleConfirmPasswordChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setConfirmPassword(e.target.value);
  };
  const handleShowPassword = () => {
    setShowPassword(!showPassword);
  };

  const handleShowConfirmPassword = () => {
    setShowConfirmPass(!showConfirmPass);
  };

  const handleShowModal = () => {
    // Clear reCAPTCHA verifier before closing modal
    clearRecaptchaVerifier();
    setStage(0);
    setLoading(false);
    setPhoneNumber(null);
    setEmail(null);
    setShowForgetPassword(false);
  };

  const handleForgetPassword = async (e: React.MouseEvent) => {
    setLoading(true);
    e.preventDefault();
    try {
      const res = await api.forgotPasswordOTP({ email: email });
      if (res.status == 1) {
        setStage(1);
        toast.success(t("verification_mail_sent_successfully"));
        setLoading(false);
      } else {
        if (res.message == "email_is_not_registered") {
          toast.error(t("email_is_not_registered"));
          setLoading(false);
        } else {
          setLoading(false);
          toast.error(res.message);
        }
      }
    } catch (error) {
      setLoading(false);
      console.log("error", error);
    }
  };

  const handleSendOTP = async (e: React.MouseEvent) => {
    e.preventDefault();
    // Re-entrancy guard to prevent duplicate OTP requests
    if (loading) return;
    setLoading(true);
    // Validate phone number digits before sending OTP
    if (!phoneNumberWithoutCountryCode?.trim()) {
      toast.error(t("please_enter_phone_number") || "Please enter phone number!");
      setLoading(false);
    } else {
      const phoneNumberWithoutSpaces = `${phoneNumber}`.replace(/\s+/g, "");
      if (setting?.firebase_authentication == 1) {
        try {
          const verifier = await getRecaptchaVerifier("forgot-recaptcha-container");
          if (!verifier) {
            toast.error(t("Something went wrong"));
            setLoading(false);
            return;
          }
          const { auth, signInWithPhoneNumber } = await loadFirebaseAuth();
          const confirmationResult = await signInWithPhoneNumber(
            auth,
            phoneNumberWithoutSpaces,
            verifier
          );
          (window as any).confirmationResult = confirmationResult;
          // setTimer(90);
          setLoading(false);
          setStage(1);
        } catch (error: any) {
          console.log("error from send otp", error);
          // Drop the spent verifier — Firebase won't accept it for a retry.
          clearRecaptchaVerifier();
          setPhoneNumber("");
          toast.error(error?.message || t("custom_send_sms_error_message"));
          setLoading(false);
          // setIsOTP(false);
        }
      } else if (setting?.custom_sms_gateway_otp_based == 1) {
        try {
          const res = await api.sendSms({
            mobile: phoneNumberWithoutSpaces,
          });
          if (res?.status == 1) {
            setStage(1);
            setLoading(false);
          } else {
            toast.error(res?.message || t("custom_send_sms_error_message"));
            setLoading(false);
          }
        } catch (error) {
          setPhoneNumber("");
          toast.error(t("custom_send_sms_error_message"));
          setLoading(false);
        }
      } else {
        toast.error(t("Something went wrong"));
        setLoading(false);
      }
    }
  };

  const handleOtpVerification = async (e: React.MouseEvent): Promise<boolean | undefined> => {
    e.preventDefault();
    if (otp == "") {
      toast.error(t("otp_required"));
      return;
    }
    if (setting?.firebase_authentication == 1) {
      setLoading(true);
      try {
        const user = await (window as any).confirmationResult.confirm(otp);
        setLoading(false);
        return true;
      } catch (error) {
        setLoading(false);
        toast.error(t("invalid_otp"));
        return false;
      }
    } else if (setting?.custom_sms_gateway_otp_based == 1) {
      try {
        const response = await api.verifyOTP({
          mobile: phoneNumberWithoutCountryCode,
          // Country code already includes "+" prefix
          country_code: countryCode,
          otp: otp,
        });
        if (
          response?.status == 1 &&
          response?.message ==
            "OTP is valid, but no user found with this phone number."
        ) {
          return false;
        } else if (response?.status == 1) {
          return true;
        } else {
          return false;
        }
      } catch (error) {
        console.log("error", error);
      }
    }
  };

  const handleEmailResetPassword = async (e: React.MouseEvent) => {
    setLoading(true);
    e.preventDefault();
    try {
      if (passwordPolicyError) {
        // Length/complexity rules come from web_settings.password_*.
        toast.error(passwordPolicyError);
        setLoading(false);
        return;
      }
      if (password !== confirmPassword) {
        toast.error(t("confirm_password_message"));
        setLoading(false);
        return;
      }
      const res = await api.forgotPassword({
        email: email,
        otp: otp,
        password: password,
        confirmPassword: confirmPassword,
        type: forgotPasswordType,
      });
      if (res.status == 1) {
        setConfirmPassword("");
        setOtp("");
        setPassword("");
        setEmail("");
        setShowForgetPassword(false);
        toast.success(res.message);
        setStage(0);
        setLoading(false);
      } else {
        setLoading(false);
        setStage(1);
        toast.error(res.message);
      }
    } catch (error) {
      setLoading(false);
      console.log("error", error);
    }
  };

  // Update phone state from PhoneNumberInput callback
  const handlePhoneNoChange = ({ dialCode, rawPhone, fullNumber }: PhoneChangePayload) => {
    setCountryCode(dialCode || "");
    setPhoneNumberWithoutCountryCode(rawPhone || "");
    setPhoneNumber(fullNumber || "");
  };

  // Seed initial country dial code on load
  const handleCountryReady = (country: CountryReadyPayload) => {
    setCountryCode(country?.dial_code || "");
  };

  const verifyUser = async (e: React.MouseEvent) => {
    e.preventDefault();
    // Validate phone number before checking user existence
    if (!phoneNumberWithoutCountryCode?.trim()) {
      toast.error(t("please_enter_phone_number") || "Please enter phone number!");
      return;
    }
    try {
      const res = await api.verifyUserByPhoneNum({
        mobile: phoneNumberWithoutCountryCode,
        countryCode: countryCode,
        type: "phone",
      });
      // Send OTP if user account exists (status 1)
      if (res?.status == 1) {
        handleSendOTP(e);
      } else {
        setShowForgetPassword(false);
        setPhoneNumber("");
        toast.error(t("user_not_exist_message") || res?.message);
      }
    } catch (error) {
      console.log("error", error);
    }
  };

  const handleMobilePasswordChange = async (e: React.MouseEvent) => {
    setLoading(true);
    e.preventDefault();
    try {
      if (passwordPolicyError) {
        // Length/complexity rules come from web_settings.password_*.
        toast.error(passwordPolicyError);
        setLoading(false);
        return;
      }
      if (password !== confirmPassword) {
        toast.error(t("confirm_password_message"));
        setLoading(false);
        return;
      }
      const otpRes = await handleOtpVerification(e);
      if (otpRes == false) {
        toast.error(t("invalid_otp"));
        setLoading(false);
        setPassword("");
        setConfirmPassword("");
        return;
      }
      const res = await api.forgotPassword({
        phone: phoneNumberWithoutCountryCode,
        // Send OTP verification payload for mobile password reset
        otp: otp,
        otpMethod: "firebase",
        type: forgotPasswordType,
        password: password,
        confirmPassword,
      });
      if (res.status == 1) {
        toast.success(res.message);
        setOtp(null);
        setPassword("");
        setConfirmPassword("");
        setShowForgetPassword(false);
        setStage(0);
      } else {
        toast.error(res.message);
        setOtp(null);
        setPassword("");
        setConfirmPassword("");
        setShowForgetPassword(false);
        setStage(0);
      }
    } catch (error) {
      console.log("error", error);
    }
  };

  const handleResetPassword = async (e: React.MouseEvent) => {
    if (forgotPasswordType == "email") {
      handleEmailResetPassword(e);
    } else {
      handleMobilePasswordChange(e);
    }
  };

  return (
    <Dialog open={showForgetPassword}>
      <DialogContent sheetOnMobile title={t("forget_password")}>
        <DialogHeader className="flex justify-between items-center flex-row">
          <h1 className="font-bold text-xl">{t("forget_password")}</h1>
          <div className="closeButtonBg rounded-full p-[8px] cursor-pointer">
            <RiCloseFill size={22} onClick={() => handleShowModal()} />
          </div>
        </DialogHeader>
        <div>
          {stage == 0 ? (
            <div className="flex flex-col w-full gap-4">
              <div className="flex flex-col gap-1">
                {isErrorMessage && (
                  <p className="text-red-500 font-semibold text-sm">
                    {t("forget_password_note")}
                  </p>
                )}
                {forgotPasswordType == "email" ? (
                  <>
                    {" "}
                    <label htmlFor="email" className="font-semibold">
                      {t("email")}
                      <span className="text-red-500">*</span>
                    </label>
                    <input
                      type="email"
                      id="email"
                      placeholder={t("emailPlaceholder")}
                      className="p-2 cardBorder rounded-sm outline-none"
                      value={email ?? ""}
                      onChange={handleEmailChange}
                    />
                  </>
                ) : (
                  <>
                    <PhoneNumberInput
                      value={phoneNumberWithoutCountryCode}
                      onChange={handlePhoneNoChange}
                      onCountryReady={handleCountryReady}
                      autoFocus
                    />
                  </>
                )}
              </div>
              {forgotPasswordType == "email" ? (
                <button
                  className="primaryBackColor rounded-sm text-white font-medium text-base py-2 "
                  onClick={handleForgetPassword}
                  disabled={loading}
                >
                  {loading ? t("loading") : t("get_mail")}
                </button>
              ) : (
                <button
                  className="primaryBackColor rounded-sm text-white font-medium text-base py-2 "
                  onClick={verifyUser}
                  disabled={loading}
                >
                  {loading ? t("loading") : t("verify_user")}
                </button>
              )}
            </div>
          ) : (
            <div className="flex flex-col w-full gap-4">
              <div className="flex flex-col gap-2">
                <div className="flex flex-col gap-1">
                  <span className="font-bold text-base">
                    {t("otp")}
                    <span className="text-red-500">*</span>
                  </span>
                  <div className="">
                    <input
                      type="number"
                      aria-label={t("otp")}
                      inputMode="numeric"
                      pattern="\d*"
                      className="py-2 px-4 cardBorder outline-none rounded-sm w-full"
                      placeholder={t("otpPlaceholder")}
                      value={otp ?? ""}
                      onChange={handleOtpChange}
                      maxLength={6}
                    />
                  </div>
                </div>
                <div className="flex flex-col gap-1">
                  <span className="font-bold text-base">
                    {t("password")}
                    <span className="text-red-500">*</span>
                  </span>
                  <div className="relative w-full ">
                    <input
                      type={showPassword ? "text" : "password"}
                      aria-label={t("password")}
                      className="py-2 px-4 cardBorder outline-none rounded-sm w-full"
                      placeholder={t("please_enter_password")}
                      value={password}
                      onChange={handlePasswordChange}
                    />
                    <button
                      type="button"
                      aria-label="Toggle password visibility"
                      className="absolute right-3 top-3"
                      onClick={handleShowPassword}
                    >
                      {showPassword ? <FaEyeSlash /> : <FaEye />}
                    </button>
                  </div>
                  <PasswordRules password={password} />
                </div>
                <div className="flex flex-col gap-1">
                  <span className="font-bold text-base">
                    {t("confirmPassword")}
                    <span className="text-red-500">*</span>
                  </span>
                  <div className="relative w-full ">
                    <input
                      type={showConfirmPass ? "text" : "password"}
                      aria-label={t("confirmPassword")}
                      className="py-2 px-4 cardBorder outline-none rounded-sm w-full"
                      placeholder={t("please_enter_confirm_password")}
                      value={confirmPassword}
                      onChange={handleConfirmPasswordChange}
                    />
                    <button
                      type="button"
                      aria-label="Toggle password visibility"
                      className="absolute right-3 top-3"
                      onClick={handleShowConfirmPassword}
                    >
                      {showConfirmPass ? <FaEyeSlash /> : <FaEye />}
                    </button>
                  </div>
                </div>
                <button
                  className="primaryBackColor rounded-sm text-white font-medium text-base py-2"
                  onClick={handleResetPassword}
                  disabled={loading}
                >
                  {loading ? t("loading") : t("reset_password")}
                </button>
              </div>
            </div>
          )}
          {/* Dedicated reCAPTCHA container for forgot password modal */}
          <div className="flex justify-center overflow-hidden">
            <div
              id="forgot-recaptcha-container"
              style={{ transform: "scale(0.85)", transformOrigin: "center" }}
            ></div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default ForgetPasswordModal;
