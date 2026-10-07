local ignored_directories = {
  ".git",
  "node_modules",
  ".venv",
  "venv",
  "dist",
  "build",
  "target",
  "coverage",
}

return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    init = function()
      vim.g.snacks_animate = false
      vim.opt.winborder = "single"
    end,
    opts = {
      animate = { enabled = false },
      bigfile = {
        enabled = true,
        notify = true,
        size = 2 * 1024 * 1024,
        line_length = 1000,
        setup = function(ctx)
          vim.b[ctx.buf].bigfile = true
          vim.b[ctx.buf].session_ignore = true
          vim.b[ctx.buf].completion = false
          vim.b[ctx.buf].disable_autoformat = true
          vim.b[ctx.buf].disable_lint = true
          vim.b[ctx.buf].miniindentscope_disable = true
          vim.b[ctx.buf].minianimate_disable = true
          Snacks.util.wo(0, { foldmethod = "manual" })
          vim.bo[ctx.buf].swapfile = false
          vim.bo[ctx.buf].syntax = ""
          vim.bo[ctx.buf].undofile = false
          vim.diagnostic.enable(false, { bufnr = ctx.buf })
        end,
      },
      dashboard = { enabled = false },
      explorer = {
        enabled = true,
        replace_netrw = true,
        trash = true,
      },
      indent = { enabled = false },
      input = { enabled = true },
      notifier = {
        enabled = true,
        timeout = 3000,
        style = "compact",
        top_down = true,
        margin = { top = 1, right = 1, bottom = 0 },
      },
      picker = {
        enabled = true,
        ui_select = true,
        matcher = {
          cwd_bonus = true,
          frecency = true,
          history_bonus = true,
        },
        formatters = {
          file = {
            filename_first = true,
            truncate = "center",
          },
        },
        previewers = {
          file = {
            max_size = 1024 * 1024,
            max_line_length = 500,
          },
        },
        sources = {
          files = {
            hidden = true,
            ignored = false,
            exclude = ignored_directories,
          },
          grep = {
            hidden = true,
            ignored = false,
            exclude = ignored_directories,
          },
          explorer = {
            hidden = true,
            ignored = false,
            exclude = ignored_directories,
          },
        },
      },
      quickfile = { enabled = true },
      scope = { enabled = false },
      scroll = { enabled = false },
      terminal = {
        win = {
          style = "terminal",
          border = "single",
        },
      },
      lazygit = {
        configure = true,
        config = {
          gui = { nerdFontsVersion = "3" },
        },
        win = {
          style = "lazygit",
          border = "single",
        },
      },
      styles = {
        input = { border = "single" },
        lazygit = { border = "single" },
        notification = { border = "single" },
        notification_history = { border = "single" },
        terminal = { border = "single" },
      },
    },
    keys = {
      {
        "<leader>gg",
        function()
          local root = require("config.root")
          Snacks.lazygit({ cwd = root.git() or root.project() })
        end,
        desc = "Lazygit",
      },
      {
        "<leader>un",
        function()
          Snacks.notifier.show_history()
        end,
        desc = "Notification history",
      },
    },
  },

  {
    "nvim-mini/mini.nvim",
    lazy = false,
    priority = 900,
    config = function()
      require("mini.icons").setup({ style = "glyph" })
      MiniIcons.mock_nvim_web_devicons()
    end,
  },

  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {
      focus = true,
    },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Workspace diagnostics" },
      {
        "<leader>xX",
        "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
        desc = "Buffer diagnostics",
      },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix list" },
      { "<leader>xl", "<cmd>Trouble loclist toggle<cr>", desc = "Location list" },
      { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Document symbols" },
      { "<leader>xr", "<cmd>Trouble lsp_references toggle<cr>", desc = "LSP references" },
    },
  },

  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      signs = true,
      highlight = {
        multiline = false,
        keyword = "wide",
        after = "fg",
        max_line_len = 400,
        exclude = { "bigfile" },
      },
      search = {
        command = "rg",
        args = {
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--glob=!**/.git/**",
          "--glob=!**/node_modules/**",
          "--glob=!**/.venv/**",
          "--glob=!**/venv/**",
          "--glob=!**/dist/**",
          "--glob=!**/build/**",
          "--glob=!**/target/**",
        },
      },
    },
    keys = {
      {
        "]t",
        function()
          require("todo-comments").jump_next()
        end,
        desc = "Next TODO comment",
      },
      {
        "[t",
        function()
          require("todo-comments").jump_prev()
        end,
        desc = "Previous TODO comment",
      },
      {
        "<leader>st",
        function()
          Snacks.picker.todo_comments()
        end,
        desc = "TODO comments",
      },
      {
        "<leader>sT",
        function()
          Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } })
        end,
        desc = "TODO/FIX/FIXME comments",
      },
    },
  },
}
