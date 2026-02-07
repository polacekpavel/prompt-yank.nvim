local config = require('prompt-yank.config')

local M = {}

local subcommands = {
  'file',
  'selection',
  'function',
  'multi',
  'diff',
  'blame',
  'diagnostics',
  'context',
  'tree',
  'remote',
  'definitions',
  'definitions_deep',
  'tokens',
  'format',
  'formats',
  'style',
}

local function as_int(value)
  local n = tonumber(value)
  if not n then return nil end
  n = math.floor(n)
  if n <= 0 then return nil end
  return n
end

function M.run(opts)
  local py = require('prompt-yank')
  local args = opts.fargs or {}
  local sub = args[1]

  if not sub or sub == '' then
    if opts.range and opts.range ~= 0 then return py.yank_range(opts.line1, opts.line2) end
    return py.yank_file()
  end

  if sub == 'file' then return py.yank_file() end

  if sub == 'selection' then
    if opts.range and opts.range ~= 0 then return py.yank_range(opts.line1, opts.line2) end
    local line = vim.api.nvim_win_get_cursor(0)[1]
    return py.yank_range(line, line)
  end

  if sub == 'function' then return py.yank_function() end

  if sub == 'multi' then return py.yank_multi() end

  if sub == 'diff' then
    if opts.range and opts.range ~= 0 then
      return py.yank_diff({ line_start = opts.line1, line_end = opts.line2 })
    end
    return py.yank_diff()
  end

  if sub == 'blame' then
    if opts.range and opts.range ~= 0 then
      return py.yank_blame({ line_start = opts.line1, line_end = opts.line2 })
    end
    return py.yank_blame()
  end

  if sub == 'diagnostics' then
    if opts.range and opts.range ~= 0 then
      return py.yank_diagnostics({ line_start = opts.line1, line_end = opts.line2 })
    end
    local line = vim.api.nvim_win_get_cursor(0)[1]
    return py.yank_diagnostics({ line_start = line, line_end = line })
  end

  if sub == 'context' then
    local n = as_int(args[2])
    local override = n and { context_lines = n } or {}
    if opts.range and opts.range ~= 0 then
      override.line_start = opts.line1
      override.line_end = opts.line2
    end
    return py.yank_context(override)
  end

  if sub == 'tree' then
    local depth = as_int(args[2])
    local override = depth and { depth = depth } or {}
    if opts.range and opts.range ~= 0 then
      override.line_start = opts.line1
      override.line_end = opts.line2
    end
    return py.yank_tree(override)
  end

  if sub == 'remote' then
    if opts.range and opts.range ~= 0 then
      return py.yank_remote({ line_start = opts.line1, line_end = opts.line2 })
    end
    return py.yank_remote()
  end

  if sub == 'definitions' then
    if opts.range and opts.range ~= 0 then
      return py.yank_with_definitions({
        line_start = opts.line1,
        line_end = opts.line2,
        from_visual = true,
      })
    end
    return py.yank_with_definitions({ from_visual = true })
  end

  if sub == 'definitions_deep' then
    local depth = as_int(args[2])
    local override = depth and { max_depth = depth } or {}
    override.from_visual = true
    if opts.range and opts.range ~= 0 then
      override.line_start = opts.line1
      override.line_end = opts.line2
    end
    return py.yank_with_definitions_deep(override)
  end

  if sub == 'tokens' then
    local tokens = require('prompt-yank.tokens')
    local yank = require('prompt-yank.yank')
    local bufnr = 0
    local text
    if opts.range and opts.range ~= 0 then
      text = yank.get_range_text(bufnr, opts.line1, opts.line2)
    else
      local sel = yank.get_visual_selection(bufnr, { from_visual = true })
      if sel then
        text = sel
      else
        text = yank.get_buffer_text(bufnr)
      end
    end
    local count = tokens.estimate(text)
    vim.notify(('prompt-yank: %s'):format(tokens.format_count(count)), vim.log.levels.INFO)
    return
  end

  if sub == 'formats' then
    local formats = config.list_formats()
    vim.notify(table.concat(formats, '\n'), vim.log.levels.INFO)
    return
  end

  if sub == 'format' then
    local name = args[2]
    if not name or name == '' then
      vim.notify(('prompt-yank: format = %s'):format(config.get().format), vim.log.levels.INFO)
      return
    end
    local ok, err = config.set_format(name)
    if ok then
      vim.notify(('prompt-yank: format = %s'):format(name), vim.log.levels.INFO)
    else
      vim.notify(('prompt-yank: %s'):format(err), vim.log.levels.ERROR)
    end
    return
  end

  if sub == 'style' then
    local name = args[2]
    if not name or name == '' then
      vim.notify(
        ('prompt-yank: output_style = %s'):format(config.get().output_style),
        vim.log.levels.INFO
      )
      return
    end
    local ok, err = config.set_output_style(name)
    if ok then
      vim.notify(
        ('prompt-yank: output_style = %s, format = %s'):format(
          config.get().output_style,
          config.get().format
        ),
        vim.log.levels.INFO
      )
    else
      vim.notify(('prompt-yank: %s'):format(err), vim.log.levels.ERROR)
    end
    return
  end

  vim.notify(('prompt-yank: unknown subcommand: %s'):format(sub), vim.log.levels.ERROR)
end

function M.complete(arg_lead, cmd_line, _cursor_pos)
  local after = cmd_line:match('PromptYank%s+(.*)$') or ''
  local parts = vim.split(after, '%s+', { trimempty = true })

  if #parts == 0 then
    return vim.tbl_filter(function(s) return s:find(arg_lead, 1, true) == 1 end, subcommands)
  end

  local first = parts[1]
  if first == 'format' and #parts <= 2 then
    local formats = config.list_formats()
    return vim.tbl_filter(function(s) return s:find(arg_lead, 1, true) == 1 end, formats)
  end

  if first == 'style' and #parts <= 2 then
    local styles = { 'markdown', 'xml' }
    return vim.tbl_filter(function(s) return s:find(arg_lead, 1, true) == 1 end, styles)
  end

  if #parts == 1 then
    return vim.tbl_filter(function(s) return s:find(arg_lead, 1, true) == 1 end, subcommands)
  end

  return {}
end

return M
