local function test_action(callback)
  return function()
    if require("config.utils").is_large_file(0) then
      vim.notify(
        "Test discovery is disabled for large files",
        vim.log.levels.INFO,
        { title = "Neotest" }
      )
      return
    end
    callback(require("neotest"))
  end
end

local vitest_config_files = {
  "vitest.config.js",
  "vitest.config.mjs",
  "vitest.config.cjs",
  "vitest.config.ts",
  "vitest.config.mts",
  "vitest.config.cts",
  "vitest.workspace.js",
  "vitest.workspace.ts",
}

local jest_config_files = {
  "jest.config.js",
  "jest.config.mjs",
  "jest.config.cjs",
  "jest.config.ts",
  "jest.config.json",
}

local function has_any_file(directory, names)
  for _, name in ipairs(names) do
    if vim.uv.fs_stat(vim.fs.joinpath(directory, name)) then
      return true
    end
  end
  return false
end

local function read_package_json(path)
  local handle = vim.uv.fs_open(path, "r", 438)
  if not handle then
    return nil
  end
  local stat = vim.uv.fs_fstat(handle)
  local content = stat and vim.uv.fs_read(handle, stat.size, 0) or nil
  vim.uv.fs_close(handle)
  if not content then
    return nil
  end
  local decoded, package = pcall(vim.json.decode, content)
  return decoded and package or nil
end

local function package_runner(package)
  if type(package) ~= "table" then
    return nil
  end

  local override = package.neotestRunner
    or (type(package.neotest) == "table" and package.neotest.runner)
  if override == "vitest" or override == "jest" then
    return override
  end

  local scripts_table = type(package.scripts) == "table" and package.scripts or {}
  local scripts = table.concat(vim.tbl_values(scripts_table), " "):lower()
  local script_vitest = scripts:find("vitest", 1, true) ~= nil
  local script_jest = scripts:find("jest", 1, true) ~= nil
  if script_vitest ~= script_jest then
    return script_vitest and "vitest" or "jest"
  end

  local dependencies = {}
  for _, section in ipairs({ "dependencies", "devDependencies", "peerDependencies" }) do
    if type(package[section]) == "table" then
      dependencies = vim.tbl_extend("force", dependencies, package[section])
    end
  end
  local has_vitest = dependencies.vitest ~= nil or dependencies["@vitest/ui"] ~= nil
  local has_jest = dependencies.jest ~= nil or dependencies["@jest/core"] ~= nil
  if has_vitest ~= has_jest then
    return has_vitest and "vitest" or "jest"
  end
  if has_vitest and has_jest then
    -- Mixed packages should set package.json's `neotestRunner`; Vitest is the
    -- deterministic default until they do.
    return "vitest"
  end
end

local function javascript_runner(file_path)
  if not file_path then
    return nil
  end

  local global_override = vim.g.neotest_javascript_runner
  if global_override == "vitest" or global_override == "jest" then
    return global_override
  end

  local stat = vim.uv.fs_stat(file_path)
  local directory = stat and stat.type == "directory" and file_path or vim.fs.dirname(file_path)
  local boundary = vim.fs.root(file_path, ".git")

  while directory do
    local package = read_package_json(vim.fs.joinpath(directory, "package.json"))
    local package_override = package
      and (package.neotestRunner or (type(package.neotest) == "table" and package.neotest.runner))
    if package_override == "vitest" or package_override == "jest" then
      return package_override
    end

    local has_vitest_config = has_any_file(directory, vitest_config_files)
    local has_jest_config = has_any_file(directory, jest_config_files)
    if has_vitest_config ~= has_jest_config then
      return has_vitest_config and "vitest" or "jest"
    end
    if has_vitest_config and has_jest_config then
      return "vitest"
    end

    local package_choice = package_runner(package)
    if package_choice then
      return package_choice
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
end

local function javascript_test_file(file_path)
  if not file_path or not file_path:match("%.[cm]?[jt]sx?$") then
    return false
  end
  return file_path:match("[/\\]__tests__[/\\]") ~= nil
    or file_path:match("%.test%.[cm]?[jt]sx?$") ~= nil
    or file_path:match("%.spec%.[cm]?[jt]sx?$") ~= nil
end

local function run_all_project_tests(neotest)
  local project = vim.fs.normalize(require("config.root").project(0))
  local prefix = project .. "/"
  local count = 0

  for _, adapter_id in ipairs(neotest.state.adapter_ids()) do
    local positions = neotest.state.positions(adapter_id)
    local suite_path = positions and positions:data().path
    if suite_path then
      suite_path = vim.fs.normalize(suite_path)
      if suite_path == project or vim.startswith(suite_path, prefix) then
        neotest.run.run({ suite = true, adapter = adapter_id })
        count = count + 1
      end
    end
  end

  if count == 0 then
    vim.notify(
      "No discovered test suites belong to " .. project,
      vim.log.levels.INFO,
      { title = "Neotest" }
    )
  end
end

