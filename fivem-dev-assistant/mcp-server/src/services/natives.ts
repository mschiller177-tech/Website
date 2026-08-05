/**
 * Offline natives cache: loading, token index and scored search.
 *
 * The cache is a plain JSON file so it can be inspected, diffed and shipped
 * with the package. The index is rebuilt in memory on first use — a few
 * thousand entries are cheap enough that persisting an index would only add a
 * second thing to keep in sync.
 */

import { readFile } from "node:fs/promises";
import { join } from "node:path";

import { DATA_DIR, NATIVES_CACHE_FILE } from "../constants.js";
import type { ApiSet, NativeEntry, NativesCache } from "../types.js";

/** Convert an upstream SCREAMING_SNAKE name to the Lua/JS call name. */
export function toLuaName(upstreamName: string): string {
  if (!/^[A-Z0-9_]+$/.test(upstreamName)) return upstreamName;
  return upstreamName
    .split("_")
    .filter((part) => part.length > 0)
    .map((part) => part.charAt(0) + part.slice(1).toLowerCase())
    .join("");
}

/**
 * Tokens shorter than this are dropped from the index and from queries. They
 * are almost always fragments ("a", "id", the tail of a hash) and match far too
 * much to be useful.
 */
const MIN_TOKEN_LENGTH = 3;

/** A query of this form is a hash and is only ever resolved exactly. */
const HASH_QUERY = /^0x[0-9a-f]+$/i;

/**
 * Matches scoring below this fraction of the best match are dropped. Without it
 * a common token such as "get" drags in most of the database behind one good
 * hit.
 */
const RELATIVE_SCORE_CUTOFF = 0.15;

/** Split a name or query into lowercase tokens usable for index lookups. */
function tokenize(value: string): string[] {
  return value
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .split(/[^A-Za-z0-9]+/)
    .filter((token) => token.length >= MIN_TOKEN_LENGTH)
    .map((token) => token.toLowerCase());
}

interface LoadedIndex {
  cache: NativesCache;
  /** token -> indices into cache.natives */
  tokens: Map<string, number[]>;
  /** normalised name or hash -> index into cache.natives */
  exact: Map<string, number>;
  /** token -> inverse document frequency weight */
  idf: Map<string, number>;
}

let loaded: LoadedIndex | undefined;

export class NativesCacheError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "NativesCacheError";
  }
}

function buildIndex(cache: NativesCache): LoadedIndex {
  const tokens = new Map<string, number[]>();
  const exact = new Map<string, number>();

  cache.natives.forEach((native, i) => {
    exact.set(native.name.toLowerCase(), i);
    exact.set(native.lua.toLowerCase(), i);
    exact.set(native.hash.toLowerCase(), i);
    if (native.jhash) exact.set(native.jhash.toLowerCase(), i);
    for (const alias of native.aliases ?? []) {
      exact.set(alias.toLowerCase(), i);
      exact.set(toLuaName(alias).toLowerCase(), i);
    }

    const seen = new Set<string>([
      ...tokenize(native.name),
      ...tokenize(native.ns),
      ...tokenize(native.description ?? "").slice(0, 60),
    ]);
    for (const token of seen) {
      const bucket = tokens.get(token);
      if (bucket) bucket.push(i);
      else tokens.set(token, [i]);
    }
  });

  const total = cache.natives.length || 1;
  const idf = new Map<string, number>();
  for (const [token, bucket] of tokens) {
    // Classic inverse document frequency, floored at zero: a token present in
    // most entries ("get", "entity") contributes almost nothing.
    idf.set(token, Math.max(0, Math.log(total / (1 + bucket.length))));
  }

  return { cache, tokens, exact, idf };
}

/**
 * Load and index the natives cache. Throws NativesCacheError with an
 * actionable message when the file is missing or malformed.
 */
