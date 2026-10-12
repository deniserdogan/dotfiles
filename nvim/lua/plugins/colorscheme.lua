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
    local options = lualine.get_config()
    options.options.theme = "auto"
    lualine.setup(options)
  end

  apply_editor_highlights()
  vim.cmd.redrawstatus()
  vim.cmd.redraw()
end

local function system_background()
  local theme_file = ("/tmp/sketchybar_theme_mode_%d"):format(vim.uv.getuid())
  local ok, lines = pcall(vim.fn.readfile, theme_file, "", 1)
  if ok and (lines[1] == "dark" or lines[1] == "light") then
    return lines[1]
  end
  local result = vim
    .system({ "defaults", "read", "-g", "AppleInterfaceStyle" }, { text = true })
    :wait()
  if result.code == 0 and vim.trim(result.stdout) == "Dark" then
    return "dark"
  end
  return "light"
end

local function apply_system_theme()
  local mode = system_background()
  local colorscheme = mode == "dark" and "nordfox" or "xcodelight"
  local ok, lines = pcall(vim.fn.readfile, ("/tmp/rice_theme_%d.json"):format(vim.uv.getuid()))
  if ok then
    local decoded, state = pcall(vim.json.decode, table.concat(lines, "\n"))
    if decoded and type(state) == "table" and type(state.neovim) == "string"
      and state.neovim:match("^[a-z0-9_%-]+$") and state.mode == mode then
      colorscheme = state.neovim
    end
  end
  -- Some plugins report a family name rather than the requested variant.
  local reported = colorscheme:match("^rose%-pine") and "rose-pine"
    or colorscheme:match("^kanagawa") and "kanagawa" or colorscheme
  if vim.g.colors_name ~= reported or vim.g.rice_requested_theme ~= colorscheme or vim.o.background ~= mode then
    vim.o.background = mode
    local applied, err = pcall(vim.cmd.colorscheme, colorscheme)
    if not applied then
      vim.notify("Theme unavailable: " .. colorscheme .. ". Run :Lazy install.\n" .. err, vim.log.levels.WARN)
      return
    end
    vim.g.rice_requested_theme = colorscheme
    finalize_system_theme_change()
  end
end

return {
  {
    "EdenEast/nightfox.nvim",
    lazy = false,
    priority = 1000,
    dependencies = {
      "lunacookies/vim-colors-xcode",
      { "folke/tokyonight.nvim", opts = { style = "night", transparent = true,
        styles = { sidebars = "transparent", floats = "transparent" } } },
      { "catppuccin/nvim", name = "catppuccin", opts = { transparent_background = true } },
      { "ellisonleao/gruvbox.nvim", opts = { transparent_mode = true } },
      { "rebelot/kanagawa.nvim", opts = { transparent = true } },
      { "rose-pine/neovim", name = "rose-pine", opts = { styles = { transparency = true } } },
      { "projekt0n/github-nvim-theme", main = "github-theme", opts = { options = { transparent = true } } },
      { "sainnhe/everforest", init = function()
        vim.g.everforest_background = "medium"
        vim.g.everforest_transparent_background = 2
        vim.g.everforest_enable_italic = 1
      end },
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
