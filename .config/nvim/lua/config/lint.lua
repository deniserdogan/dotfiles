local M = {}

local function valid_buffer(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr)
    and vim.bo[bufnr].buftype == ""
    and vim.bo[bufnr].modifiable
    and not vim.b[bufnr].disable_lint
    and not require("config.utils").is_large_file(bufnr)
end

function M.linters(bufnr)
  bufnr = bufnr or 0
  local filetype = vim.bo[bufnr].filetype
  local toolchain = require("config.toolchain")
  local configured = require("config.languages").linters(filetype)

  if vim.list_contains(configured, "shellcheck") then
    return { "shellcheck" }
  end
  if vim.list_contains(configured, "golangcilint") then
    local golangci = require("config.utils").executable("golangci-lint", bufnr)
    if toolchain.uses_golangci(bufnr) or vim.fn.executable(golangci) == 1 then
      return { "golangcilint" }
    end
  end
  if vim.list_contains(configured, "eslint_d") and toolchain.uses_eslint(bufnr) then
    local eslint_d = require("config.utils").executable("eslint_d", bufnr)
    if vim.fn.executable(eslint_d) == 1 then
      return { "eslint_d" }
    end
    return { "eslint" }
  end

  -- Ruff diagnostics are intentionally owned by the Ruff language server.
  return {}
end

function M.eslint_fix(bufnr)
  bufnr = bufnr or 0
  if not require("config.toolchain").uses_eslint(bufnr) then
    vim.notify("No ESLint configuration found for this buffer", vim.log.levels.INFO)
    return
  end
  if vim.bo[bufnr].modified then
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd.write()
    end)
  end

  local file = vim.api.nvim_buf_get_name(bufnr)
  local eslint_d = require("config.utils").executable("eslint_d", bufnr)
  local executable = vim.fn.executable(eslint_d) == 1 and eslint_d
    or require("config.utils").executable("eslint", bufnr)
  if vim.fn.executable(executable) ~= 1 then
    vim.notify("ESLint executable is unavailable", vim.log.levels.ERROR)
    return
  end

  vim.system({ executable, "--fix", file }, {
    cwd = require("config.root").project(bufnr),
    text = true,
  }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify(result.stderr, vim.log.levels.ERROR, { title = "ESLint fix" })
        return
      end
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd.checktime()
      end)
      M.run(bufnr)
    end)
  end)
end

function M.run(bufnr)
  bufnr = bufnr or 0
  if not valid_buffer(bufnr) then
    return
  end
  local names = M.linters(bufnr)
  if #names == 0 then
    return
  end
  local cwd = require("config.root").project(bufnr)
  vim.api.nvim_buf_call(bufnr, function()
    require("lint").try_lint(names, { cwd = cwd })
  end)
end

function M.info(bufnr)
  bufnr = bufnr or 0
  local lint = require("lint")
  local names = M.linters(bufnr)
  local lines = {
    "Filetype: " .. vim.bo[bufnr].filetype,
    "Working directory: " .. require("config.root").project(bufnr),
    "Selected linters: " .. (#names > 0 and table.concat(names, ", ") or "none"),
  }
  for _, name in ipairs(names) do
    local namespace = lint.get_namespace(name)
    local count = #vim.diagnostic.get(bufnr, { namespace = namespace })
    local linter = lint.linters[name]
    local command = type(linter.cmd) == "function" and linter.cmd() or linter.cmd
    table.insert(lines, string.format("  %s: %s (%d diagnostics)", name, command, count))
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "LintInfo" })
end

function M.setup()
  local lint = require("lint")
  local utils = require("config.utils")

  lint.linters.eslint.cmd = function()
    return utils.executable("eslint", 0)
  end
  lint.linters.eslint_d.cmd = function()
    return utils.executable("eslint_d", 0)
  end
  lint.linters.golangcilint.cmd = function()
    return utils.executable("golangci-lint", 0)
  end
  table.insert(lint.linters.golangcilint.args, 2, "--disable=staticcheck")
  lint.linters.shellcheck.cmd = function()
    return utils.executable("shellcheck", 0)
  end

  local group = utils.augroup("lint")
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(event)
      if vim.bo[event.buf].filetype ~= "go" then
        M.run(event.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(event)
      M.run(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function(event)
      local bufnr = event.buf
      if vim.bo[bufnr].filetype == "go" then
        return
      end
      local selected = M.linters(bufnr)
      if
        not vim.list_contains(selected, "eslint") and not vim.list_contains(selected, "eslint_d")
      then
        return
      end
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          M.run(bufnr)
        end
      end, 150)
    end,
  })

  vim.api.nvim_create_user_command("Lint", function(args)
    M.run(0)
  end, { desc = "Lint the current buffer" })
  vim.api.nvim_create_user_command("LintInfo", function(args)
    M.info(0)
  end, { desc = "Inspect selected linters" })
  vim.api.nvim_create_user_command("EslintFix", function()
    M.eslint_fix(0)
  end, { desc = "Fix the current file with project ESLint" })
end

return M
