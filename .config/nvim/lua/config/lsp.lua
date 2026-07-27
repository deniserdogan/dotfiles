local M = {}

local document_highlight_group

local function supports(bufnr, method)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method(method, bufnr) then
      return true
    end
  end
  return false
end

local function toggle_inlay_hints(bufnr)
  if not supports(bufnr, "textDocument/inlayHint") then
    vim.notify("No attached LSP server provides inlay hints", vim.log.levels.INFO)
    return
  end

  local filter = { bufnr = bufnr }
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
end

local function toggle_semantic_tokens(bufnr)
  local has_tokens = supports(bufnr, "textDocument/semanticTokens/full")
    or supports(bufnr, "textDocument/semanticTokens/range")
  if not has_tokens then
    vim.notify("No attached LSP server provides semantic tokens", vim.log.levels.INFO)
    return
  end

  local filter = { bufnr = bufnr }
  vim.lsp.semantic_tokens.enable(not vim.lsp.semantic_tokens.is_enabled(filter), filter)
end

local function configure_document_highlight(client, bufnr)
  if not client:supports_method("textDocument/documentHighlight", bufnr) then
    return
  end

  vim.api.nvim_clear_autocmds({ group = document_highlight_group, buffer = bufnr })
  vim.api.nvim_create_autocmd("CursorHold", {
    group = document_highlight_group,
    buffer = bufnr,
    callback = vim.lsp.buf.document_highlight,
    desc = "Highlight LSP references under the cursor",
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
    group = document_highlight_group,
    buffer = bufnr,
    callback = vim.lsp.buf.clear_references,
    desc = "Clear LSP reference highlights",
  })
end

local function workspace_folders()
  local folders = vim.lsp.buf.list_workspace_folders()
  vim.notify(
    #folders > 0 and table.concat(folders, "\n") or "No LSP workspace folders",
    vim.log.levels.INFO,
    { title = "LSP workspaces" }
  )
end

local function attach(client, bufnr)
  local utils = require("config.utils")
  if utils.is_large_file(bufnr) then
    -- Detach this buffer only; the client may still serve other project buffers.
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.lsp.buf_detach_client(bufnr, client.id)
      end
    end)
    return
  end

  local map = utils.map
  local opts = { buffer = bufnr }

  map("n", "gd", vim.lsp.buf.definition, "LSP definition", opts)
  map("n", "gD", vim.lsp.buf.declaration, "LSP declaration", opts)
  map("n", "gri", vim.lsp.buf.implementation, "LSP implementation", opts)
  map("n", "grr", vim.lsp.buf.references, "LSP references", opts)
  map("n", "grt", vim.lsp.buf.type_definition, "LSP type definition", opts)
  map("n", "K", vim.lsp.buf.hover, "LSP hover", opts)
  map("n", "gK", vim.lsp.buf.signature_help, "LSP signature help", opts)

  map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action", opts)
  map("n", "<leader>cA", function()
    vim.lsp.buf.code_action({ context = { only = { "source" } } })
  end, "Source action", opts)
  map("n", "<leader>cO", function()
    vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } }, apply = true })
  end, "Organize imports", opts)
  map("n", "<leader>cF", function()
    vim.lsp.buf.code_action({ context = { only = { "source.fixAll" } }, apply = true })
  end, "Fix all", opts)
  map("n", "<leader>cU", function()
    vim.lsp.buf.code_action({ context = { only = { "source.removeUnused" } }, apply = true })
  end, "Remove unused imports", opts)
  map("n", "<leader>cr", vim.lsp.buf.rename, "Rename symbol", opts)
  map("n", "<leader>cs", vim.lsp.buf.document_symbol, "Document symbols", opts)
  map("n", "<leader>cS", vim.lsp.buf.workspace_symbol, "Workspace symbols", opts)
  map("n", "<leader>ci", vim.lsp.buf.incoming_calls, "Incoming calls", opts)
  map("n", "<leader>co", vim.lsp.buf.outgoing_calls, "Outgoing calls", opts)
  map("n", "<leader>ck", vim.lsp.buf.signature_help, "Signature help", opts)
  map("n", "<leader>cwa", vim.lsp.buf.add_workspace_folder, "Add workspace folder", opts)
  map("n", "<leader>cwr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder", opts)
  map("n", "<leader>cwl", workspace_folders, "List workspace folders", opts)
  map("n", "<leader>th", function()
    toggle_inlay_hints(bufnr)
  end, "Toggle inlay hints", opts)
  map("n", "<leader>ts", function()
    toggle_semantic_tokens(bufnr)
  end, "Toggle semantic tokens", opts)

  configure_document_highlight(client, bufnr)

  if
    require("config.languages").inlay_hints(vim.bo[bufnr].filetype)
    and client:supports_method("textDocument/inlayHint", bufnr)
  then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end
