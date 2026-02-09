local config = require('prompt-yank.config')
local lsp = require('prompt-yank.lsp')
local py = require('prompt-yank')

local function code_block(filepath, lines_hash, lang, code)
  return ('`%s%s`\n```%s\n%s\n```'):format(filepath, lines_hash or '', lang or '', code or '')
end

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

describe('prompt-yank.lsp', function()
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

  before_each(function()
    original_cwd = vim.fn.getcwd()
    config.setup({
      notify = false,
      register = '"',
      root = { strategy = 'cwd' },
      path_style = 'relative',
    })
  end)

  after_each(function()
    for _, path in ipairs(cleanup) do
      pcall(vim.fn.delete, path, 'rf')
    end
    cleanup = {}
    pcall(vim.api.nvim_set_current_dir, original_cwd)
  end)

  describe('format_definition', function()
    it('formats a definition with file and line info', function()
      local root = make_root()
      local def = {
        name = 'my_func',
        filepath = root .. '/utils.lua',
        start_line = 10,
        end_line = 15,
        code = 'function my_func()\n  return true\nend',
      }

      local result = lsp.format_definition(def, root)

      assert.is_true(result:find('utils.lua#L10%-L15') ~= nil)
      assert.is_true(result:find('definition: my_func') ~= nil)
      assert.is_true(result:find('function my_func') ~= nil)
    end)
  end)

  describe('format_definitions', function()
    it('formats multiple definitions separated by newlines', function()
      local root = make_root()
      local definitions = {
        {
          name = 'func_a',
          filepath = root .. '/a.lua',
          start_line = 1,
          end_line = 3,
          code = 'function func_a() end',
        },
        {
          name = 'func_b',
          filepath = root .. '/b.lua',
          start_line = 5,
          end_line = 10,
          code = 'function func_b() end',
        },
      }

      local result = lsp.format_definitions(definitions, root)

      assert.is_true(result:find('a.lua#L1%-L3') ~= nil)
      assert.is_true(result:find('b.lua#L5%-L10') ~= nil)
      assert.is_true(result:find('func_a') ~= nil)
      assert.is_true(result:find('func_b') ~= nil)
    end)
  end)

  describe('yank_with_definitions', function()
    it('copies selection when no definitions are found', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = 1', 'print(x)' }, 'lua')

      vim.api.nvim_buf_set_mark(bufnr, '<', 1, 0, {})
      vim.api.nvim_buf_set_mark(bufnr, '>', 2, 999, {})

      local text = stub(
        lsp,
        {
          get_definitions_for_selection = function() return {} end,
        },
        function()
          return py.yank_with_definitions({ from_visual = true, notify = false, register = '"' })
        end
      )

      local expected = code_block('main.lua', '#L1-L2', 'lua', 'local x = 1\nprint(x)')
      assert.equals(expected, text)
    end)

    it('includes definitions when found', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = helper()', 'print(x)' }, 'lua')

      vim.api.nvim_buf_set_mark(bufnr, '<', 1, 0, {})
      vim.api.nvim_buf_set_mark(bufnr, '>', 1, 999, {})

      local text = stub(
        lsp,
        {
          get_definitions_for_selection = function()
            return {
              {
                name = 'helper',
                filepath = root .. '/utils.lua',
                start_line = 1,
                end_line = 3,
                code = 'function helper()\n  return 42\nend',
              },
            }
          end,
        },
        function()
          return py.yank_with_definitions({ from_visual = true, notify = false, register = '"' })
        end
      )

      assert.is_true(text:find('main.lua#L1') ~= nil)
      assert.is_true(text:find('Referenced Definitions') ~= nil)
      assert.is_true(text:find('utils.lua#L1%-L3') ~= nil)
      assert.is_true(text:find('definition: helper') ~= nil)
    end)
  end)

  describe('yank_with_definitions_deep', function()
    it('copies selection when no definitions are found', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')

      vim.api.nvim_buf_set_mark(bufnr, '<', 1, 0, {})
      vim.api.nvim_buf_set_mark(bufnr, '>', 1, 999, {})

      local text = stub(
        lsp,
        {
          get_definitions_deep = function() return {} end,
        },
        function()
          return py.yank_with_definitions_deep({
            from_visual = true,
            notify = false,
            register = '"',
          })
        end
      )

      local expected = code_block('main.lua', '#L1', 'lua', 'local x = 1')
      assert.equals(expected, text)
    end)

    it('includes deep definitions with depth info', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = outer()' }, 'lua')

      vim.api.nvim_buf_set_mark(bufnr, '<', 1, 0, {})
      vim.api.nvim_buf_set_mark(bufnr, '>', 1, 999, {})

      local text = stub(
        lsp,
        {
          get_definitions_deep = function()
            return {
              {
                name = 'outer',
                filepath = root .. '/outer.lua',
                start_line = 1,
                end_line = 3,
                code = 'function outer() return inner() end',
                depth = 1,
              },
              {
                name = 'inner',
                filepath = root .. '/inner.lua',
                start_line = 1,
                end_line = 3,
                code = 'function inner() return 42 end',
                depth = 2,
              },
            }
          end,
        },
        function()
          return py.yank_with_definitions_deep({
            from_visual = true,
            notify = false,
            register = '"',
          })
        end
      )

      assert.is_true(text:find('main.lua#L1') ~= nil)
      assert.is_true(text:find('Referenced Definitions %(deep%)') ~= nil)
      assert.is_true(text:find('outer.lua') ~= nil)
      assert.is_true(text:find('inner.lua') ~= nil)
    end)
  end)

  describe('format_definition edge cases', function()
    it('handles single-line definitions', function()
      local root = make_root()
      local def = {
        name = 'MAX_SIZE',
        filepath = root .. '/constants.lua',
        start_line = 5,
        end_line = 5,
        code = 'local MAX_SIZE = 100',
      }

      local result = lsp.format_definition(def, root)

      assert.is_true(result:find('constants.lua#L5%-L5') ~= nil)
      assert.is_true(result:find('definition: MAX_SIZE') ~= nil)
    end)

    it('handles definitions with special characters in name', function()
      local root = make_root()
      local def = {
        name = '_privateFunc',
        filepath = root .. '/utils.lua',
        start_line = 1,
        end_line = 3,
        code = 'local function _privateFunc() end',
      }

      local result = lsp.format_definition(def, root)

      assert.is_true(result:find('definition: _privateFunc') ~= nil)
    end)

    it('handles empty code gracefully', function()
      local root = make_root()
      local def = {
        name = 'empty',
        filepath = root .. '/empty.lua',
        start_line = 1,
        end_line = 1,
        code = '',
      }

      local result = lsp.format_definition(def, root)

      assert.is_true(result:find('definition: empty') ~= nil)
      assert.is_true(result:find('```lua') ~= nil)
    end)
  end)

  describe('format_definitions edge cases', function()
    it('returns empty string for empty definitions list', function()
      local root = make_root()
      local result = lsp.format_definitions({}, root)
      assert.equals('', result)
    end)

    it('handles single definition without extra separators', function()
      local root = make_root()
      local definitions = {
        {
          name = 'only_one',
          filepath = root .. '/single.lua',
          start_line = 1,
          end_line = 2,
          code = 'function only_one() end',
        },
      }

      local result = lsp.format_definitions(definitions, root)

      assert.is_true(result:find('only_one') ~= nil)
      assert.is_nil(result:find('\n\n\n'))
    end)

    it('handles definitions from same file', function()
      local root = make_root()
      local definitions = {
        {
          name = 'func1',
          filepath = root .. '/shared.lua',
          start_line = 1,
          end_line = 3,
          code = 'function func1() end',
        },
        {
          name = 'func2',
          filepath = root .. '/shared.lua',
          start_line = 5,
          end_line = 7,
          code = 'function func2() end',
        },
      }

      local result = lsp.format_definitions(definitions, root)

      assert.is_true(result:find('shared.lua#L1%-L3') ~= nil)
      assert.is_true(result:find('shared.lua#L5%-L7') ~= nil)
    end)
  end)

  describe('yank_with_definitions edge cases', function()
    it('handles multiple definitions from same file', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local a = foo() + bar()' }, 'lua')

      vim.api.nvim_buf_set_mark(bufnr, '<', 1, 0, {})
      vim.api.nvim_buf_set_mark(bufnr, '>', 1, 999, {})

      local text = stub(
        lsp,
        {
          get_definitions_for_selection = function()
            return {
              {
                name = 'foo',
                filepath = root .. '/utils.lua',
                start_line = 1,
                end_line = 3,
                code = 'function foo() return 1 end',
              },
              {
                name = 'bar',
                filepath = root .. '/utils.lua',
                start_line = 5,
                end_line = 7,
                code = 'function bar() return 2 end',
              },
            }
          end,
        },
        function()
          return py.yank_with_definitions({ from_visual = true, notify = false, register = '"' })
        end
      )

      assert.is_true(text:find('definition: foo') ~= nil)
      assert.is_true(text:find('definition: bar') ~= nil)
    end)

    it('handles definitions from different files', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = a.method() + b.other()' }, 'lua')

      vim.api.nvim_buf_set_mark(bufnr, '<', 1, 0, {})
      vim.api.nvim_buf_set_mark(bufnr, '>', 1, 999, {})

      local text = stub(
        lsp,
        {
          get_definitions_for_selection = function()
            return {
              {
                name = 'method',
                filepath = root .. '/module_a.lua',
                start_line = 10,
                end_line = 15,
                code = 'function M.method() end',
              },
              {
                name = 'other',
                filepath = root .. '/module_b.lua',
                start_line = 20,
                end_line = 25,
                code = 'function M.other() end',
              },
            }
          end,
        },
        function()
          return py.yank_with_definitions({ from_visual = true, notify = false, register = '"' })
        end
      )

      assert.is_true(text:find('module_a.lua') ~= nil)
      assert.is_true(text:find('module_b.lua') ~= nil)
    end)

    it('returns nil when no visual selection', function()
      local root = make_root()
      make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')

      local text = py.yank_with_definitions({ from_visual = false, notify = false, register = '"' })

      assert.is_nil(text)
    end)
  end)

  describe('yank_with_definitions_deep edge cases', function()
    it('respects max_depth option', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = level1()' }, 'lua')

      vim.api.nvim_buf_set_mark(bufnr, '<', 1, 0, {})
      vim.api.nvim_buf_set_mark(bufnr, '>', 1, 999, {})

      local received_opts
      local text = stub(
        lsp,
        {
          get_definitions_deep = function(_, _, _, opts)
            received_opts = opts
            return {}
          end,
        },
        function()
          return py.yank_with_definitions_deep({
            from_visual = true,
            notify = false,
            register = '"',
            max_depth = 5,
          })
        end
      )

      assert.equals(5, received_opts.max_depth)
    end)

    it('respects max_definitions option', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = func()' }, 'lua')

      vim.api.nvim_buf_set_mark(bufnr, '<', 1, 0, {})
      vim.api.nvim_buf_set_mark(bufnr, '>', 1, 999, {})

      local received_opts
      stub(
        lsp,
        {
          get_definitions_deep = function(_, _, _, opts)
            received_opts = opts
            return {}
          end,
        },
        function()
          return py.yank_with_definitions_deep({
            from_visual = true,
            notify = false,
            register = '"',
            max_definitions = 100,
          })
        end
      )

      assert.equals(100, received_opts.max_definitions)
    end)

    it('includes all depth levels in output', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = a()' }, 'lua')

      vim.api.nvim_buf_set_mark(bufnr, '<', 1, 0, {})
      vim.api.nvim_buf_set_mark(bufnr, '>', 1, 999, {})

      local text = stub(
        lsp,
        {
          get_definitions_deep = function()
            return {
              {
                name = 'a',
                filepath = root .. '/a.lua',
                start_line = 1,
                end_line = 2,
                code = 'function a() return b() end',
                depth = 1,
              },
              {
                name = 'b',
                filepath = root .. '/b.lua',
                start_line = 1,
                end_line = 2,
                code = 'function b() return c() end',
                depth = 2,
              },
              {
                name = 'c',
                filepath = root .. '/c.lua',
                start_line = 1,
                end_line = 2,
                code = 'function c() return 1 end',
                depth = 3,
              },
            }
          end,
        },
        function()
          return py.yank_with_definitions_deep({
            from_visual = true,
            notify = false,
            register = '"',
          })
        end
      )

      assert.is_true(text:find('a.lua') ~= nil)
      assert.is_true(text:find('b.lua') ~= nil)
      assert.is_true(text:find('c.lua') ~= nil)
    end)
  end)

  describe('filetype-aware identifier filtering', function()
    local function get_names(bufnr, start_line, end_line)
      local info = lsp.debug_selection(bufnr or 0, start_line, end_line)
      local names = {}
      for _, ident in ipairs(info.identifiers) do
        names[ident.name] = true
      end
      return names
    end

    it('skips Python keywords self, cls, True, False, None', function()
      local root = make_root()
      make_buffer(
        root,
        'test.py',
        { 'x = self.value', 'y = True', 'z = None', 'w = False', 'result = cls.create()' },
        'python'
      )

      local names = get_names(0, 1, 5)

      assert.is_nil(names['self'])
      assert.is_nil(names['cls'])
      assert.is_nil(names['True'])
      assert.is_nil(names['False'])
      assert.is_nil(names['None'])
    end)

    it('skips Lua self', function()
      local root = make_root()
      make_buffer(root, 'test.lua', { 'local x = self.value' }, 'lua')

      local names = get_names(0, 1, 1)

      assert.is_nil(names['self'])
    end)

    it('skips JS/TS this, undefined, super', function()
      local root = make_root()
      make_buffer(
        root,
        'test.ts',
        { 'const x = this.value', 'const y = undefined', 'super.init()' },
        'typescript'
      )

      local names = get_names(0, 1, 3)

      assert.is_nil(names['this'])
      assert.is_nil(names['undefined'])
      assert.is_nil(names['super'])
    end)

    it('skips C NULL', function()
      local root = make_root()
      make_buffer(root, 'test.c', { 'int *p = NULL;', 'int x = my_func();' }, 'c')

      local names = get_names(0, 1, 2)

      assert.is_nil(names['NULL'])
    end)

    it('skips C++ this, NULL, nullptr', function()
      local root = make_root()
      make_buffer(
        root,
        'test.cpp',
        { 'auto p = this->value;', 'auto q = NULL;', 'auto r = nullptr;' },
        'cpp'
      )

      local names = get_names(0, 1, 3)

      assert.is_nil(names['this'])
      assert.is_nil(names['NULL'])
      assert.is_nil(names['nullptr'])
    end)

    it('skips Rust self and Self', function()
      local root = make_root()
      make_buffer(root, 'test.rs', { 'let x = self.value;', 'let y = Self::new();' }, 'rust')

      local names = get_names(0, 1, 2)

      assert.is_nil(names['self'])
      assert.is_nil(names['Self'])
    end)

    it('skips Swift self, Self, super', function()
      local root = make_root()
      make_buffer(
        root,
        'test.swift',
        { 'let x = self.value', 'let y = Self.defaultValue', 'super.init()' },
        'swift'
      )

      local names = get_names(0, 1, 3)

      assert.is_nil(names['self'])
      assert.is_nil(names['Self'])
      assert.is_nil(names['super'])
    end)

    it('skips Go common keywords true, false, nil', function()
      local root = make_root()
      make_buffer(
        root,
        'test.go',
        { 'package main', 'var x = true', 'var y = false', 'var z = nil' },
        'go'
      )

      local names = get_names(0, 1, 4)

      assert.is_nil(names['true'])
      assert.is_nil(names['false'])
      assert.is_nil(names['nil'])
    end)

    it('does not skip Python keywords in Lua', function()
      local root = make_root()
      make_buffer(root, 'test.lua', { 'local None = 1', 'local True = 2' }, 'lua')

      local names = get_names(0, 1, 2)

      assert.is_true(names['None'] == true)
      assert.is_true(names['True'] == true)
    end)

    it('does not skip NULL in Lua', function()
      local root = make_root()
      make_buffer(root, 'test.lua', { 'local NULL = 1' }, 'lua')

      local names = get_names(0, 1, 1)

      assert.is_true(names['NULL'] == true)
    end)

    it('does not skip C NULL in Lua', function()
      local root = make_root()
      make_buffer(root, 'test.lua', { 'local NULL = require("something")' }, 'lua')

      local names = get_names(0, 1, 1)

      assert.is_true(names['NULL'] == true)
    end)

    it('skips self in Lua but not NULL', function()
      local root = make_root()
      make_buffer(root, 'test.lua', { 'local x = self.value', 'local NULL = 1' }, 'lua')

      local names = get_names(0, 1, 2)

      assert.is_nil(names['self'])
      assert.is_true(names['NULL'] == true)
    end)

    it('skips NULL in C but not self', function()
      local root = make_root()
      make_buffer(root, 'test.c', { 'int *p = NULL;', 'int self = 1;' }, 'c')

      local names = get_names(0, 1, 2)

      assert.is_nil(names['NULL'])
      assert.is_true(names['self'] == true)
    end)
  end)

  describe('debug_selection', function()
    it('returns debug info structure', function()
      local root = make_root()
      make_buffer(root, 'test.lua', { 'local x = 1', 'print(x)' }, 'lua')

      local info = lsp.debug_selection(0, 1, 2)

      assert.is_table(info)
      assert.is_number(info.buffer)
      assert.is_table(info.range)
      assert.is_table(info.lsp_clients)
      assert.is_number(info.identifiers_found)
      assert.is_table(info.identifiers)
      assert.is_table(info.node_types_in_range)
    end)

    it('includes correct range in output', function()
      local root = make_root()
      make_buffer(root, 'test.lua', { 'line1', 'line2', 'line3' }, 'lua')

      local info = lsp.debug_selection(0, 2, 3)

      assert.equals(2, info.range[1])
      assert.equals(3, info.range[2])
    end)
  end)
end)
