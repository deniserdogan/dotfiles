return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "Lint", "LintInfo", "EslintFix" },
    keys = {
      {
        "<leader>cl",
        function()
          require("config.lint").run(0)
        end,
        desc = "Lint buffer",
      },
      {
        "<leader>cE",
        function()
          require("config.lint").eslint_fix(0)
        end,
        desc = "ESLint fix file",
      },
    },
    config = function()
      require("config.lint").setup()
    end,
  },
}
