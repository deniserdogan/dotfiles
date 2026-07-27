return {
  {
    "stevearc/overseer.nvim",
    cmd = {
      "OverseerOpen",
      "OverseerClose",
      "OverseerToggle",
      "OverseerRun",
      "OverseerShell",
      "OverseerTaskAction",
    },
    keys = require("config.tasks").keys(),
    opts = {
      dap = true,
      output = {
        preserve_output = true,
        use_terminal = true,
      },
      task_list = {
        direction = "bottom",
        max_height = 20,
        min_height = 8,
      },
      form = { border = "single" },
      task_win = { border = "single" },
      component_aliases = {
        default = {
          "on_exit_set_status",
          "on_complete_notify",
        },
      },
    },
  },
}
