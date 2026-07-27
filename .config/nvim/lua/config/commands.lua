local M = {}

local function command(name, callback, opts)
  vim.api.nvim_create_user_command(name, callback, opts or {})
end

function M.setup()
  command("PluginSync", "Lazy sync", { desc = "Install, clean, and update plugins" })
  command("PluginUpdate", "Lazy update", { desc = "Update plugins and lock file" })
  command("PluginLockRegenerate", function()
    local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
    if vim.uv.fs_stat(lockfile) then
      vim.fn.delete(lockfile)
    end
    vim.cmd("Lazy sync")
  end, { desc = "Regenerate lazy-lock.json from installed plugin heads" })

  command("ConfigHealth", "checkhealth config", { desc = "Check this configuration" })
  command("ConfigRoot", function()
    vim.notify(require("config.root").project())
  end, { desc = "Show the detected project root" })
  command("FormatInfo", "ConformInfo", { desc = "Inspect active formatters" })
  command("TreesitterUpdate", "TSUpdate", { desc = "Update Treesitter parsers" })

  command("StartupProfile", function(opts)
    local output = opts.args ~= "" and vim.fs.normalize(opts.args)
      or (vim.fn.stdpath("cache") .. "/startuptime.log")
    vim.system(
      { vim.v.progpath, "--headless", "--startuptime", output, "+qa" },
      { text = true },
      function(result)
        vim.schedule(function()
          if result.code == 0 then
            vim.notify("Startup profile written to " .. output)
          else
            vim.notify(result.stderr, vim.log.levels.ERROR, { title = "StartupProfile" })
          end
        end)
      end
    )
  end, {
    nargs = "?",
    complete = "file",
    desc = "Profile a clean Neovim startup",
  })
end

return M
