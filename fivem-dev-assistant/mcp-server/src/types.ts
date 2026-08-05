/**
 * Shared type definitions for the FiveM Dev Assistant MCP server.
 */

/** Which side of the CFX runtime a native is callable from. */
export type ApiSet = "client" | "server" | "shared";

/** Where a cached native entry originally came from. */
export type NativeSource = "gta5" | "cfx" | "seed";

/** One parameter of a native, as documented by CFX. */
export interface NativeParam {
  type: string;
  name: string;
}

/** A single native, normalised into the shape this server works with. */
export interface NativeEntry {
  /** Upstream name in SCREAMING_SNAKE_CASE, e.g. "GET_ENTITY_COORDS". */
  name: string;
  /** Name as called from Lua/JS, e.g. "GetEntityCoords". */
  lua: string;
  /** Primary hash, e.g. "0x3FEF770D40960D5A". */
  hash: string;
  /** Joaat hash of the original name, when upstream provides one. */
  jhash?: string;
  /** Namespace, e.g. "ENTITY", "PLAYER", "CFX". */
  ns: string;
  apiset: ApiSet;
  params: NativeParam[];
  /** Return type as documented, "void" when the native returns nothing. */
  returns: string;
  description?: string;
  /** Alternative names upstream lists for the same hash. */
  aliases?: string[];
  source: NativeSource;
}

/** On-disk shape of `data/natives.json`. */
export interface NativesCache {
  /** ISO timestamp of when the cache was produced. */
  generatedAt: string;
  /**
   * True while the bundled hand-curated placeholder is in use. Set to false by
   * `npm run natives:update`, which replaces it with the full upstream set.
   */
  seed: boolean;
  /** URLs the cache was built from (empty for the seed). */
  sources: string[];
  natives: NativeEntry[];
}

/** Output format shared by every tool that returns a list or record. */
export enum ResponseFormat {
  MARKDOWN = "markdown",
  JSON = "json",
}

/** The four frameworks this server generates code for. */
export enum Framework {
  ESX = "esx",
  QBCORE = "qbcore",
  QBOX = "qbox",
  STANDALONE = "standalone",
}
