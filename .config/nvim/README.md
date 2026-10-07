# Neovim configuration

This is a modular Neovim 0.12.4+ configuration for daily development. It uses
native LSP and diagnostic APIs, keeps language policy in one manifest, prefers
project-local tools, and deliberately avoids dashboards, animation, smooth
scrolling, rounded borders, and overlapping subsystems.

`<leader>` and `<localleader>` are both `Space`. JetBrainsMono Nerd Font is the
expected font; Catppuccin Mocha and single-line borders are used throughout.

## Architecture

```text
init.lua                     minimal bootstrap and core-module loading
lazy-lock.json               reproducible plugin revisions
after/lsp/*.lua              native, server-specific LSP overrides
lua/config/
  options.lua                editor options and native EditorConfig policy
  autocmds.lua               lifecycle, prose, and large-file behavior
  keymaps.lua                global editing/navigation/picker mappings
  diagnostics.lua            diagnostic display, jumps, and toggles
  commands.lua               maintenance commands
  languages.lua              central language manifest and server policy
  root.lua                   Git-first project and tool-root detection
  toolchain.lua              project formatter/linter/package-manager detection
  utils.lua                  mappings, executables, Python environments, helpers
  lazy.lua                   lazy.nvim bootstrap and runtime-path policy
  lsp.lua                    native LSP enablement and LspAttach behavior
  format.lua                 Conform formatter routing and commands
  lint.lua                   nvim-lint routing, scheduling, and commands
  tasks.lua                  project-aware Overseer task detection and actions
  health.lua                 configuration-specific health checks
  dap/                       shared DAP setup plus Python, Go, and Node adapters
lua/plugins/
  colorscheme.lua            Nordfox / Xcode Light with Ghostty sync
  completion.lua             blink.cmp
  debugging.lua              nvim-dap, DAP UI, and virtual text
  editor.lua                 Snacks, mini, Trouble, and TODO comments
  formatting.lua             Conform plugin spec
  git.lua                    Gitsigns and Diffview
  linting.lua                nvim-lint plugin spec
  lsp.lua                    Mason and nvim-lspconfig definitions
  sessions.lua               project-scoped persistence
  tasks.lua                  thin Overseer lifecycle and options spec
  testing.lua                Neotest and language adapters
  treesitter.lua             maintained Treesitter API and text objects
  ui.lua                     Which-key and the global lualine statusline
```

Plugin specs remain independent. Foundational plugins are loaded at startup;
feature plugins are command-, key-, event-, or buffer-loaded where that does not
break correctness.

## Language manifest

[`lua/config/languages.lua`](lua/config/languages.lua) is the authoritative
inventory for filetypes, LSP servers, formatter profiles, linters, Treesitter
parsers, Mason tools, debuggers, test adapters, and default inlay-hint policy.
The consumers derive their lists from it instead of maintaining parallel copies.

| Language | LSP | Formatting | Extra lint | Debug/test |
| --- | --- | --- | --- | --- |
| Lua | `lua_ls` | Stylua | LSP diagnostics | LuaJIT/Neovim runtime awareness |
| Python | `basedpyright`, `ruff` | Ruff | Ruff LSP (not nvim-lint) | debugpy, pytest |
| Go | `gopls` | goimports, then gofumpt | golangci-lint | Delve, neotest-golang |
| JavaScript/TypeScript/JSX/TSX | `vtsls` | Biome, otherwise prettierd/prettier | eslint_d or ESLint when configured | js-debug, Vitest/Jest |
| Bash/sh/zsh | `bashls` | shfmt (not zsh) | ShellCheck | — |
| JSON/JSONC/JSON5 | `jsonls` | web formatter policy | LSP diagnostics | SchemaStore schemas |
| YAML | `yamlls` | web formatter policy | LSP diagnostics | SchemaStore schemas |
| Markdown/MDX | — | web formatter policy | — | Treesitter |

The core parser set also includes C, C++, Diff, Git config/commit, Query, Regex,
Rust, TOML, Vim, and Vimdoc. Inlay hints default on for Lua, Go, and web
filetypes and off for Python; `<leader>th` remains a per-buffer override.

Project roots prefer the nearest Git root, then language/tool markers. Tool
lookup searches the nearest package or Python project before the broader project,
which keeps monorepos usable. Python selection checks `$VIRTUAL_ENV`, `.venv`,
`venv`, Poetry, Pipenv, uv, then `python3`.

### Adding a language

