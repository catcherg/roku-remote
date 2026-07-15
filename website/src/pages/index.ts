import "../styles/tokens.css";
import "../styles/base.css";
import "../styles/components.css";
import "../styles/motion.css";
import { initNav, initFooter } from "../lib/nav";
import { captureRef, initWaitlistForms } from "../lib/waitlist";
import { initReveals, initNavScroll, initPhoneTilt } from "../lib/animate";

captureRef();
void initNav();
initFooter();
initWaitlistForms();
initReveals();
initNavScroll();
initPhoneTilt();
