"use client";
import React, { useRef, useState } from "react";
import { useSelector } from "react-redux";
import { toast } from "react-toastify";
import * as api from "@/api/apiRoutes";

interface Props {
  method: string;
  orderId: number | string;
  amount: number;
  onDone: () => void;
}

const TITLES: Record<string, string> = {
  Esewa: "Pay with eSewa",
  BankTransfer: "Pay by bank transfer",
  QrPayment: "Pay by QR",
};

// Payment instructions + proof upload for eSewa / bank transfer / QR. The order is
// already placed; staff verify the payment by hand before dispatch.
export default function OfflinePaymentModal({ method, orderId, amount, onDone }: Props) {
  const offline = useSelector((s: any) => s.Setting?.payment_setting?.offline_payments) || {};
  const [file, setFile] = useState<File | null>(null);
  const [reference, setReference] = useState("");
  const [busy, setBusy] = useState(false);
  const input = useRef<HTMLInputElement>(null);

  const esewa = offline.esewa || {};
  const bank = offline.bank || {};
  const qr = offline.qr || {};
  const section = method === "Esewa" ? esewa : method === "BankTransfer" ? bank : qr;
  const qrImage = method === "Esewa" ? esewa.qr_image : method === "QrPayment" ? qr.qr_image : "";

  const submit = async () => {
    if (!file) return toast.error("Please attach your payment screenshot");
    setBusy(true);
    try {
      const res = await api.submitPaymentProof({ orderId, reference, proof: file });
      if (res?.status == 1) {
        toast.success("Payment proof received. We'll verify it shortly.");
        onDone();
      } else {
        toast.error(res?.message || "Upload failed");
      }
    } catch (e: any) {
      toast.error(e?.message || "Upload failed");
    }
    setBusy(false);
  };

  const row = (k: string, v?: string) =>
    v ? (
      <div className="flex justify-between gap-3 text-sm">
        <span className="SecondaryTextColor">{k}</span>
        <b className="textColor text-right break-all">{v}</b>
      </div>
    ) : null;

  return (
    <div className="fixed inset-0 z-[1000] flex items-end justify-center bg-black/50 p-0 sm:items-center sm:p-4">
      <div className="bodyBackgroundColor w-full max-w-md max-h-[92vh] overflow-y-auto rounded-t-2xl sm:rounded-2xl p-5 shadow-xl">
        <h3 className="text-lg font-bold textColor">{TITLES[method] || "Complete your payment"}</h3>
        <p className="mt-1 text-sm SecondaryTextColor">
          Your order #{orderId} is placed. Pay the exact amount below, then upload the screenshot so we can verify it.
        </p>
        <div className="mt-3 rounded-lg p-3 primaryLightBack text-center">
          <div className="text-xs SecondaryTextColor">Amount to pay</div>
          <div className="text-2xl font-extrabold primaryColor">Rs {Number(amount || 0).toFixed(2)}</div>
        </div>

        {qrImage ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={qrImage} alt="Payment QR" className="mx-auto mt-3 h-56 w-56 rounded-lg border object-contain bg-white" />
        ) : null}

        <div className="mt-3 flex flex-col gap-1.5">
          {method === "Esewa" && (<>{row("eSewa ID", esewa.esewa_id)}{row("Name", esewa.account_name)}</>)}
          {method === "BankTransfer" && (
            <>
              {row("Bank", bank.bank_name)}{row("Branch", bank.branch)}
              {row("Account name", bank.account_name)}{row("Account number", bank.account_number)}
            </>
          )}
        </div>
        {section?.instructions ? <p className="mt-2 text-xs SecondaryTextColor">{section.instructions}</p> : null}

        <div className="mt-4 flex flex-col gap-2">
          <input
            value={reference}
            onChange={(e) => setReference(e.target.value)}
            placeholder="Transaction / reference no. (optional)"
            className="w-full rounded-lg border p-2.5 text-sm bg-transparent textColor"
          />
          <input ref={input} type="file" accept="image/*" hidden onChange={(e) => setFile(e.target.files?.[0] || null)} />
          <button type="button" onClick={() => input.current?.click()} className="rounded-lg border border-dashed p-3 text-sm textColor">
            {file ? `Selected: ${file.name}` : "Upload payment screenshot"}
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={submit}
            className="rounded-lg py-3 font-bold text-white primaryBackColor disabled:opacity-60"
          >
            {busy ? "Uploading…" : "Submit payment proof"}
          </button>
          <button type="button" onClick={onDone} className="text-xs SecondaryTextColor underline py-1">
            Skip for now - our team will contact you
          </button>
        </div>
      </div>
    </div>
  );
}
