/**
 * fivem_natives_lookup — search the offline CFX natives cache.
 */

import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

import {
  NativesCacheError,
  formatSignature,
  searchNatives,
} from "../services/natives.js";
import { describeError, fail, ok, withCharacterLimit } from "../services/result.js";
import type { ToolResult } from "../services/result.js";
import type { NativeEntry } from "../types.js";
import { ResponseFormat } from "../types.js";

const inputSchema = {
  query: z
    .string()
    .min(2, "query must be at least 2 characters")
    .max(200, "query must not exceed 200 characters")
    .describe(
      "Native name, hash or free text. Accepts 'GetEntityCoords', 'GET_ENTITY_COORDS', '0x3FEF770D40960D5A' or 'vehicle engine on'.",
    ),
  apiset: z
    .enum(["client", "server"])
    .optional()
    .describe(
      "Restrict to natives callable from this side. Shared natives are always included. Omit to search everything.",
    ),
  namespace: z
    .string()
    .max(40)
    .optional()
    .describe("Restrict to one namespace, e.g. 'ENTITY', 'VEHICLE', 'CFX'."),
  limit: z
    .number()
    .int()
    .min(1)
    .max(50)
    .default(10)
    .describe("Maximum matches to return (1-50)."),
  offset: z
    .number()
    .int()
    .min(0)
    .default(0)
    .describe("Number of matches to skip, for paging through results."),
  response_format: z
    .nativeEnum(ResponseFormat)
    .default(ResponseFormat.MARKDOWN)
    .describe("'markdown' for readable output, 'json' for structured data."),
};

type Input = {
  query: string;
  apiset?: "client" | "server";
  namespace?: string;
  limit: number;
  offset: number;
  response_format: ResponseFormat;
};

const description = `Look up FiveM/CFX natives in a local offline cache by name, hash or description.

Use this before writing any Lua that calls a native, to confirm the exact name, the parameter order and which side (client/server) the native is callable from. It reads a checked-in JSON cache and never touches the network.

Args:
  - query (string): native name, hash or free text, e.g. "GetEntityCoords", "0x3FEF770D40960D5A", "vehicle engine"
  - apiset ('client' | 'server', optional): restrict to one side; shared natives always included
  - namespace (string, optional): restrict to a namespace such as "ENTITY", "VEHICLE", "CFX"
  - limit (number): max matches, 1-50 (default 10)
  - offset (number): matches to skip for paging (default 0)
  - response_format ('markdown' | 'json'): output format (default 'markdown')

Returns:
  For JSON format:
  {
    "total": number,              // matches found
    "count": number,              // matches in this response
    "offset": number,
    "has_more": boolean,
    "next_offset": number,        // present when has_more
    "cache": {
      "is_seed": boolean,         // true while only the bundled placeholder set is present
      "generated_at": string,     // ISO timestamp
      "size": number              // natives in the cache
    },
    "natives": [
      {
        "name": string,           // "GET_ENTITY_COORDS"
        "lua": string,            // "GetEntityCoords"
        "hash": string,           // "0x3FEF770D40960D5A"
        "namespace": string,      // "ENTITY"
        "apiset": string,         // "client" | "server" | "shared"
        "signature": string,      // "GetEntityCoords(entity: Entity, alive: BOOL) -> Vector3"
        "params": [{ "type": string, "name": string }],
        "returns": string,
        "description": string
      }
    ]
  }

Examples:
  - Use when: "which native gives me a player's coordinates" -> query="player coords"
  - Use when: "what are the arguments of SetVehicleEngineOn" -> query="SetVehicleEngineOn"
  - Use when: "is GetPlayers callable on the client" -> query="GetPlayers", apiset="server"
  - Don't use when: you need Lua runtime functions such as RegisterNetEvent or TriggerServerEvent — those are not natives.

Error Handling:
  - Returns an error naming the cache path and the 'npm run natives:update' command when the cache is missing or malformed.
  - Returns "No natives matched" with the active filters when the search is empty.
  - When the cache is still the bundled seed, every response says so and points at 'npm run natives:update'.`;

