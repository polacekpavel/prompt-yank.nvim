local config = require('prompt-yank.config')

local M = {}

local function keymap_opts(desc) return { silent = true, noremap = true, desc = desc } end

local function apply_keymaps()
  local conf = config.get()
  if conf.keymaps == false then return end

  local keymaps = conf.keymaps or {}

  local function parse(value)
    if value == false or value == nil then return nil end
    if type(value) == 'string' then return { lhs = value } end
    if type(value) == 'table' then return { lhs = value.lhs or value[1], format = value.format } end
    return nil
  end

  local function nmap(name, fn, desc)
    local km = parse(keymaps[name])
    if not km or not km.lhs then return end
    vim.keymap.set('n', km.lhs, function() fn({ format = km.format }) end, keymap_opts(desc))
  end

  local function vmap(name, fn, desc)
    local km = parse(keymaps[name])
    if not km or not km.lhs then return end
    vim.keymap.set(
      'v',
      km.lhs,
      function() fn({ format = km.format, from_visual = true }) end,
      keymap_opts(desc)
    )
  end

  nmap('copy_file', M.yank_file, 'PromptYank: file')
  vmap('copy_selection', M.yank_selection, 'PromptYank: selection')

  nmap('copy_function', M.yank_function, 'PromptYank: function')
  nmap('copy_multi', M.yank_multi, 'PromptYank: multi-file')

  nmap('copy_diff', M.yank_diff, 'PromptYank: diff')
  vmap('copy_diff', M.yank_diff, 'PromptYank: selection + diff')

  nmap('copy_blame', M.yank_blame, 'PromptYank: blame')
  vmap('copy_blame', M.yank_blame, 'PromptYank: selection blame')

  vmap('copy_diagnostics', M.yank_diagnostics, 'PromptYank: diagnostics')

  nmap('copy_context', M.yank_context, 'PromptYank: context')
  vmap('copy_context', M.yank_context, 'PromptYank: selection + context')

  nmap('copy_tree', M.yank_tree, 'PromptYank: project tree')
  vmap('copy_tree', M.yank_tree, 'PromptYank: tree path + selection')

  nmap('copy_remote', M.yank_remote, 'PromptYank: remote URL')
  vmap('copy_remote', M.yank_remote, 'PromptYank: remote URL + selection')

  vmap('copy_with_definitions', M.yank_with_definitions, 'PromptYank: selection + definitions')
  vmap(
    'copy_with_definitions_deep',
    M.yank_with_definitions_deep,
    'PromptYank: selection + deep definitions'
  )

  nmap('copy_related', M.yank_related, 'PromptYank: related files')
end

function M.setup(opts)
  config.setup(opts or {})
  apply_keymaps()
end

local function current_bufnr() return 0 end

local function get_root(bufnr)
  local conf = config.get()
  local util = require('prompt-yank.util')
  return util.project_root(conf.root.strategy, bufnr)
end

