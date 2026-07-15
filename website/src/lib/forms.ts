/** Shared form helpers: pending states + inline error/success messaging. */

export function setPending(form: HTMLFormElement, pending: boolean): void {
  const btn = form.querySelector<HTMLButtonElement>("button[type=submit]");
  if (!btn) return;
  btn.disabled = pending;
  if (pending) {
    btn.dataset.label = btn.textContent ?? "";
    btn.textContent = "Please wait…";
  } else if (btn.dataset.label) {
    btn.textContent = btn.dataset.label;
  }
}

export function showMessage(
  form: HTMLFormElement,
  text: string,
  kind: "error" | "success",
): void {
  let el = form.querySelector<HTMLElement>(".form-message");
  if (!el) {
    el = document.createElement("p");
    el.className = "form-message";
    el.setAttribute("role", "alert");
    form.prepend(el);
  }
  el.textContent = text;
  el.dataset.kind = kind;
}

export function clearMessage(form: HTMLFormElement): void {
  form.querySelector(".form-message")?.remove();
}
