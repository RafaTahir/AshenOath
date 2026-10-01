import { createHash } from "node:crypto";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

export function artifactIdentity(directory) {
  const files = [];
  function visit(relative) {
    for (const entry of readdirSync(join(directory, relative), { withFileTypes: true })) {
      if (entry.isSymbolicLink()) throw new Error(`Web artifact contains a symbolic link: ${entry.name}`);
      const child = relative ? `${relative}/${entry.name}` : entry.name;
      if (entry.isDirectory()) {
        visit(child);
      } else if (entry.isFile()) {
        const path = join(directory, child);
        files.push({
          path: child,
          bytes: statSync(path).size,
          sha256: createHash("sha256").update(readFileSync(path)).digest("hex"),
        });
      }
    }
  }
  visit("");
  files.sort((left, right) => left.path.localeCompare(right.path, "en"));
  if (!files.some((file) => file.path === "index.pck")) throw new Error("Web artifact has no index.pck");
  return {
    fingerprint: createHash("sha256").update(JSON.stringify(files)).digest("hex"),
    total_bytes: files.reduce((sum, file) => sum + file.bytes, 0),
    files,
  };
}
