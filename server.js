#!/usr/bin/env node
//
// Static file server for the seminar decks.
//
// Serves this repository's root on port 8000, on all interfaces
// (so the iPad on the same network can connect). No dependencies
// beyond Node itself. Decks reference the reveal.js engine and
// plugins through vendor/, which scripts/vendor.js fills from
// node_modules at install time.
//
// Missing files return a plain 404 (unlike the vite dev server,
// which fell back to a demo page).

import http from "node:http";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const PORT = process.env.PORT || 8000;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".eot": "application/vnd.ms-fontobject",
  ".map": "application/json"
};

const server = http.createServer(async (req, res) => {
  try {
    let urlPath = decodeURIComponent(
      new URL(req.url, "http://localhost").pathname
    );

    // Directory requests get their index page.
    if (urlPath.endsWith("/")) urlPath += "index.html";

    const filePath = path.normalize(
      path.join(ROOT, urlPath)
    );

    // Never serve outside this repo.
    if (!filePath.startsWith(ROOT + path.sep)) {
      res.writeHead(403);
      res.end("Forbidden");
      return;
    }

    const data = await readFile(filePath);
    res.writeHead(200, {
      "Content-Type":
        MIME[path.extname(filePath).toLowerCase()] ||
        "application/octet-stream"
    });
    res.end(data);
  } catch {
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("Not found");
  }
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(
    `Deck server running on port ${PORT} (all interfaces)`
  );
  console.log(
    `  Projector:  http://localhost:${PORT}/`
  );
});