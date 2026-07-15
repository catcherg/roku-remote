import type { Session } from "@supabase/supabase-js";
import { supabase, type Profile } from "./supabase";

/** Friendly error mapping — never surface raw Supabase errors to users. */
function friendly(message: string): string {
  const m = message.toLowerCase();
  if (m.includes("invalid login credentials"))
    return "Wrong email or password. Double-check and try again.";
  if (m.includes("email not confirmed"))
    return "Please confirm your email first — check your inbox for the confirmation link.";
  if (m.includes("user already registered"))
    return "An account with this email already exists. Try logging in instead.";
  if (m.includes("rate limit") || m.includes("too many"))
    return "Too many attempts. Wait a minute and try again.";
  if (m.includes("network") || m.includes("fetch"))
    return "Couldn't reach the server. Check your connection and try again.";
  return "Something went wrong. Please try again.";
}

export async function signUp(
  email: string,
  password: string,
  displayName?: string,
): Promise<{ error?: string }> {
  const { error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: displayName ? { display_name: displayName } : undefined,
      emailRedirectTo: `${location.origin}/account.html`,
    },
  });
  return error ? { error: friendly(error.message) } : {};
}

export async function signIn(
  email: string,
  password: string,
): Promise<{ error?: string }> {
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  return error ? { error: friendly(error.message) } : {};
}

export async function signOut(): Promise<void> {
  await supabase.auth.signOut();
  location.href = "/";
}

export async function resetPassword(email: string): Promise<{ error?: string }> {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${location.origin}/reset.html`,
  });
  return error ? { error: friendly(error.message) } : {};
}

export async function updatePassword(password: string): Promise<{ error?: string }> {
  const { error } = await supabase.auth.updateUser({ password });
  return error ? { error: friendly(error.message) } : {};
}

export async function getSession(): Promise<Session | null> {
  const { data } = await supabase.auth.getSession();
  return data.session;
}

/** Redirects to login if there is no session. Returns the session otherwise. */
export async function requireAuth(): Promise<Session> {
  const session = await getSession();
  if (!session) {
    location.href = "/login.html";
    // Never resolves — navigation is in flight.
    return new Promise<never>(() => {});
  }
  return session;
}

export async function getProfile(userId: string): Promise<Profile | null> {
  const { data, error } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .single();
  return error ? null : (data as Profile);
}

/** Validates signup/login form input. Returns an error string or null. */
export function validateCredentials(email: string, password: string): string | null {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return "Enter a valid email address.";
  if (password.length < 10) return "Password must be at least 10 characters.";
  return null;
}
