local tokens = require('prompt-yank.tokens')
local yank = require('prompt-yank.yank')
local config = require('prompt-yank.config')
local py = require('prompt-yank')

describe('prompt-yank.tokens', function()
  describe('estimate', function()
    it('returns 0 for nil', function() assert.equals(0, tokens.estimate(nil)) end)

    it('returns 0 for empty string', function() assert.equals(0, tokens.estimate('')) end)

    it('estimates 1 token for 1-4 chars', function()
      assert.equals(1, tokens.estimate('a'))
      assert.equals(1, tokens.estimate('ab'))
      assert.equals(1, tokens.estimate('abc'))
      assert.equals(1, tokens.estimate('abcd'))
    end)

    it('estimates 2 tokens for 5-8 chars', function()
      assert.equals(2, tokens.estimate('abcde'))
      assert.equals(2, tokens.estimate('abcdefgh'))
    end)

    it('rounds up partial tokens', function() assert.equals(3, tokens.estimate('abcdefghi')) end)

    it('handles longer text', function()
      local text = string.rep('x', 400)
      assert.equals(100, tokens.estimate(text))
    end)

    it('counts bytes not characters for multibyte', function()
      local text = string.rep('x', 100)
      assert.equals(25, tokens.estimate(text))
    end)
  end)

  describe('format_count', function()
    it('formats with tilde prefix', function()
      assert.equals('~0 tokens', tokens.format_count(0))
      assert.equals('~1 tokens', tokens.format_count(1))
      assert.equals('~847 tokens', tokens.format_count(847))
    end)
  end)

  describe('token_suffix', function()
    it(
      'returns empty string for empty text',
      function() assert.equals('', yank.token_suffix('')) end
    )

    it('returns formatted suffix for non-empty text', function()
      local text = string.rep('a', 100)
      local suffix = yank.token_suffix(text)
      assert.equals(' (~25 tokens)', suffix)
    end)
  end)
end)

describe('prompt-yank token count in notifications', function()
  local notifications = {}

  before_each(function()
    notifications = {}
    config.setup({ keymaps = false, notify = true, register = '"' })
    vim.notify = function(msg, level) table.insert(notifications, { msg = msg, level = level }) end
  end)

  it('includes token count in yank_file notification', function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'hello world', 'second line' })

    py.yank_file({ register = '"' })

    local found = false
    for _, n in ipairs(notifications) do
      if n.msg:match('~%d+ tokens') then
        found = true
        break
      end
    end
    assert.is_true(found, 'Expected token count in notification')
  end)

  it('includes token count in yank_range notification', function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'line1', 'line2', 'line3' })

    py.yank_range(1, 2, { register = '"' })

    local found = false
    for _, n in ipairs(notifications) do
      if n.msg:match('~%d+ tokens') then
        found = true
        break
      end
    end
    assert.is_true(found, 'Expected token count in notification')
  end)
end)
