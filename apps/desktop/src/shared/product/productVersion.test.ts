import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

import {
  PRODUCT_CHANNEL,
  PRODUCT_VERSION,
  PRODUCT_VERSION_LABEL,
} from "@/shared/product/productVersion";

const repositoryRoot = resolve(import.meta.dirname, "../../../../..");
const canonical = JSON.parse(
  readFileSync(resolve(repositoryRoot, "eng/product-version.json"), "utf8"),
) as { channel: string; productVersion: string };

describe("version produit affichée", () => {
  it("reprend exactement la source canonique", () => {
    expect(PRODUCT_VERSION).toBe(canonical.productVersion);
    expect(PRODUCT_CHANNEL).toBe(canonical.channel);
  });

  it("reste une préversion SemVer ordonnée et non opaque", () => {
    expect(PRODUCT_VERSION).toMatch(/^0\.\d+\.\d+-(?:alpha|beta|rc)\.[1-9]\d*$/);
  });

  it("n'expose ni métadonnée de build, ni chemin, ni secret dans son libellé", () => {
    expect(PRODUCT_VERSION_LABEL).toBe(`Version ${canonical.productVersion}`);
    expect(PRODUCT_VERSION_LABEL).not.toMatch(/[+\\/]|[A-Za-z]:|token|key|secret/i);
  });
});
