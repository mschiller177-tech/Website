/**
 * Shared helpers for building tool results.
 *
 * Every tool funnels through here so success and failure look the same across
 * the server, and so no failure can be silent: errors always carry a message
 * that says what went wrong and what to do next.
 */

import { CHARACTER_LIMIT } from "../constants.js";

export interface ToolResult {
  [key: string]: unknown;
  content: Array<{ type: "text"; text: string }>;
  structuredContent?: Record<string, unknown>;
  isError?: boolean;
}

/** A successful result carrying both a rendered text form and structured data. */
export function ok(
  text: string,
  structuredContent?: Record<string, unknown>,
): ToolResult {
  return {
    content: [{ type: "text", text }],
    ...(structuredContent ? { structuredContent } : {}),
  };
}

/**
 * A failed result. `hint` should tell the caller how to recover — a different
 * parameter, a command to run, a prerequisite to install.
 */
export function fail(message: string, hint?: string): ToolResult {
  return {
    isError: true,
    content: [
      { type: "text", text: hint ? `Error: ${message}\nHint: ${hint}` : `Error: ${message}` },
    ],
  };
}

/**
 * Result for a tool that is registered but not implemented yet. Kept explicit
 * so an agent gets a usable answer instead of an empty success.
 */
export function notImplemented(toolName: string, plannedBehaviour: string): ToolResult {
  return fail(
    `'${toolName}' is registered but not implemented yet.`,
    `Planned behaviour: ${plannedBehaviour} Until then, write the code manually or use 'fivem_natives_lookup', which is implemented.`,
  );
}

/** Turn an unknown thrown value into a readable one-line message. */
export function describeError(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

/**
 * Enforce CHARACTER_LIMIT on a rendered response. Returns the text unchanged
 * when it fits, otherwise a truncated version with an explicit notice so the
 * caller knows results are missing and how to narrow them.
 */
export function withCharacterLimit(text: string, narrowingHint: string): string {
  if (text.length <= CHARACTER_LIMIT) return text;
  const keep = Math.max(0, CHARACTER_LIMIT - 200);
  return (
    `${text.slice(0, keep)}\n\n---\n` +
    `[Truncated: response exceeded ${CHARACTER_LIMIT} characters. ${narrowingHint}]`
  );
}
