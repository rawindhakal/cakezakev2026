import Image from "next/image";
import { FiCreditCard } from "react-icons/fi";
import { FaMoneyBillWave } from "react-icons/fa";
import { t } from "@/utils/translation";
import RazorpayLogo from "@/assets/payment_methods_svgs/ic_razorpay.svg";
import PaypalLogo from "@/assets/payment_methods_svgs/ic_paypal.svg";
import PaystackLogo from "@/assets/payment_methods_svgs/ic_paystack.svg";
import StripeLogo from "@/assets/payment_methods_svgs/ic_stripe.svg";
import CashfreeLogo from "@/assets/payment_methods_svgs/ic_cashfree.svg";
import MidtransLogo from "@/assets/payment_methods_svgs/Midtrans.svg";
import PhonePeLogo from "@/assets/payment_methods_svgs/Phonepe.svg";
import PaytabsLogo from "@/assets/payment_methods_svgs/ic_paytabs.svg";
import PayuLogo from "@/assets/payment_methods_svgs/payu.png";

export const paymentMethodKeys = [
  { key: "razorpay_payment_method", label: "razorpay" },
  { key: "paypal_payment_method", label: "paypal" },
  { key: "paystack_payment_method", label: "paystack" },
  { key: "stripe_payment_method", label: "stripe" },
  { key: "cashfree_payment_method", label: "cashfree" },
  { key: "midtrans_payment_method", label: "midtrans" },
  { key: "phonepay_payment_method", label: "phonepe" },
  { key: "paytabs_payment_method", label: "paytabs" },
  { key: "payu_payment_method", label: "payu" },
];

// Brand logo per gateway; COD uses a cash icon.
const payMethodLogos = {
  razorpay: RazorpayLogo,
  paypal: PaypalLogo,
  paystack: PaystackLogo,
  stripe: StripeLogo,
  cashfree: CashfreeLogo,
  midtrans: MidtransLogo,
  phonepe: PhonePeLogo,
  paytabs: PaytabsLogo,
  payu: PayuLogo,
};

export const payMethodIcon = (method: string) => {
  if (method === "COD") return <FaMoneyBillWave size={18} />;
  const logo = (payMethodLogos as Record<string, any>)[method];
  if (logo) {
    return (
      <Image
        src={logo}
        alt={method}
        width={24}
        height={24}
        unoptimized
        className="h-6 w-6 object-contain"
      />
    );
  }
  return <FiCreditCard size={18} />;
};


// Subtitle per payment method.
export const payMethodSubtitle = (method: string) => {
  const map: Record<string, string> = {
    COD: t("pay_when_delivered") || "Pay in cash when your order arrives",
    razorpay: t("pay_via_upi_cards") || "UPI, cards, net banking & wallets",
    paypal: t("pay_with_paypal") || "Pay securely with your PayPal account",
    paystack: t("cards_and_bank") || "Cards & bank transfer",
    stripe: t("pay_via_upi_cards") || "Credit & debit cards",
    cashfree: t("pay_via_upi_cards") || "UPI, cards & net banking",
    midtrans: t("cards_and_bank") || "Cards, bank transfer & e-wallets",
    phonepe: t("pay_via_upi_cards") || "UPI & wallet",
    paytabs: t("cards_and_bank") || "Cards & bank transfer",
    payu: t("pay_via_upi_cards") || "UPI, cards, net banking & wallets",
  };
  return map[method] || "";
};

