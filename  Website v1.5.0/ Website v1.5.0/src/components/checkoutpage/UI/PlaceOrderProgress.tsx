// Fill + shimmer drawn inside the place-order button while the order is placing.
const PlaceOrderProgress = () => (
  <span
    aria-hidden
    className="pointer-events-none absolute inset-0 overflow-hidden rounded-[inherit]"
  >
    <span className="ckAnimFill absolute inset-0 origin-left rtl:origin-right bg-white/20" />
    <span className="ckAnimShimmer absolute inset-y-0 left-0 w-1/2 bg-gradient-to-r from-transparent via-white/30 to-transparent" />
  </span>
);

export default PlaceOrderProgress;
