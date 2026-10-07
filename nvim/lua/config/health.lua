local M = {}

local required_executables = {
  "fd",
  "git",
  "jq",
  "lazygit",
  "rg",
  "stylua",
  "tree-sitter",
}

function M.check()
  vim.health.start("Neovim configuration")

  if vim.fn.has("nvim-0.12.4") == 1 then
    vim.health.ok("Neovim 0.12.4 or newer")
  else
    vim.health.error("Neovim 0.12.4 or newer is required")
  end

  for _, executable in ipairs(required_executables) do
    if vim.fn.executable(executable) == 1 then
      vim.health.ok(executable .. " is available at " .. vim.fn.exepath(executable))
    else
      vim.health.error(executable .. " is missing")
    end
  end

  vim.health.start("Native LSP definitions")
  for _, server in ipairs(require("config.languages").lsp_servers()) do
    if vim.lsp.config[server] then
      vim.health.ok(server .. " configuration is available")
    else
      vim.health.error(server .. " configuration is missing")
    end
  end

  vim.health.start("Architecture")
  if vim.uv.fs_stat(vim.fn.stdpath("config") .. "/lazy-lock.json") then
    vim.health.ok("lazy-lock.json exists")
  else
    vim.health.warn("lazy-lock.json has not been generated yet; run :PluginSync")
  end
  vim.health.ok("Native EditorConfig support is enabled")
end

return M
