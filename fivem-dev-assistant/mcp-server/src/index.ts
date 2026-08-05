#!/usr/bin/env node
/**
 * FiveM Dev Assistant — MCP server (phase 1).
 *
 * Exposes five tools for FiveM/CFX resource development over stdio:
 * natives lookup (implemented), NUI generator, resource scaffolder, framework
 * snippets and docs search (contracts fixed, implementations outstanding).
 *
 * stdio transport: never write to stdout, it carries the protocol. All logging
 * goes to stderr.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { DATA_DIR, SERVER_NAME, SERVER_VERSION } from "./constants.js";
import { NativesCacheError, loadNatives } from "./services/natives.js";
import { registerNativesLookup } from "./tools/natives-lookup.js";
import { registerPlannedTools } from "./tools/planned.js";

function log(message: string): void {
  process.stderr.write(`[${SERVER_NAME}] ${message}\n`);
}

function printHelp(): void {
  process.stderr.write(
    `${SERVER_NAME} ${SERVER_VERSION}\n\n` +
      `MCP server for FiveM/CFX resource development. Speaks MCP over stdio and\n` +
      `is meant to be launched by an MCP client, not run interactively.\n\n` +
      `Usage:\n` +
      `  fivem-dev-assistant-mcp            Start the server on stdio\n` +
      `  fivem-dev-assistant-mcp --help     Show this help\n` +
      `  fivem-dev-assistant-mcp --version  Print the version\n\n` +
      `Environment:\n` +
      `  FIVEM_MCP_DATA_DIR  Directory holding natives.json (default: ${DATA_DIR})\n\n` +
      `Tools:\n` +
      `  fivem_natives_lookup      Search the offline CFX natives cache (implemented)\n` +
      `  fivem_nui_generate        Generate NUI HTML/CSS/JS (not implemented yet)\n` +
      `  fivem_resource_scaffold   Scaffold a resource (not implemented yet)\n` +
      `  fivem_framework_snippet   Framework code snippets (not implemented yet)\n` +
      `  fivem_docs_search         Search cached documentation (not implemented yet)\n\n` +
      `Update the natives cache with: npm run natives:update\n`,
  );
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  if (argv.includes("--help") || argv.includes("-h")) {
    printHelp();
    return;
  }
  if (argv.includes("--version") || argv.includes("-v")) {
    process.stderr.write(`${SERVER_VERSION}\n`);
    return;
  }

  const server = new McpServer({ name: SERVER_NAME, version: SERVER_VERSION });

  registerNativesLookup(server);
  registerPlannedTools(server);

  // Warm and validate the cache at startup so a broken install is reported
  // here rather than on the first tool call. A missing cache is not fatal:
  // the tool returns the same actionable message when it is actually used.
  try {
    const { cache } = await loadNatives();
    log(
      `natives cache: ${cache.natives.length} entries` +
        (cache.seed ? " (bundled seed set — run 'npm run natives:update')" : ` (generated ${cache.generatedAt})`),
    );
  } catch (error) {
    if (error instanceof NativesCacheError) log(`warning: ${error.message}`);
    else throw error;
  }

  const transport = new StdioServerTransport();
  await server.connect(transport);
  log(`running on stdio, data dir ${DATA_DIR}`);
}

main().catch((error: unknown) => {
  log(`fatal: ${error instanceof Error ? error.stack ?? error.message : String(error)}`);
  process.exit(1);
});
