local M = {}

local function has_prettierd(bufnr)
  local command = require("config.utils").executable("prettierd", bufnr)
  return vim.fn.executable(command) == 1
end

local function web_formatters(bufnr)
  if require("config.toolchain").uses_biome(bufnr) then
    return { "biome" }
  end
  if has_prettierd(bufnr) then
    return { "prettierd" }
  end
  return { "prettier" }
end

local profile_formatters = {
  go = function()
    return { "goimports", "gofumpt" }
  end,
  lua = function()
    return { "stylua" }
  end,
  python = function()
    return { "ruff_format" }
  end,
  shell = function(_, filetype)
    return filetype == "zsh" and {} or { "shfmt" }
  end,
  web = web_formatters,
}

function M.options()
  local conform_util = require("conform.util")
  local formatters_by_ft = {}
  for _, definition in pairs(require("config.languages").all()) do
    if definition.formatter_profile then
      local resolver = assert(
        profile_formatters[definition.formatter_profile],
        "Unknown formatter profile: " .. definition.formatter_profile
      )
      for _, filetype in ipairs(definition.filetypes or {}) do
        local resolved_filetype = filetype
        formatters_by_ft[filetype] = function(bufnr)
          return resolver(bufnr, resolved_filetype)
        end
      end
    end
  end

  return {
    default_format_opts = {
      lsp_format = "fallback",
    },
    format_on_save = function(bufnr)
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
        return nil
      end
      if require("config.utils").is_large_file(bufnr) then
        return nil
      end
      return {
        lsp_format = "fallback",
        timeout_ms = 1500,
      }
    end,
    formatters_by_ft = formatters_by_ft,
    formatters = {
      biome = {
        cwd = conform_util.root_file({ "biome.json", "biome.jsonc", "package.json" }),
        require_cwd = true,
      },
      prettier = {
        cwd = conform_util.root_file({
          ".prettierrc",
          ".prettierrc.json",
          "prettier.config.js",
          "prettier.config.mjs",
          "package.json",
        }),
      },
      prettierd = {
        cwd = conform_util.root_file({
          ".prettierrc",
          ".prettierrc.json",
          "prettier.config.js",
          "prettier.config.mjs",
          "package.json",
        }),
      },
      ruff_format = {
        cwd = conform_util.root_file({
          "pyproject.toml",
          "ruff.toml",
          ".ruff.toml",
          "basedpyrightconfig.json",
          "pyrightconfig.json",
        }),
      },
      stylua = {
        cwd = conform_util.root_file({ "stylua.toml", ".stylua.toml", ".git" }),
      },
    },
  }
end

function M.format(bufnr)
  require("conform").format({
    async = true,
    bufnr = bufnr or 0,
    lsp_format = "fallback",
  })
end

function M.setup_commands()
  vim.api.nvim_create_user_command("Format", function(args)
    M.format(0)
  end, { desc = "Format the current buffer" })

  vim.api.nvim_create_user_command("FormatDisable", function(args)
    if args.bang then
      vim.g.disable_autoformat = true
      vim.notify("Global format-on-save disabled")
    else
      vim.b.disable_autoformat = true
      vim.notify("Buffer format-on-save disabled")
    end
  end, { bang = true, desc = "Disable format-on-save (! for global)" })

  vim.api.nvim_create_user_command("FormatEnable", function(args)
    if args.bang then
      vim.g.disable_autoformat = false
      vim.notify("Global format-on-save enabled")
    else
      vim.b.disable_autoformat = false
      vim.notify("Buffer format-on-save enabled")
    end
  end, { bang = true, desc = "Enable format-on-save (! for global)" })
end

return M
