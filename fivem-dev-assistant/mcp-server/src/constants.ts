/**
 * Shared constants. No hard-coded absolute paths: everything resolves relative
 * to this package, with an environment override for callers that relocate the
 * data directory.
 */

import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const SERVER_NAME = "fivem-dev-assistant-mcp-server";
export const SERVER_VERSION = "0.1.0";

/** Maximum characters a single tool response may return before truncation. */
export const CHARACTER_LIMIT = 25_000;

const moduleDir = dirname(fileURLToPath(import.meta.url));

/**
 * Directory holding the offline caches. Resolves to `<package>/data` for both
 * `src/` (tsx) and `dist/` (built) layouts, since both sit one level below the
 * package root. Override with FIVEM_MCP_DATA_DIR.
 */
export const DATA_DIR: string =
  process.env.FIVEM_MCP_DATA_DIR ?? resolve(moduleDir, "..", "data");

export const NATIVES_CACHE_FILE = "natives.json";

/** Upstream sources used by `npm run natives:update`. */
export const NATIVES_SOURCES: readonly string[] = [
  "https://runtime.fivem.net/doc/natives.json",
  "https://runtime.fivem.net/doc/natives_cfx.json",
];
