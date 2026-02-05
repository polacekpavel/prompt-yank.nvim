return {
  "polacekpavel/prompt-yank.nvim",
  opts = {},
  config = function(_, opts)
    require("prompt-yank").setup(opts)
  end,
}
