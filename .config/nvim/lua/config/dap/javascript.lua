local M = {}

local package_markers = {
  "package.json",
  "tsconfig.json",
  "jsconfig.json",
  "pnpm-workspace.yaml",
}

local function mason_or_project_executable(name)
  local mason = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", name)
  if vim.fn.executable(mason) == 1 then
    return mason
  end
  return require("config.utils").executable(name, 0)
end

local function package_root()
  return require("config.root").tool(0, package_markers)
end

local function package_manager()
  local root = require("config.root")
  local lock_root =
    root.find({ "bun.lock", "bun.lockb", "pnpm-lock.yaml", "yarn.lock", "package-lock.json" }, 0)
  if lock_root then
    if
      vim.uv.fs_stat(vim.fs.joinpath(lock_root, "bun.lock"))
      or vim.uv.fs_stat(vim.fs.joinpath(lock_root, "bun.lockb"))
    then
      return mason_or_project_executable("bun")
    end
    if vim.uv.fs_stat(vim.fs.joinpath(lock_root, "pnpm-lock.yaml")) then
      return mason_or_project_executable("pnpm")
    end
    if vim.uv.fs_stat(vim.fs.joinpath(lock_root, "yarn.lock")) then
      return mason_or_project_executable("yarn")
    end
  end
  return mason_or_project_executable("npm")
end

function M.setup(dap)
  local adapter = {
    type = "server",
    host = "127.0.0.1",
    port = "${port}",
    executable = {
      command = mason_or_project_executable("js-debug-adapter"),
      args = { "${port}" },
      detached = false,
    },
  }

  -- The aliases also make conventional VS Code launch.json files work unchanged.
  for _, adapter_name in ipairs({ "pwa-node", "node", "node-terminal" }) do
    dap.adapters[adapter_name] = adapter
  end

  local configurations = {
    {
      type = "pwa-node",
      request = "launch",
      name = "Node: current file",
      program = "${file}",
      cwd = package_root,
      runtimeExecutable = function()
        return mason_or_project_executable("node")
      end,
      console = "integratedTerminal",
      sourceMaps = true,
      skipFiles = { "<node_internals>/**", "**/node_modules/**" },
    },
    {
      type = "pwa-node",
      request = "launch",
      name = "Node: package script",
      cwd = package_root,
      runtimeExecutable = package_manager,
      runtimeArgs = function()
        local script = vim.fn.input("Package script: ", "test")
        return { "run", script }
      end,
      console = "integratedTerminal",
      sourceMaps = true,
      skipFiles = { "<node_internals>/**", "**/node_modules/**" },
    },
    {
      type = "pwa-node",
      request = "attach",
      name = "Node: attach to process",
      cwd = package_root,
      processId = require("dap.utils").pick_process,
      sourceMaps = true,
      skipFiles = { "<node_internals>/**", "**/node_modules/**" },
    },
  }

  for _, filetype in ipairs(require("config.languages").all().web.filetypes) do
    if
      vim.list_contains(
        { "javascript", "javascriptreact", "typescript", "typescriptreact" },
        filetype
      )
    then
      dap.configurations[filetype] = configurations
    end
  end

  dap.providers.configs["dap.launch.json"] = function(bufnr)
    local root = require("config.root")
    local directory = root.buffer_directory(bufnr)
    local boundary = root.git(bufnr) or root.project(bufnr)

    while directory do
      local launch_json = vim.fs.joinpath(directory, ".vscode", "launch.json")
      if vim.uv.fs_stat(launch_json) then
        return require("dap.ext.vscode").getconfigs(launch_json) or {}
      end
      if directory == boundary then
        break
      end
      local parent = vim.fs.dirname(directory)
      if not parent or parent == directory then
        break
      end
      directory = parent
    end

    return {}
  end
end

return M
