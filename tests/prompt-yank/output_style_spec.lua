local config = require('prompt-yank.config')
local format = require('prompt-yank.format')
local py = require('prompt-yank')

local function stub(module, overrides, fn)
  local originals = {}
  for key, value in pairs(overrides or {}) do
    originals[key] = module[key]
    module[key] = value
  end
  local ok, res = pcall(fn)
  for key, value in pairs(originals) do
    module[key] = value
  end
  if not ok then error(res) end
  return res
end

describe('output_style', function()
  local original_cwd
  local cleanup = {}

  local function track(path)
    table.insert(cleanup, path)
    return path
  end

  local function make_root()
    local root = track(vim.fn.tempname())
    vim.fn.mkdir(root, 'p')
    vim.api.nvim_set_current_dir(root)
    return root
  end

  local function make_buffer(root, relpath, lines, filetype)
    local fullpath = root .. '/' .. relpath
    vim.fn.mkdir(vim.fn.fnamemodify(fullpath, ':h'), 'p')
    vim.fn.writefile(lines, fullpath)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_name(bufnr, fullpath)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    if filetype then vim.bo[bufnr].filetype = filetype end
    return bufnr, fullpath
  end

  before_each(function() original_cwd = vim.fn.getcwd() end)

  after_each(function()
    for _, path in ipairs(cleanup) do
      pcall(vim.fn.delete, path, 'rf')
    end
    cleanup = {}
    pcall(vim.api.nvim_set_current_dir, original_cwd)
  end)

  describe('config', function()
    it('defaults to markdown output_style', function()
      config.setup({})
      local conf = config.get()
      assert.equals('markdown', conf.output_style)
      assert.equals('default', conf.format)
    end)

    it('sets format to xml when output_style is xml', function()
      config.setup({ output_style = 'xml' })
      local conf = config.get()
      assert.equals('xml', conf.output_style)
      assert.equals('xml', conf.format)
    end)

    it('preserves explicit format even when output_style is xml', function()
      config.setup({ output_style = 'xml', format = 'claude' })
      local conf = config.get()
      assert.equals('xml', conf.output_style)
      assert.equals('claude', conf.format)
    end)
  end)

  describe('set_output_style', function()
    it('switches from markdown to xml at runtime', function()
      config.setup({})
      assert.equals('markdown', config.get().output_style)
      assert.equals('default', config.get().format)

      local ok = config.set_output_style('xml')
      assert.is_true(ok)
      assert.equals('xml', config.get().output_style)
      assert.equals('xml', config.get().format)
    end)

    it('switches from xml back to markdown at runtime', function()
      config.setup({ output_style = 'xml' })
      assert.equals('xml', config.get().output_style)

      local ok = config.set_output_style('markdown')
      assert.is_true(ok)
      assert.equals('markdown', config.get().output_style)
      assert.equals('default', config.get().format)
    end)

    it('rejects invalid style names', function()
      config.setup({})
      local ok, err = config.set_output_style('json')
      assert.is_false(ok)
      assert.is_true(err:find('unknown output_style') ~= nil)
    end)

    it('rejects empty string', function()
      config.setup({})
      local ok, err = config.set_output_style('')
      assert.is_false(ok)
      assert.is_true(err:find('non%-empty') ~= nil)
    end)

    it('affects template resolution after switch', function()
      config.setup({})
      local tpl_md = config.resolve_template('diagnostics')
      assert.is_true(tpl_md:find('**Diagnostics:**', 1, true) ~= nil)

      config.set_output_style('xml')
      local tpl_xml = config.resolve_template('diagnostics')
      assert.is_true(tpl_xml:find('<diagnostics>', 1, true) ~= nil)

      config.set_output_style('markdown')
      local tpl_md2 = config.resolve_template('diagnostics')
      assert.is_true(tpl_md2:find('**Diagnostics:**', 1, true) ~= nil)
    end)
  end)

  describe('resolve_template', function()
    it('returns markdown templates by default', function()
      config.setup({})
      local tpl = config.resolve_template('diagnostics')
      assert.is_true(tpl:find('**Diagnostics:**', 1, true) ~= nil)
    end)

    it('returns xml templates when output_style is xml', function()
      config.setup({ output_style = 'xml' })
      local tpl = config.resolve_template('diagnostics')
      assert.is_true(tpl:find('<diagnostics>', 1, true) ~= nil)
    end)

    it('falls back to markdown template if xml template is missing', function()
      config.setup({ output_style = 'xml' })
      local conf = config.get()
      conf.xml_templates.diagnostics = nil
      local tpl = config.resolve_template('diagnostics')
      assert.is_true(tpl:find('**Diagnostics:**', 1, true) ~= nil)
    end)
  end)

  describe('code block format', function()
    it('renders markdown code block by default', function()
      config.setup({})
      local ctx = {
        filepath = 'src/main.lua',
        lines_hash = '#L1-L5',
        lines_plain = '1-5',
        lang = 'lua',
        code = 'print("hi")',
      }
      local out = format.render_code_block(ctx)
      assert.is_true(out:find('```lua', 1, true) ~= nil)
      assert.is_true(out:find('`src/main.lua#L1-L5`', 1, true) ~= nil)
    end)

    it('renders xml code block when output_style is xml', function()
      config.setup({ output_style = 'xml' })
      local ctx = {
        filepath = 'src/main.lua',
        lines_hash = '#L1-L5',
        lines_plain = '1-5',
        lang = 'lua',
        code = 'print("hi")',
      }
      local out = format.render_code_block(ctx)
      assert.is_true(out:find('<file path="src/main.lua"', 1, true) ~= nil)
      assert.is_true(out:find('print("hi")', 1, true) ~= nil)
    end)
  end)

  describe('named templates', function()
    it('renders xml diff_file template', function()
      config.setup({ output_style = 'xml' })
      local ctx = {
        filepath = 'app.lua',
        lines_plain = '',
        lang = 'lua',
        diff = '+ new line',
      }
      local out = format.render_named_template('diff_file', ctx)
      assert.is_true(out:find('<diff path="app.lua"', 1, true) ~= nil)
      assert.is_true(out:find('+ new line', 1, true) ~= nil)
    end)

    it('renders xml blame_selection template', function()
      config.setup({ output_style = 'xml' })
      local ctx = {
        filepath = 'app.lua',
        lines_plain = '1-5',
        lang = 'lua',
        blame = 'abc123 line content',
      }
      local out = format.render_named_template('blame_selection', ctx)
      assert.is_true(out:find('<blame path="app.lua" lines="1-5"', 1, true) ~= nil)
    end)

    it('renders xml tree_full template', function()
      config.setup({ output_style = 'xml' })
      local ctx = {
        project_name = 'myproject',
        project_tree = '└── main.lua',
      }
      local out = format.render_named_template('tree_full', ctx)
      assert.is_true(out:find('<project name="myproject">', 1, true) ~= nil)
      assert.is_true(out:find('└── main.lua', 1, true) ~= nil)
    end)

    it('renders xml function_named template', function()
      config.setup({ output_style = 'xml' })
      local ctx = {
        symbol_name = 'my_func',
        filepath = 'app.lua',
        lines_plain = '5-10',
        lang = 'lua',
        code = 'function my_func() end',
      }
      local out = format.render_named_template('function_named', ctx)
      assert.is_true(out:find('<function name="my_func"', 1, true) ~= nil)
    end)

    it('renders xml definition_item template', function()
      config.setup({ output_style = 'xml' })
      local ctx = {
        name = 'doStuff',
        filepath = 'lib.lua',
        start_line = 10,
        end_line = 20,
        lang = 'lua',
        code = 'function doStuff() end',
      }
      local out = format.render_named_template('definition_item', ctx)
      assert.is_true(out:find('<definition name="doStuff"', 1, true) ~= nil)
      assert.is_true(out:find('lines="10-20"', 1, true) ~= nil)
    end)
  end)

  describe('integration', function()
    it('yank_file uses xml format', function()
      local root = make_root()
      config.setup({
        output_style = 'xml',
        notify = false,
        register = '"',
        root = { strategy = 'cwd' },
        path_style = 'relative',
      })
      make_buffer(root, 'file.lua', { 'line1', 'line2' }, 'lua')

      local text = py.yank_file({ notify = false, register = '"' })
      assert.is_true(text:find('<file path="file.lua"', 1, true) ~= nil)
      assert.is_true(text:find('line1\nline2', 1, true) ~= nil)
    end)

    it('yank_diff uses xml template', function()
      local root = make_root()
      config.setup({
        output_style = 'xml',
        notify = false,
        register = '"',
        root = { strategy = 'cwd' },
        path_style = 'relative',
      })
      make_buffer(root, 'diff.lua', { 'line1', 'line2' }, 'lua')

      local git = require('prompt-yank.git')
      local text = stub(git, {
        diff_for_file = function() return 'DIFF' end,
      }, function() return py.yank_diff({ notify = false, register = '"' }) end)

      assert.is_true(text:find('<diff path="diff.lua"', 1, true) ~= nil)
      assert.is_true(text:find('DIFF', 1, true) ~= nil)
    end)

    it('yank_function uses xml function_named template', function()
      local root = make_root()
      config.setup({
        output_style = 'xml',
        notify = false,
        register = '"',
        root = { strategy = 'cwd' },
        path_style = 'relative',
      })
      make_buffer(root, 'func.lua', { 'line1', 'line2', 'line3' }, 'lua')

      local ts = require('prompt-yank.treesitter')
      local text = stub(ts, {
        current_container = function()
          return { start_line = 1, end_line = 2, name = 'my_func', node_type = 'function' }
        end,
      }, function() return py.yank_function({ notify = false, register = '"' }) end)

      assert.is_true(text:find('<function name="my_func"', 1, true) ~= nil)
    end)

    it('yank_diagnostics uses xml template', function()
      local root = make_root()
      config.setup({
        output_style = 'xml',
        notify = false,
        register = '"',
        root = { strategy = 'cwd' },
        path_style = 'relative',
      })
      local bufnr = make_buffer(root, 'diag.lua', { 'l1', 'l2', 'l3' }, 'lua')

      local ns = vim.api.nvim_create_namespace('prompt-yank-test-xml')
      vim.diagnostic.set(ns, bufnr, {
        { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'Boom' },
      })

      local text =
        py.yank_diagnostics({ line_start = 1, line_end = 2, notify = false, register = '"' })
      assert.is_true(text:find('<diagnostics>', 1, true) ~= nil)
      assert.is_true(text:find('</diagnostics>', 1, true) ~= nil)
    end)
  end)
end)
