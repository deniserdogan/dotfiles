local function dap_action(method)
  return function()
    require("dap")[method]()
  end
end

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
      },
      "theHamsta/nvim-dap-virtual-text",
    },
    keys = {
      { "<leader>dc", dap_action("continue"), desc = "Debug continue / start" },
      { "<leader>db", dap_action("toggle_breakpoint"), desc = "Toggle breakpoint" },
      {
        "<leader>dB",
        function()
          require("config.dap").conditional_breakpoint()
        end,
        desc = "Conditional breakpoint",
      },
      {
        "<leader>dl",
        function()
          require("config.dap").log_point()
        end,
        desc = "Log point",
      },
      { "<leader>do", dap_action("step_over"), desc = "Step over" },
      { "<leader>di", dap_action("step_into"), desc = "Step into" },
      { "<leader>dO", dap_action("step_out"), desc = "Step out" },
      { "<leader>dC", dap_action("run_to_cursor"), desc = "Run to cursor" },
      { "<leader>dR", dap_action("restart_frame"), desc = "Restart frame" },
      { "<leader>dL", dap_action("run_last"), desc = "Run last debug configuration" },
      { "<leader>dp", dap_action("pause"), desc = "Pause" },
      { "<leader>dt", dap_action("terminate"), desc = "Terminate" },
      {
        "<leader>dr",
        function()
          require("dap").repl.toggle()
        end,
        desc = "Toggle REPL",
      },
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = "Toggle DAP UI",
      },
      {
        "<leader>ds",
        function()
          require("config.dap").scopes()
        end,
        desc = "Inspect scopes",
      },
      {
        "<leader>de",
        function()
          require("config.dap").evaluate()
        end,
        mode = { "n", "x" },
        desc = "Evaluate expression",
      },
      { "<leader>dk", dap_action("up"), desc = "Stack frame up" },
      { "<leader>dj", dap_action("down"), desc = "Stack frame down" },
      {
        "]b",
        function()
          require("config.dap").jump_breakpoint(1)
        end,
        desc = "Next breakpoint",
      },
      {
        "[b",
        function()
          require("config.dap").jump_breakpoint(-1)
        end,
        desc = "Previous breakpoint",
      },
    },
    config = function()
      require("config.dap").setup()
    end,
  },
}
