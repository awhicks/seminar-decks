#!/usr/bin/env node
//
// Copies the reveal.js engine and the deck plugins out of
// node_modules into vendor/, where the decks reference them
// with stable paths (../vendor/reveal.css etc. from a course
// folder). Run automatically by npm install; re-run any time
// with `npm run vendor`.

import { cpSync, mkdirSync, rmSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  ".."
);

const NM = path.join(ROOT, "node_modules");
const VENDOR = path.join(ROOT, "vendor");

// [source under node_modules, destination under vendor/]
const ASSETS = [
  ["reveal.js/dist/reveal.css", "reveal.css"],
  ["reveal.js/dist/reveal.js", "reveal.js"],
  ["reveal.js/dist/theme", "theme"],
  ["reveal.js-plugins/chalkboard", "plugins/chalkboard"],
  ["reveal.js-plugins/customcontrols", "plugins/customcontrols"],
  ["reveal.js-plugins/seminar", "plugins/seminar"]
];

rmSync(VENDOR, { recursive: true, force: true });
mkdirSync(VENDOR, { recursive: true });

for (const [src, dest] of ASSETS) {
  cpSync(
    path.join(NM, src),
    path.join(VENDOR, dest),
    { recursive: true }
  );
  console.log(`vendored ${src} → vendor/${dest}`);
}

console.log("done.");