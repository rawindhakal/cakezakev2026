"use client";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import PhoneNumberInput from "@/components/phonenumberinput/PhoneNumberInput";
import useBillingDetails from "@/hooks/useBillingDetails";
import { t } from "@/utils/translation";

interface BillingFieldsProps {
  billingDetails: ReturnType<typeof useBillingDetails>;
  className?: string;
}

// Billing name/mobile/address/country/region inputs.
const BillingFields = ({ billingDetails, className }: BillingFieldsProps) => (
  <div className={className}>
      <div className="flex flex-col gap-1.5">
        <Label className="text-sm font-semibold textColor">{t("name")}</Label>
        <Input
          type="text"
          className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
          placeholder={t("name")}
          value={billingDetails.billing.name}
          onChange={(e) => billingDetails.setField("name", e.target.value)}
          required
        />
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
        <div className="flex flex-col gap-1.5">
          <Label className="text-sm font-semibold textColor">{t("mobileNumber")}</Label>
          {/* Cancel PhoneNumberInput's own top margin. */}
          <div className="-mt-1.5">
            <PhoneNumberInput
              value={billingDetails.billing.mobile}
              countryCode={billingDetails.billing.countryCode}
              onChange={billingDetails.handleMobileChange}
              onCountryReady={billingDetails.handleMobileCountryReady}
            />
          </div>
        </div>
        <div className="flex flex-col gap-1.5">
          <Label className="text-sm font-semibold textColor">{t("enter_city")}</Label>
          <Input
            type="text"
            className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
            placeholder={t("enter_city")}
            value={billingDetails.billing.city}
            onChange={(e) => billingDetails.setField("city", e.target.value)}
            required
          />
        </div>
      </div>
      <div className="flex flex-col gap-1.5">
        <Label className="text-sm font-semibold textColor">{t("address")}</Label>
        <Input
          type="text"
          className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
          placeholder={t("address")}
          value={billingDetails.billing.address}
          onChange={(e) => billingDetails.setField("address", e.target.value)}
          required
        />
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
        <div className="flex flex-col gap-1.5">
          <Label className="text-sm font-semibold textColor">{t("enter_pincode")}</Label>
          <Input
            type="text"
            className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
            placeholder={t("enter_pincode")}
            value={billingDetails.billing.pincode}
            onChange={(e) => billingDetails.setField("pincode", e.target.value)}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label className="text-sm font-semibold textColor">{t("enter_country")}</Label>
          <Select
            value={billingDetails.billing.countryId || undefined}
            onValueChange={billingDetails.handleCountryChange}
          >
            <SelectTrigger className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent focus:primaryColorBorder focus:ring-2 focus:ring-[color-mix(in_srgb,var(--primary-color)_25%,transparent)]">
              <SelectValue placeholder={t("enter_country")} />
            </SelectTrigger>
            <SelectContent>
              {billingDetails.countries.map((c: any) => (
                <SelectItem key={c.id} value={String(c.id)}>
                  {c.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="flex flex-col gap-1.5">
          <Label className="text-sm font-semibold textColor">{t("enter_region")}</Label>
          {/* No regions for this country → free-text field. */}
          {billingDetails.regionsEmpty ? (
            <Input
              type="text"
              className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
              placeholder={t("enter_region")}
              value={billingDetails.billing.regionId}
              onChange={(e) =>
                billingDetails.handleRegionChange(e.target.value)
              }
            />
          ) : (
            <Select
              value={billingDetails.billing.regionId || undefined}
              onValueChange={billingDetails.handleRegionChange}
              disabled={!billingDetails.billing.countryId}
            >
              <SelectTrigger className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent focus:primaryColorBorder focus:ring-2 focus:ring-[color-mix(in_srgb,var(--primary-color)_25%,transparent)]">
                <SelectValue placeholder={t("enter_region")} />
              </SelectTrigger>
              <SelectContent>
                {billingDetails.regions.map((region: any) => (
                  <SelectItem key={region.id} value={String(region.id)}>
                    {region.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        </div>
      </div>
  </div>
);

export default BillingFields;
