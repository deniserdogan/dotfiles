return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo", "Format", "FormatDisable", "FormatEnable" },
    keys = {
      {
        "<leader>cf",
        function()
          require("config.format").format(0)
        end,
        mode = { "n", "x" },
        desc = "Format buffer",
      },
    },
    opts = function()
      return require("config.format").options()
    end,
    config = function(_, opts)
      require("conform").setup(opts)
      require("config.format").setup_commands()
    end,
  },
}
