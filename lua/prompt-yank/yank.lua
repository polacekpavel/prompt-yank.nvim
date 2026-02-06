local config = require('prompt-yank.config')
local format = require('prompt-yank.format')
local lang = require('prompt-yank.lang')
local util = require('prompt-yank.util')

local M = {}

local function line_placeholders(line_start, line_end)
  if not line_start or not line_end then
    return {
      lines_plain = '',
      lines_md = '',
      lines_hash = '',
    }
  end

  if line_start == line_end then
    local n = tostring(line_start)
    return {
      lines_plain = n,
      lines_md = 'L' .. n,
      lines_hash = '#L' .. n,
    }
  end

  local s = tostring(line_start)
  local e = tostring(line_end)
  return {
    lines_plain = ('%s-%s'):format(s, e),
    lines_md = ('L%s-L%s'):format(s, e),
    lines_hash = ('#L%s-L%s'):format(s, e),
  }
end

function M.build_ctx_for_buffer(bufnr, code, line_start, line_end, extra)
  local conf = config.get()
  local root = util.project_root(conf.root.strategy, bufnr)

  local fullpath = vim.api.nvim_buf_get_name(bufnr)
  if fullpath == '' then fullpath = nil end

  local filepath = util.display_path(fullpath, root, conf.path_style)
  local filename = fullpath and vim.fn.fnamemodify(fullpath, ':t') or filepath
  local lines = line_placeholders(line_start, line_end)

  local ctx = {
    filepath = filepath,
    fullpath = fullpath or '',
    filename = filename,
    lang = lang.for_buffer(bufnr, conf),
    code = code or '',
    line_start = line_start,
    line_end = line_end,
    lines_plain = lines.lines_plain,
    lines_md = lines.lines_md,
    lines_hash = lines.lines_hash,
  }

  for k, v in pairs(extra or {}) do
    ctx[k] = v
  end

  return ctx, root, fullpath
end

function M.build_ctx_for_path(fullpath, root, code, language, line_start, line_end, extra)
  local conf = config.get()
  local filepath = util.display_path(fullpath, root, conf.path_style)
  local filename = fullpath and vim.fn.fnamemodify(fullpath, ':t') or filepath
  local lines = line_placeholders(line_start, line_end)

  local ctx = {
    filepath = filepath,
    fullpath = fullpath or '',
    filename = filename,
    lang = language or '',
    code = code or '',
    line_start = line_start,
    line_end = line_end,
    lines_plain = lines.lines_plain,
    lines_md = lines.lines_md,
    lines_hash = lines.lines_hash,
  }

  for k, v in pairs(extra or {}) do
    ctx[k] = v
  end

  return ctx
end

function M.notify(message, level, opts)
  local conf = config.get()
  local notify = conf.notify
  if opts and opts.notify ~= nil then notify = opts.notify end
  if not notify then return end
  vim.notify(message, level or vim.log.levels.INFO)
end

function M.copy(text, opts)
  local conf = config.get()
  local register = (opts and opts.register) or conf.register
  vim.fn.setreg(register, text, 'v')
  return text
end

function M.format_code_block(ctx, opts) return format.render_code_block(ctx, opts) end

function M.format_named_template(template_name, ctx, opts)
  local conf = config.get()
  ctx.code_block = ctx.code_block or format.render_code_block(ctx, opts)
  local tpl = conf.templates and conf.templates[template_name] or nil
  if tpl == nil or tpl == '' then return ctx.code_block end
  return format.render_template(tpl, ctx)
end

function M.get_buffer_text(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, '\n'), #lines
end

function M.get_range_text(bufnr, line_start, line_end)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_start - 1, line_end, false)
  return table.concat(lines, '\n'), #lines
end

function M.get_visual_selection(bufnr, opts)
  bufnr = bufnr or 0

  local function normalize_mode(m)
    if m == 's' then return 'v' end
    if m == 'S' then return 'V' end
    if m == '\19' then return '\22' end
    return m
  end

  local current_mode = vim.fn.mode()
  local in_selection = current_mode == 'v'
    or current_mode == 'V'
    or current_mode == '\22'
    or current_mode == 's'
    or current_mode == 'S'
    or current_mode == '\19'

  local mode = in_selection and normalize_mode(current_mode) or vim.fn.visualmode()
  if mode ~= 'v' and mode ~= 'V' and mode ~= '\22' then mode = 'v' end

  local pos1
  local pos2
  if in_selection then
    pos1 = vim.fn.getpos('v')
    pos2 = vim.fn.getpos('.')
  else
    if not (opts and opts.from_visual) then return nil end
    pos1 = vim.fn.getpos("'<")
    pos2 = vim.fn.getpos("'>")
  end
  if type(pos1) ~= 'table' or type(pos2) ~= 'table' then return nil end

  local start_line, start_col = pos1[2], (pos1[3] or 1) - 1
  local end_line, end_col = pos2[2], (pos2[3] or 1) - 1
  if start_line == 0 or end_line == 0 then return nil end

  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    pos1, pos2 = pos2, pos1
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  if mode == 'V' or mode == '\22' then
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
    return table.concat(lines, '\n'), start_line, end_line, mode
  end

  local ok, region = pcall(vim.fn.getregion, pos1, pos2, { type = mode })
  if ok and type(region) == 'table' and #region > 0 then
    return table.concat(region, '\n'), start_line, end_line, mode
  end

  local end_col_exclusive = end_col + 1
  local last_line = vim.api.nvim_buf_get_lines(bufnr, end_line - 1, end_line, false)[1] or ''
  if end_col_exclusive > #last_line then end_col_exclusive = #last_line end

  local chunks =
    vim.api.nvim_buf_get_text(bufnr, start_line - 1, start_col, end_line - 1, end_col_exclusive, {})
  return table.concat(chunks, '\n'), start_line, end_line, mode
end

function M.ensure_size_ok(kind, size, limit)
  if not limit or limit <= 0 then return true end
  if size <= limit then return true end
  local msg = ('This %s is %d bytes (limit %d). Copy anyway?'):format(kind, size, limit)
  return util.confirm('prompt-yank.nvim', msg)
end

function M.read_file(fullpath, max_bytes)
  local size = util.file_size(fullpath)
  if size and max_bytes and max_bytes > 0 and size > max_bytes then
    local ok = M.ensure_size_ok('file', size, max_bytes)
    if not ok then return nil, 'skipped (too large)' end
  end

  local ok, lines = pcall(vim.fn.readfile, fullpath)
  if not ok then return nil, 'failed to read file' end
  return table.concat(lines, '\n'), nil
end

function M.join_blocks(blocks)
  local conf = config.get()
  local sep = conf.templates.multi_sep or '\n\n'
  return table.concat(blocks, sep)
end

return M