1. Add one entry to `definitions` in `lua/config/languages.lua`: filetypes,
   parsers, the `server = Mason-package` mapping, formatter profile, optional
   linters/tools, debugger/test-adapter key, and inlay-hint default.
2. Add the server policy to `server_configs` and create
   `after/lsp/<server>.lua` returning
   `require("config.languages").server_config("<server>")`. Extend that small
   override only when a runtime dependency such as SchemaStore is needed.
3. Add a formatter resolver in `lua/config/format.lua` only if no existing
   profile fits. Add selection/scheduling policy in `lua/config/lint.lua` only
   for a new linter class.
4. For a new debugger family, add `lua/config/dap/<name>.lua` and register it in
   `debugger_modules`. Add a Neotest adapter in `lua/plugins/testing.lua` only
   when the manifest requests it.
5. Run `:PluginSync`, `:MasonToolsInstall`, `:TreesitterUpdate`, and
   `:ConfigHealth`; then inspect `:LspConfigs`, `:LspClients`, `:FormatInfo`, and
   `:LintInfo` in a representative project.

### Project overrides

- Set `vim.b.project_root` to an absolute path for a one-buffer root override.
- Put `typeCheckingMode = "strict"` in `basedpyrightconfig.json`, or set
  `typeCheckingMode = "strict"` under `[tool.basedpyright]` in `pyproject.toml`,
  to opt a Python project into strict analysis. The editor default is `basic`,
  matching Pyright's quieter VS Code-style baseline.
- Biome wins when `biome.json`, `biome.jsonc`, or its package dependency exists.
  Otherwise the nearest Prettier configuration/package is used. Prettier is not
  run inside a Biome-managed project.
- ESLint lint/fix is enabled only when an ESLint configuration or dependency is
  present. Package-local executables win over Mason/global executables.
- JavaScript test adapters prefer an explicit local `vitest.config.*` or
  `jest.config.*`, then package scripts and dependencies. In a package that
  deliberately carries both runners, set `"neotestRunner": "jest"` (or
  `"vitest"`) in `package.json`; `vim.g.neotest_javascript_runner` provides a
  global override.
- A `.golangci.*` file enables project-specific golangci-lint policy; when the
  executable is available it can also run without one. Staticcheck remains owned
  by gopls and is disabled in the external golangci-lint invocation.

## Keymaps

The leader hierarchy is: `b` buffers, `c` code/LSP, `d` debugger, `f` find,
`g` Git, `p` projects/sessions, `r` tasks, `s` search/symbols, `t` tests/toggles,
`u` UI, `v` windows, and `x` diagnostics/Trouble. The direct `w`, `W`, `q`, and
`Q` mappings save and quit. `<leader>?` shows the active buffer-local mappings.

### Editing and navigation

| Mapping | Modes | Action |
| --- | --- | --- |
| `J` | normal | Join without moving the cursor |
| `Y` | normal | Yank to end of line |
| `n` / `N` | normal | Next/previous search result, open folds, center |
| `<C-d>` / `<C-u>` | normal | Half-page down/up and center |
| `<leader>tc` | normal | Toggle sticky function/class context |
| `<` / `>` | visual | Indent and keep the selection |
| `J` / `K` | visual | Move selected lines down/up |
| `p` | visual | Paste without replacing the unnamed register |
| `,` / `.` / `;` | insert | Insert punctuation with an undo breakpoint |
| `q` | selected utility buffers | Close the utility window |

### Files, projects, buffers, windows, and terminals

| Mapping | Action |
| --- | --- |
| `<leader>w` / `<leader>W` | Save current file / save all files |
| `<leader>q` / `<leader>Q` | Quit current window / save all files and quit Neovim |
| `<leader><space>` | Smart project file picker |
| `<leader>ff` / `<leader>fg` | Find files / live grep in project root |
| `<leader>fb` / `<leader>bl` | Buffer picker |
| `<leader>fr` / `<leader>fp` | Recent files / projects |
| `<leader>fc` / `<leader>fh` | Command history / help tags |
| `<leader>e` | Project-root explorer |
| `<leader>bd` / `<leader>bo` | Delete current / all other buffers without destroying layouts |
| `<leader>bn` / `<leader>bp` | Next / previous buffer |
| `<C-h/j/k/l>` | Move across splits (normal and terminal modes) |
| `<Esc><Esc>` | Leave terminal mode |
| `<leader>v=` | Equalize splits |
| `<leader>v+` / `<leader>v-` | Increase / decrease height by four |
| `<leader>v>` / `<leader>v<` | Increase / decrease width by four |
| `<leader>vr` | Rotate windows |
| `<leader>vH/J/K/L` | Move window to the far left/bottom/top/right |
| `<leader>ut` / `<leader>uT` | Toggle project floating terminal / open project bottom terminal |

