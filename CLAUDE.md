# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repo (`Website`) is a monorepo with three distinct parts. Know which one you're touching before you edit:

1. **`ui-ux-pro-max` toolkit** (aka Antigravity Kit) — the engineered core, and what most of this file documents. An AI-powered design intelligence toolkit providing searchable databases of UI styles, color palettes, font pairings, chart types, and UX guidelines. It works as a skill/workflow for AI coding assistants (Claude Code, Windsurf, Cursor, etc.). Lives in `src/`, `cli/`, `.claude-plugin/`.
2. **Anthropic example skills** — a vendored copy of the `anthropics/skills` collection (`skills/`, `spec/`, `template/`, root `README.md`). Reference material; not built or tested here.
3. **Demo static sites/games** built with the toolkit — plain HTML/CSS/JS, no build step. Open the `.html` directly in a browser:
   - `index.html` — "TETRIS — Neon Edition", a self-contained browser game.
   - `fit-is-fun/` — multi-page German personal-training website (`index.html` + `pages/`, `css/`, `js/`).
   - `cat-feeding-app/`, `preview/` — smaller single-page demos.

The section below (Search Command through Git Workflow) is about part 1 unless noted.

## Search Command

```bash
python3 src/ui-ux-pro-max/scripts/search.py "<query>" --domain <domain> [-n <max_results>]
```

**Domain search:**
- `product` - Product type recommendations (SaaS, e-commerce, portfolio)
- `style` - UI styles (glassmorphism, minimalism, brutalism) + AI prompts and CSS keywords
- `typography` - Font pairings with Google Fonts imports
- `color` - Color palettes by product type
- `landing` - Page structure and CTA strategies
- `chart` - Chart types and library recommendations
- `ux` - Best practices and anti-patterns

**Stack search:**
```bash
python3 src/ui-ux-pro-max/scripts/search.py "<query>" --stack <stack>
```
Available stacks: `html-tailwind` (default), `react`, `nextjs`, `astro`, `vue`, `nuxtjs`, `nuxt-ui`, `svelte`, `swiftui`, `react-native`, `flutter`, `shadcn`, `jetpack-compose`

## Architecture

```
src/ui-ux-pro-max/                # Source of Truth
├── data/                         # Canonical CSV databases
│   ├── products.csv, styles.csv, colors.csv, typography.csv, ...
│   └── stacks/                   # Stack-specific guidelines
├── scripts/
│   ├── search.py                 # CLI entry point
│   ├── core.py                   # BM25 + regex hybrid search engine
│   └── design_system.py          # Design system generation
└── templates/
    ├── base/                     # Base templates (skill-content.md, quick-reference.md)
    └── platforms/                # Platform configs (claude.json, cursor.json, ...)

cli/                              # CLI installer (uipro-cli on npm)
├── src/
│   ├── commands/init.ts          # Install command with template generation
│   └── utils/template.ts         # Template rendering engine
└── assets/                       # Bundled assets (~564KB)
    ├── data/                     # Copy of src/ui-ux-pro-max/data/
    ├── scripts/                  # Copy of src/ui-ux-pro-max/scripts/
    └── templates/                # Copy of src/ui-ux-pro-max/templates/

.claude/skills/ui-ux-pro-max/     # Claude Code skill (symlinks to src/)
.factory/skills/ui-ux-pro-max/   # Droid (Factory) skill (symlinks to src/)
.shared/ui-ux-pro-max/            # Symlink to src/ui-ux-pro-max/
.claude-plugin/                   # Claude Marketplace publishing
```

The search engine uses BM25 ranking combined with regex matching. Domain auto-detection is available when `--domain` is omitted.

The search engine (`core.py`) has no external Python dependencies — it implements BM25 by hand — so `search.py` runs against `src/` directly without any install step.

## CLI (`cli/`)

The `uipro-cli` npm package uses **Bun** as its toolchain (`bun.lock` present). Run commands from `cli/`:

```bash
bun install          # install deps
bun run dev          # run the CLI from source (src/index.ts) without building
bun run build        # bundle to cli/dist/ (target node) — also runs on prepublishOnly
```

There is no test script and no linter configured. The CLI ships bundled copies of `data/`, `scripts/`, and `templates/` under `cli/assets/`; keep them in sync per Sync Rules below before publishing.

## Sync Rules

**Source of Truth:** `src/ui-ux-pro-max/`

When modifying files:

1. **Data & Scripts** - Edit in `src/ui-ux-pro-max/`:
   - `data/*.csv` and `data/stacks/*.csv`
   - `scripts/*.py`
   - Changes automatically available via symlinks in `.claude/`, `.factory/`, `.shared/`

2. **Templates** - Edit in `src/ui-ux-pro-max/templates/`:
   - `base/skill-content.md` - Common SKILL.md content
   - `base/quick-reference.md` - Quick reference section (Claude only)
   - `platforms/*.json` - Platform-specific configs

3. **CLI Assets** - Run sync before publishing:
   ```bash
   cp -r src/ui-ux-pro-max/data/* cli/assets/data/
   cp -r src/ui-ux-pro-max/scripts/* cli/assets/scripts/
   cp -r src/ui-ux-pro-max/templates/* cli/assets/templates/
   ```

4. **Reference Folders** - No manual sync needed. The CLI generates these from templates during `uipro init`.

## Prerequisites

Python 3.x (no external dependencies required)

## Git Workflow

Never push directly to `main`. Always:

1. Create a new branch: `git checkout -b feat/...` or `fix/...`
2. Commit changes
3. Push branch: `git push -u origin <branch>`
4. Create PR: `gh pr create`
