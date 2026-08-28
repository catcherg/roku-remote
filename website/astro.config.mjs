import { defineConfig } from "astro/config";
import sitemap from "@astrojs/sitemap";

// Deployed to GitHub Pages on the getclicker.me apex domain.
// `site` drives canonical URLs, OpenGraph URLs, and sitemap entries — if the
// domain changes, this is the single value to update (see WEBSITE.md).
export default defineConfig({
  site: "https://getclicker.me",
  output: "static",
  integrations: [sitemap()],
});
