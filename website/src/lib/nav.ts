import { getSession, signOut } from "./auth";

/** Renders auth-aware nav links into <div data-nav-auth> and wires logout. */
export async function initNav(): Promise<void> {
  const slot = document.querySelector<HTMLElement>("[data-nav-auth]");
  if (!slot) return;

  const session = await getSession();
  if (session) {
    slot.innerHTML = `
      <a href="/account.html" class="nav-link">Account</a>
      <button type="button" class="btn btn-secondary btn-sm" data-logout>Log out</button>`;
    slot.querySelector("[data-logout]")?.addEventListener("click", () => void signOut());
  } else {
    slot.innerHTML = `
      <a href="/login.html" class="nav-link">Log in</a>
      <a href="/signup.html" class="btn btn-primary btn-sm">Sign up</a>`;
  }
}

/** Sets the current year in <span id="year">. */
export function initFooter(): void {
  const year = document.querySelector<HTMLSpanElement>("#year");
  if (year) year.textContent = String(new Date().getFullYear());
}
