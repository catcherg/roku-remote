import "../styles/tokens.css";
import "../styles/base.css";
import "../styles/components.css";
import { requireAuth, getProfile, signOut } from "../lib/auth";
import { initNav, initFooter } from "../lib/nav";

void initNav();
initFooter();

void (async () => {
  const session = await requireAuth();
  const profile = await getProfile(session.user.id);

  const greeting = document.querySelector<HTMLElement>("#greeting")!;
  const position = document.querySelector<HTMLElement>("#waitlist-position")!;
  const badge = document.querySelector<HTMLElement>("#beta-badge")!;
  const testflight = document.querySelector<HTMLAnchorElement>("#testflight-link")!;

  if (!profile) {
    greeting.textContent = "Welcome!";
    position.textContent =
      "We couldn't load your profile. Refresh, or contact us if it persists.";
    return;
  }

  greeting.textContent = `Hi, ${profile.display_name || profile.email}`;
  position.textContent = `You're #${profile.waitlist_position} on the list.`;

  const labels: Record<string, string> = {
    waitlist: "On the waitlist",
    invited: "Invited to beta",
    tester: "Beta tester",
  };
  badge.textContent = labels[profile.beta_status] ?? profile.beta_status;
  badge.dataset.status = profile.beta_status;

  if (profile.beta_status === "invited" && profile.testflight_url) {
    testflight.href = profile.testflight_url;
    testflight.hidden = false;
  }
})();

document
  .querySelector("#logout-btn")
  ?.addEventListener("click", () => void signOut());
