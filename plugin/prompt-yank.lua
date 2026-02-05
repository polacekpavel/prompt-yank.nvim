if vim.g.loaded_prompt_yank == 1 then
  return
end
vim.g.loaded_prompt_yank = 1

vim.api.nvim_create_user_command("PromptYank", function(opts)
  require("prompt-yank.command").run(opts)
end, {
  nargs = "*",
  range = true,
  desc = "Copy code with context for LLM prompts",
  complete = function(arg_lead, cmd_line, cursor_pos)
    return require("prompt-yank.command").complete(arg_lead, cmd_line, cursor_pos)
  end,
})

