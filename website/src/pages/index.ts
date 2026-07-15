// Phase W0 placeholder entry. Proves the TS build pipeline end to end.
// Real page logic arrives in Phase W1.

const year = document.querySelector<HTMLSpanElement>("#year");
if (year) {
  year.textContent = String(new Date().getFullYear());
}
