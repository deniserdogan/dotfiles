local M = {}

local root = require("config.root")

local function read_json(path)
  if not vim.uv.fs_stat(path) then
    return nil
  end

  local lines = vim.fn.readfile(path)
  local ok, value = pcall(vim.json.decode, table.concat(lines, "\n"))
  return ok and type(value) == "table" and value or nil
end

function M.node_root(bufnr)
  return root.tool(bufnr, {
    "biome.json",
    "biome.jsonc",
    "package.json",
    "pnpm-lock.yaml",
    "yarn.lock",
    "bun.lock",
    "bun.lockb",
    "package-lock.json",
  })
end

function M.package_json(bufnr)
  local directory = root.find({ "package.json" }, bufnr)
  return directory and read_json(directory .. "/package.json") or nil
end

local function package_has(package, names)
  if not package then
    return false
  end
  for _, section in ipairs({
    "dependencies",
    "devDependencies",
    "peerDependencies",
    "optionalDependencies",
  }) do
    for _, name in ipairs(names) do
      if type(package[section]) == "table" and package[section][name] then
        return true
      end
    end
  end
  return false
end

function M.uses_biome(bufnr)
  if root.find({ "biome.json", "biome.jsonc" }, bufnr) then
    return true
  end
  return package_has(M.package_json(bufnr), { "@biomejs/biome", "rome" })
end

function M.uses_prettier(bufnr)
  if
    root.find({
      ".prettierrc",
      ".prettierrc.json",
      ".prettierrc.json5",
      ".prettierrc.js",
      ".prettierrc.cjs",
      ".prettierrc.mjs",
      "prettier.config.js",
      "prettier.config.cjs",
      "prettier.config.mjs",
    }, bufnr)
  then
    return true
  end
  local package = M.package_json(bufnr)
  return package_has(package, { "prettier", "prettierd" }) or (package and package.prettier ~= nil)
end

function M.uses_eslint(bufnr)
  if
    root.find({
      "eslint.config.js",
      "eslint.config.mjs",
      "eslint.config.cjs",
      "eslint.config.ts",
      ".eslintrc",
      ".eslintrc.json",
      ".eslintrc.js",
      ".eslintrc.cjs",
      ".eslintrc.yml",
      ".eslintrc.yaml",
    }, bufnr)
  then
    return true
  end
  return package_has(M.package_json(bufnr), { "eslint", "@eslint/js" })
end

function M.uses_golangci(bufnr)
  return root.find({
    ".golangci.yml",
    ".golangci.yaml",
    ".golangci.toml",
    ".golangci.json",
  }, bufnr) ~= nil
end

function M.package_manager(bufnr)
  local directory = M.node_root(bufnr)
  local candidates = {
    { "bun.lock", "bun" },
    { "bun.lockb", "bun" },
    { "pnpm-lock.yaml", "pnpm" },
    { "yarn.lock", "yarn" },
    { "package-lock.json", "npm" },
  }
  for _, candidate in ipairs(candidates) do
    if vim.uv.fs_stat(directory .. "/" .. candidate[1]) then
      return candidate[2], directory
    end
  end
  return "npm", directory
end

function M.formatter_root(bufnr)
  if M.uses_biome(bufnr) then
    return root.tool(bufnr, { "biome.json", "biome.jsonc", "package.json" })
  end
  return root.tool(bufnr, {
    ".prettierrc",
    ".prettierrc.json",
    "prettier.config.js",
    "prettier.config.mjs",
    "package.json",
  })
end

return M
