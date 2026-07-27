local M = {}

function M.augroup(name)
  return vim.api.nvim_create_augroup("user_" .. name, { clear = true })
end

function M.map(mode, lhs, rhs, desc, opts)
  opts = vim.tbl_extend("force", { silent = true, desc = desc }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

function M.is_large_file(bufnr)
  bufnr = bufnr or 0
  if vim.b[bufnr].bigfile or vim.bo[bufnr].filetype == "bigfile" then
    return true
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  local stat = name ~= "" and vim.uv.fs_stat(name) or nil
  return stat ~= nil and stat.size > 2 * 1024 * 1024
end

function M.executable(name, bufnr)
  local roots = require("config.root")
  local project = roots.project(bufnr)
  local node_root = roots.find({ "package.json" }, bufnr) or project
  local python_root = roots.find({
    "pyproject.toml",
    "basedpyrightconfig.json",
    "pyrightconfig.json",
    "Pipfile",
  }, bufnr) or project
  local candidates = {
    node_root .. "/node_modules/.bin/" .. name,
    python_root .. "/.venv/bin/" .. name,
    python_root .. "/venv/bin/" .. name,
    project .. "/node_modules/.bin/" .. name,
    project .. "/.venv/bin/" .. name,
    project .. "/venv/bin/" .. name,
  }

  for _, path in ipairs(candidates) do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end

  local path = vim.fn.exepath(name)
  return path ~= "" and path or name
end

local python_cache = {}

local function command_output(command, cwd)
  local result = vim.system(command, { cwd = cwd, text = true, timeout = 2000 }):wait()
  if result.code == 0 then
    return vim.trim(result.stdout)
  end
end

function M.python_for_root(root)
  root = vim.fs.normalize(root)
  if vim.uv.fs_stat(root) and vim.uv.fs_stat(root).type ~= "directory" then
    root = vim.fs.dirname(root)
  end
  if python_cache[root] and vim.fn.executable(python_cache[root]) == 1 then
    return python_cache[root]
  end

  local candidates = {}
  if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
    table.insert(candidates, vim.env.VIRTUAL_ENV .. "/bin/python")
  end
  vim.list_extend(candidates, {
    root .. "/.venv/bin/python",
    root .. "/venv/bin/python",
  })

  for _, path in ipairs(candidates) do
    if vim.fn.executable(path) == 1 then
      python_cache[root] = path
      return path
    end
  end

  if vim.uv.fs_stat(root .. "/pyproject.toml") and vim.fn.executable("poetry") == 1 then
    local poetry_env = command_output({ "poetry", "env", "info", "-p" }, root)
    if poetry_env and vim.fn.executable(poetry_env .. "/bin/python") == 1 then
      python_cache[root] = poetry_env .. "/bin/python"
      return python_cache[root]
    end
  end

  if vim.uv.fs_stat(root .. "/Pipfile") and vim.fn.executable("pipenv") == 1 then
    local pipenv = command_output({ "pipenv", "--venv" }, root)
    if pipenv and vim.fn.executable(pipenv .. "/bin/python") == 1 then
      python_cache[root] = pipenv .. "/bin/python"
      return python_cache[root]
    end
  end

  if vim.fn.executable("uv") == 1 and vim.uv.fs_stat(root .. "/pyproject.toml") then
    local uv_python = command_output({ "uv", "python", "find" }, root)
    if uv_python and vim.fn.executable(uv_python) == 1 then
      python_cache[root] = uv_python
      return uv_python
    end
  end

  python_cache[root] = vim.fn.exepath("python3")
  return python_cache[root] ~= "" and python_cache[root] or "python3"
end

function M.python(bufnr)
  local root = require("config.root").tool(bufnr, {
    "pyproject.toml",
    "basedpyrightconfig.json",
    "pyrightconfig.json",
    "Pipfile",
  })
  return M.python_for_root(root)
end

function M.has_file(markers, bufnr)
  return require("config.root").find(markers, bufnr) ~= nil
end

return M
