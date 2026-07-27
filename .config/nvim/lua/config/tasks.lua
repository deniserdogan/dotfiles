local M = {}

local languages = require("config.languages")
local root = require("config.root")
local toolchain = require("config.toolchain")
local utils = require("config.utils")

local function file_exists(directory, name)
  return vim.uv.fs_stat(vim.fs.joinpath(directory, name)) ~= nil
end

local function any_file_exists(directory, names)
  for _, name in ipairs(names) do
    if file_exists(directory, name) then
      return true
    end
  end
  return false
end

local function executable(name)
  return utils.executable(name, 0)
end

local function package_manager()
  local manager = toolchain.package_manager(0)
  return executable(manager)
end

local function package_json()
  local package = toolchain.package_json(0)
  if not package then
    vim.notify(
      "Could not decode the nearest package.json",
      vim.log.levels.ERROR,
      { title = "Overseer" }
    )
  end
  return package
end

local function project_context()
  local _, language = languages.for_filetype(vim.bo.filetype)
  local language_markers = {
    go = { "go.work", "go.mod" },
    python = { "pyproject.toml", "Pipfile", "setup.py", "setup.cfg" },
    web = { "package.json" },
  }
  if language_markers[language] then
    local directory = root.find(language_markers[language], 0)
    if directory then
      return { kind = language == "web" and "node" or language, directory = directory }
    end
  end

  local directory = root.find(
    { "package.json", "pyproject.toml", "Pipfile", "go.work", "go.mod", "Makefile", "makefile" },
    0
  ) or root.project(0)
  if file_exists(directory, "package.json") then
    return { kind = "node", directory = directory }
  elseif any_file_exists(directory, { "pyproject.toml", "Pipfile", "setup.py", "setup.cfg" }) then
    return { kind = "python", directory = directory }
  elseif any_file_exists(directory, { "go.work", "go.mod" }) then
    return { kind = "go", directory = directory }
  elseif any_file_exists(directory, { "Makefile", "makefile" }) then
    return { kind = "make", directory = directory }
  end
  return { kind = "generic", directory = directory }
end

local function node_command(context, task_kind)
  local package = package_json()
  local scripts = package and type(package.scripts) == "table" and package.scripts or {}
  if scripts[task_kind] then
    return { package_manager(), "run", task_kind }, "Node " .. task_kind
  end

  if task_kind == "build" and file_exists(context.directory, "tsconfig.json") then
    return { executable("tsc"), "--build" }, "TypeScript build"
  elseif task_kind == "test" then
    if
      any_file_exists(
        context.directory,
        { "vitest.config.js", "vitest.config.mjs", "vitest.config.ts", "vitest.workspace.ts" }
      )
    then
      return { executable("vitest"), "run" }, "Vitest"
    elseif
      any_file_exists(
        context.directory,
        { "jest.config.js", "jest.config.mjs", "jest.config.ts", "jest.config.cjs" }
      )
    then
      return { executable("jest") }, "Jest"
    end
  elseif task_kind == "lint" and toolchain.uses_eslint(0) then
    return { executable("eslint"), "." }, "ESLint"
  elseif task_kind == "format" then
    if toolchain.uses_biome(0) then
      return { executable("biome"), "format", "--write", "." }, "Biome format"
    end
    return { executable("prettier"), "--write", "." }, "Prettier format"
  end
end

local function command_for(context, task_kind)
  if context.kind == "node" then
    return node_command(context, task_kind)
  elseif context.kind == "python" then
    local commands = {
      build = { utils.python(0), "-m", "build" },
      test = { utils.python(0), "-m", "pytest" },
      lint = { executable("ruff"), "check", "." },
      format = { executable("ruff"), "format", "." },
    }
    return commands[task_kind], "Python " .. task_kind
  elseif context.kind == "go" then
    local commands = {
      build = { executable("go"), "build", "./..." },
      test = { executable("go"), "test", "./..." },
      lint = { executable("golangci-lint"), "run" },
      format = { executable("go"), "fmt", "./..." },
    }
    return commands[task_kind], "Go " .. task_kind
  elseif context.kind == "make" then
    local command = { executable("make") }
    if task_kind ~= "build" then
      command[#command + 1] = task_kind
    end
    return command, "Make " .. task_kind
  end
end

function M.run_project_task(task_kind)
  local context = project_context()
  local command, name = command_for(context, task_kind)
  if not command then
    vim.notify(
      "No project " .. task_kind .. " command detected",
      vim.log.levels.WARN,
      { title = "Overseer" }
    )
    return
  end
  if vim.fn.executable(command[1]) ~= 1 then
    vim.notify("Executable not found: " .. command[1], vim.log.levels.ERROR, { title = "Overseer" })
    return
  end
  require("overseer")
    .new_task({
      name = name,
      cmd = command,
      cwd = context.directory,
      components = { "default" },
    })
    :start()
end

function M.select_package_script()
  local context = project_context()
  if context.kind ~= "node" then
    vim.notify(
      "No package.json found for the current project",
      vim.log.levels.INFO,
      { title = "Overseer" }
    )
    return
  end
  local package = package_json()
  local scripts = package and package.scripts or {}
  local names = vim.tbl_keys(type(scripts) == "table" and scripts or {})
  table.sort(names)
  if #names == 0 then
    vim.notify("package.json contains no scripts", vim.log.levels.INFO, { title = "Overseer" })
    return
  end

  local manager = package_manager()
  vim.ui.select(names, { prompt = "Package script" }, function(script)
    if script then
      require("overseer")
        .new_task({
          name = "Package: " .. script,
          cmd = { manager, "run", script },
          cwd = context.directory,
          components = { "default" },
        })
        :start()
    end
  end)
end

local function latest_task()
  local tasks = require("overseer").list_tasks({ include_ephemeral = false })
  table.sort(tasks, function(left, right)
    return left.id > right.id
  end)
  return tasks[1]
end

local function with_latest_task(action)
  local task = latest_task()
  if not task then
    vim.notify("No task history", vim.log.levels.INFO, { title = "Overseer" })
    return
  end
  action(task)
end

function M.keys()
  return {
    { "<leader>rr", "<cmd>OverseerRun<cr>", desc = "Run task template" },
    {
      "<leader>rb",
      function()
        M.run_project_task("build")
      end,
      desc = "Run project build",
    },
    {
      "<leader>rt",
      function()
        M.run_project_task("test")
      end,
      desc = "Run project test task",
    },
    {
      "<leader>rl",
      function()
        M.run_project_task("lint")
      end,
      desc = "Run project lint task",
    },
    {
      "<leader>rf",
      function()
        M.run_project_task("format")
      end,
      desc = "Run project format task",
    },
    { "<leader>rp", M.select_package_script, desc = "Run package script" },
    {
      "<leader>rR",
      function()
        with_latest_task(function(task)
          task:restart(true)
        end)
      end,
      desc = "Rerun last task",
    },
    {
      "<leader>ro",
      function()
        with_latest_task(function(task)
          task:open_output("horizontal")
        end)
      end,
      desc = "Open last task output",
    },
    {
      "<leader>rh",
      function()
        require("overseer").toggle({ direction = "bottom", enter = true })
      end,
      desc = "Task history",
    },
    { "<leader>ra", "<cmd>OverseerTaskAction<cr>", desc = "Task action" },
  }
end

return M
