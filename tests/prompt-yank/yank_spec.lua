local yank = require('prompt-yank.yank')

describe('prompt-yank.yank copy register', function()
  local config = require('prompt-yank.config')

  before_each(function() config.setup({ notify = false, register = '+' }) end)

  it('copies to a single register string', function()
    config.setup({ notify = false, register = '"' })
    yank.copy('hello')
    assert.equals('hello', vim.fn.getreg('"'))
  end)

  it('copies to multiple registers when register is a list', function()
    config.setup({ notify = false, register = { '*', '+' } })
    yank.copy('multi')
    assert.equals('multi', vim.fn.getreg('*'))
    assert.equals('multi', vim.fn.getreg('+'))
  end)

  it('opts.register list overrides config', function()
    config.setup({ notify = false, register = '"' })
    yank.copy('override', { register = { 'a', 'b' } })
    assert.equals('override', vim.fn.getreg('a'))
    assert.equals('override', vim.fn.getreg('b'))
  end)

  it('opts.register string overrides config', function()
    config.setup({ notify = false, register = '"' })
    yank.copy('single', { register = 'a' })
    assert.equals('single', vim.fn.getreg('a'))
  end)
end)

describe('prompt-yank.yank ctx placeholders', function()
  it('computes line placeholders for ranges', function()
    local ctx = yank.build_ctx_for_path('/tmp/a.lua', '/tmp', 'x', 'lua', 1, 3)
    assert.equals('#L1-L3', ctx.lines_hash)
    assert.equals('L1-L3', ctx.lines_md)
    assert.equals('1-3', ctx.lines_plain)
  end)

  it('omits line placeholders when absent', function()
    local ctx = yank.build_ctx_for_path('/tmp/a.lua', '/tmp', 'x', 'lua')
    assert.equals('', ctx.lines_hash)
    assert.equals('', ctx.lines_md)
    assert.equals('', ctx.lines_plain)
  end)

  it('extracts selection from visual marks when invoked from visual mode', function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'aaa', 'bbb', 'ccc' })

    vim.api.nvim_buf_set_mark(bufnr, '<', 1, 0, {})
    vim.api.nvim_buf_set_mark(bufnr, '>', 2, 999, {})

    local code, l1, l2 = yank.get_visual_selection(bufnr, { from_visual = true })
    assert.equals('aaa\nbbb', code)
    assert.equals(1, l1)
    assert.equals(2, l2)
  end)

  it('does not treat stale visual marks as a selection in normal mode', function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'aaa', 'bbb', 'ccc' })

    vim.api.nvim_buf_set_mark(bufnr, '<', 1, 0, {})
    vim.api.nvim_buf_set_mark(bufnr, '>', 2, 999, {})

    local code = yank.get_visual_selection(bufnr)
    assert.is_nil(code)
  end)

  it('extracts selection in select mode (avoids stale marks)', function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'l1',
      'l2',
      'l3',
      'l4',
      'l5',
      'l6',
      'l7',
      'l8',
      'l9',
      'l10',
    })

    local function feed(keys)
      local k = vim.api.nvim_replace_termcodes(keys, true, false, true)
      vim.api.nvim_feedkeys(k, 'x', false)
    end

    -- Set up stale visual marks by making a prior selection and leaving it.
    feed('ggVj<Esc>')
    vim.wait(100)

    -- Now enter Select Line mode with a different (larger) selection.
    feed('ggjjVjjjj<C-g>')
    vim.wait(100, function() return vim.fn.mode() == 'S' end)

    local code, l1, l2, mode = yank.get_visual_selection(bufnr)
    assert.equals(3, l1)
    assert.equals(7, l2)
    assert.equals('V', mode)
    assert.equals('l3\nl4\nl5\nl6\nl7', code)
  end)
end)
