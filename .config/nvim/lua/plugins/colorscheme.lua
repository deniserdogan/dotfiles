local terminal_themes = {
  dark = {
    palette = {
      "#3b4252",
      "#bf616a",
      "#a3be8c",
      "#ebcb8b",
      "#81a1c1",
      "#b48ead",
      "#88c0d0",
      "#e5e9f0",
      "#53648d",
      "#d06f79",
      "#b1d196",
      "#f0d399",
      "#8cafd2",
      "#c895bf",
      "#93ccdc",
      "#e7ecf4",
    },
    background = "#2e3440",
    foreground = "#cdcecf",
    cursor = "#cdcecf",
    selection_background = "#3e4a5b",
    selection_foreground = "#cdcecf",
  },
  light = {
    palette = {
      "#b4d8fd",
      "#d12f1b",
      "#3e8087",
      "#78492a",
      "#0f68a0",
      "#ad3da4",
      "#804fb8",
      "#262626",
      "#8a99a6",
      "#d12f1b",
      "#23575c",
      "#78492a",
      "#0b4f79",
      "#ad3da4",
      "#4b21b0",
      "#262626",
    },
    background = "#ffffff",
    foreground = "#262626",
    cursor = "#262626",
    selection_background = "#b4d8fd",
    selection_foreground = "#262626",
  },
}

local function sync_ghostty()
  if vim.env.TERM_PROGRAM ~= "ghostty" then
    return
  end

  local theme = terminal_themes[vim.o.background]
  if not theme then
    return
  end

  local palette = {}
  for index, color in ipairs(theme.palette) do
    palette[#palette + 1] = ("%d;%s"):format(index - 1, color)
  end

  local osc = "\27]"
  local terminator = "\27\\"
  local sequences = {
    osc .. "4;" .. table.concat(palette, ";") .. terminator,
    osc .. "10;" .. theme.foreground .. terminator,
    osc .. "11;" .. theme.background .. terminator,
    osc .. "12;" .. theme.cursor .. terminator,
    osc .. "17;" .. theme.selection_background .. terminator,
    osc .. "19;" .. theme.selection_foreground .. terminator,
  }

  pcall(function()
    io.stdout:write(table.concat(sequences))
    io.stdout:flush()
  end)
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
  else
    sync_ghostty()
  end
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
        },
      })

      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("sync_ghostty_theme", { clear = true }),
        callback = sync_ghostty,
      })

      vim.api.nvim_create_autocmd("Signal", {
        group = vim.api.nvim_create_augroup("sync_system_theme", { clear = true }),
        pattern = "SIGUSR1",
        callback = apply_system_theme,
      })

      apply_system_theme()
    end,
  },
}
