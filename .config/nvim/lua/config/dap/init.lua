local M = {}

local debugger_modules = {
  python = "config.dap.python",
  go = "config.dap.go",
  javascript = "config.dap.javascript",
}

local function define_signs()
  local signs = {
    DapBreakpoint = { text = "●", texthl = "DiagnosticError" },
    DapBreakpointCondition = { text = "◆", texthl = "DiagnosticWarn" },
    DapBreakpointRejected = { text = "○", texthl = "DiagnosticError" },
    DapLogPoint = { text = "◆", texthl = "DiagnosticInfo" },
    DapStopped = { text = "▶", texthl = "DiagnosticOk" },
  }
  for name, opts in pairs(signs) do
    vim.fn.sign_define(name, opts)
  end
end

local function setup_adapters(dap)
  local configured = {}
  for _, definition in pairs(require("config.languages").all()) do
    local debugger = definition.debugger
    if debugger and not configured[debugger] then
      local module = debugger_modules[debugger]
      if not module then
        error("No DAP configuration module for debugger " .. debugger)
      end
      require(module).setup(dap)
      configured[debugger] = true
    end
  end
end

function M.setup()
  local dap = require("dap")
  local dapui = require("dapui")

  define_signs()
  setup_adapters(dap)

  dap.defaults.fallback.exception_breakpoints = { "uncaught" }
  dap.defaults.fallback.focus_terminal = false
  dap.defaults.fallback.terminal_win_cmd = "belowright new"

  dapui.setup({
    controls = {
      enabled = true,
      element = "repl",
    },
    expand_lines = true,
    floating = {
      border = "single",
      mappings = { close = { "q", "<Esc>" } },
    },
    layouts = {
      {
        position = "left",
        size = 42,
        elements = {
          { id = "scopes", size = 0.4 },
          { id = "stacks", size = 0.25 },
          { id = "breakpoints", size = 0.2 },
          { id = "watches", size = 0.15 },
        },
      },
      {
        position = "bottom",
        size = 12,
        elements = {
          { id = "repl", size = 0.5 },
          { id = "console", size = 0.5 },
        },
      },
    },
    render = {
      indent = 1,
      max_value_lines = 100,
    },
  })

  require("nvim-dap-virtual-text").setup({
    all_frames = false,
    all_references = false,
    clear_on_continue = true,
    commented = false,
    highlight_changed_variables = true,
    only_first_definition = true,
    show_stop_reason = true,
    virt_lines = false,
    virt_text_pos = "eol",
  })

  dap.listeners.after.event_initialized["user_dapui"] = function()
    dapui.open()
  end
  local close_ui = function()
    dapui.close()
  end
  dap.listeners.before.event_terminated["user_dapui"] = close_ui
  dap.listeners.before.event_exited["user_dapui"] = close_ui
  dap.listeners.before.disconnect["user_dapui"] = close_ui
end

function M.conditional_breakpoint()
  vim.ui.input({ prompt = "Breakpoint condition: " }, function(condition)
    if condition ~= nil then
      require("dap").set_breakpoint(condition ~= "" and condition or nil)
    end
  end)
end

function M.log_point()
  vim.ui.input({ prompt = "Log point message: " }, function(message)
    if message and message ~= "" then
      require("dap").set_breakpoint(nil, nil, message)
    end
  end)
end

local function breakpoint_locations()
  local locations = {}
  for bufnr, breakpoints in pairs(require("dap.breakpoints").get()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local path = vim.api.nvim_buf_get_name(bufnr)
      if path == "" then
        path = tostring(bufnr)
      end
      for _, breakpoint in ipairs(breakpoints) do
        locations[#locations + 1] = {
          bufnr = bufnr,
          line = breakpoint.line,
          path = path,
        }
      end
    end
  end
  table.sort(locations, function(left, right)
    return left.path == right.path and left.line < right.line or left.path < right.path
  end)
  return locations
end

function M.jump_breakpoint(direction)
  local locations = breakpoint_locations()
  if #locations == 0 then
    vim.notify("No DAP breakpoints set", vim.log.levels.INFO, { title = "DAP" })
    return
  end

  local current_buffer = vim.api.nvim_get_current_buf()
  local current_path = vim.api.nvim_buf_get_name(current_buffer)
  if current_path == "" then
    current_path = tostring(current_buffer)
  end
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local target

  if direction > 0 then
    for _, location in ipairs(locations) do
      if
        location.path > current_path
        or location.path == current_path and location.line > current_line
      then
        target = location
        break
      end
    end
    target = target or locations[1]
  else
    for index = #locations, 1, -1 do
      local location = locations[index]
      if
        location.path < current_path
        or location.path == current_path and location.line < current_line
      then
        target = location
        break
      end
    end
    target = target or locations[#locations]
  end

  vim.api.nvim_win_set_buf(0, target.bufnr)
  vim.api.nvim_win_set_cursor(0, { target.line, 0 })
  vim.cmd.normal({ "zz", bang = true })
end

function M.scopes()
  require("dapui").float_element("scopes", { enter = true })
end

function M.evaluate()
  require("dapui").eval()
end

return M
