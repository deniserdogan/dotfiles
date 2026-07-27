return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    lazy = false,
    dependencies = { "rafamadriz/friendly-snippets" },
    opts_extend = { "sources.default" },
    opts = {
      keymap = {
        preset = "none",
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
        ["<C-e>"] = { "cancel", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
      },
      appearance = {
        nerd_font_variant = "mono",
      },
      completion = {
        accept = {
          auto_brackets = {
            enabled = true,
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 250,
          window = {
            border = "single",
          },
        },
        ghost_text = {
          enabled = true,
          show_without_selection = false,
        },
        list = {
          max_items = 100,
          selection = {
            preselect = false,
            auto_insert = false,
          },
        },
        menu = {
          border = "single",
          max_height = 12,
          scrollbar = false,
          draw = {
            columns = {
              { "kind_icon" },
              { "label", "label_description", gap = 1 },
              { "source_name" },
            },
          },
        },
      },
      cmdline = {
        keymap = {
          preset = "none",
          ["<C-Space>"] = { "show", "fallback" },
          ["<C-n>"] = { "select_next", "fallback" },
          ["<C-p>"] = { "select_prev", "fallback" },
          ["<Tab>"] = { "show", "select_next", "fallback" },
          ["<S-Tab>"] = { "show", "select_prev", "fallback" },
          ["<CR>"] = { "select_and_accept", "fallback" },
          ["<C-e>"] = { "cancel", "fallback" },
        },
        sources = function()
          local command_type = vim.fn.getcmdtype()
          if command_type == "/" or command_type == "?" then
            return { "buffer" }
          end
          if command_type == ":" or command_type == "@" then
            return { "cmdline", "path" }
          end
          return {}
        end,
        completion = {
          list = {
            selection = {
              preselect = false,
              auto_insert = true,
            },
          },
          menu = {
            auto_show = function()
              return vim.fn.getcmdtype() == ":"
            end,
          },
          ghost_text = {
            enabled = true,
          },
        },
      },
      signature = {
        enabled = true,
        window = {
          border = "single",
          treesitter_highlighting = true,
        },
      },
      snippets = {
        preset = "default",
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          lsp = {
            name = "LSP",
            score_offset = 4,
          },
          snippets = {
            name = "Snippet",
            score_offset = 3,
          },
          path = {
            name = "Path",
            score_offset = 2,
          },
          buffer = {
            name = "Buffer",
            score_offset = -3,
            min_keyword_length = 3,
            max_items = 20,
          },
        },
      },
      fuzzy = {
        implementation = "prefer_rust_with_warning",
        sorts = { "exact", "score", "sort_text" },
      },
    },
  },
}
