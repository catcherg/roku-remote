import "../styles/tokens.css";
import "../styles/base.css";
import "../styles/components.css";
import { signIn, resetPassword, getSession } from "../lib/auth";
import { setPending, showMessage, clearMessage } from "../lib/forms";
import { initNav, initFooter } from "../lib/nav";

void initNav();
initFooter();

void getSession().then((s) => {
  if (s) location.href = "/account.html";
});

const loginForm = document.querySelector<HTMLFormElement>("#login-form")!;
const resetForm = document.querySelector<HTMLFormElement>("#reset-request-form")!;
const toggleReset = document.querySelector<HTMLAnchorElement>("#toggle-reset")!;

loginForm.addEventListener("submit", (e) => {
  e.preventDefault();
  void (async () => {
    clearMessage(loginForm);
    const email = (loginForm.elements.namedItem("email") as HTMLInputElement).value.trim();
    const password = (loginForm.elements.namedItem("password") as HTMLInputElement).value;
    if (!email || !password)
      return showMessage(loginForm, "Enter your email and password.", "error");

    setPending(loginForm, true);
    const { error } = await signIn(email, password);
    setPending(loginForm, false);

    if (error) return showMessage(loginForm, error, "error");
    location.href = "/account.html";
  })();
});

toggleReset.addEventListener("click", (e) => {
  e.preventDefault();
  resetForm.hidden = !resetForm.hidden;
});

resetForm.addEventListener("submit", (e) => {
  e.preventDefault();
  void (async () => {
    clearMessage(resetForm);
    const email = (resetForm.elements.namedItem("email") as HTMLInputElement).value.trim();
    if (!email) return showMessage(resetForm, "Enter your account email.", "error");

    setPending(resetForm, true);
    const { error } = await resetPassword(email);
    setPending(resetForm, false);

    if (error) return showMessage(resetForm, error, "error");
    showMessage(resetForm, "Reset link sent — check your email.", "success");
  })();
});
