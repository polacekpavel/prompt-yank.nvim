local M = {}

local sep = package.config:sub(1, 1)

function M.trim(value)
  if value == nil then return '' end
  return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''))
end

function M.is_windows() return sep == '\\' end

function M.normalize_path(path)
  if not path or path == '' then return '' end
  if vim.fs and vim.fs.normalize then return vim.fs.normalize(path) end
  return path
end

function M.realpath(path)
  if not path or path == '' then return nil end
  local uv = vim.uv or vim.loop
  if not uv or not uv.fs_realpath then return nil end
  return uv.fs_realpath(path)
end

function M.path_basename(path)
  if not path or path == '' then return '' end
  return path:match('([^' .. sep .. ']+)$') or path
end

function M.path_is_absolute(path)
  if not path or path == '' then return false end
  if M.is_windows() then
    return path:match('^%a:[/\\]') ~= nil or path:match('^[/\\][/\\]') ~= nil
  end
  return path:sub(1, 1) == '/'
end

function M.path_relative(path, root)
  path = M.normalize_path(path)
  root = M.normalize_path(root)
  if path == '' or root == '' then return path end
  if path == root then return '.' end

  local root_with_sep = root
  if root_with_sep:sub(-1) ~= sep then root_with_sep = root_with_sep .. sep end

  if path:sub(1, #root_with_sep) == root_with_sep then return path:sub(#root_with_sep + 1) end

  if sep ~= '/' then
    local alt_root = root:gsub('\\', '/')
    local alt_path = path:gsub('\\', '/')
    local alt_root_sep = alt_root
    if alt_root_sep:sub(-1) ~= '/' then alt_root_sep = alt_root_sep .. '/' end
    if alt_path:sub(1, #alt_root_sep) == alt_root_sep then
      return alt_path:sub(#alt_root_sep + 1)
    end
  end

  return path
end

local function is_parent_relative(rel)
  if not rel or rel == '' then return false end
  if rel == '..' then return true end
  if rel:sub(1, 3) == '..' .. sep then return true end
  if sep ~= '/' and rel:sub(1, 3) == '../' then return true end
  if sep ~= '\\' and rel:sub(1, 3) == '..\\' then return true end
  return false
end

function M.relpath_under_root(fullpath, root)
  if not fullpath or not root then return nil end
  local fullpath_real = M.realpath(fullpath)
  local root_real = M.realpath(root)
  local check_full
  local check_root
  if fullpath_real and root_real then
    check_full = fullpath_real
    check_root = root_real
  else
    check_full = fullpath
    check_root = root
  end

  check_full = M.normalize_path(check_full)
  check_root = M.normalize_path(check_root)
  if check_full == '' or check_root == '' then return nil end

  local rel = M.path_relative(check_full, check_root):gsub('^%./', '')
  if rel == '' or rel == '.' then return nil end
  if M.path_is_absolute(rel) then return nil end
  if is_parent_relative(rel) then return nil end

  return rel
end

function M.file_size(path)
  if not path or path == '' then return nil end
  local uv = vim.uv or vim.loop
  local stat = uv.fs_stat(path)
  if not stat then return nil end
  return stat.size
end

function M.confirm(title, message)
  local choice = vim.fn.confirm(('%s\n\n%s'):format(title, message), '&Yes\n&No', 2)
  return choice == 1
end

function M.system(cmd)
  local output = vim.fn.system(cmd)
  return output, vim.v.shell_error
end

function M.executable(bin) return vim.fn.executable(bin) == 1 end

function M.git_root(dir)
  dir = dir or vim.fn.getcwd()
  local out, code = M.system({ 'git', '-C', dir, 'rev-parse', '--show-toplevel' })
  if code ~= 0 then return nil end
  out = M.trim(out)
  if out == '' or out:match('^fatal:') then return nil end
  return out
end

function M.project_root(strategy, bufnr)
  strategy = strategy or 'git_or_cwd'
  local bufname = vim.api.nvim_buf_get_name(bufnr or 0)
  local dir
  if bufname ~= '' then
    dir = vim.fn.fnamemodify(bufname, ':p:h')
  else
    dir = vim.fn.getcwd()
  end

  if strategy == 'cwd' then return vim.fn.getcwd() end

  local git = M.git_root(dir)
  if git then return git end

  return vim.fn.getcwd()
end

function M.project_name(root)
  local name = vim.fn.fnamemodify(root or vim.fn.getcwd(), ':t')
  if name == '' then name = '(project)' end
  return name
end

function M.display_path(fullpath, root, path_style)
  path_style = path_style or 'relative'
  if not fullpath or fullpath == '' then return '[untitled]' end

  if path_style == 'absolute' then return fullpath end

  if path_style == 'filename' then return vim.fn.fnamemodify(fullpath, ':t') end

  if path_style == 'relative' then
    if root and root ~= '' then
      local rel = M.relpath_under_root(fullpath, root)
      if rel then return rel end
    end

    local rel_to_cwd = vim.fn.fnamemodify(fullpath, ':.')
    if M.path_is_absolute(rel_to_cwd) then return vim.fn.fnamemodify(fullpath, ':t') end
    return rel_to_cwd
  end

  if root and root ~= '' then
    local rel = M.path_relative(fullpath, root):gsub('^%./', '')
    if rel ~= '' and rel ~= '.' then return rel end
  end

  return vim.fn.fnamemodify(fullpath, ':.')
end

function M.is_sensitive(path, patterns)
  if not path or path == '' then return false end
  local lower = path:lower()
  for _, pattern in ipairs(patterns or {}) do
    if lower:match(pattern) then return true end
  end
  return false
end

return M
