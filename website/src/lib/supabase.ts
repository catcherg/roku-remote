import { createClient } from "@supabase/supabase-js";

// The publishable key is public-by-design (see WEBSITE_FRAMEWORK.md §0.2).
// All data security lives in Postgres Row Level Security policies.
const SUPABASE_URL = "https://ylfmwaoqnrscaenvgght.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_1bdd6kc3Nk7lH6CNn_hqMw_AlYQlZFR";

export interface Profile {
  id: string;
  email: string;
  display_name: string | null;
  created_at: string;
  waitlist_position: number;
  beta_status: "waitlist" | "invited" | "tester";
  testflight_url: string | null;
  referral_code: string;
  referred_by: string | null;
}

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
