#!/usr/bin/env tsx
/**
 * Rebuilds `data/natives.json` from the official CFX native documentation.
 *
 * Run explicitly with `npm run natives:update`. The server never fetches at
 * runtime — the checked-in cache is what makes it usable offline.
 *
 * Usage:
 *   npm run natives:update
 *   npm run natives:update -- --out ./somewhere/natives.json
 */

import { mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

import { DATA_DIR, NATIVES_CACHE_FILE, NATIVES_SOURCES } from "../src/constants.js";
import { toLuaName } from "../src/services/natives.js";
import type { ApiSet, NativeEntry, NativeParam, NativesCache, NativeSource } from "../src/types.js";

/** Shape of a single entry in the upstream natives documentation. */
interface UpstreamNative {
  name?: string;
  params?: Array<{ type?: string; name?: string }>;
  results?: string;
  description?: string;
  hash?: string;
  jhash?: string;
  ns?: string;
  apiset?: string;
  aliases?: string[];
}

/** Upstream file layout: namespace -> hash -> native. */
type UpstreamDocument = Record<string, Record<string, UpstreamNative>>;

function parseArgs(argv: string[]): { out: string } {
  const outIndex = argv.indexOf("--out");
  if (outIndex !== -1) {
    const value = argv[outIndex + 1];
    if (!value) {
      throw new Error("--out requires a file path, e.g. --out ./data/natives.json");
    }
    return { out: value };
  }
  return { out: join(DATA_DIR, NATIVES_CACHE_FILE) };
}

function normaliseApiSet(value: string | undefined): ApiSet {
  if (value === "server" || value === "shared") return value;
  return "client";
}

function normaliseParams(params: UpstreamNative["params"]): NativeParam[] {
  if (!Array.isArray(params)) return [];
  return params.map((param, i) => ({
    type: param.type ?? "any",
    name: param.name ?? `arg${i + 1}`,
  }));
}

async function fetchDocument(url: string): Promise<UpstreamDocument> {
  const response = await fetch(url, {
    headers: { Accept: "application/json" },
    signal: AbortSignal.timeout(60_000),
  });
  if (!response.ok) {
    throw new Error(
      `${url} returned HTTP ${response.status} ${response.statusText}. ` +
        `Check network access to runtime.fivem.net, then re-run.`,
    );
  }
  return (await response.json()) as UpstreamDocument;
}

function flatten(document: UpstreamDocument, source: NativeSource): NativeEntry[] {
  const entries: NativeEntry[] = [];

  for (const [namespace, natives] of Object.entries(document)) {
    if (!natives || typeof natives !== "object") continue;

    for (const [hashKey, native] of Object.entries(natives)) {
      const name = native.name ?? hashKey;
      const hash = native.hash ?? hashKey;
      entries.push({
        name,
        lua: toLuaName(name),
        hash,
        ...(native.jhash ? { jhash: native.jhash } : {}),
        ns: native.ns ?? namespace,
        apiset: normaliseApiSet(native.apiset),
        params: normaliseParams(native.params),
        returns: native.results ?? "void",
        ...(native.description ? { description: native.description.trim() } : {}),
        ...(native.aliases?.length ? { aliases: native.aliases } : {}),
        source,
      });
    }
  }

  return entries;
}

/** Later sources win, so CFX definitions override the base GTA V documentation. */
function dedupe(entries: NativeEntry[]): NativeEntry[] {
  const byHash = new Map<string, NativeEntry>();
  for (const entry of entries) {
    byHash.set(entry.hash.toLowerCase(), entry);
  }
  return [...byHash.values()].sort((a, b) =>
    a.ns.localeCompare(b.ns) || a.name.localeCompare(b.name),
  );
}

async function main(): Promise<void> {
  const { out } = parseArgs(process.argv.slice(2));
  const collected: NativeEntry[] = [];

  for (const url of NATIVES_SOURCES) {
    process.stderr.write(`Fetching ${url} ...\n`);
    const document = await fetchDocument(url);
    const source: NativeSource = url.includes("natives_cfx") ? "cfx" : "gta5";
    const flat = flatten(document, source);
    process.stderr.write(`  ${flat.length} natives\n`);
    collected.push(...flat);
  }

  const natives = dedupe(collected);
  if (natives.length === 0) {
    throw new Error(
      "Upstream returned no natives. The existing cache was left untouched.",
    );
  }

  const cache: NativesCache = {
    generatedAt: new Date().toISOString(),
    seed: false,
    sources: [...NATIVES_SOURCES],
    natives,
  };

  await mkdir(dirname(out), { recursive: true });
  await writeFile(out, `${JSON.stringify(cache, null, 2)}\n`, "utf8");
  process.stderr.write(`Wrote ${natives.length} natives to ${out}\n`);
}

main().catch((error: unknown) => {
  process.stderr.write(
    `natives:update failed: ${error instanceof Error ? error.message : String(error)}\n`,
  );
  process.exit(1);
});
