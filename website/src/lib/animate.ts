/** Motion helpers. Every effect is gated behind prefers-reduced-motion. */

export const motionOK = (): boolean =>
  window.matchMedia("(prefers-reduced-motion: no-preference)").matches;

/** Scroll-triggered reveals for [data-reveal] elements (staggered per group). */
export function initReveals(): void {
  const els = document.querySelectorAll<HTMLElement>("[data-reveal]");
  if (!motionOK()) {
    els.forEach((el) => el.classList.add("is-visible"));
    return;
  }
  const io = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        const el = entry.target as HTMLElement;
        el.style.transitionDelay = `${(Number(el.dataset.reveal) || 0) * 90}ms`;
        el.classList.add("is-visible");
        io.unobserve(el);
      }
    },
    { threshold: 0.15, rootMargin: "0px 0px -40px 0px" },
  );
  els.forEach((el) => io.observe(el));
}

/** Animated count-up for numbers (waitlist position, referral count). */
export function countUp(el: HTMLElement, target: number, prefix = "", suffix = ""): void {
  if (!motionOK() || target <= 1) {
    el.textContent = `${prefix}${target}${suffix}`;
    return;
  }
  const duration = 900;
  const start = performance.now();
  const from = Math.max(1, target - Math.min(target - 1, 40));
  const tick = (now: number) => {
    const t = Math.min(1, (now - start) / duration);
    const eased = 1 - Math.pow(1 - t, 3);
    el.textContent = `${prefix}${Math.round(from + (target - from) * eased)}${suffix}`;
    if (t < 1) requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
}

/** Nav gains a border/tint once the page scrolls. */
export function initNavScroll(): void {
  const nav = document.querySelector(".site-nav");
  if (!nav) return;
  const update = () => nav.classList.toggle("is-scrolled", window.scrollY > 8);
  update();
  window.addEventListener("scroll", update, { passive: true });
}

/** Subtle pointer-tilt on the hero phone (desktop, fine pointers only). */
export function initPhoneTilt(): void {
  const phone = document.querySelector<HTMLElement>(".phone");
  if (!phone || !motionOK() || !window.matchMedia("(pointer: fine)").matches) return;
  const wrap = phone.closest<HTMLElement>(".hero-device") ?? phone;
  wrap.addEventListener("pointermove", (e) => {
    const r = phone.getBoundingClientRect();
    const dx = (e.clientX - r.left - r.width / 2) / r.width;
    const dy = (e.clientY - r.top - r.height / 2) / r.height;
    phone.style.transform = `rotateY(${dx * 8}deg) rotateX(${dy * -8}deg)`;
  });
  wrap.addEventListener("pointerleave", () => {
    phone.style.transform = "";
  });
}
