local function project_name()
  local directory = require("config.root").project(0)
  return "󰉋 " .. vim.fn.fnamemodify(directory, ":t")
end

local function lsp_clients()
  local names = {}
  local seen = {}

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    if not seen[client.name] then
      seen[client.name] = true
      names[#names + 1] = client.name
    end
  end

  table.sort(names)
  return #names > 0 and ("󰒋 " .. table.concat(names, ", ")) or ""
end

return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-mini/mini.nvim" },
    opts = {
      preset = "classic",
      delay = 300,
      win = {
        border = "single",
        padding = { 1, 2 },
      },
      layout = {
        spacing = 3,
      },
      spec = {
        { "<leader>b", group = "buffers" },
        { "<leader>c", group = "code / LSP" },
        { "<leader>d", group = "debugger" },
        { "<leader>f", group = "find / picker" },
        { "<leader>g", group = "Git" },
        { "<leader>gc", group = "conflicts" },
        { "<leader>p", group = "projects / sessions" },
        { "<leader>r", group = "run / tasks" },
        { "<leader>s", group = "search / symbols" },
        { "<leader>t", group = "tests / toggles" },
        { "<leader>u", group = "UI" },
        { "<leader>v", group = "windows" },
        { "<leader>x", group = "diagnostics / Trouble" },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer-local keymaps",
      },
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-mini/mini.nvim" },
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        icons_enabled = true,
        component_separators = { left = "│", right = "│" },
        section_separators = { left = "", right = "" },
        disabled_filetypes = {
          statusline = { "snacks_dashboard" },
        },
        refresh = {
          statusline = 500,
          tabline = 1000,
          winbar = 1000,
        },
      },
      sections = {
        lualine_a = {
          {
            "mode",
            fmt = function(mode)
              return mode:sub(1, 3)
            end,
          },
        },
        lualine_b = {
          { "branch", icon = "" },
          {
            "diff",
            symbols = { added = " ", modified = " ", removed = " " },
          },
        },
        lualine_c = {
          { project_name },
          {
            "filename",
            path = 1,
            shorting_target = 40,
            symbols = {
              modified = " ●",
              readonly = " ",
              unnamed = "[No Name]",
              newfile = "[New]",
            },
          },
        },
        lualine_x = {
          {
            "diagnostics",
            symbols = { error = " ", warn = " ", info = " ", hint = " " },
          },
          {
            lsp_clients,
            cond = function()
              return #vim.lsp.get_clients({ bufnr = 0 }) > 0
            end,
          },
          { "filetype", colored = true },
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },
      extensions = { "lazy", "mason", "overseer", "quickfix", "trouble" },
    },
  },
}
