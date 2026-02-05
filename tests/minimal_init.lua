local cwd = vim.fn.getcwd()
vim.opt.runtimepath:prepend(cwd)

local plenary_env = vim.env.PLENARY_DIR
local plenary_path = (plenary_env and plenary_env ~= "") and plenary_env
  or (cwd .. "/tests/vendor/plenary.nvim")
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.runtimepath:prepend(plenary_path)
  pcall(vim.cmd, "runtime plugin/plenary.vim")
end

vim.o.swapfile = false
vim.o.writebackup = false
vim.o.backup = false
vim.o.shadafile = "NONE"
