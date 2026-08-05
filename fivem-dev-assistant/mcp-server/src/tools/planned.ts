/**
 * The four tools whose contracts are fixed but whose implementations are still
 * outstanding: NUI generator, resource scaffolder, framework snippets and docs
 * search.
 *
 * They are registered with their final input schemas so callers and the
 * implementation can be developed against the same contract. Every call returns
 * an explicit error explaining what the tool will do and what to use instead —
 * never a silent empty success.
 */

import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { ZodRawShape } from "zod";

import { notImplemented } from "../services/result.js";
import type { ToolResult } from "../services/result.js";
import { Framework, ResponseFormat } from "../types.js";

const frameworkField = z
  .nativeEnum(Framework)
  .describe(
    "Target framework: 'esx' (es_extended), 'qbcore' (qb-core), 'qbox' (qbx_core, requires ox_lib) or 'standalone' (ox_lib or framework-free).",
  );

const resourceNameField = z
  .string()
  .regex(
    /^[a-z0-9][a-z0-9_-]{1,49}$/,
    "resource_name must be lowercase and may contain letters, digits, '_' and '-' (2-50 characters)",
  )
  .describe("Resource folder name, e.g. 'my_fuel_system'.");

interface PlannedTool {
  name: string;
  title: string;
  summary: string;
  /** Argument documentation appended to the description. */
  args: string;
  /** What the tool will do once implemented, used in the error message. */
  planned: string;
  inputSchema: ZodRawShape;
  annotations: {
    readOnlyHint: boolean;
    destructiveHint: boolean;
    idempotentHint: boolean;
    openWorldHint: boolean;
  };
}