return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "neovim-treesitter/nvim-treesitter",
      "mfussenegger/nvim-dap",
      "nvim-neotest/neotest-python",
      "fredrikaverpil/neotest-golang",
      "marilari88/neotest-vitest",
      "nvim-neotest/neotest-jest",
    },
    keys = {
      {
        "<leader>tn",
        test_action(function(neotest)
          neotest.run.run()
        end),
        desc = "Run nearest test",
      },
      {
        "<leader>tf",
        test_action(function(neotest)
          neotest.run.run(vim.fn.expand("%:p"))
        end),
        desc = "Run test file",
      },
      {
        "<leader>tp",
        test_action(function(neotest)
          neotest.run.run(vim.fn.expand("%:p:h"))
        end),
        desc = "Run test package / directory",
      },
      {
        "<leader>ta",
        test_action(run_all_project_tests),
        desc = "Run all project tests",
      },
      {
        "<leader>tl",
        test_action(function(neotest)
          neotest.run.run_last()
        end),
        desc = "Run last test",
      },
      {
        "<leader>tD",
        test_action(function(neotest)
          neotest.run.run({ strategy = "dap" })
        end),
        desc = "Debug nearest test",
      },
      {
        "<leader>to",
        test_action(function(neotest)
          neotest.output.open({ enter = true, last_run = true })
        end),
        desc = "Open test output",
      },
      {
        "<leader>tO",
        test_action(function(neotest)
          neotest.output_panel.toggle()
        end),
        desc = "Toggle test output panel",
      },
      {
        "<leader>tu",
        test_action(function(neotest)
          neotest.summary.toggle()
        end),
        desc = "Toggle test summary",
      },
      {
        "<leader>tS",
        test_action(function(neotest)
          neotest.run.stop({ interactive = true })
        end),
        desc = "Stop test",
      },
      {
        "]T",
        test_action(function(neotest)
          neotest.jump.next({ status = "failed" })
          vim.cmd.normal({ "zz", bang = true })
        end),
        desc = "Next failed test",
      },
      {
        "[T",
        test_action(function(neotest)
          neotest.jump.prev({ status = "failed" })
          vim.cmd.normal({ "zz", bang = true })
        end),
        desc = "Previous failed test",
      },
    },
    config = function()
      local languages = require("config.languages")
      local utils = require("config.utils")
      local enabled = {}
      for _, definition in pairs(languages.all()) do
        if definition.test_adapter then
          enabled[definition.test_adapter] = true
        end
      end

      local adapters = {}
      if enabled.python then
        adapters[#adapters + 1] = require("neotest-python")({
          runner = "pytest",
          python = function(root)
            return utils.python_for_root(root)
          end,
          dap = { justMyCode = true },
        })
      end
      if enabled.go then
        local gotestsum = utils.executable("gotestsum", 0)
        adapters[#adapters + 1] = require("neotest-golang")({
          runner = vim.fn.executable(gotestsum) == 1 and "gotestsum" or "go",
          dap_mode = "manual",
          dap_manual_config = function()
            return {
              name = "Debug Go test",
              type = "go",
              request = "launch",
              mode = "test",
              cwd = require("config.root").tool(0, { "go.work", "go.mod" }),
            }
          end,
          filter_dir_patterns = {
            "**/.git",
            "**/node_modules",
            "**/.venv",
            "**/venv",
            "**/vendor",
            "**/dist",
            "**/build",
          },
        })
      end
      if enabled.javascript then
        local vitest = require("neotest-vitest")({
          filter_dir = function(name)
            return not vim.list_contains(
              { ".git", "node_modules", "dist", "build", "coverage" },
              name
            )
          end,
        })
        -- Override after adapter construction: neotest-vitest otherwise wraps a
        -- custom matcher with Git-root dependency detection, which lets a root
        -- Vitest dependency incorrectly claim Jest packages in monorepos.
        vitest.is_test_file = function(file_path)
          return javascript_test_file(file_path) and javascript_runner(file_path) == "vitest"
        end
        adapters[#adapters + 1] = vitest
        adapters[#adapters + 1] = require("neotest-jest")({
          isTestFile = function(file_path)
            return javascript_test_file(file_path) and javascript_runner(file_path) == "jest"
          end,
        })
      end

      require("neotest").setup({
        adapters = adapters,
        diagnostic = {
          enabled = true,
          severity = vim.diagnostic.severity.ERROR,
        },
        discovery = {
          concurrent = 4,
          enabled = true,
          filter_dir = function(name)
            return not vim.list_contains(
              { ".git", "node_modules", ".venv", "venv", "vendor", "dist", "build", "coverage" },
              name
            )
          end,
        },
        floating = {
          border = "single",
          max_height = 0.7,
          max_width = 0.8,
          options = { winblend = 0 },
        },
        output = {
          enabled = true,
          open_on_run = false,
        },
        output_panel = {
          enabled = true,
          open = "botright split | resize 15",
        },
        quickfix = {
          enabled = true,
          open = false,
        },
        running = { concurrent = true },
        status = {
          enabled = true,
          signs = true,
          virtual_text = false,
        },
        summary = {
          animated = false,
          enabled = true,
          expand_errors = true,
          follow = true,
          open = "botright vsplit | vertical resize 45",
        },
      })
    end,
  },
}
