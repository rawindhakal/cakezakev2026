import { useEffect, useState } from "react";

// Current layout bucket, matching the breakpoints the home_layout API expects.
const useDeviceBreakpoint = () => {
  const [device, setDevice] = useState("web");

  useEffect(() => {
    const compute = () => {
      const w = window.innerWidth;
      let next = "web";
      if (w < 768) next = "app";
      else if (w < 1024) next = "tablet";
      setDevice(next);
    };
    compute();
    window.addEventListener("resize", compute);
    return () => window.removeEventListener("resize", compute);
  }, []);

  return device;
};

export default useDeviceBreakpoint;