const PLANNED_TOOLS: PlannedTool[] = [
  {
    name: "fivem_nui_generate",
    title: "Generate a FiveM NUI",
    summary:
      "Generate the HTML/CSS/JS for a FiveM NUI panel or HUD, styled with the project's design tokens and readable over a moving game image.",
    args: `  - kind ('panel' | 'hud' | 'menu' | 'notification'): what the UI is
  - resource_name (string): target resource folder name
  - title (string): visible heading of the UI
  - elements (string[]): the fields, rows or actions the UI must show
  - theme ('dark' | 'light' | 'both'): colour scheme to emit (default 'both')
  - nui_callbacks (string[], optional): callback names the UI will POST to
  - response_format ('markdown' | 'json'): output format (default 'markdown')`,
    planned:
      "It will return web/index.html, web/style.css and web/script.js as complete files — no CDN dependencies, focus released on every exit path including ESC, and one accent colour used only for the primary action.",
    inputSchema: {
      kind: z
        .enum(["panel", "hud", "menu", "notification"])
        .describe("Type of interface to generate."),
      resource_name: resourceNameField,
      title: z.string().min(1).max(80).describe("Visible heading of the interface."),
      elements: z
        .array(z.string().min(1).max(120))
        .min(1, "list at least one element")
        .max(40)
        .describe("Fields, rows or actions the interface must show."),
      theme: z
        .enum(["dark", "light", "both"])
        .default("both")
        .describe("Colour scheme to emit; 'both' uses CSS custom properties."),
      nui_callbacks: z
        .array(z.string().regex(/^[a-zA-Z][a-zA-Z0-9_]*$/))
        .max(20)
        .optional()
        .describe("Callback names the UI will POST to via fetch."),
      response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN),
    },
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
  },
  {
    name: "fivem_resource_scaffold",
    title: "Scaffold a FiveM resource",
    summary:
      "Produce the full file layout of a new FiveM resource — fxmanifest.lua, client/, server/, shared/, config.lua and optional locales/ and web/ — for a chosen framework.",
    args: `  - resource_name (string): resource folder name
  - framework ('esx' | 'qbcore' | 'qbox' | 'standalone'): target framework
  - description (string): one line describing what the resource does
  - features (string[]): capabilities to wire up, e.g. "target interaction", "database persistence"
  - with_nui (boolean): include a web/ folder and ui_page (default false)
  - dependencies (string[], optional): extra resources to declare, e.g. "ox_lib", "oxmysql"
  - response_format ('markdown' | 'json'): output format (default 'markdown')`,
    planned:
      "It will return every file's full contents with fx_version 'cerulean', game 'gta5', lua54 'yes', declared dependencies, server-authoritative handlers, and cleanup in onResourceStop. It returns files for review; writing them to disk stays a separate, confirmed step.",
    inputSchema: {
      resource_name: resourceNameField,
      framework: frameworkField,
      description: z
        .string()
        .min(1)
        .max(200)
        .describe("One line describing what the resource does."),
      features: z
        .array(z.string().min(1).max(120))
        .min(1, "list at least one feature")
        .max(30)
        .describe("Capabilities to wire up."),
      with_nui: z
        .boolean()
        .default(false)
        .describe("Include a web/ folder and a ui_page entry in the manifest."),
      dependencies: z
        .array(z.string().min(1).max(60))
        .max(20)
        .optional()
        .describe("Extra resources to declare as dependencies."),
      response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN),
    },
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
  },
  {
    name: "fivem_framework_snippet",
    title: "Get a framework code snippet",
    summary:
      "Return an idiomatic, production-ready Lua snippet for a common task (money, items, jobs, callbacks, player data) in one specific framework, without mixing framework styles.",
    args: `  - topic (string): the task, e.g. "remove money", "add item", "server callback", "check job"
  - framework ('esx' | 'qbcore' | 'qbox' | 'standalone'): target framework
  - side ('client' | 'server' | 'both'): which side the snippet is for (default 'server')
  - response_format ('markdown' | 'json'): output format (default 'markdown')`,
    planned:
      "It will return one snippet written in the idiom of the requested framework only, with values re-derived server-side and source validated, plus the exact dependencies the snippet assumes.",
    inputSchema: {
      topic: z
        .string()
        .min(2)
        .max(120)
        .describe('The task, e.g. "remove money", "server callback", "check job".'),
      framework: frameworkField,
      side: z
        .enum(["client", "server", "both"])
        .default("server")
        .describe("Which side the snippet is for."),
      response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN),
    },
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
  },
  {
    name: "fivem_docs_search",
    title: "Search FiveM documentation",
    summary:
      "Search a local offline cache of CFX and framework documentation (manifest reference, events, state bags, ox_lib, ESX/QBCore/Qbox APIs) and return matching passages with their source.",
    args: `  - query (string): what to look up, e.g. "state bag change handler", "fxmanifest files block"
  - scope ('cfx' | 'esx' | 'qbcore' | 'qbox' | 'ox' | 'all'): which documentation set to search (default 'all')
  - limit (number): max passages, 1-20 (default 5)
  - response_format ('markdown' | 'json'): output format (default 'markdown')`,
    planned:
      "It will search a checked-in docs cache built by a separate update script and return passages with their source URL, so answers can be attributed instead of guessed.",
    inputSchema: {
      query: z
        .string()
        .min(2)
        .max(200)
        .describe('What to look up, e.g. "state bag change handler".'),
      scope: z
        .enum(["cfx", "esx", "qbcore", "qbox", "ox", "all"])
        .default("all")
        .describe("Which documentation set to search."),
      limit: z.number().int().min(1).max(20).default(5).describe("Maximum passages to return."),
      response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN),
    },
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
  },
];

function buildDescription(tool: PlannedTool): string {
  return `${tool.summary}

STATUS: NOT IMPLEMENTED YET. Calling this tool returns an error describing what it will do. Do not call it to get working code — write the code directly instead. The input schema below is final and will not change when the implementation lands.

Args:
${tool.args}

Returns:
  Currently an error result. Planned: ${tool.planned}

Error Handling:
  - Always returns "Error: '<name>' is registered but not implemented yet." together with the planned behaviour.`;
}

/** Register the placeholder tools. Remove an entry here when it gets a real implementation. */
export function registerPlannedTools(server: McpServer): void {
  for (const tool of PLANNED_TOOLS) {
    server.registerTool(
      tool.name,
      {
        title: tool.title,
        description: buildDescription(tool),
        inputSchema: tool.inputSchema,
        annotations: tool.annotations,
      },
      async (): Promise<ToolResult> => notImplemented(tool.name, tool.planned),
    );
  }
}
