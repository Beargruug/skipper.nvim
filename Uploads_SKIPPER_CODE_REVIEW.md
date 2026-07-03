# skipper.nvim — Code Review & Improvement Report

**Repo:** `Beargruug/skipper.nvim`
**Scope:** All 13 Lua files (`config`, `default`, `react`, `ruby`, `typescript`, `vue`, `handle_window`, `init`, `navigation`, `parser`, `skipper_spec`, `ui`, `skipper`)
**Date:** 2 July 2026

---

## 1. What the plugin does

Skipper is a lightweight **"function outline / jump-to-symbol"** plugin. It gives you a fast, dependency-light alternative to a full LSP/aerial/symbols-outline setup.

**User-facing flow**

1. Run `:ShowFunctionsWindow` (registered in `plugin/skipper.lua`).
2. A centered floating window opens listing every function/method in the current buffer.
3. Keybindings inside the window:
   - `<CR>` → jump to the function and center it (`zz`)
   - `a` → toggle the item as a **favorite** (favorites are pinned to the top of the list)
   - `x` → remove a favorite (only when the cursor is in the favorites section)
   - `?` → toggle a floating help panel
   - `q` / `<Esc>` / `<C-c>` → close

**Architecture (data flow)**

```
plugin/skipper.lua        → registers :ShowFunctionsWindow
  └─ init.lua (M.setup, show_functions_window)
       └─ handle_window.lua   → orchestrates: get functions, build list, open UI
            ├─ parser.lua      → get_functions() dispatches by &filetype
            │     └─ filetypes/{default,typescript,react,vue,ruby}.lua  → Treesitter extraction
            ├─ ui.lua          → creates the float + help window + keymaps
            └─ navigation.lua  → jump / favorite actions (called via keymaps)
       └─ config.lua           → window options
```

The design is clean at a high level: a dispatcher (`parser`) + per-filetype extractors + a UI layer + a navigation layer. The main problems are in **duplication**, **the Vue extractor**, **favorite persistence**, **error signalling**, and a few **correctness edge cases**. Details below.

---

## 2. Bugs & correctness issues (fix these first)

### 2.1 `favorites` are lost on restart (in-memory only)
`parser.lua` stores favorites in a module-local table `favorites_by_file = {}`. Nothing is persisted, so every favorite disappears when Neovim exits — and even when the buffer is unloaded/reloaded the association survives only because it's keyed by absolute path in RAM. For a "favorites" feature this is the single biggest gap. See §5.1 for a persistence design.

### 2.7 Vue extractor produces duplicates and can misfire
`vue.lua` matches with several overlapping Lua patterns over the raw text. A single `const x = async () => {}` can be caught by more than one loop, and the lifecycle-hook catch-all `([%w_]+)%s*%b()` filtered by `^on[%u]` will also match calls like `onClick(...)` that aren't definitions. There is no de-duplication. See §3.3 for a Treesitter-based rewrite.

### 2.8 Inconsistent nesting depth across extractors
- `default.lua` and `typescript.lua`: only iterate **top-level** `root:named_children()` → nested/inner functions are missed.
- `react.lua`: recursively `traverse`s the whole tree → finds nested ones.
- `ruby.lua`: recursive.

This means behavior differs by filetype for no principled reason. Pick one strategy (recursive with a depth guard is usually what users expect for an outline) and apply it uniformly.

---

## 3. Code quality & refactoring

### 3.2 Replace "sentinel name" control flow with a status field
`get_functions()` communicates errors by inserting `{ name = "No parser found!" }` / `{ name = "No functions found!" }`, and `handle_window.lua` then re-detects those exact strings via an `errors` lookup table. Using display strings as control flow is brittle (a real function could be named that; localization breaks it). Return a structured result instead:

```lua
-- parser.get_functions -> returns (functions, status)
-- status = "ok" | "no_parser" | "empty"
return functions, status
```

`handle_window` then keys off `status`, and renders a friendly message line without enabling the jump/favorite keymaps.

### 3.3 Rewrite the Vue extractor on Treesitter (drop the regex)
`vue.lua` is the weakest module: it extracts the `<script>` text and runs a dozen Lua patterns, then looks up each function's line with `get_line_by_name`, which **re-scans the entire buffer for every function** (see §4.1). The Vue Treesitter parser injects `javascript`/`typescript` into `script_element`, so you can reuse the JS extractor on the injected tree:

