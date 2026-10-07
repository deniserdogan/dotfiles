local M = {}

M.project_markers = {
  ".git",
  "go.work",
  "go.mod",
  "pyproject.toml",
  "basedpyrightconfig.json",
  "pyrightconfig.json",
  "package.json",
  "biome.json",
  "biome.jsonc",
  "Cargo.toml",
  "Makefile",
}

local function buffer_path(bufnr)
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  if
    name == ""
    or vim.bo[bufnr].buftype ~= ""
    or name:match("^%a[%w+.-]*://")
    or name:match("^term://")
  then
    return vim.uv.cwd()
  end
  return vim.fs.normalize(name)
end

local function start_directory(bufnr)
  local path = buffer_path(bufnr)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == "directory" and path or vim.fs.dirname(path)
end

function M.buffer_path(bufnr)
  return buffer_path(bufnr)
end

function M.buffer_directory(bufnr)
  return start_directory(bufnr)
end

function M.find(markers, bufnr)
  local matches = vim.fs.find(markers, {
    path = start_directory(bufnr),
    upward = true,
    stop = vim.uv.os_homedir(),
    limit = 1,
  })
  return matches[1] and vim.fs.dirname(matches[1]) or nil
end

function M.git(bufnr)
  return M.find({ ".git" }, bufnr)
end

function M.project(bufnr)
  bufnr = bufnr or 0
  if vim.b[bufnr].project_root and vim.b[bufnr].project_root ~= "" then
    return vim.b[bufnr].project_root
  end

  return M.git(bufnr) or M.find(M.project_markers, bufnr) or start_directory(bufnr)
end

function M.tool(bufnr, markers)
  return M.find(markers, bufnr) or M.project(bufnr)
end

function M.workspace(bufnr, marker_tiers)
  for _, markers in ipairs(marker_tiers) do
    local found = M.find(type(markers) == "table" and markers or { markers }, bufnr)
    if found then
      return found
    end
  end
  return M.project(bufnr)
end

function M.relative(path, bufnr)
  return vim.fs.relpath(M.project(bufnr), path) or path
end

return M
