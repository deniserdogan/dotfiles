local M = {}

local definitions = {
  core = {
    treesitter = {
      "c",
      "cpp",
      "diff",
      "git_config",
      "gitcommit",
      "json5",
      "query",
      "regex",
      "rust",
      "toml",
      "vim",
      "vimdoc",
    },
    treesitter_queries = { "ecma", "html_tags", "jsx" },
  },
  lua = {
    filetypes = { "lua" },
    treesitter = { "lua", "luadoc" },
    lsp = { lua_ls = "lua-language-server" },
    formatter_profile = "lua",
    inlay_hints = true,
  },
  python = {
    filetypes = { "python" },
    treesitter = { "python" },
    lsp = {
      basedpyright = "basedpyright",
      ruff = "ruff",
    },
    formatter_profile = "python",
    mason_tools = { "debugpy" },
    debugger = "python",
    test_adapter = "python",
    inlay_hints = false,
  },
  go = {
    filetypes = { "go", "gomod", "gowork", "gosum" },
    treesitter = { "go", "gomod", "gosum", "gowork" },
    lsp = { gopls = "gopls" },
    formatter_profile = "go",
    linters = { go = { "golangcilint" } },
    mason_tools = { "gofumpt", "goimports", "golangci-lint", "delve" },
    debugger = "go",
    test_adapter = "go",
    inlay_hints = true,
  },
  web = {
    filetypes = {
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
      "css",
      "html",
    },
    treesitter = { "javascript", "typescript", "tsx", "css", "html" },
    lsp = { vtsls = "vtsls" },
    formatter_profile = "web",
    linters = {
      javascript = { "eslint_d", "eslint" },
      javascriptreact = { "eslint_d", "eslint" },
      typescript = { "eslint_d", "eslint" },
      typescriptreact = { "eslint_d", "eslint" },
    },
    mason_tools = { "biome", "prettierd", "prettier", "eslint_d", "js-debug-adapter" },
    debugger = "javascript",
    test_adapter = "javascript",
    inlay_hints = true,
  },
  bash = {
    filetypes = { "bash", "sh", "zsh" },
    treesitter = { "bash" },
    lsp = { bashls = "bash-language-server" },
    formatter_profile = "shell",
    linters = {
      bash = { "shellcheck" },
      sh = { "shellcheck" },
    },
    mason_tools = { "shfmt", "shellcheck" },
  },
  json = {
    filetypes = { "json", "jsonc", "json5" },
    treesitter = { "json", "json5" },
    lsp = { jsonls = "json-lsp" },
    formatter_profile = "web",
  },
  yaml = {
    filetypes = { "yaml" },
    treesitter = { "yaml" },
    lsp = { yamlls = "yaml-language-server" },
    formatter_profile = "web",
  },
  markdown = {
    filetypes = { "markdown", "markdown.mdx" },
    treesitter = { "markdown", "markdown_inline" },
    formatter_profile = "web",
  },
}

