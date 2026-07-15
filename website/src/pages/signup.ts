import "../styles/tokens.css";
import "../styles/base.css";
import "../styles/components.css";
import { signUp, validateCredentials, getSession } from "../lib/auth";
import { captureRef } from "../lib/waitlist";
import { setPending, showMessage, clearMessage } from "../lib/forms";
import { initNav, initFooter } from "../lib/nav";

void initNav();
initFooter();

// Already logged in? Straight to the dashboard.
void getSession().then((s) => {
  if (s) location.href = "/account.html";
});

const form = document.querySelector<HTMLFormElement>("#signup-form")!;
const done = document.querySelector<HTMLElement>("#signup-done")!;

form.addEventListener("submit", (e) => {
  e.preventDefault();
  void (async () => {
    clearMessage(form);
    const email = (form.elements.namedItem("email") as HTMLInputElement).value.trim();
    const password = (form.elements.namedItem("password") as HTMLInputElement).value;
    const displayName = (form.elements.namedItem("display_name") as HTMLInputElement).value.trim();

    const invalid = validateCredentials(email, password);
    if (invalid) return showMessage(form, invalid, "error");

    setPending(form, true);
    const { error } = await signUp(email, password, displayName || undefined, captureRef());
    setPending(form, false);

    if (error) return showMessage(form, error, "error");
    form.hidden = true;
    done.hidden = false;
  })();
});
