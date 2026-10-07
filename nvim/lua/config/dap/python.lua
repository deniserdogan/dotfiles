local M = {}

local project_markers = {
  "pyproject.toml",
  "basedpyrightconfig.json",
  "pyrightconfig.json",
  "Pipfile",
  "setup.cfg",
  "setup.py",
}

local function mason_or_project_executable(name)
  local mason = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", name)
  if vim.fn.executable(mason) == 1 then
    return mason
  end
  return require("config.utils").executable(name, 0)
end

local function project_root()
  return require("config.root").tool(0, project_markers)
end

function M.setup(dap)
  local utils = require("config.utils")

  dap.adapters.python = {
    type = "executable",
    command = mason_or_project_executable("debugpy-adapter"),
  }

  dap.configurations.python = {
    {
      type = "python",
      request = "launch",
      name = "Python: current file",
      program = "${file}",
      cwd = project_root,
      pythonPath = function()
        return utils.python(0)
      end,
      justMyCode = true,
    },
    {
      type = "python",
      request = "attach",
      name = "Python: attach to debugpy",
      connect = function()
        local host = vim.fn.input("Host [127.0.0.1]: ")
        local port = tonumber(vim.fn.input("Port [5678]: ")) or 5678
        return {
          host = host ~= "" and host or "127.0.0.1",
          port = port,
        }
      end,
      cwd = project_root,
      pythonPath = function()
        return utils.python(0)
      end,
      justMyCode = true,
    },
  }
end

return M
