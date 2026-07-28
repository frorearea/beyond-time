import { cp, mkdir, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const flutterBuild = join(root, "build", "web");
const dist = join(root, "dist");

if (!existsSync(join(flutterBuild, "index.html"))) {
  throw new Error("Missing Flutter web build at build/web. Build the Flutter app first.");
}

await rm(dist, { recursive: true, force: true });
await mkdir(join(dist, "server"), { recursive: true });
await cp(flutterBuild, join(dist, "assets"), { recursive: true });
await cp(join(root, "sites", "worker.js"), join(dist, "server", "index.js"));

console.log("Sites build is ready.");
