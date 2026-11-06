import VegIcon from "@/assets/icon/Veg.svg";
import NonVegIcon from "@/assets/icon/Non-Veg.svg";
import MedicalIcon from "@/assets/icon/Medical.svg";
import EggetarianIcon from "@/assets/icon/eggetarian.svg";
import ChemicalIcon from "@/assets/icon/chemical.svg";

export interface ProductTypeMeta {
  svg: any;
  labelKey: string;
  color: string;
  bg: string;
}

// Product type indicator metadata helper
export const getProductTypeMeta = (indicator: number | string): ProductTypeMeta | null => {
  switch (Number(indicator)) {
    case 1:
      return {
        svg: VegIcon,
        labelKey: "vegetarian",
        color: "text-green-600",
        bg: "primaryLightBack",
      };
    case 2:
      return {
        svg: NonVegIcon,
        labelKey: "non-vegetarian",
        color: "text-red-600",
        bg: "primaryLightBack",
      };
    case 3:
      return {
        svg: ChemicalIcon,
        labelKey: "chemical",
        color: "primaryColor",
        bg: "primaryLightBack",
      };
    case 4:
      return {
        svg: EggetarianIcon,
        labelKey: "eggetarian",
        color: "primaryColor",
        bg: "primaryLightBack",
      };
    case 5:
      return {
        svg: MedicalIcon,
        labelKey: "medical",
        color: "primaryColor",
        bg: "primaryLightBack",
      };
    default:
      return null;
  }
};
