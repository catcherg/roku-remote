import { defineConfig } from "vite";
import { resolve } from "node:path";

// Multi-page build. Custom domain (getclicker.me) serves from root, so base is "/".
export default defineConfig({
  base: "/",
  build: {
    rollupOptions: {
      input: {
        index: resolve(__dirname, "index.html"),
        login: resolve(__dirname, "login.html"),
        signup: resolve(__dirname, "signup.html"),
        account: resolve(__dirname, "account.html"),
        reset: resolve(__dirname, "reset.html"),
        privacy: resolve(__dirname, "privacy.html"),
        terms: resolve(__dirname, "terms.html"),
      },
    },
  },
});