local function get_fullpath(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then return nil end
  return name
end

function M.format_selection(opts)
  local yank = require('prompt-yank.yank')
  local code, line_start, line_end = yank.get_visual_selection(current_bufnr(), opts)
  if not code then
    yank.notify('No visual selection found', vim.log.levels.WARN, opts)
    return nil
  end
  local ctx = yank.build_ctx_for_buffer(current_bufnr(), code, line_start, line_end)
  return yank.format_code_block(ctx, opts)
end

function M.format_file(opts)
  local yank = require('prompt-yank.yank')
  local code = yank.get_buffer_text(current_bufnr())
  local ctx = yank.build_ctx_for_buffer(current_bufnr(), code, nil, nil)
  return yank.format_code_block(ctx, opts)
end

function M.yank_selection(opts)
  local yank = require('prompt-yank.yank')
  local code, line_start, line_end = yank.get_visual_selection(current_bufnr(), opts)
  if not code then
    yank.notify('No visual selection found', vim.log.levels.WARN, opts)
    return nil
  end

  local ctx = yank.build_ctx_for_buffer(current_bufnr(), code, line_start, line_end)
  local text = yank.format_code_block(ctx, opts)
  yank.copy(text, opts)
  yank.notify(
    ('Copied %d lines from %s%s'):format(
      line_end - line_start + 1,
      ctx.filepath,
      yank.token_suffix(text)
    ),
    nil,
    opts
  )
  return text
end

function M.yank_file(opts)
  local yank = require('prompt-yank.yank')
  local conf = config.get()
  local bufnr = current_bufnr()
  local fullpath = get_fullpath(bufnr)

  if fullpath then
    local size = require('prompt-yank.util').file_size(fullpath) or 0
    if not yank.ensure_size_ok('file', size, conf.limits.max_file_bytes) then return nil end
  end

  local code, total_lines = yank.get_buffer_text(bufnr)
  local ctx = yank.build_ctx_for_buffer(bufnr, code, nil, nil)
  local text = yank.format_code_block(ctx, opts)
  yank.copy(text, opts)
  yank.notify(
    ('Copied entire file (%d lines) from %s%s'):format(
      total_lines,
      ctx.filepath,
      yank.token_suffix(text)
    ),
    nil,
    opts
  )
  return text
end

function M.yank_range(line_start, line_end, opts)
  local yank = require('prompt-yank.yank')
  local bufnr = current_bufnr()
  local code = yank.get_range_text(bufnr, line_start, line_end)
  local ctx = yank.build_ctx_for_buffer(bufnr, code, line_start, line_end)
  local text = yank.format_code_block(ctx, opts)
  yank.copy(text, opts)
  yank.notify(
    ('Copied %d lines from %s%s'):format(
      line_end - line_start + 1,
      ctx.filepath,
      yank.token_suffix(text)
    ),
    nil,
    opts
  )
  return text
end

function M.yank_diagnostics(opts)
  opts = opts or {}
  local yank = require('prompt-yank.yank')
  local diag = require('prompt-yank.diagnostics')

  local bufnr = current_bufnr()

  local code, line_start, line_end = yank.get_visual_selection(bufnr, opts)
  if not code then
    line_start = opts.line_start or vim.api.nvim_win_get_cursor(0)[1]
    line_end = opts.line_end or line_start
    code = yank.get_range_text(bufnr, line_start, line_end)
  end

  local ctx = yank.build_ctx_for_buffer(bufnr, code, line_start, line_end)
  ctx.diagnostics = diag.format_in_range(bufnr, line_start, line_end)
  ctx.code_block = yank.format_code_block(ctx, opts)

  local text = yank.format_named_template('diagnostics', ctx, opts)
  yank.copy(text, opts)
  yank.notify(
    ('Copied %d lines + diagnostics from %s%s'):format(
      line_end - line_start + 1,
      ctx.filepath,
      yank.token_suffix(text)
    ),
    nil,
    opts
  )
  return text
end

function M.yank_diff(opts)
  opts = opts or {}
  local yank = require('prompt-yank.yank')
  local git = require('prompt-yank.git')
  local util = require('prompt-yank.util')

  local bufnr = current_bufnr()
  local fullpath = get_fullpath(bufnr)
  if not fullpath then
    yank.notify('No file open', vim.log.levels.WARN, opts)
    return nil
  end

  local selection_code, range_start, range_end = yank.get_visual_selection(bufnr, opts)
  range_start = opts.line_start or range_start
  range_end = opts.line_end or range_end

  local root = get_root(bufnr)
  if not util.relpath_under_root(fullpath, root) then
    yank.notify('File is outside project root; diff unavailable', vim.log.levels.WARN, opts)
    if range_start and range_end then
      local code = selection_code or yank.get_range_text(bufnr, range_start, range_end)
      local ctx = yank.build_ctx_for_buffer(bufnr, code, range_start, range_end)
      local text = yank.format_code_block(ctx, opts)
      yank.copy(text, opts)
      yank.notify(
        ('Copied selection from %s%s'):format(ctx.filepath, yank.token_suffix(text)),
        nil,
        opts
      )
      return text
    end
    return nil
  end

  local diff = git.diff_for_file(fullpath, root)
  if diff and not yank.ensure_size_ok('diff', #diff, config.get().limits.max_diff_bytes) then
    return nil
  end

  if range_start and range_end then
    local code = selection_code
    if not code then code = yank.get_range_text(bufnr, range_start, range_end) end
    local ctx = yank.build_ctx_for_buffer(bufnr, code, range_start, range_end)
    if not diff then
      local text = yank.format_code_block(ctx, opts)
      yank.copy(text, opts)
      yank.notify(
        ('No uncommitted changes; copied selection from %s%s'):format(
          ctx.filepath,
          yank.token_suffix(text)
        ),
        nil,
        opts
      )
      return text
    end

    ctx.diff = diff
    local text = yank.format_named_template('diff_with_selection', ctx, opts)
    yank.copy(text, opts)
    yank.notify(
      ('Copied selection + diff from %s%s'):format(ctx.filepath, yank.token_suffix(text)),
      nil,
      opts
    )
    return text
  end

  if not diff then
    yank.notify('No uncommitted changes in this file', vim.log.levels.INFO, opts)
    return nil
  end

  local ctx = yank.build_ctx_for_buffer(bufnr, '', nil, nil)
  ctx.diff = diff
  local text = yank.format_named_template('diff_file', ctx, opts)
  yank.copy(text, opts)
  yank.notify(('Copied diff for %s%s'):format(ctx.filepath, yank.token_suffix(text)), nil, opts)
  return text
end

function M.yank_blame(opts)
  opts = opts or {}
  local yank = require('prompt-yank.yank')
  local git = require('prompt-yank.git')
  local util = require('prompt-yank.util')

  local bufnr = current_bufnr()
  local fullpath = get_fullpath(bufnr)
  if not fullpath then
    yank.notify('No file open', vim.log.levels.WARN, opts)
    return nil
  end

  local root = get_root(bufnr)
  if not git.is_git_repo(root) then
    yank.notify('Not in a git repository', vim.log.levels.WARN, opts)
    return nil
  end
  if not util.relpath_under_root(fullpath, root) then
    yank.notify('File is outside project root; blame unavailable', vim.log.levels.WARN, opts)
    return nil
  end

  local _, range_start, range_end = yank.get_visual_selection(bufnr, opts)
  range_start = opts.line_start or range_start
  range_end = opts.line_end or range_end

  local blame = git.blame_for_file(fullpath, root, range_start, range_end)
  if not blame then
    yank.notify('git blame failed (file not tracked?)', vim.log.levels.WARN, opts)
    return nil
  end

  local ctx = yank.build_ctx_for_buffer(bufnr, '', range_start, range_end)
  ctx.blame = blame

  local template = range_start and 'blame_selection' or 'blame_file'
  local text = yank.format_named_template(template, ctx, opts)
  yank.copy(text, opts)
  yank.notify(('Copied blame for %s%s'):format(ctx.filepath, yank.token_suffix(text)), nil, opts)
  return text
end

function M.yank_tree(opts)
  opts = opts or {}
  local yank = require('prompt-yank.yank')
  local tree = require('prompt-yank.tree')

  local conf = config.get()
  local bufnr = current_bufnr()
  local root = get_root(bufnr)
  local project_name = require('prompt-yank.util').project_name(root)

  local selection_code, selection_start, selection_end = yank.get_visual_selection(bufnr, opts)
  selection_start = opts.line_start or selection_start
  selection_end = opts.line_end or selection_end

  if selection_start and selection_end then
    local fullpath = get_fullpath(bufnr)
    if not fullpath then
      yank.notify('No file open', vim.log.levels.WARN, opts)
      return nil
    end

    local code = selection_code or yank.get_range_text(bufnr, selection_start, selection_end)
    local rel = require('prompt-yank.util').relpath_under_root(fullpath, root)
    if not rel then
      local ctx = yank.build_ctx_for_buffer(bufnr, code, selection_start, selection_end)
      local text = yank.format_code_block(ctx, opts)
      yank.copy(text, opts)
      yank.notify(
        'File is outside project root; tree unavailable; copied selection only',
        vim.log.levels.WARN,
        opts
      )
      return text
    end

    local project_tree = tree.render_path(rel)

    local ctx = yank.build_ctx_for_buffer(bufnr, code, selection_start, selection_end, {
      project_name = project_name,
      project_tree = project_tree,
    })
    ctx.code_block = yank.format_code_block(ctx, opts)

    local text = yank.format_named_template('tree_with_selection', ctx, opts)
    yank.copy(text, opts)
    yank.notify(
      ('Copied tree path + selection from %s%s'):format(ctx.filepath, yank.token_suffix(text)),
      nil,
      opts
    )
    return text
  end

  local depth = opts.depth or conf.tree.max_depth
  local project_tree, item_count =
    tree.build_tree(root, depth, conf.tree.ignore, conf.tree.max_files_fallback)
  local ctx = yank.build_ctx_for_buffer(bufnr, '', nil, nil, {
    project_name = project_name,
    project_tree = project_tree,
  })

  local text = yank.format_named_template('tree_full', ctx, opts)
  yank.copy(text, opts)
  yank.notify(
    ('Copied project tree (%d items)%s'):format(item_count, yank.token_suffix(text)),
    nil,
    opts
  )
  return text
end

function M.yank_context(opts)
  opts = opts or {}
  local yank = require('prompt-yank.yank')

  local conf = config.get()
  local bufnr = current_bufnr()
  local context_lines = opts.context_lines or conf.context_lines

  local _, line_start, line_end = yank.get_visual_selection(bufnr, opts)
  line_start = opts.line_start or line_start
  line_end = opts.line_end or line_end
  if not line_start or not line_end then
    local cursor = vim.api.nvim_win_get_cursor(0)
    line_start = cursor[1]
    line_end = cursor[1]
  end

  local total = vim.api.nvim_buf_line_count(bufnr)
  local start_ctx = math.max(1, line_start - context_lines)
  local end_ctx = math.min(total, line_end + context_lines)

  local code = yank.get_range_text(bufnr, start_ctx, end_ctx)
  local ctx =
    yank.build_ctx_for_buffer(bufnr, code, start_ctx, end_ctx, { context_lines = context_lines })

  local text = yank.format_named_template('context', ctx, opts)
  yank.copy(text, opts)
  yank.notify(
    ('Copied context (L%d-L%d) from %s%s'):format(
      start_ctx,
      end_ctx,
      ctx.filepath,
      yank.token_suffix(text)
    ),
    nil,
    opts
  )
  return text
end

function M.yank_remote(opts)
  opts = opts or {}
  local yank = require('prompt-yank.yank')
  local git = require('prompt-yank.git')
  local util = require('prompt-yank.util')
  local lang = require('prompt-yank.lang')

  local bufnr = current_bufnr()
  local fullpath = get_fullpath(bufnr)
  if not fullpath then
    yank.notify('No file open', vim.log.levels.WARN, opts)
    return nil
  end

  local conf = config.get()
  local root = get_root(bufnr)
  if not git.is_git_repo(root) then
    yank.notify('Not in a git repository', vim.log.levels.WARN, opts)
    return nil
  end

  local commit = git.head_sha(root)
  local remote_raw = git.remote_url(root, conf.git.remote)
  local base = remote_raw and git.normalize_remote_url(remote_raw) or nil
  local provider = base and git.detect_provider(base) or 'unknown'

  local selection_code, line_start, line_end = yank.get_visual_selection(bufnr, opts)
  line_start = opts.line_start or line_start
  line_end = opts.line_end or line_end

  local code
  if line_start and line_end then
    code = selection_code or yank.get_range_text(bufnr, line_start, line_end)
  else
    code = yank.get_buffer_text(bufnr)
  end

  local rel = util.relpath_under_root(fullpath, root)
  if not rel then
    local ctx = yank.build_ctx_for_buffer(bufnr, code, line_start, line_end)
    local text = yank.format_code_block(ctx, opts)
    yank.copy(text, opts)
    yank.notify(
      'File is outside project root; remote URL unavailable; copied code only',
      vim.log.levels.WARN,
      opts
    )
    return text
  end

  local remote_url = base
    and commit
    and git.build_remote_url(base, provider, commit, rel, line_start, line_end)
  if not remote_url then
    local ctx = yank.build_ctx_for_buffer(bufnr, code, line_start, line_end)
    local text = yank.format_code_block(ctx, opts)
    yank.copy(text, opts)
    yank.notify('Remote URL unavailable; copied code only', vim.log.levels.WARN, opts)
    return text
  end

  local ctx = yank.build_ctx_for_path(
    fullpath,
    root,
    code,
    lang.for_buffer(bufnr, conf),
    line_start,
    line_end,
    {
      remote_url = remote_url,
    }
  )

  local text = yank.format_named_template('remote_with_code', ctx, opts)
  yank.copy(text, opts)
  yank.notify(
    ('Copied remote URL + code for %s%s'):format(ctx.filepath, yank.token_suffix(text)),
    nil,
    opts
  )
  return text
end

function M.yank_function(opts)
  opts = opts or {}
  local yank = require('prompt-yank.yank')
  local ts = require('prompt-yank.treesitter')

  local bufnr = current_bufnr()
  local info, err = ts.current_container(bufnr)
  if not info then
    yank.notify(err or 'Tree-sitter unavailable; yanking current line', vim.log.levels.WARN, opts)
    local line = vim.api.nvim_win_get_cursor(0)[1]
    return M.yank_range(line, line, opts)
  end

  local code = yank.get_range_text(bufnr, info.start_line, info.end_line)
  local extra = { symbol_name = info.name or '' }
  local ctx = yank.build_ctx_for_buffer(bufnr, code, info.start_line, info.end_line, extra)

  local text
  if info.name and info.name ~= '' then
    text = yank.format_named_template('function_named', ctx, opts)
  else
    text = yank.format_code_block(ctx, opts)
  end

  yank.copy(text, opts)
  yank.notify(
    ('Copied %s (%s) from %s%s'):format(
      info.node_type,
      info.name or 'unnamed',
      ctx.filepath,
      yank.token_suffix(text)
    ),
    nil,
    opts
  )
  return text
end

function M.yank_files(paths, opts)
  opts = opts or {}
  local yank = require('prompt-yank.yank')
  local util = require('prompt-yank.util')
  local lang = require('prompt-yank.lang')

  local conf = config.get()
  local root = get_root(current_bufnr())

  local blocks = {}
  local skipped_sensitive = {}
  local skipped_outside_root = {}

  for _, path in ipairs(paths or {}) do
    path = util.trim(path)
    if path ~= '' then
      if util.is_sensitive(path, conf.sensitive_patterns) then
        table.insert(skipped_sensitive, path)
      else
        local fullpath
        if util.path_is_absolute(path) then
          fullpath = path
        else
          fullpath = (vim.fs and vim.fs.joinpath) and vim.fs.joinpath(root, path)
            or (root .. '/' .. path)
        end
        fullpath = util.normalize_path(fullpath)

        local rel = util.relpath_under_root(fullpath, root)
        if not rel then
          table.insert(skipped_outside_root, path)
        elseif util.is_sensitive(rel, conf.sensitive_patterns) then
          table.insert(skipped_sensitive, path)
        else
          local code, err = yank.read_file(fullpath, conf.limits.max_file_bytes)
          if code then
            local language = lang.for_path(fullpath, conf)
            local ctx = yank.build_ctx_for_path(fullpath, root, code, language, nil, nil)
            table.insert(blocks, yank.format_code_block(ctx, opts))
          else
            yank.notify(
              ('Skipped %s: %s'):format(path, err or 'unreadable'),
              vim.log.levels.WARN,
              opts
            )
          end
        end
      end
    end
  end

  if #skipped_sensitive > 0 then
    yank.notify(
      ('Skipped %d sensitive file(s): %s'):format(
        #skipped_sensitive,
        table.concat(skipped_sensitive, ', ')
      ),
      vim.log.levels.WARN,
      opts
    )
  end

  if #skipped_outside_root > 0 then
    yank.notify(
      ('Skipped %d file(s) outside project root: %s'):format(
        #skipped_outside_root,
        table.concat(skipped_outside_root, ', ')
      ),
      vim.log.levels.WARN,
      opts
    )
  end

  if #blocks == 0 then
    yank.notify('No files copied', vim.log.levels.INFO, opts)
    return nil
  end

  local text = yank.join_blocks(blocks)
  yank.copy(text, opts)
  yank.notify(('Copied %d files%s'):format(#blocks, yank.token_suffix(text)), nil, opts)
  return text
end

function M.yank_multi(opts)
  opts = opts or {}
  local picker = require('prompt-yank.picker')
  local yank = require('prompt-yank.yank')

  local root = get_root(current_bufnr())
  picker.pick_files({ root = root }, function(paths)
    if not paths or #paths == 0 then
      yank.notify('No files selected', vim.log.levels.INFO, opts)
      return
    end
    M.yank_files(paths, opts)
  end)
end

function M.yank_with_definitions(opts)
  opts = opts or {}
  local yank = require('prompt-yank.yank')
  local lsp = require('prompt-yank.lsp')

  local bufnr = current_bufnr()
  local code, line_start, line_end = yank.get_visual_selection(bufnr, opts)
  if not code then
    yank.notify('No visual selection found', vim.log.levels.WARN, opts)
    return nil
  end

  local root = get_root(bufnr)
  local ctx = yank.build_ctx_for_buffer(bufnr, code, line_start, line_end)
  local selection_block = yank.format_code_block(ctx, opts)

  local definitions = lsp.get_definitions_for_selection(bufnr, line_start, line_end, {
    timeout_ms = opts.timeout_ms or 2000,
  })

  if #definitions == 0 then
    yank.copy(selection_block, opts)
    yank.notify(
      ('Copied %d lines (no definitions found)%s'):format(
        line_end - line_start + 1,
        yank.token_suffix(selection_block)
      ),
      nil,
      opts
    )
    return selection_block
  end

  local defs_block = lsp.format_definitions(definitions, root)
  local header = config.resolve_template('definitions_header')
    or '\n\n---\n\n**Referenced Definitions:**\n\n'
  local footer = config.resolve_template('definitions_footer') or ''
  local text = selection_block .. header .. defs_block .. footer

  yank.copy(text, opts)
  yank.notify(
    ('Copied %d lines + %d definitions from %s%s'):format(
      line_end - line_start + 1,
      #definitions,
      ctx.filepath,
      yank.token_suffix(text)
    ),
    nil,
    opts
  )
  return text
end

function M.yank_with_definitions_deep(opts)
  opts = opts or {}
  local yank = require('prompt-yank.yank')
  local lsp = require('prompt-yank.lsp')

  local bufnr = current_bufnr()
  local code, line_start, line_end = yank.get_visual_selection(bufnr, opts)
  if not code then
    yank.notify('No visual selection found', vim.log.levels.WARN, opts)
    return nil
  end

  local root = get_root(bufnr)
  local ctx = yank.build_ctx_for_buffer(bufnr, code, line_start, line_end)
  local selection_block = yank.format_code_block(ctx, opts)

  local definitions = lsp.get_definitions_deep(bufnr, line_start, line_end, {
    max_depth = opts.max_depth or 3,
    timeout_ms = opts.timeout_ms or 2000,
    max_definitions = opts.max_definitions or 50,
  })

  if #definitions == 0 then
    yank.copy(selection_block, opts)
    yank.notify(
      ('Copied %d lines (no definitions found)%s'):format(
        line_end - line_start + 1,
        yank.token_suffix(selection_block)
      ),
      nil,
      opts
    )
    return selection_block
  end

  local defs_block = lsp.format_definitions(definitions, root)
  local header = config.resolve_template('definitions_deep_header')
    or '\n\n---\n\n**Referenced Definitions (deep):**\n\n'
  local footer = config.resolve_template('definitions_footer') or ''
  local text = selection_block .. header .. defs_block .. footer

  yank.copy(text, opts)
  yank.notify(
    ('Copied %d lines + %d deep definitions from %s%s'):format(
      line_end - line_start + 1,
      #definitions,
      ctx.filepath,
      yank.token_suffix(text)
    ),
    nil,
    opts
  )
  return text
end

function M.yank_related(opts)
  opts = opts or {}
  local yank = require('prompt-yank.yank')
  local related = require('prompt-yank.related')
  local util = require('prompt-yank.util')
  local lang_mod = require('prompt-yank.lang')
  local format_mod = require('prompt-yank.format')

  local conf = config.get()
  local bufnr = current_bufnr()
  local root = get_root(bufnr)
  local current = get_fullpath(bufnr)
  if not current then
    yank.notify('No file open', vim.log.levels.WARN, opts)
    return nil
  end

  local paths = related.find_related_files(bufnr, root, {
    max_files = (conf.related and conf.related.max_files) or 10,
    timeout_ms = opts.timeout_ms or 2000,
  })

  local blocks = {}
  local skipped_sensitive = {}

  local current_code = yank.get_buffer_text(bufnr)
  local current_ctx = yank.build_ctx_for_buffer(bufnr, current_code, nil, nil)
  table.insert(blocks, yank.format_code_block(current_ctx, opts))

  for _, fullpath in ipairs(paths) do
    local rel = util.relpath_under_root(fullpath, root)
    if rel then
      if util.is_sensitive(rel, conf.sensitive_patterns) then
        table.insert(skipped_sensitive, rel)
      else
        local code, err = yank.read_file(fullpath, conf.limits.max_file_bytes)
        if code then
          local language = lang_mod.for_path(fullpath, conf)
          local ctx = yank.build_ctx_for_path(fullpath, root, code, language, nil, nil)
          table.insert(blocks, yank.format_code_block(ctx, opts))
        else
          yank.notify(
            ('Skipped %s: %s'):format(rel, err or 'unreadable'),
            vim.log.levels.WARN,
            opts
          )
        end
      end
    end
  end

  if #skipped_sensitive > 0 then
    yank.notify(
      ('Skipped %d sensitive file(s): %s'):format(
        #skipped_sensitive,
        table.concat(skipped_sensitive, ', ')
      ),
      vim.log.levels.WARN,
      opts
    )
  end

  local joined = yank.join_blocks(blocks)
  local origin = util.display_path(current, root, conf.path_style)
  local tpl = config.resolve_template('related')
  local text
  if tpl then
    text = format_mod.render_template(tpl, {
      origin = origin,
      related_count = #blocks - 1,
      related_blocks = joined,
    })
  else
    text = joined
  end

  yank.copy(text, opts)
  local related_count = #blocks - 1
  yank.notify(
    ('Copied current file + %d related files for %s%s'):format(related_count, origin, yank.token_suffix(text)),
    nil,
    opts
  )
  return text
end

return M
