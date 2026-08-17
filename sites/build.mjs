import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.dirname(scriptDir);
const htmlPath = path.join(projectRoot, "prompt-log.html");
const hostingPath = path.join(projectRoot, ".openai", "hosting.json");
const serverDir = path.join(projectRoot, "dist", "server");
const metadataDir = path.join(projectRoot, "dist", ".openai");

if (!fs.existsSync(htmlPath)) throw new Error(`Missing app HTML: ${htmlPath}`);
if (!fs.existsSync(hostingPath)) throw new Error(`Missing hosting metadata: ${hostingPath}`);

const html = fs.readFileSync(htmlPath, "utf8");
const worker = `const html = ${JSON.stringify(html)};

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const isAppRoute = url.pathname === "/" || url.pathname === "/prompt-log.html";
    if (!isAppRoute) return new Response("Not Found", { status: 404 });
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed", { status: 405 });
    }
    return new Response(request.method === "HEAD" ? null : html, {
      headers: {
        "content-type": "text/html; charset=utf-8",
        "cache-control": "no-cache",
        "referrer-policy": "no-referrer",
        "x-content-type-options": "nosniff"
      }
    });
  }
};
`;

fs.rmSync(path.join(projectRoot, "dist"), { recursive: true, force: true });
fs.mkdirSync(serverDir, { recursive: true });
fs.mkdirSync(metadataDir, { recursive: true });
fs.writeFileSync(path.join(serverDir, "index.js"), worker, "utf8");
fs.copyFileSync(hostingPath, path.join(metadataDir, "hosting.json"));

console.log(`Built Prompt Log site (${Buffer.byteLength(html)} HTML bytes)`);
