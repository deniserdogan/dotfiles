local languages = require("config.languages")

return {
  {
    "mason-org/mason.nvim",
    lazy = false,
    priority = 950,
    keys = {
      { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" },
    },
    opts = {
      max_concurrent_installers = 4,
      PATH = "prepend",
      ui = {
        border = "single",
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    priority = 850,
    dependencies = {
      "mason-org/mason.nvim",
      "saghen/blink.cmp",
      "b0o/schemastore.nvim",
    },
    config = function()
      require("config.lsp").setup()
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    lazy = false,
    priority = 900,
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      ensure_installed = languages.mason_lsp_servers(),
      -- Native enablement is owned by config.lsp, including non-Mason servers.
      automatic_enable = false,
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    lazy = false,
    priority = 800,
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = languages.mason_tools(),
      auto_update = false,
      run_on_start = true,
      start_delay = 2000,
      debounce_hours = 24,
    },
  },
  {
    "b0o/schemastore.nvim",
    lazy = true,
  },
}
