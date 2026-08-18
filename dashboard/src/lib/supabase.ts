import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const supabaseConfigured = Boolean(url && key);

// env 미설정 시에도 빌드가 깨지지 않도록 placeholder로 초기화한다.
export const supabase = createClient(
  url ?? "https://placeholder.supabase.co",
  key ?? "placeholder"
);
