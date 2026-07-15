import { defineConfig } from "vite";
import { resolve } from "node:path";

// Multi-page build. Custom domain (getclicker.me) serves from root, so base is "/".
// Additional pages (login, signup, account, reset, privacy, terms) are added to
// rollupOptions.input as they are created in later phases.
export default defineConfig({
  base: "/",
  build: {
    rollupOptions: {
      input: {
        index: resolve(__dirname, "index.html"),
      },
    },
  },
});