local function typescript_root(bufnr, on_dir)
  local deno_root = vim.fs.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" })
  local project_root = vim.fs.root(bufnr, {
    { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" },
    ".git",
    { "package.json", "tsconfig.json", "jsconfig.json" },
  })

  if deno_root and (not project_root or #deno_root >= #project_root) then
    return
  end

  on_dir(project_root or require("config.root").buffer_directory(bufnr))
end

local function local_typescript_sdk(bufnr, boundary)
  local directory = require("config.root").buffer_directory(bufnr)
  while directory do
    local candidate = vim.fs.joinpath(directory, "node_modules", "typescript", "lib")
    if vim.uv.fs_stat(vim.fs.joinpath(candidate, "tsserver.js")) then
      return candidate
    end
    if directory == boundary then
      break
    end
    local parent = vim.fs.dirname(directory)
    if not parent or parent == directory then
      break
    end
    directory = parent
  end
end

local server_configs = {
  lua_ls = {
    root_markers = { ".luarc.json", ".luarc.jsonc", "stylua.toml", ".git" },
    settings = {
      Lua = {
        runtime = { version = "LuaJIT" },
        completion = { callSnippet = "Replace" },
        diagnostics = { globals = { "vim", "Snacks" } },
        hint = {
          enable = true,
          arrayIndex = "Disable",
          await = true,
          paramName = "Literal",
          paramType = true,
          semicolon = "Disable",
          setType = false,
        },
        telemetry = { enable = false },
        workspace = {
          checkThirdParty = false,
          library = vim.api.nvim_get_runtime_file("", true),
        },
      },
    },
  },
  basedpyright = {
    root_markers = {
      {
        "basedpyrightconfig.json",
        "pyrightconfig.json",
        "pyproject.toml",
        "setup.py",
        "setup.cfg",
        "Pipfile",
      },
      ".git",
    },
    before_init = function(_, config)
      config.settings = config.settings or {}
      config.settings.python = config.settings.python or {}
      config.settings.python.pythonPath = require("config.utils").python_for_root(
        config.root_dir or require("config.root").project(0)
      )
    end,
    settings = {
      basedpyright = {
        analysis = {
          autoImportCompletions = true,
          autoSearchPaths = true,
          diagnosticMode = "openFilesOnly",
          typeCheckingMode = "basic",
          diagnosticSeverityOverrides = {
            reportUnusedImport = "none",
          },
          inlayHints = {
            callArgumentNames = true,
            functionReturnTypes = false,
            genericTypes = false,
            variableTypes = false,
          },
        },
      },
    },
  },
  ruff = {
    root_markers = {
      { "pyproject.toml", "ruff.toml", ".ruff.toml" },
      ".git",
    },
    init_options = {
      settings = {
        fixAll = true,
        organizeImports = true,
        lint = { enable = true },
      },
    },
  },
  gopls = {
    root_markers = { "go.work", "go.mod", ".git" },
    settings = {
      gopls = {
        analyses = {
          nilness = true,
          unusedparams = true,
          unusedwrite = true,
        },
        completeUnimported = true,
        directoryFilters = { "-.git", "-node_modules", "-vendor" },
        gofumpt = true,
        hints = {
          assignVariableTypes = false,
          compositeLiteralFields = true,
          compositeLiteralTypes = false,
          constantValues = true,
          functionTypeParameters = true,
          parameterNames = true,
          rangeVariableTypes = false,
        },
        semanticTokens = true,
        staticcheck = true,
        usePlaceholders = true,
      },
    },
  },
  vtsls = {
    root_dir = typescript_root,
    before_init = function(_, config)
      local root = config.root_dir or require("config.root").project(0)
      local tsdk = local_typescript_sdk(0, root)
      if tsdk then
        config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
          typescript = { tsdk = tsdk },
        })
      end
    end,
    settings = {
      vtsls = {
        autoUseWorkspaceTsdk = true,
        enableMoveToFileCodeAction = true,
      },
      javascript = {
        inlayHints = {
          enumMemberValues = { enabled = true },
          functionLikeReturnTypes = { enabled = false },
          parameterNames = { enabled = "literals" },
          parameterTypes = { enabled = true },
          propertyDeclarationTypes = { enabled = true },
          variableTypes = { enabled = false },
        },
        preferences = { importModuleSpecifier = "shortest" },
        suggest = { completeFunctionCalls = true },
        updateImportsOnFileMove = { enabled = "always" },
      },
      typescript = {
        inlayHints = {
          enumMemberValues = { enabled = true },
          functionLikeReturnTypes = { enabled = false },
          parameterNames = { enabled = "literals" },
          parameterTypes = { enabled = true },
          propertyDeclarationTypes = { enabled = true },
          variableTypes = { enabled = false },
        },
        preferences = { importModuleSpecifier = "shortest" },
        suggest = { completeFunctionCalls = true },
        updateImportsOnFileMove = { enabled = "always" },
      },
    },
  },
  bashls = {
    root_markers = { ".bashrc", ".shellcheckrc", ".git" },
    settings = {
      bashIde = {
        shellcheckPath = "",
      },
    },
  },
  jsonls = {
    root_markers = { "package.json", ".git" },
    settings = {
      json = { validate = { enable = true } },
    },
  },
  yamlls = {
    root_markers = { ".yamllint", ".git" },
    settings = {
      yaml = {
        keyOrdering = false,
        schemaStore = { enable = false, url = "" },
        validate = true,
      },
    },
  },
}

local function unique(values)
  local seen, result = {}, {}
  for _, value in ipairs(values) do
    if not seen[value] then
      seen[value] = true
      table.insert(result, value)
    end
  end
  table.sort(result)
  return result
end

function M.all()
  return definitions
end

function M.for_filetype(filetype)
  for name, definition in pairs(definitions) do
    if vim.list_contains(definition.filetypes or {}, filetype) then
      return definition, name
    end
  end
end

function M.lsp_servers()
  local servers = {}
  for _, definition in pairs(definitions) do
    vim.list_extend(servers, vim.tbl_keys(definition.lsp or {}))
  end
  return unique(servers)
end

function M.mason_lsp_servers()
  return M.lsp_servers()
end

function M.mason_tools()
  local tools = {}
  for _, definition in pairs(definitions) do
    vim.list_extend(tools, definition.mason_tools or {})
  end
  return unique(tools)
end

function M.mason_packages()
  local packages = M.mason_tools()
  for _, definition in pairs(definitions) do
    for _, package in pairs(definition.lsp or {}) do
      table.insert(packages, package)
    end
  end
  return unique(packages)
end

function M.treesitter_parsers()
  local parsers = {}
  for _, definition in pairs(definitions) do
    vim.list_extend(parsers, definition.treesitter or {})
  end
  return unique(parsers)
end

function M.treesitter_packages()
  local packages = M.treesitter_parsers()
  for _, definition in pairs(definitions) do
    vim.list_extend(packages, definition.treesitter_queries or {})
  end
  return unique(packages)
end

function M.server_config(server)
  return vim.deepcopy(server_configs[server] or {})
end

function M.formatter_profile(filetype)
  local definition = M.for_filetype(filetype)
  return definition and definition.formatter_profile or nil
end

function M.linters(filetype)
  local definition = M.for_filetype(filetype)
  return definition and (definition.linters or {})[filetype] or {}
end

function M.inlay_hints(filetype)
  local definition = M.for_filetype(filetype)
  return definition and definition.inlay_hints == true or false
end

return M
