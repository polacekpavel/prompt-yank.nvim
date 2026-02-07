local util = require('prompt-yank.util')

local M = {}

local function relpath_in_root(fullpath, root)
  local rel = util.path_relative(fullpath, root)
  rel = rel:gsub('^%./', '')
  if rel == '.' then return util.path_basename(fullpath) end
  return rel
end

function M.is_git_repo(dir)
  local out, code = util.system({ 'git', '-C', dir, 'rev-parse', '--is-inside-work-tree' })
  if code ~= 0 then return false end
  out = util.trim(out)
  return out == 'true'
end

function M.head_sha(root)
  local out, code = util.system({ 'git', '-C', root, 'rev-parse', 'HEAD' })
  if code ~= 0 then return nil end
  out = util.trim(out)
  if out == '' or out:match('^fatal:') then return nil end
  return out
end

function M.remote_url(root, remote_name)
  remote_name = remote_name or 'origin'
  local key = ('remote.%s.url'):format(remote_name)
  local out, code = util.system({ 'git', '-C', root, 'config', '--get', key })
  if code ~= 0 then return nil end
  out = util.trim(out)
  if out == '' then return nil end
  return out
end

function M.diff_for_file(fullpath, root)
  local rel = relpath_in_root(fullpath, root)
  local head = M.head_sha(root)

  if head then
    local out, code = util.system({ 'git', '-C', root, 'diff', 'HEAD', '--', rel })
    if code == 0 then
      out = util.trim(out)
      if out ~= '' then return out end
    end
  end

  local unstaged, code_unstaged = util.system({ 'git', '-C', root, 'diff', '--', rel })
  if code_unstaged ~= 0 then unstaged = '' end

  local staged, code_staged = util.system({ 'git', '-C', root, 'diff', '--cached', '--', rel })
  if code_staged ~= 0 then staged = '' end

  unstaged = util.trim(unstaged)
  staged = util.trim(staged)

  if unstaged == '' and staged == '' then return nil end

  if unstaged ~= '' and staged ~= '' then return staged .. '\n' .. unstaged end

  return staged ~= '' and staged or unstaged
end

function M.blame_for_file(fullpath, root, line_start, line_end)
  local rel = relpath_in_root(fullpath, root)
  local cmd = { 'git', '-C', root, 'blame', '--date=relative' }
  if line_start and line_end then table.insert(cmd, ('-L%d,%d'):format(line_start, line_end)) end
  table.insert(cmd, '--')
  table.insert(cmd, rel)

  local out, code = util.system(cmd)
  if code ~= 0 then return nil end
  out = util.trim(out)
  if out == '' or out:match('^fatal:') then return nil end
  return out
end

function M.normalize_remote_url(url)
  url = util.trim(url)
  if url == '' then return nil end

  local host, path = url:match('^git@([^:]+):(.+)$')
  if host and path then
    path = path:gsub('%.git$', '')
    return ('https://%s/%s'):format(host, path)
  end

  if url:match('^ssh://') then
    local rest = url:gsub('^ssh://', '')
    rest = rest:gsub('^[^@]+@', '')
    host, path = rest:match('^([^/]+)/(.+)$')
    if host and path then
      path = path:gsub('%.git$', '')
      return ('https://%s/%s'):format(host, path)
    end
  end

  host, path = url:match('^https?://([^/]+)/(.+)$')
  if host and path then
    host = host:gsub('^.*@', '')
    path = path:gsub('%.git$', '')
    return ('https://%s/%s'):format(host, path)
  end

  return nil
end

function M.detect_provider(base_url)
  local host = (base_url or ''):match('^https?://([^/]+)/')
  host = (host or ''):lower()
  if host:find('github', 1, true) then return 'github' end
  if host:find('gitlab', 1, true) then return 'gitlab' end
  if host:find('bitbucket', 1, true) then return 'bitbucket' end
  return 'unknown'
end

local function anchor_for(provider, filepath, line_start, line_end)
  if not line_start or not line_end then return '' end

  if provider == 'github' then
    if line_start == line_end then return ('#L%d'):format(line_start) end
    return ('#L%d-L%d'):format(line_start, line_end)
  end

  if provider == 'gitlab' then
    if line_start == line_end then return ('#L%d'):format(line_start) end
    return ('#L%d-%d'):format(line_start, line_end)
  end

  if provider == 'bitbucket' then
    local file = util.path_basename(filepath)
    return ('#%s-%d'):format(file, line_start)
  end

  return ''
end

function M.diff_stat(root, scope)
  local cmd = { 'git', '-C', root, 'diff', '--stat' }
  if scope then
    table.insert(cmd, '--')
    table.insert(cmd, scope)
  end
  local out, code = util.system(cmd)
  if code ~= 0 then return nil end
  out = util.trim(out)
  if out == '' then return nil end
  return out
end

function M.log(root, count, scope)
  count = count or 10
  local cmd = {
    'git',
    '-C',
    root,
    'log',
    ('--max-count=%d'):format(count),
    '--format=%h %s (%cr)',
  }
  if scope then
    table.insert(cmd, '--')
    table.insert(cmd, scope)
  end
  local out, code = util.system(cmd)
  if code ~= 0 then return nil end
  out = util.trim(out)
  if out == '' then return nil end
  return out
end

function M.build_remote_url(base_url, provider, commit, filepath, line_start, line_end)
  if not base_url or not commit or not filepath then return nil end
  provider = provider or M.detect_provider(base_url)
  local anchor = anchor_for(provider, filepath, line_start, line_end)

  if provider == 'github' then
    return ('%s/blob/%s/%s%s'):format(base_url, commit, filepath, anchor)
  end
  if provider == 'gitlab' then
    return ('%s/-/blob/%s/%s%s'):format(base_url, commit, filepath, anchor)
  end
  if provider == 'bitbucket' then
    return ('%s/src/%s/%s%s'):format(base_url, commit, filepath, anchor)
  end

  return nil
end

return M
