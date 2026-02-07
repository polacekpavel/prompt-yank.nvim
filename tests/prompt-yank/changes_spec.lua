local git = require('prompt-yank.git')
local config = require('prompt-yank.config')
local format = require('prompt-yank.format')
local util = require('prompt-yank.util')

describe('prompt-yank.git changes helpers', function()
  describe('diff_stat', function()
    it('returns nil for non-git dir', function()
      local result = git.diff_stat('/tmp/not-a-repo-xyz-9999')
      assert.is_nil(result)
    end)

    it('returns string or nil for current repo', function()
      local root = util.git_root()
      if not root then return pending('not in a git repo') end
      local result = git.diff_stat(root)
      if result then
        assert.is_string(result)
        assert.is_true(#result > 0)
      end
    end)

    it('accepts a scope path', function()
      local root = util.git_root()
      if not root then return pending('not in a git repo') end
      local result = git.diff_stat(root, 'lua')
      if result then assert.is_string(result) end
    end)
  end)

  describe('log', function()
    it('returns nil for non-git dir', function()
      local result = git.log('/tmp/not-a-repo-xyz-9999')
      assert.is_nil(result)
    end)

    it('returns recent commits for current repo', function()
      local root = util.git_root()
      if not root then return pending('not in a git repo') end
      local result = git.log(root, 5)
      if result then
        assert.is_string(result)
        local lines = vim.split(result, '\n')
        assert.is_true(#lines <= 5)
        assert.is_true(#lines >= 1)
      end
    end)

    it('defaults count to 10', function()
      local root = util.git_root()
      if not root then return pending('not in a git repo') end
      local result = git.log(root)
      if result then
        local lines = vim.split(result, '\n')
        assert.is_true(#lines <= 10)
      end
    end)

    it('respects scope parameter', function()
      local root = util.git_root()
      if not root then return pending('not in a git repo') end
      local result = git.log(root, 3, 'lua')
      if result then
        local lines = vim.split(result, '\n')
        assert.is_true(#lines <= 3)
      end
    end)
  end)
end)

describe('prompt-yank.changes templates', function()
  before_each(function() config.setup({ keymaps = false }) end)

  describe('markdown style', function()
    it('renders changes_stat template', function()
      local tpl = config.resolve_template('changes_stat')
      assert.is_not_nil(tpl)
      local rendered = format.render_template(tpl, { diff_stat = ' a.lua | 2 ++\n 1 file changed' })
      assert.truthy(rendered:match('Changed files'))
      assert.truthy(rendered:match('a%.lua'))
    end)

    it('renders changes_log template', function()
      local tpl = config.resolve_template('changes_log')
      assert.is_not_nil(tpl)
      local rendered = format.render_template(
        tpl,
        { commit_log = 'abc1234 fix bug (2 hours ago)', commit_count = 5 }
      )
      assert.truthy(rendered:match('Recent commits'))
      assert.truthy(rendered:match('5'))
      assert.truthy(rendered:match('fix bug'))
    end)

    it('renders changes wrapper template without scope', function()
      local tpl = config.resolve_template('changes')
      assert.is_not_nil(tpl)
      local rendered = format.render_template(tpl, {
        changes_body = 'body here',
        changes_scope = '',
        changes_scope_attr = '',
      })
      assert.truthy(rendered:match('Recent Changes'))
      assert.truthy(rendered:match('body here'))
      assert.is_falsy(rendered:match('scope'))
    end)

    it('renders changes wrapper template with scope', function()
      local tpl = config.resolve_template('changes')
      local rendered = format.render_template(tpl, {
        changes_body = 'body',
        changes_scope = ' (src/app.lua)',
        changes_scope_attr = ' scope="src/app.lua"',
      })
      assert.truthy(rendered:match('src/app%.lua'))
    end)
  end)

  describe('xml style', function()
    before_each(function() config.setup({ keymaps = false, output_style = 'xml' }) end)

    it('renders changes_stat as xml', function()
      local tpl = config.resolve_template('changes_stat')
      assert.is_not_nil(tpl)
      local rendered = format.render_template(tpl, { diff_stat = 'a.lua | 1 +' })
      assert.truthy(rendered:match('<diff%-stat>'))
      assert.truthy(rendered:match('</diff%-stat>'))
    end)

    it('renders changes_log as xml', function()
      local tpl = config.resolve_template('changes_log')
      local rendered =
        format.render_template(tpl, { commit_log = 'abc fix (1 day ago)', commit_count = 3 })
      assert.truthy(rendered:match('<commits'))
      assert.truthy(rendered:match('count="3"'))
    end)

    it('renders changes wrapper as xml with scope attr', function()
      local tpl = config.resolve_template('changes')
      local rendered = format.render_template(tpl, {
        changes_body = 'inner',
        changes_scope = ' (lua)',
        changes_scope_attr = ' scope="lua"',
      })
      assert.truthy(rendered:match('<changes'))
      assert.truthy(rendered:match('scope="lua"'))
      assert.truthy(rendered:match('</changes>'))
    end)
  end)
end)

describe('prompt-yank.config changes defaults', function()
  before_each(function() config.setup({ keymaps = false }) end)

  it('has default commit_count', function()
    local conf = config.get()
    assert.equals(10, conf.changes.commit_count)
  end)

  it('allows overriding commit_count', function()
    config.setup({ keymaps = false, changes = { commit_count = 25 } })
    local conf = config.get()
    assert.equals(25, conf.changes.commit_count)
  end)
end)

describe('prompt-yank.command changes subcommand', function()
  it('is in the subcommands list', function()
    local command = require('prompt-yank.command')
    local completions = command.complete('ch', 'PromptYank ch', 14)
    local found = false
    for _, c in ipairs(completions) do
      if c == 'changes' then
        found = true
        break
      end
    end
    assert.is_true(found, 'Expected "changes" in completions')
  end)
end)
