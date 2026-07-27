local M = {}

local function center()
  vim.cmd.normal({ "zz", bang = true })
end

local function cycle_list(kind, direction)
  local list = kind == "quickfix" and vim.fn.getqflist({ idx = 0, size = 0 })
    or vim.fn.getloclist(0, { idx = 0, size = 0 })
  if list.size == 0 then
    vim.notify(
      (kind == "quickfix" and "Quickfix" or "Location") .. " list is empty",
      vim.log.levels.INFO
    )
    return
  end

  local forward = direction > 0
  local wrap = (forward and list.idx >= list.size) or (not forward and list.idx <= 1)
  local command
  if kind == "quickfix" then
    command = wrap and (forward and "cfirst" or "clast") or (forward and "cnext" or "cprevious")
  else
    command = wrap and (forward and "lfirst" or "llast") or (forward and "lnext" or "lprevious")
  end
  vim.cmd(command)
  center()
end

function M.setup()
  local map = require("config.utils").map
  local diagnostic = require("config.diagnostics")
  local severity = vim.diagnostic.severity

  map({ "n", "v" }, "<Space>", "<Nop>", "Leader")

  -- Editing keeps registers, selections, and the viewport predictable.
  map("n", "J", "mzJ`z", "Join lines without moving cursor")
  map("n", "Y", "y$", "Yank to end of line")
  map("n", "n", "nzzzv", "Next search result")
  map("n", "N", "Nzzzv", "Previous search result")
  map("n", "<C-d>", "<C-d>zz", "Scroll down and center")
  map("n", "<C-u>", "<C-u>zz", "Scroll up and center")
  map("x", "<", "<gv", "Indent left and reselect")
  map("x", ">", ">gv", "Indent right and reselect")
  map("x", "J", ":move '>+1<CR>gv=gv", "Move selection down")
  map("x", "K", ":move '<-2<CR>gv=gv", "Move selection up")
  map("x", "p", '"_dP', "Paste without replacing register")
  map("i", ",", ",<C-g>u", "Undo break after comma")
  map("i", ".", ".<C-g>u", "Undo break after period")
  map("i", ";", ";<C-g>u", "Undo break after semicolon")

  -- Frequent file lifecycle actions remain immediate, single-key leader mappings.
  map("n", "<leader>w", "<cmd>write<cr>", "Save file")
  map("n", "<leader>W", "<cmd>wall<cr>", "Save all files")
  map("n", "<leader>q", "<cmd>quit<cr>", "Quit window")
  map("n", "<leader>Q", "<cmd>wqa<cr>", "Save all and quit")

  -- Files, projects, buffers, and explorer are all backed by Snacks.
  map("n", "<leader><space>", function()
    Snacks.picker.smart({ cwd = require("config.root").project() })
  end, "Smart files")
  map("n", "<leader>ff", function()
    Snacks.picker.files({ cwd = require("config.root").project() })
  end, "Find files")
  map("n", "<leader>fg", function()
    Snacks.picker.grep({ cwd = require("config.root").project() })
  end, "Live grep")
  map("n", "<leader>fb", function()
    Snacks.picker.buffers()
  end, "Buffers")
  map("n", "<leader>fr", function()
    Snacks.picker.recent()
  end, "Recent files")
  map("n", "<leader>fp", function()
    Snacks.picker.projects()
  end, "Projects")
  map("n", "<leader>fc", function()
    Snacks.picker.command_history()
  end, "Command history")
  map("n", "<leader>fh", function()
    Snacks.picker.help()
  end, "Help tags")
  map("n", "<leader>e", function()
    Snacks.explorer({ cwd = require("config.root").project() })
  end, "Explorer")

  map("n", "<leader>bd", function()
    Snacks.bufdelete()
  end, "Delete buffer")
  map("n", "<leader>bo", function()
    local current = vim.api.nvim_get_current_buf()
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if buffer ~= current and vim.bo[buffer].buflisted then
        Snacks.bufdelete(buffer)
      end
    end
  end, "Delete other buffers")
  map("n", "<leader>bn", "<cmd>bnext<cr>", "Next buffer")
  map("n", "<leader>bp", "<cmd>bprevious<cr>", "Previous buffer")
  map("n", "<leader>bl", function()
    Snacks.picker.buffers()
  end, "Buffer picker")

  -- Split navigation is identical in normal and terminal modes.
  map("n", "<C-h>", "<C-w>h", "Window left")
  map("n", "<C-j>", "<C-w>j", "Window down")
  map("n", "<C-k>", "<C-w>k", "Window up")
  map("n", "<C-l>", "<C-w>l", "Window right")
  map("t", "<C-h>", "<C-\\><C-n><C-w>h", "Window left")
  map("t", "<C-j>", "<C-\\><C-n><C-w>j", "Window down")
  map("t", "<C-k>", "<C-\\><C-n><C-w>k", "Window up")
  map("t", "<C-l>", "<C-\\><C-n><C-w>l", "Window right")
  map("t", "<Esc><Esc>", "<C-\\><C-n>", "Terminal normal mode")
  map("n", "<leader>v=", "<C-w>=", "Equalize windows")
  map("n", "<leader>v+", "<cmd>resize +4<cr>", "Increase window height")
  map("n", "<leader>v-", "<cmd>resize -4<cr>", "Decrease window height")
  map("n", "<leader>v>", "<cmd>vertical resize +4<cr>", "Increase window width")
  map("n", "<leader>v<", "<cmd>vertical resize -4<cr>", "Decrease window width")
  map("n", "<leader>vr", "<C-w>r", "Rotate windows")
  map("n", "<leader>vH", "<C-w>H", "Move window far left")
  map("n", "<leader>vJ", "<C-w>J", "Move window to bottom")
  map("n", "<leader>vK", "<C-w>K", "Move window to top")
  map("n", "<leader>vL", "<C-w>L", "Move window far right")

  map("n", "<leader>ut", function()
    Snacks.terminal(nil, {
      count = 1,
      cwd = require("config.root").project(),
      win = { position = "float", border = "single" },
    })
  end, "Toggle project terminal")
  map("n", "<leader>uT", function()
    Snacks.terminal(nil, {
      count = 2,
      cwd = require("config.root").project(),
      win = { position = "bottom", height = 0.35 },
    })
  end, "Open project terminal split")

  -- Diagnostics use exact severities and the same bracket language as lists and hunks.
  map("n", "]d", function()
    diagnostic.jump(1)
  end, "Next diagnostic")
  map("n", "[d", function()
    diagnostic.jump(-1)
  end, "Previous diagnostic")
  map("n", "]e", function()
    diagnostic.jump(1, severity.ERROR)
  end, "Next error")
  map("n", "[e", function()
    diagnostic.jump(-1, severity.ERROR)
  end, "Previous error")
  map("n", "]w", function()
    diagnostic.jump(1, severity.WARN)
  end, "Next warning")
  map("n", "[w", function()
    diagnostic.jump(-1, severity.WARN)
  end, "Previous warning")
  map("n", "<leader>cd", function()
    vim.diagnostic.open_float({ scope = "cursor", source = true, border = "single" })
  end, "Line diagnostics")
  map("n", "<leader>cD", function()
    vim.diagnostic.setloclist({ open = true })
  end, "Buffer diagnostics")
  map("n", "<leader>td", diagnostic.toggle, "Toggle diagnostics")
  map("n", "<leader>tv", diagnostic.toggle_virtual_lines, "Toggle diagnostic virtual lines")
  map("n", "<leader>uD", diagnostic.toggle_signs, "Toggle diagnostic signs")

  map("n", "]q", function()
    cycle_list("quickfix", 1)
  end, "Next quickfix item")
  map("n", "[q", function()
    cycle_list("quickfix", -1)
  end, "Previous quickfix item")
  map("n", "]l", function()
    cycle_list("location", 1)
  end, "Next location item")
  map("n", "[l", function()
    cycle_list("location", -1)
  end, "Previous location item")
end

return M