```lua
-- vue.lua
local common = require("skipper.filetypes._js_common")
local extract = common.make_extractor({ recursive = true })

function M.extract_functions(root, functions)
  -- Prefer language-tree injections so we get real line numbers for free
  local ltree = vim.treesitter.get_parser(0)
  ltree:for_each_tree(function(tree, lang_tree)
    local lang = lang_tree:lang()
    if lang == "javascript" or lang == "typescript" or lang == "tsx" then
      extract(tree:root(), functions)
    end
  end)
end
```

This eliminates the O(n²) line lookup, the duplicates, and the false positives — and it gives you `computed`/`ref`/lifecycle hooks correctly if you add those node/callback patterns to the common table.

### 3.5 Prefer `vim.notify` over `nvim_err_writeln`
`navigation.lua` uses `vim.api.nvim_err_writeln(...)` for user errors. Standardize on `vim.notify(msg, vim.log.levels.ERROR)` — consistent with the rest of the file and respects notification plugins (noice, notify).

### 3.6 Centralize keymaps & make them configurable
The keys are currently hard-coded across `ui.lua` (`q`, `<Esc>`, `<C-c>`, `<CR>`, `?`) and `handle_window.lua` (`<CR>`, `a`, `x`, wired via `:lua require(...)` command strings). Two improvements:
- Pass Lua callbacks to `vim.keymap.set` instead of `:lua require(...)<CR>` command strings — faster, no string parsing, easier to debug.
- Move the key definitions into `config.options.keymaps` so users can remap. Then `HELP_ITEMS` can be generated from that same table so the help panel never drifts from reality (which is how the `<C>-c` typo slipped in).

### 3.7 Config validation
`config.set` blindly merges `opts`. Add light validation (`vim.validate`) for `win_width`/`win_height`/`border` so a bad value fails loudly at `setup()` rather than at window-open time. Also consider fractional sizing (e.g. `win_width = 0.6` → 60% of columns) since a fixed 120×20 overflows small terminals.

### 3.8 Minor style
- `typescript.lua` uses `({ vim.treesitter.get_node_range(export_node) })[1]` in one place and bare `local x = get_node_range(node)` elsewhere — both yield the start row; pick one. (Bare assignment already keeps only the first return value.)
- Indentation inside the nested `export_statement` blocks in `typescript.lua`/`react.lua` is off (contents not indented under their `if`), which hurts readability.
- `navigation.add_to_favorite` is just an alias for `toggle_favorite` — either document it or remove it.

---

## 4. Performance

### 4.1 Vue: O(n²) line resolution — biggest hotspot
For each matched function name, `get_line_by_name` scans the whole buffer with `nvim_buf_get_lines(buf, line, line+1, ...)` **one line at a time**. That's O(functions × lines) plus one API round-trip per line. On a large SFC this is noticeably slow. The Treesitter rewrite in §3.3 removes it entirely (line numbers come straight from the node range). If you must keep regex, at least fetch all lines once (`nvim_buf_get_lines(buf, 0, -1, false)`) and build a name→line index in a single pass.

### 4.2 Favorite membership is a linear scan
`is_favorite`/`save_function`/`remove_function` each loop over the file's favorites list. In `handle_window` you call `is_favorite` **once per function**, so building the list is O(functions × favorites). Back the store with a set keyed by a stable id:

```lua
local function key(t) return t.name .. ":" .. tostring(t.line) end
-- favorites_by_file[path] = { list = {...}, set = { [key]=true } }
```
Lookups become O(1); the ordered `list` is still available for display.

### 4.3 Cache extraction by `changedtick`
`get_functions` re-parses and re-walks the tree every time the window opens (and `refresh_window` reopens it on every favorite toggle). Cache per buffer keyed on `vim.api.nvim_buf_get_changedtick(bufnr)` so repeated opens without edits are free:

```lua
local cache = {}  -- [bufnr] = { tick = n, functions = {...} }
```

### 4.4 Don't destroy/recreate the window to refresh
`navigation.refresh_window` closes the float and calls `handle_window()` again to rebuild everything after every favorite toggle. Instead, keep the window/buffer open and just rewrite the lines + `all_items` var (`nvim_buf_set_lines`). Fewer allocations, no fl\​icker, cursor position preserved.

### 4.5 Use `elseif`, not sequential `if`
In the JS extractors each node runs through 5–6 independent `if node:type() == ...` checks. They're mutually exclusive, so an `elseif` chain (or the dispatch table in §3.1) short-circuits. Micro-optimization, but free.

---

## 5. Feature ideas

