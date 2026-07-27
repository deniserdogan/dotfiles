return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "┆" },
      },
      signs_staged = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "┆" },
      },
      signs_staged_enable = true,
      attach_to_untracked = true,
      current_line_blame = false,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 500,
        ignore_whitespace = false,
        use_focus = true,
      },
      current_line_blame_formatter = "<author>, <author_time:%R> • <summary>",
      preview_config = {
        border = "single",
        style = "minimal",
        relative = "cursor",
        row = 0,
        col = 1,
      },
      max_file_length = 20000,
      on_attach = function(bufnr)
        local gitsigns = require("gitsigns")

        local function map(mode, lhs, rhs, description)
          vim.keymap.set(mode, lhs, rhs, {
            buffer = bufnr,
            silent = true,
            desc = description,
          })
        end

        local function navigate(direction)
          if vim.wo.diff then
            vim.cmd.normal({ direction == "next" and "]c" or "[c", bang = true })
            vim.cmd.normal({ "zz", bang = true })
            return
          end

          gitsigns.nav_hunk(direction, { target = "all" }, function()
            if vim.api.nvim_get_current_buf() == bufnr then
              vim.cmd.normal({ "zz", bang = true })
            end
          end)
        end

        map("n", "]h", function()
          navigate("next")
        end, "Next Git hunk")
        map("n", "[h", function()
          navigate("prev")
        end, "Previous Git hunk")

        map("n", "<leader>gs", gitsigns.stage_hunk, "Stage/unstage hunk")
        map("x", "<leader>gs", function()
          gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage selected hunk")
        map("n", "<leader>gr", gitsigns.reset_hunk, "Reset hunk")
        map("x", "<leader>gr", function()
          gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset selected hunk")
        map("n", "<leader>gS", gitsigns.stage_buffer, "Stage buffer")
        map("n", "<leader>gp", gitsigns.preview_hunk, "Preview hunk")
        map("n", "<leader>gb", function()
          gitsigns.blame_line({ full = true })
        end, "Blame line")
        map("n", "<leader>gB", gitsigns.toggle_current_line_blame, "Toggle line blame")
        map("n", "<leader>gd", gitsigns.diffthis, "Diff current file")
        map("n", "<leader>gq", function()
          gitsigns.setqflist("all")
        end, "Repository hunks")
        map({ "o", "x" }, "ih", gitsigns.select_hunk, "Git hunk")
      end,
    },
  },

  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewFileHistory",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewToggleFiles",
    },
    dependencies = { "nvim-mini/mini.nvim" },
    opts = function()
      local actions = require("diffview.actions")

      return {
        enhanced_diff_hl = true,
        use_icons = true,
        view = {
          default = {
            layout = "diff2_horizontal",
            disable_diagnostics = true,
          },
          merge_tool = {
            layout = "diff3_horizontal",
            disable_diagnostics = true,
            winbar_info = true,
          },
          file_history = {
            layout = "diff2_horizontal",
            disable_diagnostics = true,
          },
        },
        file_panel = {
          listing_style = "tree",
          tree_options = {
            flatten_dirs = true,
            folder_statuses = "only_folded",
          },
          win_config = {
            position = "left",
            width = 35,
          },
        },
        keymaps = {
          disable_defaults = false,
          view = {
            { "n", "]x", actions.next_conflict, { desc = "Next conflict" } },
            { "n", "[x", actions.prev_conflict, { desc = "Previous conflict" } },
            { "n", "<leader>gco", actions.conflict_choose("ours"), { desc = "Choose ours" } },
            { "n", "<leader>gct", actions.conflict_choose("theirs"), { desc = "Choose theirs" } },
            { "n", "<leader>gcb", actions.conflict_choose("base"), { desc = "Choose base" } },
            { "n", "<leader>gca", actions.conflict_choose("all"), { desc = "Choose all" } },
            { "n", "<leader>gcn", actions.conflict_choose("none"), { desc = "Delete conflict" } },
          },
        },
      }
    end,
    keys = {
      { "<leader>gD", "<cmd>DiffviewOpen<cr>", desc = "Open Diffview" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Repository history" },
      { "<leader>gC", "<cmd>DiffviewClose<cr>", desc = "Close Diffview" },
    },
  },
}
