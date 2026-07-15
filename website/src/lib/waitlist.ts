import { supabase } from "./supabase";

/** Persist a ?ref= code across page navigation for later signup. */
export function captureRef(): string | null {
  const fromUrl = new URLSearchParams(location.search).get("ref");
  if (fromUrl) sessionStorage.setItem("clicker-ref", fromUrl);
  return fromUrl ?? sessionStorage.getItem("clicker-ref");
}

/**
 * One-field waitlist opt-in: sends a magic link. New emails become accounts
 * (profile row + waitlist position via DB trigger); existing emails get a
 * login link. No password required.
 */
export async function joinWaitlist(email: string): Promise<{ error?: string }> {
  const ref = captureRef();
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: {
      emailRedirectTo: `${location.origin}/account.html`,
      data: ref ? { ref } : undefined,
    },
  });
  if (!error) return {};
  const m = error.message.toLowerCase();
  if (m.includes("rate limit") || m.includes("too many"))
    return { error: "Too many signups right now — try again in a few minutes." };
  if (m.includes("invalid")) return { error: "Enter a valid email address." };
  return { error: "Something went wrong. Please try again." };
}

/** Wire every [data-waitlist] form on the page. */
export function initWaitlistForms(): void {
  document.querySelectorAll<HTMLFormElement>("form[data-waitlist]").forEach((form) => {
    form.addEventListener("submit", (e) => {
      e.preventDefault();
      void (async () => {
        const input = form.querySelector<HTMLInputElement>("input[type=email]")!;
        const btn = form.querySelector<HTMLButtonElement>("button")!;
        const email = input.value.trim();
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
          input.setCustomValidity("Enter a valid email address.");
          input.reportValidity();
          input.setCustomValidity("");
          return;
        }
        btn.disabled = true;
        btn.textContent = "Reserving…";
        const { error } = await joinWaitlist(email);
        if (error) {
          btn.disabled = false;
          btn.textContent = "Reserve my spot";
          let msg = form.querySelector<HTMLElement>(".waitlist-error");
          if (!msg) {
            msg = document.createElement("p");
            msg.className = "waitlist-error";
            msg.setAttribute("role", "alert");
            form.append(msg);
          }
          msg.textContent = error;
          return;
        }
        form.innerHTML = `
          <div class="waitlist-success" role="status">
            <strong>Your spot is reserved.</strong>
            <span>Check your inbox — one click confirms your place in line.</span>
          </div>`;
      })();
    });
  });
}