### 5.1 Persistent favorites (high value, closes §2.1)
Serialize `favorites_by_file` to `stdpath("data") .. "/skipper/favorites.json"` on change and load it at `setup()`. Key by absolute path; optionally scope by project root (git root) so favorites travel with the repo.

```lua
local function save_to_disk()
  local dir = vim.fn.stdpath("data") .. "/skipper"
  vim.fn.mkdir(dir, "p")
  local fd = assert(io.open(dir .. "/favorites.json", "w"))
  fd:write(vim.json.encode(favorites_by_file)); fd:close()
end
```
Guard against stale lines: on load, if a favorite's line no longer matches its name, re-resolve by name or mark it stale.

### 5.2 Fuzzy filtering inside the window
Add `/` to open a prompt that filters the list as you type (simple substring or `vim.fn.matchfuzzy`). For large files this is the difference between "outline" and "usable outline."

### 5.3 Telescope / fzf-lua / snacks picker backend
Offer an alternative front-end so users already living in Telescope get previews, multi-select, and their own keymaps for free. Keep the float as the zero-dependency default.

### 5.4 Show richer metadata
Display the kind (function/method/computed/hook) with an icon (via `nvim-web-devicons`), and optionally the signature or line number aligned right. This also disambiguates the duplicated-favorite display (§2.4).

### 5.5 Peek / preview without leaving
`<Tab>` (or cursor-move) previews the target by scrolling the source window or opening a small preview float, while `<CR>` commits the jump. Great for scanning.

### 5.6 Generic Treesitter language support via queries
Instead of hand-writing a module per language, ship a fallback that runs the standard `locals`/`textobjects` query `@function`/`@method` captures. That instantly supports Lua, Python, Go, Rust, C, Java, etc. Keep the bespoke modules only where you want special handling (Vue SFC, Ruby singleton methods). This turns "5 languages" into "every language nvim-treesitter parses."

### 5.7 Hierarchical outline
Group methods under their class/module (Ruby `class`/`module`, JS `class`, Vue `<script setup>` sections) as an indented tree. `aerial.nvim`-style but lighter.

### 5.8 Auto-refresh & live outline
Optional `autocmd` on `BufWritePost`/`TextChanged` to refresh if the window is open, so the outline stays in sync while editing.

### 5.9 `:checkhealth skipper`
Add a `health.lua` that verifies Treesitter is installed and the relevant parsers are present, and reports which filetypes are supported. Cheap, and reduces "it doesn't work" issues.

### 5.10 Sorting options
`config.sort = "position" | "name" | "kind"`. Currently order is document/traversal order only.

---

## 6. Testing

`skipper_spec.lua` is a good start (busted/plenary style) but thin:
- The mock `p.get_functions` in the first `before_each` returns `{ name = "..." }` (a single map), while the real API returns a **list** of `{name,line}`. The assertions pass against the mock but don't exercise real shapes. Align the mock with the real contract.
- No tests for `navigation` (jump bounds, separator handling), favorites (add/remove/toggle/dedup), or the extractors against real Treesitter trees.
- Add table-driven extractor tests: feed a known source string, parse it, assert the `{name,line}` list. This is where regressions will actually happen (especially after the §3.1 refactor), so it's the highest-ROI test surface.
- Consider CI (GitHub Actions) running `plenary` headless across a matrix of Neovim versions.

---

## 7. Priority summary

| Priority | Item | Section |
|---|---|---|
| P0 | Persist favorites to disk | 2.1 / 5.1 |
| P0 | Fix Vue O(n²) + duplicates → Treesitter rewrite | 2.7 / 3.3 / 4.1 |
| P0 | Pass filepath explicitly to favorite lookups | 2.2 |
| P1 | De-duplicate TS/React via shared dispatch module | 3.1 |
| P1 | Replace sentinel-string errors with a status field | 3.2 |
| P1 | Unify nesting strategy across extractors | 2.8 |
| P1 | Refresh in place instead of close+reopen | 4.4 |
| P2 | Configurable keymaps + generate help from them (fixes `<C>-c` typo) | 2.3 / 3.6 |
| P2 | Cache by changedtick; O(1) favorite set | 4.2 / 4.3 |
| P2 | Config validation + fractional sizing | 3.7 |
| P3 | Generic TS-query language support, fuzzy filter, picker backends, health check | 5.x |

Overall: a well-scoped, genuinely useful plugin with a sound module layout. The top wins are **persisting favorites**, **replacing the Vue regex extractor with Treesitter**, and **collapsing the TS/React duplication** — those three address the biggest correctness, performance, and maintainability issues at once.
