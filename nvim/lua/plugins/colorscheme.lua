local function apply_editor_highlights()
  local transparent_groups = {
    "Normal",
    "NormalNC",
    "EndOfBuffer",
    "SignColumn",
    "FoldColumn",
    "LineNr",
    "LineNrAbove",
    "LineNrBelow",
    "CursorLineNr",
    "TreesitterContext",
    "TreesitterContextLineNumber",
  }

  for _, group in ipairs(transparent_groups) do
    local highlight = vim.api.nvim_get_hl(0, { name = group, link = false })
    highlight.bg = nil
    vim.api.nvim_set_hl(0, group, highlight)
  end
end

local function apply_theme_overrides()
  apply_editor_highlights()
end

local function finalize_system_theme_change()
  -- `:colorscheme` returns only after every ColorScheme/OptionSet handler has
  -- finished. Refreshing here prevents lualine from retaining the old palette.
  local has_lualine, lualine = pcall(require, "lualine")
  if has_lualine then
    lualine.setup()
  end

  apply_editor_highlights()
  vim.cmd.redrawstatus()
  vim.cmd.redraw()
end

local function system_background()
  local result = vim
    .system({ "defaults", "read", "-g", "AppleInterfaceStyle" }, { text = true })
    :wait()
  if result.code == 0 and vim.trim(result.stdout) == "Dark" then
    return "dark"
  end
  return "light"
end

local function apply_system_theme()
  local colorscheme = system_background() == "dark" and "nordfox" or "xcodelight"
  if vim.g.colors_name ~= colorscheme then
    vim.cmd.colorscheme(colorscheme)
  end
  finalize_system_theme_change()
end

return {
  {
    "EdenEast/nightfox.nvim",
    lazy = false,
    priority = 1000,
    dependencies = {
      "lunacookies/vim-colors-xcode",
    },
    config = function()
      require("nightfox").setup({
        options = {
          terminal_colors = true,
          transparent = true,
        },
      })

      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("sync_ghostty_theme", { clear = true }),
        callback = apply_theme_overrides,
      })

      vim.api.nvim_create_autocmd("Signal", {
        group = vim.api.nvim_create_augroup("sync_system_theme", { clear = true }),
        pattern = "SIGUSR1",
        callback = apply_system_theme,
      })

      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("transparent_editor_background", { clear = true }),
        once = true,
        callback = apply_editor_highlights,
      })

      apply_system_theme()
    end,
  },
}
