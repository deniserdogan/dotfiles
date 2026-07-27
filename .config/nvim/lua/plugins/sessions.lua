local function load_project_session()
  local project = require("config.root").project(0)
  vim.g.persistence_project_root = project
  vim.fn.chdir(project)
  require("persistence").load()
end

local function setup_project_tracking()
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("user_project_sessions", { clear = true }),
    callback = function(event)
      if vim.bo[event.buf].buftype == "" and vim.api.nvim_buf_get_name(event.buf) ~= "" then
        vim.g.persistence_project_root = require("config.root").project(event.buf)
      end
    end,
    desc = "Track the project owning the active session",
  })
end

local function make_save_project_scoped(persistence)
  local save = persistence.save
  persistence.save = function()
    local previous_directory = vim.fn.getcwd()
    local project = vim.g.persistence_project_root or require("config.root").project(0)
    local ignored_buffers = {}

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(bufnr)
      local is_other_project = vim.bo[bufnr].buftype == ""
        and name ~= ""
        and require("config.root").project(bufnr) ~= project
      if (vim.b[bufnr].session_ignore or is_other_project) and vim.bo[bufnr].buflisted then
        vim.bo[bufnr].buflisted = false
        table.insert(ignored_buffers, bufnr)
      end
    end

    vim.fn.chdir(project)
    local ok, err = xpcall(save, debug.traceback)
    vim.fn.chdir(previous_directory)
    for _, bufnr in ipairs(ignored_buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.bo[bufnr].buflisted = true
      end
    end
    if not ok then
      error(err)
    end
  end
end

return {
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    init = function()
      -- Terminal and blank entries are deliberately omitted; the transient DAP,
      -- Neotest, and task-runner buffers are unlisted and stay out of sessions.
      vim.opt.sessionoptions = {
        "buffers",
        "curdir",
        "folds",
        "globals",
        "help",
        "localoptions",
        "skiprtp",
        "tabpages",
        "winsize",
      }
      setup_project_tracking()
    end,
    opts = {
      branch = true,
      need = 1,
    },
    config = function(_, opts)
      local persistence = require("persistence")
      persistence.setup(opts)
      make_save_project_scoped(persistence)
    end,
    keys = {
      { "<leader>pr", load_project_session, desc = "Restore project session" },
      {
        "<leader>pc",
        function()
          require("persistence").load()
        end,
        desc = "Restore current-directory session",
      },
      {
        "<leader>pl",
        function()
          require("persistence").load({ last = true })
        end,
        desc = "Restore last session",
      },
      {
        "<leader>ps",
        function()
          require("persistence").select()
        end,
        desc = "Select session",
      },
      {
        "<leader>pw",
        function()
          require("persistence").save()
        end,
        desc = "Save session",
      },
      {
        "<leader>pd",
        function()
          require("persistence").stop()
        end,
        desc = "Stop session persistence",
      },
    },
  },
}
