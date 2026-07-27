local languages = require("config.languages")

local parser_aliases = {
  bash = { "sh", "zsh" },
  git_config = { "gitconfig" },
  javascript = { "javascriptreact" },
  json = { "jsonc" },
  markdown = { "markdown.mdx" },
  tsx = { "typescriptreact" },
}

local reliable_indent = {
  bash = true,
  c = true,
  cpp = true,
  go = true,
  html = true,
  javascript = true,
  json = true,
  json5 = true,
  lua = true,
  tsx = true,
  typescript = true,
}

local function register_aliases()
  for parser, filetypes in pairs(parser_aliases) do
    vim.treesitter.language.register(parser, filetypes)
  end
end

local function configured_filetypes(parsers)
  local filetypes = {}
  for _, parser in ipairs(parsers) do
    for _, filetype in ipairs(vim.treesitter.language.get_filetypes(parser)) do
      filetypes[filetype] = true
    end
  end
  return vim.tbl_keys(filetypes)
end

local function setup_buffer_textobjects(bufnr)
  local map = require("config.utils").map
  local select = require("nvim-treesitter-textobjects.select")
  local move = require("nvim-treesitter-textobjects.move")
  local swap = require("nvim-treesitter-textobjects.swap")
  local opts = { buffer = bufnr }

  local function textobject(lhs, capture, description)
    map({ "x", "o" }, lhs, function()
      select.select_textobject(capture, "textobjects")
    end, description, opts)
  end

  textobject("af", "@function.outer", "Around function")
  textobject("if", "@function.inner", "Inside function")
  textobject("ac", "@class.outer", "Around class")
  textobject("ic", "@class.inner", "Inside class")
  textobject("aa", "@parameter.outer", "Around argument")
  textobject("ia", "@parameter.inner", "Inside argument")

  map({ "n", "x", "o" }, "]m", function()
    move.goto_next_start("@function.outer", "textobjects")
  end, "Next function start", opts)
  map({ "n", "x", "o" }, "[m", function()
    move.goto_previous_start("@function.outer", "textobjects")
  end, "Previous function start", opts)
  map({ "n", "x", "o" }, "]M", function()
    move.goto_next_end("@function.outer", "textobjects")
  end, "Next function end", opts)
  map({ "n", "x", "o" }, "[M", function()
    move.goto_previous_end("@function.outer", "textobjects")
  end, "Previous function end", opts)
  map({ "n", "x", "o" }, "]]", function()
    move.goto_next_start("@class.outer", "textobjects")
  end, "Next class start", opts)
  map({ "n", "x", "o" }, "[[", function()
    move.goto_previous_start("@class.outer", "textobjects")
  end, "Previous class start", opts)

  map("n", "<leader>cn", function()
    swap.swap_next("@parameter.inner")
  end, "Swap with next argument", opts)
  map("n", "<leader>cN", function()
    swap.swap_previous("@parameter.inner")
  end, "Swap with previous argument", opts)
end

local function enable_for_buffer(event)
  if require("config.utils").is_large_file(event.buf) then
    return
  end

  local language = vim.treesitter.language.get_lang(vim.bo[event.buf].filetype)
  if not language then
    return
  end

  local loaded, error_message = vim.treesitter.language.add(language)
  if not loaded then
    -- Missing parsers are expected while the asynchronous installer runs;
    -- incompatible or corrupt parsers should remain visible to the user.
    if error_message and not error_message:match('^No parser for language "') then
      vim.notify(error_message, vim.log.levels.ERROR, { title = "Treesitter" })
    end
    return
  end

  vim.treesitter.start(event.buf, language)
  for _, winid in ipairs(vim.fn.win_findbuf(event.buf)) do
    vim.api.nvim_win_call(winid, function()
      vim.wo.foldmethod = "expr"
      vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    end)
  end

  if reliable_indent[language] then
    vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end

  local map = require("config.utils").map
  local opts = { buffer = event.buf }
  map({ "n", "x" }, "<C-Space>", function()
    vim.treesitter.select("parent")
  end, "Select parent syntax node", opts)
  map("x", "<BS>", function()
    vim.treesitter.select("child")
  end, "Select child syntax node", opts)
  setup_buffer_textobjects(event.buf)
end

local function setup_treesitter()
  register_aliases()

  local parsers = languages.treesitter_parsers()
  require("nvim-treesitter").install(languages.treesitter_packages())

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
    pattern = configured_filetypes(parsers),
    callback = enable_for_buffer,
    desc = "Enable native Treesitter features",
  })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = "user_treesitter",
    callback = function(event)
      if vim.list_contains(configured_filetypes(parsers), vim.bo[event.buf].filetype) then
        enable_for_buffer(event)
      end
    end,
    desc = "Apply Treesitter window-local folds",
  })
end

local function setup_textobjects()
  require("nvim-treesitter-textobjects").setup({
    select = {
      lookahead = true,
      selection_modes = {
        ["@parameter.outer"] = "v",
        ["@function.outer"] = "V",
        ["@class.outer"] = "V",
      },
    },
    move = {
      set_jumps = true,
    },
  })
end

return {
  {
    "neovim-treesitter/nvim-treesitter",
    dependencies = { "neovim-treesitter/treesitter-parser-registry" },
    lazy = false,
    build = ":TSUpdate",
    config = setup_treesitter,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    lazy = false,
    dependencies = { "neovim-treesitter/nvim-treesitter" },
    config = setup_textobjects,
  },
}
