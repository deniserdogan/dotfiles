local M = {}

local function mason_or_project_executable(name)
  local mason = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", name)
  if vim.fn.executable(mason) == 1 then
    return mason
  end
  return require("config.utils").executable(name, 0)
end

local function module_root()
  return require("config.root").tool(0, { "go.work", "go.mod" })
end

function M.setup(dap)
  dap.adapters.go = {
    type = "server",
    host = "127.0.0.1",
    port = "${port}",
    executable = {
      command = mason_or_project_executable("dlv"),
      args = { "dap", "-l", "127.0.0.1:${port}" },
      detached = false,
    },
  }

  dap.configurations.go = {
    {
      type = "go",
      request = "launch",
      name = "Go: current file",
      mode = "debug",
      program = "${file}",
      cwd = module_root,
    },
    {
      type = "go",
      request = "launch",
      name = "Go: package",
      mode = "debug",
      program = "${fileDirname}",
      cwd = module_root,
    },
    {
      type = "go",
      request = "attach",
      name = "Go: attach to process",
      mode = "local",
      processId = require("dap.utils").pick_process,
      cwd = module_root,
    },
  }
end

return M