end

local function setup_autocmds()
  local attach_group = vim.api.nvim_create_augroup("user_lsp_attach", { clear = true })
  document_highlight_group =
    vim.api.nvim_create_augroup("user_lsp_document_highlight", { clear = true })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = attach_group,
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client then
        attach(client, event.buf)
      end
    end,
    desc = "Configure buffer-local LSP behavior",
  })

  vim.api.nvim_create_autocmd("LspDetach", {
    group = attach_group,
    callback = function(event)
      if vim.api.nvim_buf_is_valid(event.buf) then
        vim.api.nvim_buf_call(event.buf, vim.lsp.buf.clear_references)
      end
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(event.buf) then
          return
        end

        for _, client in ipairs(vim.lsp.get_clients({ bufnr = event.buf })) do
          if
            client.id ~= event.data.client_id
            and client:supports_method("textDocument/documentHighlight", event.buf)
          then
            return
          end
        end
        vim.api.nvim_clear_autocmds({ group = document_highlight_group, buffer = event.buf })
      end)
    end,
    desc = "Clean up detached LSP state",
  })

  vim.api.nvim_create_autocmd("LspProgress", {
    group = attach_group,
    callback = function(event)
      local params = event.data.params
      local value = params and params.value
      if type(value) ~= "table" then
        return
      end

      local client = vim.lsp.get_client_by_id(event.data.client_id)
      vim.api.nvim_echo({ { value.message or (value.kind == "end" and "done" or "") } }, false, {
        id = ("lsp.%d.%s"):format(event.data.client_id, tostring(params.token)),
        kind = "progress",
        source = "vim.lsp",
        title = value.title or (client and client.name) or "LSP",
        status = value.kind == "end" and "success" or "running",
        percent = value.percentage,
      })
    end,
    desc = "Report native LSP work progress",
  })
end

local function setup_commands()
  vim.api.nvim_create_user_command("LspClients", function()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    local details = vim.tbl_map(function(client)
      return {
        id = client.id,
        name = client.name,
        root_dir = client.config.root_dir,
        workspace_folders = client.workspace_folders,
      }
    end, clients)
    vim.print(details)
  end, { desc = "Inspect LSP clients attached to the current buffer" })

  vim.api.nvim_create_user_command("LspConfigs", function()
    vim.print(vim.lsp.get_configs({ enabled = true }))
  end, { desc = "Inspect enabled native LSP configurations" })

  if vim.fn.exists(":LspRestart") == 0 then
    vim.api.nvim_create_user_command("LspRestart", function()
      vim.cmd("lsp restart")
    end, { desc = "Restart attached LSP clients" })
  end

  local map = require("config.utils").map
  map("n", "<leader>cI", "<cmd>LspClients<cr>", "Inspect LSP clients")
  map("n", "<leader>cR", "<cmd>LspRestart<cr>", "Restart LSP clients")
end

function M.setup()
  if M.did_setup then
    return
  end
  M.did_setup = true

  setup_autocmds()
  setup_commands()

  local capabilities = require("blink.cmp").get_lsp_capabilities({
    workspace = {
      -- Native recursive watchers can exhaust macOS file descriptors in large
      -- monorepos; servers still receive open/change/save notifications.
      didChangeWatchedFiles = {
        dynamicRegistration = false,
      },
      fileOperations = {
        didRename = true,
        willRename = true,
      },
    },
  })

  -- The wildcard is merged into every definition supplied by nvim-lspconfig,
  -- while after/lsp/*.lua retains the higher-priority server-specific policy.
  vim.lsp.config("*", {
    capabilities = capabilities,
  })
  vim.lsp.enable(require("config.languages").lsp_servers())
end

return M
