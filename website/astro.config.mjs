import { defineConfig } from "astro/config";

// Local-only static site (see WEBSITE.md). No deploy target configured on purpose.
export default defineConfig({
  output: "static",
});
