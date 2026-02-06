local util = require('prompt-yank.util')

local M = {}

local function health_api()
  local h = vim.health
  return {
    start = h.start or h.report_start,
    ok = h.ok or h.report_ok,
    warn = h.warn or h.report_warn,
    error = h.error or h.report_error,
  }
end

function M.check()
  local h = health_api()
  h.start('prompt-yank.nvim')

  local v = vim.version()
  if v.major > 0 or v.minor >= 9 then
    h.ok(('Neovim %d.%d.%d'):format(v.major, v.minor, v.patch))
  else
    h.error(('Neovim %d.%d.%d (requires >= 0.9)'):format(v.major, v.minor, v.patch))
  end

  if util.executable('git') then
    h.ok('git found')
  else
    h.warn('git not found (diff/blame/remote/tree limited)')
  end

  if pcall(require, 'vim.treesitter') then
    h.ok('Tree-sitter available')
  else
    h.warn('Tree-sitter not available (function yank will fall back)')
  end

  if pcall(require, 'fzf-lua') then
    h.ok('fzf-lua available (multi-file picker)')
  else
    h.warn('fzf-lua not found (multi-file picker will try telescope, then builtin)')
  end

  if pcall(require, 'telescope') then
    h.ok('telescope available (multi-file picker)')
  else
    h.warn('telescope not found (multi-file picker will try fzf-lua, then builtin)')
  end
end

return M
