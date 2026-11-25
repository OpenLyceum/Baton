import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, resolve, sep } from "node:path";

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".webmanifest": "application/manifest+json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".ico": "image/x-icon",
  ".wasm": "application/wasm",
  ".wav": "audio/wav",
  ".mp3": "audio/mpeg",
  ".ogg": "audio/ogg",
  ".mp4": "video/mp4",
  ".webm": "video/webm",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
};

export function startDistServer(root, { mount = "/", crossOrigin = false } = {}) {
  const server = createServer(async (request, response) => {
    try {
      const pathname = new URL(request.url, "http://localhost").pathname;
      if (!pathname.startsWith(mount)) {
        response.writeHead(404).end("Not found");
        return;
      }
      // A callback lets the update test switch builds without changing the origin.
      const rootPath = resolve(typeof root === "function" ? root() : root);
      const relativePath = decodeURIComponent(pathname.slice(mount.length)) || "index.html";
      const filePath = resolve(rootPath, relativePath);
      if (!filePath.startsWith(rootPath + sep) || !(await stat(filePath)).isFile()) {
        response.writeHead(404).end("Not found");
        return;
      }
      const extension = extname(filePath).toLowerCase();
      response.writeHead(200, {
        "Content-Type": MIME[extension] || "application/octet-stream",
        "Cache-Control": "no-cache",
        ...(crossOrigin && { "Cross-Origin-Resource-Policy": "cross-origin" }),
      });
      const stream = createReadStream(filePath);
      response.on("close", () => stream.destroy());
      stream.on("error", () => response.destroy());
      stream.pipe(response);
    } catch {
      response.writeHead(404).end("Not found");
    }
  });
  return new Promise((resolvePromise, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      resolvePromise({ server, port, origin: `http://127.0.0.1:${port}` });
    });
  });
}