function toStructured(native: NativeEntry): Record<string, unknown> {
  return {
    name: native.name,
    lua: native.lua,
    hash: native.hash,
    namespace: native.ns,
    apiset: native.apiset,
    signature: formatSignature(native),
    params: native.params,
    returns: native.returns,
    ...(native.description ? { description: native.description } : {}),
    ...(native.aliases?.length ? { aliases: native.aliases } : {}),
  };
}

function renderMarkdown(
  params: Input,
  natives: NativeEntry[],
  meta: { total: number; hasMore: boolean; nextOffset?: number; seedNotice?: string },
): string {
  const lines: string[] = [
    `# Natives matching '${params.query}'`,
    "",
    `${meta.total} match(es), showing ${natives.length} from offset ${params.offset}.`,
  ];
  if (params.apiset) lines.push(`Filtered to apiset '${params.apiset}' (plus shared).`);
  if (params.namespace) lines.push(`Filtered to namespace '${params.namespace.toUpperCase()}'.`);
  lines.push("");

  for (const native of natives) {
    lines.push(`## ${native.lua}  \`${native.hash}\``);
    lines.push(`- **Namespace**: ${native.ns} · **Apiset**: ${native.apiset}`);
    lines.push(`- **Signature**: \`${formatSignature(native)}\``);
    if (native.description) lines.push(`- ${native.description}`);
    lines.push("");
  }

  if (meta.hasMore && meta.nextOffset !== undefined) {
    lines.push(`More results available — call again with offset=${meta.nextOffset}.`);
  }
  if (meta.seedNotice) lines.push("", meta.seedNotice);

  return lines.join("\n");
}

export function registerNativesLookup(server: McpServer): void {
  server.registerTool(
    "fivem_natives_lookup",
    {
      title: "Look up FiveM natives",
      description,
      inputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async (params: Input): Promise<ToolResult> => {
      try {
        const result = await searchNatives({
          query: params.query,
          ...(params.apiset ? { apiset: params.apiset } : {}),
          ...(params.namespace ? { namespace: params.namespace } : {}),
          limit: params.limit,
          offset: params.offset,
        });

        const seedNotice = result.cacheIsSeed
          ? `Note: the natives cache is still the bundled seed set (${result.cacheSize} entries, curated by hand). Run 'npm run natives:update' in the server directory to fetch the full CFX documentation.`
          : undefined;

        if (result.matches.length === 0) {
          const filters = [
            params.apiset ? `apiset='${params.apiset}'` : undefined,
            params.namespace ? `namespace='${params.namespace}'` : undefined,
          ]
            .filter(Boolean)
            .join(", ");
          const hint =
            result.suggestion ??
            seedNotice ??
            "Try a shorter query, drop the apiset/namespace filter, or search for a word from the native's purpose instead of its exact name.";
          return fail(
            `No natives matched '${params.query}'${filters ? ` with ${filters}` : ""}.`,
            hint,
          );
        }

        const structured: Record<string, unknown> = {
          total: result.total,
          count: result.matches.length,
          offset: result.offset,
          has_more: result.hasMore,
          ...(result.nextOffset !== undefined ? { next_offset: result.nextOffset } : {}),
          cache: {
            is_seed: result.cacheIsSeed,
            generated_at: result.cacheGeneratedAt,
            size: result.cacheSize,
          },
          natives: result.matches.map(toStructured),
        };

        const text =
          params.response_format === ResponseFormat.JSON
            ? JSON.stringify(structured, null, 2)
            : renderMarkdown(params, result.matches, {
                total: result.total,
                hasMore: result.hasMore,
                ...(result.nextOffset !== undefined ? { nextOffset: result.nextOffset } : {}),
                ...(seedNotice ? { seedNotice } : {}),
              });

        return ok(
          withCharacterLimit(text, "Lower 'limit' or add a 'namespace' filter."),
          structured,
        );
      } catch (error) {
        if (error instanceof NativesCacheError) {
          return fail(error.message);
        }
        return fail(
          `Natives lookup failed: ${describeError(error)}`,
          "This is a bug in the server; re-run with a simpler query to confirm.",
        );
      }
    },
  );
}