export async function loadNatives(): Promise<LoadedIndex> {
  if (loaded) return loaded;

  const path = join(DATA_DIR, NATIVES_CACHE_FILE);
  let raw: string;
  try {
    raw = await readFile(path, "utf8");
  } catch {
    throw new NativesCacheError(
      `Natives cache not found at ${path}. Run 'npm run natives:update' in the server directory, or point FIVEM_MCP_DATA_DIR at a directory containing ${NATIVES_CACHE_FILE}.`,
    );
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    throw new NativesCacheError(
      `Natives cache at ${path} is not valid JSON (${error instanceof Error ? error.message : String(error)}). Re-run 'npm run natives:update' to rebuild it.`,
    );
  }

  const cache = parsed as NativesCache;
  if (!cache || !Array.isArray(cache.natives)) {
    throw new NativesCacheError(
      `Natives cache at ${path} has an unexpected shape (missing 'natives' array). Re-run 'npm run natives:update' to rebuild it.`,
    );
  }

  loaded = buildIndex(cache);
  return loaded;
}

export interface NativeSearchOptions {
  query: string;
  apiset?: ApiSet;
  namespace?: string;
  limit: number;
  offset: number;
}

export interface NativeSearchResult {
  total: number;
  offset: number;
  matches: NativeEntry[];
  hasMore: boolean;
  nextOffset?: number;
  cacheIsSeed: boolean;
  cacheGeneratedAt: string;
  cacheSize: number;
  /**
   * Set when the filtered search found nothing but the same query matches
   * without the apiset/namespace filter — e.g. asking for GetPlayers on the
   * client when it is server-only.
   */
  suggestion?: string;
}

/**
 * Score a native against a query. Higher is better; 0 means no match.
 *
 * Exact name and hash hits dominate so that a caller who already knows the
 * native gets it first, with fuzzier name and description hits behind them.
 */
/**
 * The share of the strongest query token's weight a token must reach to count
 * as discriminative. Matching only weak tokens ("get" in "GetPlayers") is not
 * evidence of a match.
 */
const DISCRIMINATIVE_IDF_RATIO = 0.5;

/** Query tokens carrying enough weight to justify a match on their own. */
function discriminativeTokens(index: LoadedIndex, queryTokens: string[]): Set<string> {
  const weights = queryTokens.map((token) => index.idf.get(token) ?? 1);
  const maxWeight = Math.max(0, ...weights);
  if (maxWeight === 0) return new Set(queryTokens);

  const result = new Set<string>();
  queryTokens.forEach((token, i) => {
    if ((weights[i] ?? 0) >= maxWeight * DISCRIMINATIVE_IDF_RATIO) result.add(token);
  });
  return result;
}

function score(
  index: LoadedIndex,
  native: NativeEntry,
  query: string,
  queryTokens: string[],
  discriminative: Set<string>,
): number {
  const q = query.toLowerCase();
  const name = native.name.toLowerCase();
  const lua = native.lua.toLowerCase();

  if (name === q || lua === q || native.hash.toLowerCase() === q) return 10_000;
  // A hash that is not an exact hit is never a fuzzy hit.
  if (HASH_QUERY.test(query)) return 0;

  let total = 0;
  let substringHit = false;
  if (lua.startsWith(q) || name.startsWith(q)) {
    total += 2_000;
    substringHit = true;
  } else if (lua.includes(q) || name.includes(q)) {
    total += 800;
    substringHit = true;
  }

  const nameTokens = new Set(tokenize(native.name));
  const descTokens = new Set(tokenize(native.description ?? ""));
  let discriminativeHit = false;
  for (const token of queryTokens) {
    const weight = index.idf.get(token) ?? 1;
    const inName = nameTokens.has(token);
    if (inName) total += 200 * weight;
    else if (lua.includes(token)) total += 60 * weight;
    if (descTokens.has(token)) total += 15 * weight;
    if (discriminative.has(token) && (inName || lua.includes(token))) discriminativeHit = true;
  }

  // Weak-token-only matches are noise: "GetPlayers" must not surface every
  // native whose name happens to start with "Get".
  if (!substringHit && !discriminativeHit) return 0;

  if (tokenize(native.ns).some((t) => queryTokens.includes(t))) total += 50;
  return total;
}

