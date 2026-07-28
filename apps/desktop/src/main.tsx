import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

import { App } from "@/app/App";
import "@/styles/index.css";

const rootElement = document.getElementById("root");

if (rootElement === null) {
  throw new Error("Impossible de démarrer Thrustline : la racine #root est absente.");
}

createRoot(rootElement).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
