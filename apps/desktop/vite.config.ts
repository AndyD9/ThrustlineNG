import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { fileURLToPath } from "node:url";
import { defineConfig, loadEnv } from "vite";

export default defineConfig(({ mode }) => {
  const publicConnectionEnvironment = loadEnv(
    mode,
    fileURLToPath(new URL(".", import.meta.url)),
    "VITE_THRUSTLINE_SUPABASE_",
  );

  return {
    base: "./",
    envPrefix: [],
    define: {
      "import.meta.env.VITE_THRUSTLINE_SUPABASE_ANON_KEY": JSON.stringify(
        publicConnectionEnvironment.VITE_THRUSTLINE_SUPABASE_ANON_KEY ?? "",
      ),
      "import.meta.env.VITE_THRUSTLINE_SUPABASE_URL": JSON.stringify(
        publicConnectionEnvironment.VITE_THRUSTLINE_SUPABASE_URL ?? "",
      ),
    },
    plugins: [react(), tailwindcss()],
    resolve: {
      alias: {
        "@": fileURLToPath(new URL("./src", import.meta.url)),
      },
    },
    server: {
      host: "127.0.0.1",
      port: 1420,
      strictPort: true,
      watch: {
        // Le watcher ne doit jamais entrer dans src-tauri : cargo y écrit des
        // binaires verrouillés pendant `tauri dev`, ce qui tue Vite en EBUSY.
        ignored: ["**/src-tauri/**"],
      },
    },
    build: {
      outDir: "dist",
      emptyOutDir: true,
      sourcemap: false,
    },
  };
});
