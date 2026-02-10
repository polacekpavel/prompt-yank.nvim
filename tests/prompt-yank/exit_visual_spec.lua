local config = require('prompt-yank.config')
local py = require('prompt-yank')

describe('prompt-yank exit_visual', function()
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

  local function feed(keys)
    local k = vim.api.nvim_replace_termcodes(keys, true, false, true)
    vim.api.nvim_feedkeys(k, 'x', false)
  end

  before_each(function() original_cwd = vim.fn.getcwd() end)

  after_each(function()
    pcall(feed, '<Esc>')
    for _, path in ipairs(cleanup) do
      pcall(vim.fn.delete, path, 'rf')
    end
    cleanup = {}
    pcall(vim.api.nvim_set_current_dir, original_cwd)
  end)

  it('defaults exit_visual to true', function()
    config.setup({})
    local conf = config.get()
    assert.is_true(conf.exit_visual)
  end)

  it('allows exit_visual to be set to false', function()
    config.setup({ exit_visual = false })
    local conf = config.get()
    assert.is_false(conf.exit_visual)
  end)

  it('exits visual mode after copy_selection keymap when exit_visual is true', function()
    local root = make_root()
    make_buffer(root, 'ev.lua', { 'aaa', 'bbb', 'ccc' }, 'lua')

    config.setup({
      notify = false,
      register = '"',
      root = { strategy = 'cwd' },
      exit_visual = true,
      keymaps = {
        copy_selection = '<Leader>yp',
        copy_file = '<Leader>yp',
      },
    })
    py.setup({
      notify = false,
      register = '"',
      root = { strategy = 'cwd' },
      exit_visual = true,
      keymaps = {
        copy_selection = '<Leader>yp',
        copy_file = '<Leader>yp',
      },
    })

    feed('ggVj')
    vim.wait(50, function()
      local m = vim.fn.mode()
      return m == 'V' or m == 'v'
    end)

    feed('<Leader>yp')
    vim.wait(100)

    local mode = vim.fn.mode()
    assert.equals('n', mode)
  end)

  it('stays in visual mode after copy_selection keymap when exit_visual is false', function()
    local root = make_root()
    make_buffer(root, 'ev2.lua', { 'aaa', 'bbb', 'ccc' }, 'lua')

    py.setup({
      notify = false,
      register = '"',
      root = { strategy = 'cwd' },
      exit_visual = false,
      keymaps = {
        copy_selection = '<Leader>yp',
        copy_file = '<Leader>yp',
      },
    })

    feed('ggVj')
    vim.wait(50, function()
      local m = vim.fn.mode()
      return m == 'V' or m == 'v'
    end)

    feed('<Leader>yp')
    vim.wait(100)

    local mode = vim.fn.mode()
    assert.not_equals('n', mode)
  end)
end)
