local M = {}

local signs = {
  text = {
    [vim.diagnostic.severity.ERROR] = "󰅚 ",
    [vim.diagnostic.severity.WARN] = "󰀪 ",
    [vim.diagnostic.severity.INFO] = "󰋽 ",
    [vim.diagnostic.severity.HINT] = "󰌶 ",
  },
}

local virtual_text = {
  current_line = true,
  prefix = "●",
  source = "if_many",
  spacing = 2,
  virt_text_pos = "eol",
}
local diagnostics_enabled = true

function M.setup()
  vim.diagnostic.config({
    float = {
      border = "single",
      focusable = false,
      header = "",
      prefix = "",
      source = true,
    },
    severity_sort = true,
    signs = signs,
    underline = true,
    update_in_insert = false,
    virtual_lines = false,
    virtual_text = virtual_text,
  })
end

function M.jump(count, severity)
  vim.diagnostic.jump({
    count = count,
    float = false,
    severity = severity,
  })
  vim.cmd.normal({ "zz", bang = true })
  vim.schedule(function()
    vim.diagnostic.open_float({
      border = "single",
      focus = false,
      scope = "cursor",
      source = true,
    })
  end)
end

function M.toggle()
  diagnostics_enabled = not diagnostics_enabled
  vim.diagnostic.enable(diagnostics_enabled)
  if diagnostics_enabled then
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) and require("config.utils").is_large_file(bufnr) then
        vim.diagnostic.enable(false, { bufnr = bufnr })
      end
    end
  end
  vim.notify("Diagnostics " .. (diagnostics_enabled and "enabled" or "disabled"))
end

function M.toggle_virtual_text()
  local enabled = vim.diagnostic.config().virtual_text ~= false
  vim.diagnostic.config({ virtual_text = enabled and false or virtual_text })
  vim.notify("Diagnostic inline text " .. (enabled and "disabled" or "enabled"))
end

function M.toggle_signs()
  local enabled = vim.diagnostic.config().signs ~= false
  vim.diagnostic.config({ signs = enabled and false or signs })
  vim.notify("Diagnostic signs " .. (enabled and "disabled" or "enabled"))
end

return M
