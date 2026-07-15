import "../styles/tokens.css";
import "../styles/base.css";
import "../styles/components.css";
import { updatePassword } from "../lib/auth";
import { setPending, showMessage, clearMessage } from "../lib/forms";
import { initNav, initFooter } from "../lib/nav";

void initNav();
initFooter();

const form = document.querySelector<HTMLFormElement>("#reset-form")!;

form.addEventListener("submit", (e) => {
  e.preventDefault();
  void (async () => {
    clearMessage(form);
    const password = (form.elements.namedItem("password") as HTMLInputElement).value;
    const confirm = (form.elements.namedItem("confirm") as HTMLInputElement).value;

    if (password.length < 10)
      return showMessage(form, "Password must be at least 10 characters.", "error");
    if (password !== confirm)
      return showMessage(form, "Passwords don't match.", "error");

    setPending(form, true);
    const { error } = await updatePassword(password);
    setPending(form, false);

    if (error)
      return showMessage(
        form,
        "This reset link may have expired. Request a new one from the login page.",
        "error",
      );
    showMessage(form, "Password updated. Taking you to your account…", "success");
    setTimeout(() => (location.href = "/account.html"), 1200);
  })();
});
