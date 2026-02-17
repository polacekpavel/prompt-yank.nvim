local config = require('prompt-yank.config')

local M = {}

local function resolve_target(opts)
  local conf = config.get()
  if opts and opts.tmux and opts.tmux.target ~= nil then return opts.tmux.target end
  if conf.tmux and conf.tmux.target then return conf.tmux.target end
  return nil
end

function M.send(text, opts)
  if not text or text == '' then return nil, 'empty text' end
  if vim.fn.executable('tmux') ~= 1 then return nil, 'tmux not found' end

  local target = resolve_target(opts)
  if not target or target == '' then return nil, 'tmux target not configured' end

  vim.fn.system({ 'tmux', 'load-buffer', '-' }, text)
  if vim.v.shell_error ~= 0 then return nil, 'tmux load-buffer failed' end

  vim.fn.system({ 'tmux', 'paste-buffer', '-t', target })
  if vim.v.shell_error ~= 0 then return nil, 'tmux paste-buffer failed' end

  return true
end

return M