### LSP, code, formatting, and linting

These LSP mappings are buffer-local and appear after `LspAttach`.

| Mapping | Action |
| --- | --- |
| `gd` / `gD` | Definition / declaration |
| `gri` / `grr` / `grt` | Implementation / references / type definition |
| `K` / `gK` | Hover / signature help |
| `<leader>ca` | Code action (normal or visual) |
| `<leader>cA` | All source actions |
| `<leader>cO` / `<leader>cF` / `<leader>cU` | Organize imports / fix all / remove unused imports |
| `<leader>cr` | Rename symbol |
| `<leader>cs` / `<leader>cS` | Document / workspace symbols |
| `<leader>ci` / `<leader>co` | Incoming / outgoing calls |
| `<leader>ck` | Signature help |
| `<leader>cwa` / `<leader>cwr` / `<leader>cwl` | Add / remove / list workspace folders |
| `<leader>cI` / `<leader>cR` | Inspect clients / restart LSP clients |
| `<leader>cm` | Mason UI |
| `<leader>cf` | Asynchronous format (normal or visual) |
| `<leader>cl` | Run selected linter |
| `<leader>cE` | Fix current file with project ESLint |
| `<leader>th` / `<leader>ts` | Toggle buffer inlay hints / semantic tokens |

### Diagnostics, lists, and Trouble

| Mapping | Action |
| --- | --- |
| `]d` / `[d` | Next / previous diagnostic |
| `]e` / `[e` | Next / previous error only |
| `]w` / `[w` | Next / previous warning only |
| `<leader>cd` | Diagnostic under cursor |
| `<leader>cD` | Put current-buffer diagnostics in the location list |
| `<leader>td` | Toggle diagnostics globally |
| `<leader>tv` | Toggle current-line diagnostic inline text |
| `<leader>uD` | Toggle diagnostic signs |
| `]q` / `[q` | Next / previous quickfix item, wrapping |
| `]l` / `[l` | Next / previous location-list item, wrapping |
| `<leader>xx` / `<leader>xX` | Workspace / current-buffer diagnostics in Trouble |
| `<leader>xq` / `<leader>xl` | Quickfix / location list in Trouble |
| `<leader>xs` / `<leader>xr` | Document symbols / LSP references in Trouble |

Diagnostic jumps center the destination without changing mode and then show a
source-labelled float. Diagnostics are severity-sorted, underlined, signposted,
and not updated while typing. Extra virtual lines are off; the current line's
diagnostic appears at its end and can be toggled.

Sources are intentionally non-overlapping: Basedpyright supplies Python type
analysis while Ruff LSP supplies Ruff diagnostics/actions; gopls supplies
staticcheck while golangci-lint runs without staticcheck; vtsls supplies JS/TS
language diagnostics while configured ESLint supplies style/project diagnostics;
BashLS and ShellCheck retain their separate server/shell roles. ShellCheck and
ESLint run after read/write as appropriate, ESLint may also run shortly after
`InsertLeave`, and Go's heavier linter runs on write or manually. Neotest reports
failed-test diagnostics at error severity.

### Git

| Mapping | Action |
| --- | --- |
| `]h` / `[h` | Next / previous hunk (native diff hunk in diff mode) |
| `<leader>gs` | Stage/unstage hunk; stage selection in visual mode |
| `<leader>gr` | Reset hunk; reset selection in visual mode |
| `<leader>gS` / `<leader>gp` | Stage buffer / preview hunk |
| `<leader>gb` / `<leader>gB` | Full line blame / toggle current-line blame |
| `<leader>gd` / `<leader>gq` | Diff current file / put repository hunks in quickfix |
| `ih` | Select hunk (operator-pending or visual) |
| `<leader>gD` / `<leader>gC` | Open / close Diffview |
| `<leader>gh` / `<leader>gH` | File / repository history |
| `<leader>gg` | Lazygit at Git or project root |
| `]x` / `[x` | Next / previous conflict in Diffview |
| `<leader>gco/gct/gcb/gca/gcn` | Choose ours/theirs/base/all/none for a conflict |

### Testing

