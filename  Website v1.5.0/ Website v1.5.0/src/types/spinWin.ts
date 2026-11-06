// Shapes matching GET /customer/spin_wheel and POST /customer/spin_wheel/spin response bodies.

// Spin wheel campaign theme configuration options.
export interface SpinWheelTheme {
  /** Main background color for the spin wheel stage and cabinet. */
  bg_color?: string;
  /** Campaign title first line color. */
  title_color?: string;
  /** Campaign title second line color. */
  title_color_2?: string;
  /** Pointer fill color. */
  pointer_color?: string;
  /** Outer rim border color. */
  border_color?: string;
  /** Divider line and inner ring color. */
  line_color?: string;
  /** Spin button background color. */
  button_color?: string;
  /** Spin button label text (defaults to "SPIN"). */
  button_text?: string;
  /** Spin button text color. */
  button_text_color?: string;
  segment_fill?: string;
  /** Center hub icon image URL. */
  hub_icon_url?: string;
  /** Side chase-light dot color. */
  light_color?: string;
}

export interface SpinWheelCampaign {
  id: number;
  name: string;
  theme?: SpinWheelTheme;
}

export interface SpinWheelSegment {
  index: number;
  id: number;
  label: string;
  display_mode?: string;
  color: string;
  text_color?: string;
  icon_url?: string;
}

export interface SpinWheelSpins {
  spins_per_day: number;
  used_today: number;
  remaining_today: number;
  max_spins_per_user?: number;
  used_lifetime?: number;
  remaining_lifetime?: number | null;
  can_spin: boolean;
  // Human-readable reason message when user cannot spin.
  reason?: string | null;
  // Machine-readable key for localized reason messages.
  reason_key?: string | null;
  next_spin_at?: string | null;
  next_spin_at_label?: string | null;
  /** Seconds remaining until next spin is available. */
  next_spin_in_seconds?: number | null;
}

export interface SpinWheelData {
  is_available: number; // 0 | 1
  requires_login: number; // 0 | 1
  message?: string;
  campaign: SpinWheelCampaign;
  segments: SpinWheelSegment[];
  spins: SpinWheelSpins;
  currency?: string;
  currency_code?: string;
  decimal_point?: number;
}

// Promo code reward details won from spin wheel.
export interface SpinWheelPromoCode {
  id: number;
  promo_code: string;
  title: string;
  discount_type: string;
  discount: number;
  max_discount_amount: number;
  minimum_order_amount: number;
  start_date: string;
  end_date: string;
  start_date_label: string;
  end_date_label: string;
}

// Wallet credit reward won from spin wheel.
export interface SpinWheelWalletReward {
  amount: number;
  [key: string]: any;
}

// Promo code details for items in spin wheel reward history.
export interface SpinWheelRewardPromoCode {
  promo_code: string;
  discount_type: string;
  discount: number;
  max_discount_amount: number;
  minimum_order_amount: number;
  start_date: string;
  end_date: string;
  end_date_label: string;
}

export interface SpinWheelReward {
  id: number;
  /** Reward type ("wallet" | "promo_code" | "free_delivery"). */
  reward_type: string;
  label: string;
  campaign_name?: string;
  icon_url?: string;
  /** Won reward value or discount amount. */
  amount: number;
  currency?: string;
  currency_code?: string;
  won_at: string;
  won_at_label: string;
  promo_code: SpinWheelRewardPromoCode | null;
}

export interface SpinWheelRewardsSummary {
  spins: number;
  wins: number;
  wallet_won: number;
  coupons_won: number;
  free_deliveries_won: number;
}

export interface SpinWheelRewardsData {
  rewards: SpinWheelReward[];
  summary: SpinWheelRewardsSummary;
}

export interface SpinWheelSpinResult {
  segment_id: number;
  segment_index: number;
  /** Spin result status ("win" | "lose"). */
  result: string;
  /** Reward type identifier for wins. */
  reward_type?: string;
  label?: string;
  title?: string;
  message?: string;
  promo_code?: SpinWheelPromoCode | null;
  wallet?: SpinWheelWalletReward | null;
  /** Detailed reward entry matching reward history shape. */
  reward?: SpinWheelReward | null;
  spins?: SpinWheelSpins;
  currency?: string;
  currency_code?: string;
  decimal_point?: number;
}

