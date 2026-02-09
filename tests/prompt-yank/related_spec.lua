local config = require('prompt-yank.config')
local related = require('prompt-yank.related')
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

describe('prompt-yank.related', function()
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

  local function write_file(root, relpath, lines)
    local fullpath = root .. '/' .. relpath
    vim.fn.mkdir(vim.fn.fnamemodify(fullpath, ':h'), 'p')
    vim.fn.writefile(lines, fullpath)
    return fullpath
  end

  local function make_buffer(root, relpath, lines, filetype)
    local fullpath = write_file(root, relpath, lines)
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

  describe('resolve_import', function()
    it('resolves lua require to file under root', function()
      local root = make_root()
      write_file(root, 'lua/mymod/utils.lua', { 'return {}' })

      local result = related.resolve_import('mymod.utils', root .. '/init.lua', root, 'lua')

      assert.is_not_nil(result)
      assert.is_true(result:find('mymod/utils%.lua') ~= nil)
    end)

    it('resolves lua require to init.lua under root', function()
      local root = make_root()
      write_file(root, 'lua/mymod/init.lua', { 'return {}' })

      local result = related.resolve_import('mymod', root .. '/init.lua', root, 'lua')

      assert.is_not_nil(result)
      assert.is_true(result:find('mymod/init%.lua') ~= nil)
    end)

    it('returns nil for non-existent lua module', function()
      local root = make_root()

      local result = related.resolve_import('nonexistent.module', root .. '/init.lua', root, 'lua')

      assert.is_nil(result)
    end)

    it('resolves relative JS import with extension', function()
      local root = make_root()
      local helper_path = write_file(root, 'src/helpers.ts', { 'export {}' })
      local current = root .. '/src/main.ts'

      local result = related.resolve_import('./helpers.ts', current, root, 'typescript')

      assert.is_not_nil(result)
      assert.is_true(result:find('helpers%.ts') ~= nil)
    end)

    it('resolves relative JS import without extension', function()
      local root = make_root()
      write_file(root, 'src/helpers.ts', { 'export {}' })
      local current = root .. '/src/main.ts'

      local result = related.resolve_import('./helpers', current, root, 'typescript')

      assert.is_not_nil(result)
      assert.is_true(result:find('helpers%.ts') ~= nil)
    end)

    it('resolves JS directory import to index file', function()
      local root = make_root()
      write_file(root, 'src/utils/index.ts', { 'export {}' })
      local current = root .. '/src/main.ts'

      local result = related.resolve_import('./utils', current, root, 'typescript')

      assert.is_not_nil(result)
      assert.is_true(result:find('utils/index%.ts') ~= nil)
    end)

    it('returns nil for non-relative JS import', function()
      local root = make_root()

      local result = related.resolve_import('lodash', root .. '/src/main.ts', root, 'typescript')

      assert.is_nil(result)
    end)

    it('resolves relative python import', function()
      local root = make_root()
      write_file(root, 'src/helpers.py', { 'pass' })
      local current = root .. '/src/main.py'

      local result = related.resolve_import('.helpers', current, root, 'python')

      assert.is_not_nil(result)
      assert.is_true(result:find('helpers%.py') ~= nil)
    end)

    it('resolves absolute python import', function()
      local root = make_root()
      write_file(root, 'mypackage/utils.py', { 'pass' })

      local result = related.resolve_import('mypackage.utils', root .. '/main.py', root, 'python')

      assert.is_not_nil(result)
      assert.is_true(result:find('mypackage/utils%.py') ~= nil)
    end)

    it('resolves double-dot relative python import', function()
      local root = make_root()
      write_file(root, 'pkg/sibling.py', { 'pass' })
      local current = root .. '/pkg/sub/main.py'

      local result = related.resolve_import('..sibling', current, root, 'python')

      assert.is_not_nil(result)
      assert.is_true(result:find('sibling%.py') ~= nil)
    end)

    it('resolves triple-dot relative python import', function()
      local root = make_root()
      write_file(root, 'a/top.py', { 'pass' })
      local current = root .. '/a/b/c/main.py'

      local result = related.resolve_import('...top', current, root, 'python')

      assert.is_not_nil(result)
      assert.is_true(result:find('top%.py') ~= nil)
    end)

    it('resolves bare dot python import to __init__.py', function()
      local root = make_root()
      write_file(root, 'pkg/__init__.py', { 'pass' })
      local current = root .. '/pkg/main.py'

      local result = related.resolve_import('.', current, root, 'python')

      assert.is_not_nil(result)
      assert.is_true(result:find('__init__%.py') ~= nil)
    end)

    it('resolves python import to __init__.py when module is a package', function()
      local root = make_root()
      write_file(root, 'mypackage/__init__.py', { 'pass' })

      local result = related.resolve_import('mypackage', root .. '/main.py', root, 'python')

      assert.is_not_nil(result)
      assert.is_true(result:find('__init__%.py') ~= nil)
    end)

    it('returns nil for non-existent double-dot python import', function()
      local root = make_root()
      local current = root .. '/pkg/sub/main.py'

      local result = related.resolve_import('..nonexistent', current, root, 'python')

      assert.is_nil(result)
    end)

    it('returns nil for unsupported filetype', function()
      local root = make_root()

      local result = related.resolve_import('something', root .. '/main.rb', root, 'ruby')

      assert.is_nil(result)
    end)
  end)

  describe('find_related_files', function()
    it('deduplicates paths', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')
      write_file(root, 'utils.lua', { 'return {}' })
      local utils_path = root .. '/utils.lua'

      local paths = stub(related, {
        imports_from_treesitter = function() return { utils_path } end,
        reference_files_from_lsp = function() return { utils_path } end,
      }, function() return related.find_related_files(bufnr, root, { max_files = 10 }) end)

      local count = 0
      for _, p in ipairs(paths) do
        if p:find('utils%.lua') then count = count + 1 end
      end
      assert.equals(1, count)
    end)

    it('excludes current file', function()
      local root = make_root()
      local bufnr, current = make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')

      local paths = stub(related, {
        imports_from_treesitter = function() return { current } end,
        reference_files_from_lsp = function() return {} end,
      }, function() return related.find_related_files(bufnr, root, { max_files = 10 }) end)

      assert.equals(0, #paths)
    end)

    it('respects max_files limit', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')
      write_file(root, 'a.lua', { 'return {}' })
      write_file(root, 'b.lua', { 'return {}' })
      write_file(root, 'c.lua', { 'return {}' })

      local paths = stub(related, {
        imports_from_treesitter = function()
          return { root .. '/a.lua', root .. '/b.lua', root .. '/c.lua' }
        end,
        reference_files_from_lsp = function() return {} end,
      }, function() return related.find_related_files(bufnr, root, { max_files = 2 }) end)

      assert.equals(2, #paths)
    end)

    it('merges imports and lsp results', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')
      write_file(root, 'import_dep.lua', { 'return {}' })
      write_file(root, 'lsp_dep.lua', { 'return {}' })

      local paths = stub(related, {
        imports_from_treesitter = function() return { root .. '/import_dep.lua' } end,
        reference_files_from_lsp = function() return { root .. '/lsp_dep.lua' } end,
      }, function() return related.find_related_files(bufnr, root, { max_files = 10 }) end)

      assert.equals(2, #paths)
    end)
  end)

  describe('yank_related', function()
    it('copies related files to register', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')
      write_file(root, 'utils.lua', { 'return {}' })

      local text = stub(related, {
        find_related_files = function() return { root .. '/utils.lua' } end,
      }, function() return py.yank_related({ notify = false, register = '"' }) end)

      assert.is_not_nil(text)
      assert.is_true(text:find('utils.lua') ~= nil)
      assert.is_true(text:find('return {}') ~= nil)
    end)

    it('includes current file in output', function()
      local root = make_root()
      make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')
      write_file(root, 'utils.lua', { 'return {}' })

      local text = stub(related, {
        find_related_files = function() return { root .. '/utils.lua' } end,
      }, function() return py.yank_related({ notify = false, register = '"' }) end)

      assert.is_not_nil(text)
      assert.is_true(text:find('main.lua') ~= nil)
      assert.is_true(text:find('local x = 1') ~= nil)
    end)

    it('includes current file even when no related files found', function()
      local root = make_root()
      make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')

      local text = stub(related, {
        find_related_files = function() return {} end,
      }, function() return py.yank_related({ notify = false, register = '"' }) end)

      assert.is_not_nil(text)
      assert.is_true(text:find('main.lua') ~= nil)
      assert.is_true(text:find('local x = 1') ~= nil)
    end)

    it('places current file before related files', function()
      local root = make_root()
      make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')
      write_file(root, 'utils.lua', { 'return {}' })

      local text = stub(related, {
        find_related_files = function() return { root .. '/utils.lua' } end,
      }, function() return py.yank_related({ notify = false, register = '"' }) end)

      assert.is_not_nil(text)
      local main_pos = text:find('main.lua')
      local utils_pos = text:find('utils.lua')
      assert.is_not_nil(main_pos)
      assert.is_not_nil(utils_pos)
      assert.is_true(main_pos < utils_pos)
    end)

    it('returns nil when no file open', function()
      local root = make_root()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)

      local text = py.yank_related({ notify = false, register = '"' })

      assert.is_nil(text)
    end)

    it('includes template wrapper with origin and related count excluding current file', function()
      local root = make_root()
      local bufnr = make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')
      write_file(root, 'a.lua', { 'return 1' })
      write_file(root, 'b.lua', { 'return 2' })

      local text = stub(related, {
        find_related_files = function() return { root .. '/a.lua', root .. '/b.lua' } end,
      }, function() return py.yank_related({ notify = false, register = '"' }) end)

      assert.is_not_nil(text)
      assert.is_true(text:find('Related files for `main.lua`') ~= nil)
      assert.is_true(text:find('%(2%)') ~= nil)
    end)

    it('skips sensitive files', function()
      local root = make_root()
      make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')
      write_file(root, '.env', { 'SECRET=abc' })
      write_file(root, 'safe.lua', { 'return {}' })

      local text = stub(related, {
        find_related_files = function() return { root .. '/.env', root .. '/safe.lua' } end,
      }, function() return py.yank_related({ notify = false, register = '"' }) end)

      assert.is_not_nil(text)
      assert.is_true(text:find('safe.lua') ~= nil)
      assert.is_nil(text:find('SECRET'))
    end)

    it('uses xml template when output_style is xml', function()
      local root = make_root()
      config.setup({
        notify = false,
        register = '"',
        root = { strategy = 'cwd' },
        path_style = 'relative',
        output_style = 'xml',
      })
      make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')
      write_file(root, 'dep.lua', { 'return {}' })

      local text = stub(related, {
        find_related_files = function() return { root .. '/dep.lua' } end,
      }, function() return py.yank_related({ notify = false, register = '"' }) end)

      assert.is_not_nil(text)
      assert.is_true(text:find('<related') ~= nil)
      assert.is_true(text:find('origin="main.lua"') ~= nil)
    end)

    it('respects max_files from config', function()
      local root = make_root()
      config.setup({
        notify = false,
        register = '"',
        root = { strategy = 'cwd' },
        path_style = 'relative',
        related = { max_files = 1 },
      })
      make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')
      write_file(root, 'a.lua', { 'return 1' })
      write_file(root, 'b.lua', { 'return 2' })

      local received_opts
      local text = stub(related, {
        find_related_files = function(_, _, opts)
          received_opts = opts
          return { root .. '/a.lua' }
        end,
      }, function() return py.yank_related({ notify = false, register = '"' }) end)

      assert.equals(1, received_opts.max_files)
    end)

    it('formats multiple related files separated properly', function()
      local root = make_root()
      make_buffer(root, 'main.lua', { 'local x = 1' }, 'lua')
      write_file(root, 'a.lua', { 'return 1' })
      write_file(root, 'b.lua', { 'return 2' })

      local text = stub(related, {
        find_related_files = function() return { root .. '/a.lua', root .. '/b.lua' } end,
      }, function() return py.yank_related({ notify = false, register = '"' }) end)

      assert.is_not_nil(text)
      assert.is_true(text:find('main.lua') ~= nil)
      assert.is_true(text:find('a.lua') ~= nil)
      assert.is_true(text:find('b.lua') ~= nil)
      assert.is_true(text:find('local x = 1') ~= nil)
      assert.is_true(text:find('return 1') ~= nil)
      assert.is_true(text:find('return 2') ~= nil)
    end)
  end)
end)