| Mapping | Action |
| --- | --- |
| `<leader>tn` | Run nearest test |
| `<leader>tf` / `<leader>tp` | Run current file / package or directory |
| `<leader>ta` | Run all project tests |
| `<leader>tl` | Run last test |
| `<leader>tD` | Debug nearest test through DAP |
| `<leader>to` / `<leader>tO` | Open last output / toggle output panel |
| `<leader>tu` | Toggle test summary |
| `<leader>tS` | Stop test interactively |
| `]T` / `[T` | Next / previous failed test and center |

### Debugging

| Mapping | Action |
| --- | --- |
| `<leader>dc` | Start/continue |
| `<leader>db` / `<leader>dB` / `<leader>dl` | Breakpoint / conditional breakpoint / log point |
| `<leader>do` / `<leader>di` / `<leader>dO` | Step over / into / out |
| `<leader>dC` / `<leader>dR` | Run to cursor / restart frame |
| `<leader>dL` / `<leader>dp` | Run last configuration / pause |
| `<leader>dt` | Terminate |
| `<leader>dr` / `<leader>du` | Toggle REPL / DAP UI |
| `<leader>ds` / `<leader>de` | Inspect scopes / evaluate expression (normal or visual) |
| `<leader>dk` / `<leader>dj` | Move up / down the stack |
| `]b` / `[b` | Next / previous breakpoint across buffers |

DAP UI opens after initialization and closes on termination, exit, or disconnect.
Adapters are debugpy, Delve, and js-debug; Node configurations include current
file, package script, process attach, and compatible `.vscode/launch.json` input.

### Tasks and sessions

| Mapping | Action |
| --- | --- |
| `<leader>rr` | Choose an Overseer template |
| `<leader>rb/rt/rl/rf` | Detected project build/test/lint/format task |
| `<leader>rp` | Choose a package script |
| `<leader>rR` / `<leader>ro` | Rerun / open output of the latest task |
| `<leader>rh` / `<leader>ra` | Task history / task action |
| `<leader>pr` / `<leader>pc` | Restore project / current-directory session |
| `<leader>pl` / `<leader>ps` | Restore last / select session |
| `<leader>pw` / `<leader>pd` | Save session / stop persistence |

Task detection supports Make, Go, Python, npm, pnpm, Yarn, and Bun projects.
Sessions are keyed to project root and Git branch. Unlisted DAP, Neotest, and
Overseer windows, terminal buffers, and explicitly ignored buffers are omitted.

### Treesitter, TODOs, UI, and completion

| Mapping | Modes | Action |
| --- | --- | --- |
| `<C-Space>` / `<BS>` | normal/visual / visual | Select parent / child syntax node |
| `af` / `if` | visual, operator | Around / inside function |
| `ac` / `ic` | visual, operator | Around / inside class |
| `aa` / `ia` | visual, operator | Around / inside argument |
| `]m` / `[m` | normal, visual, operator | Next / previous function start |
| `]M` / `[M` | normal, visual, operator | Next / previous function end |
| `]]` / `[[` | normal, visual, operator | Next / previous class start |
| `<leader>cn` / `<leader>cN` | normal | Swap with next / previous argument |
| `]t` / `[t` | normal | Next / previous TODO comment |
| `<leader>st` / `<leader>sT` | normal | All TODOs / TODO-FIX-FIXME picker |
| `<leader>un` | normal | Notification history |
| `<leader>?` | normal | Buffer-local which-key view |

Blink's insert-mode completion maps are explicit and never preselect or
auto-insert an item:

| Mapping | Action |
| --- | --- |
| `<C-Space>` | Show completion or toggle documentation |
| `<C-n>` / `<C-p>` | Select next / previous item, otherwise fall back |
| `<Tab>` / `<S-Tab>` | Select item, jump snippet forward/backward, or fall back |
| `<CR>` | Explicitly accept selected completion; otherwise normal Enter |
| `<C-e>` | Cancel completion |
| `<C-b>` / `<C-f>` | Scroll documentation up / down |

Command-line completion uses `<C-Space>`, `<C-n/p>`, `<Tab>/<S-Tab>`, `<CR>`,
and `<C-e>`. In `:` and `@`, `<CR>` accepts the selected item or the first
visible suggestion while keeping the command line open; press `<CR>` again to
execute. With no suggestion it remains normal Enter. Search command lines use
buffer words and retain normal Enter behavior.

## Formatting, linting, and large files

Conform formats on save with a 1500 ms timeout and uses LSP formatting only when
no configured external formatter applies. Manual formatting is asynchronous.
Formatter routing is mutually exclusive, so Biome and Prettier never fight.
Conform preserves edits through its normal minimal-diff pipeline.

