import "../styles/tokens.css";
import "../styles/base.css";
import "../styles/components.css";
import "../styles/motion.css";
import { requireAuth, getProfile, signOut } from "../lib/auth";
import { initNav, initFooter } from "../lib/nav";
import { countUp } from "../lib/animate";
import { supabase } from "../lib/supabase";

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

  // Count-up waitlist position
  position.innerHTML = `You're <strong class="position-number">#${profile.waitlist_position}</strong> on the list.`;
  const num = position.querySelector<HTMLElement>(".position-number")!;
  countUp(num, profile.waitlist_position, "#");

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

  // ---- Referral loop ----
  const link = `https://getclicker.me/?ref=${profile.referral_code}`;
  const shareText = "I just reserved my spot for Clicker — a Roku remote app with no ads and no subscriptions, one price forever. Join the beta waitlist:";

  document.querySelector<HTMLElement>("#referral-link")!.textContent = link;

  const copyBtn = document.querySelector<HTMLButtonElement>("#copy-referral")!;
  copyBtn.addEventListener("click", () => {
    void navigator.clipboard.writeText(link).then(() => {
      copyBtn.textContent = "Copied!";
      setTimeout(() => (copyBtn.textContent = "Copy"), 1600);
    });
  });

  const enc = encodeURIComponent;
  document.querySelector<HTMLAnchorElement>("#share-x")!.href =
    `https://twitter.com/intent/tweet?text=${enc(shareText)}&url=${enc(link)}`;
  document.querySelector<HTMLAnchorElement>("#share-whatsapp")!.href =
    `https://wa.me/?text=${enc(`${shareText} ${link}`)}`;
  document.querySelector<HTMLAnchorElement>("#share-reddit")!.href =
    `https://www.reddit.com/submit?url=${enc(link)}&title=${enc("Clicker — the remote Roku deserves (beta waitlist)")}`;

  // Referral count via security-definer RPC
  const { data: count } = await supabase.rpc("referral_stats");
  if (typeof count === "number" && count > 0) {
    const el = document.querySelector<HTMLElement>("#referral-count")!;
    el.hidden = false;
    el.innerHTML = `<strong>${count}</strong> ${count === 1 ? "person has" : "people have"} joined through your link — you're prioritized for the next wave. 🎉`;
  }
})();

document
  .querySelector("#logout-btn")
  ?.addEventListener("click", () => void signOut());
