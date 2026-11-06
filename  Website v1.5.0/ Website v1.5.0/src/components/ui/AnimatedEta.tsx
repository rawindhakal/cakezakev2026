import { useState } from "react";
import AnimatedNumber from "@/components/ui/AnimatedNumber";

interface AnimatedEtaProps {
  value: string | number;
  className?: string;
}

const splitNumeric = (text: string) => {
  const match = text.match(/^(\D*)(\d+)(.*)$/);
  return match ? { prefix: match[1], num: Number(match[2]), suffix: match[3] } : null;
};

// Counts the number when only it changes; otherwise slides the new text in. First render is plain.
const AnimatedEta = ({ value, className = "" }: AnimatedEtaProps) => {
  const text = String(value ?? "");
  const [prevText, setPrevText] = useState(text);
  const [swapCount, setSwapCount] = useState(0);
  const current = splitNumeric(text);
  if (prevText !== text) {
    const prev = splitNumeric(prevText);
    const sameShape =
      !!prev && !!current && prev.prefix === current.prefix && prev.suffix === current.suffix;
    setPrevText(text);
    if (!sameShape) setSwapCount((c) => c + 1);
  }

  return (
    <span key={swapCount} className={`inline-block ${swapCount ? "etaAnimSwap" : ""} ${className}`}>
      {current ? (
        <AnimatedNumber
          value={current.num}
          duration={600}
          format={(n) => `${current.prefix}${Math.round(n)}${current.suffix}`}
        />
      ) : (
        text
      )}
    </span>
  );
};

export default AnimatedEta;