Files larger than 2 MiB (and files classified by Snacks' long-line detector)
disable expensive features: LSP attachment, diagnostics, Treesitter/syntax,
completion, autoformat, lint, persistent undo/swap, and session inclusion. Pickers
exclude `.git`, `node_modules`, virtual environments, build output, coverage, and
other generated directories from routine scans.

## Maintenance commands

| Command | Purpose |
| --- | --- |
| `:PluginSync` | Install, clean, update, and write `lazy-lock.json` |
| `:PluginUpdate` | Update plugins and the lock file |
| `:PluginLockRegenerate` | Delete and regenerate the lock from installed heads |
| `:Lazy` / `:Lazy profile` | Plugin manager / plugin startup profile |
| `:Mason` | Inspect/install editor-specific tools |
| `:MasonToolsInstall` / `:MasonToolsUpdate` | Install/update manifest tools |
| `:TreesitterUpdate` or `:TSUpdate` | Install/update configured parsers |
| `:checkhealth` | Full Neovim/plugin health report |
| `:ConfigHealth` | Configuration requirements, LSP definitions, and lock file |
| `:ConformInfo` or `:FormatInfo` | Selected formatter and executable details |
| `:Format` | Format the current buffer asynchronously |
| `:FormatDisable` / `:FormatEnable` | Disable/enable format-on-save for this buffer |
| `:FormatDisable!` / `:FormatEnable!` | Disable/enable format-on-save globally |
| `:Lint` / `:LintInfo` | Run or inspect selected nvim-lint providers |
| `:EslintFix` | Fix current file with project-local ESLint preference |
| `:LspInfo` | Native LSP status UI |
| `:LspClients` / `:LspConfigs` | Inspect buffer clients / all enabled configs |
| `:LspRestart` | Restart attached clients |
| `:ConformInfo` | Inspect active and available formatter definitions |
| `:StartupProfile [path]` | Write a clean `--startuptime` log |

Mason owns editor-specific language tooling; Homebrew owns general CLI tools.
`lazy-lock.json` belongs in version control. Prefer `:PluginUpdate` for routine
upgrades and use lock regeneration only when intentionally rebuilding the lock.

## Disabling or replacing modules

- To disable one optional plugin module, replace its plugin-spec table with
  `return {}` (or remove just the relevant spec from a multi-plugin file), then
  run `:PluginSync`. Remove dependent mappings or manifest flags at the same
  time. Do not edit lazy.nvim's downloaded plugin directories.
- To replace a subsystem, keep the public boundary small: `config.format`,
  `config.lint`, `config.dap`, and `config.lsp` are the policy modules; the
  matching `plugins/*.lua` file only declares lifecycle/dependencies.
- To disable one language capability, remove only its manifest field (`lsp`,
  `formatter_profile`, `linters`, `debugger`, or `test_adapter`). The remaining
  capabilities continue to derive normally.
- To replace a server, change the manifest mapping and add its `after/lsp` file.
  `nvim-lspconfig` supplies definitions only; never add legacy
  `require("lspconfig").server.setup()` calls.
- Local experiments can live in a new independent `lua/plugins/<topic>.lua`.
  lazy.nvim imports every module in that directory automatically.

## Neovim 0.12.4 compatibility choices

- LSP uses `vim.lsp.config("*", ...)`, `vim.lsp.enable()`, native `LspAttach`,
  and `after/lsp/*.lua`. Blink capabilities are merged into every server.
  nvim-lspconfig is only a source of server definitions.
- Recursive dynamic LSP file watchers are disabled to avoid exhausting macOS
  file descriptors in large monorepos; normal open/change/save notifications and
  file-rename capabilities remain available.
- Diagnostic movement uses `vim.diagnostic.jump()` and native current-line
  `virtual_lines`; deprecated `goto_next`/`goto_prev` APIs are not used.
- Treesitter uses the maintained `neovim-treesitter/nvim-treesitter` repository
  plus its parser registry, the current `install()` API, native
  `vim.treesitter.start()`, native `vim.treesitter.foldexpr()`, and the current
  textobjects setup. The `ecma`, `jsx`, and `html_tags` query-only dependency
  packages are installed alongside the 29 binary parsers required by the
  maintained registry. Treesitter is deliberately not lazy-loaded. Removed legacy
  `require("nvim-treesitter.configs").setup()` patterns are absent.
- Native EditorConfig remains authoritative (`vim.g.editorconfig = true`).
- The global statusline uses `laststatus=3`; floats use `winborder=single`; native
  loader/cache support is enabled without sacrificing startup correctness.
