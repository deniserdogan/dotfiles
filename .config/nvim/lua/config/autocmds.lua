local M = {}

function M.setup()
  local utils = require("config.utils")

  vim.api.nvim_create_autocmd("TextYankPost", {
    group = utils.augroup("highlight_yank"),
    callback = function()
      vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
    end,
  })

  vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
    group = utils.augroup("checktime"),
    callback = function()
      if vim.o.buftype ~= "nofile" then
        vim.cmd.checktime()
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = utils.augroup("equalize_splits"),
    command = "tabdo wincmd =",
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = utils.augroup("restore_cursor"),
    callback = function(event)
      local mark = vim.api.nvim_buf_get_mark(event.buf, '"')
      local line_count = vim.api.nvim_buf_line_count(event.buf)
      if mark[1] > 0 and mark[1] <= line_count and vim.bo[event.buf].filetype ~= "gitcommit" then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufReadPre", {
    group = utils.augroup("large_file_detect"),
    callback = function(event)
      local stat = vim.uv.fs_stat(event.file)
      if stat and stat.size > 2 * 1024 * 1024 then
        vim.b[event.buf].bigfile = true
        vim.b[event.buf].completion = false
        vim.b[event.buf].disable_autoformat = true
        vim.b[event.buf].disable_lint = true
        vim.b[event.buf].session_ignore = true
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = utils.augroup("large_file_disable"),
    callback = function(event)
      if not utils.is_large_file(event.buf) then
        return
      end
      vim.diagnostic.enable(false, { bufnr = event.buf })
      vim.treesitter.stop(event.buf)
      for _, winid in ipairs(vim.fn.win_findbuf(event.buf)) do
        vim.wo[winid].foldmethod = "manual"
      end
      vim.bo[event.buf].syntax = ""
      vim.bo[event.buf].swapfile = false
      vim.cmd("silent! NoMatchParen")
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = utils.augroup("close_with_q"),
    pattern = {
      "checkhealth",
      "git",
      "help",
      "lspinfo",
      "man",
      "notify",
      "qf",
      "startuptime",
    },
    callback = function(event)
      vim.bo[event.buf].buflisted = false
      vim.keymap.set("n", "q", "<cmd>close<cr>", {
        buffer = event.buf,
        silent = true,
        desc = "Close window",
      })
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = utils.augroup("prose"),
    pattern = { "gitcommit", "markdown" },
    callback = function(event)
      for _, winid in ipairs(vim.fn.win_findbuf(event.buf)) do
        vim.wo[winid].spell = true
        vim.wo[winid].wrap = true
      end
    end,
  })
end

return M