interface ScoredNative {
  native: NativeEntry;
  points: number;
}

/** Score every candidate against the query under the given filters. */
function collect(
  index: LoadedIndex,
  query: string,
  filters: { apiset?: ApiSet; namespace?: string },
): ScoredNative[] {
  const queryTokens = tokenize(query);
  const discriminative = discriminativeTokens(index, queryTokens);
  const wantedNs = filters.namespace?.toUpperCase();

  // Narrow to candidates via the token index when possible; fall back to a
  // full scan for queries whose tokens are all unknown (e.g. partial words).
  const candidates = new Set<number>();
  const exactHit = index.exact.get(query.toLowerCase());
  if (exactHit !== undefined) candidates.add(exactHit);
  for (const token of queryTokens) {
    for (const i of index.tokens.get(token) ?? []) candidates.add(i);
  }
  const pool = candidates.size > 0 ? [...candidates] : index.cache.natives.map((_, i) => i);

  const scored: ScoredNative[] = [];
  for (const i of pool) {
    const native = index.cache.natives[i];
    if (!native) continue;
    if (filters.apiset && native.apiset !== filters.apiset && native.apiset !== "shared") {
      continue;
    }
    if (wantedNs && native.ns.toUpperCase() !== wantedNs) continue;

    const points = score(index, native, query, queryTokens, discriminative);
    if (points > 0) scored.push({ native, points });
  }

  scored.sort((a, b) => b.points - a.points || a.native.name.localeCompare(b.native.name));

  // Drop the long tail of weak matches relative to the best hit.
  const best = scored[0]?.points ?? 0;
  const threshold = best * RELATIVE_SCORE_CUTOFF;
  return scored.filter((entry) => entry.points >= threshold);
}

/** Search the cache. Returns an empty match list rather than throwing. */
export async function searchNatives(
  options: NativeSearchOptions,
): Promise<NativeSearchResult> {
  const index = await loadNatives();
  const filters = {
    ...(options.apiset ? { apiset: options.apiset } : {}),
    ...(options.namespace ? { namespace: options.namespace } : {}),
  };
  const scored = collect(index, options.query, filters);

  // When filters emptied the result, check whether the query matches at all so
  // the caller learns the native exists on the other side rather than that it
  // does not exist.
  let suggestion: string | undefined;
  if (scored.length === 0 && (filters.apiset || filters.namespace)) {
    const unfiltered = collect(index, options.query, {});
    const top = unfiltered[0]?.native;
    if (top) {
      suggestion =
        `'${top.lua}' exists but is in namespace ${top.ns} with apiset '${top.apiset}'. ` +
        `Drop or change the filter to see it.`;
    }
  }

  const page = scored.slice(options.offset, options.offset + options.limit);
  const consumed = options.offset + page.length;

  return {
    total: scored.length,
    offset: options.offset,
    matches: page.map((entry) => entry.native),
    hasMore: scored.length > consumed,
    ...(scored.length > consumed ? { nextOffset: consumed } : {}),
    cacheIsSeed: index.cache.seed === true,
    cacheGeneratedAt: index.cache.generatedAt,
    cacheSize: index.cache.natives.length,
    ...(suggestion ? { suggestion } : {}),
  };
}

/** Render a native's Lua call signature, e.g. `GetEntityCoords(entity, alive) -> Vector3`. */
export function formatSignature(native: NativeEntry): string {
  const params = native.params
    .map((param) => `${param.name}: ${param.type}`)
    .join(", ");
  const returns = native.returns && native.returns !== "void" ? ` -> ${native.returns}` : "";
  return `${native.lua}(${params})${returns}`;
}
