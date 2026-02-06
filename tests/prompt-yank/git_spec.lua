local git = require('prompt-yank.git')

describe('prompt-yank.git', function()
  it('normalizes https remotes', function()
    local base = git.normalize_remote_url('https://github.com/user/repo.git')
    assert.equals('https://github.com/user/repo', base)
  end)

  it('strips userinfo from https remotes (token@host)', function()
    local base = git.normalize_remote_url('https://token@github.com/user/repo.git')
    assert.equals('https://github.com/user/repo', base)
  end)

  it('strips userinfo from https remotes (user:pass@host)', function()
    local base = git.normalize_remote_url('https://user:pass@github.com/user/repo.git')
    assert.equals('https://github.com/user/repo', base)
  end)

  it('normalizes ssh remotes', function()
    local base = git.normalize_remote_url('git@github.com:user/repo.git')
    assert.equals('https://github.com/user/repo', base)
  end)

  it('builds GitHub line anchors', function()
    local url =
      git.build_remote_url('https://github.com/user/repo', 'github', 'abc', 'src/a.lua', 1, 3)
    assert.equals('https://github.com/user/repo/blob/abc/src/a.lua#L1-L3', url)
  end)

  it('builds GitLab line anchors', function()
    local url =
      git.build_remote_url('https://gitlab.com/user/repo', 'gitlab', 'abc', 'src/a.lua', 6, 10)
    assert.equals('https://gitlab.com/user/repo/-/blob/abc/src/a.lua#L6-10', url)
  end)
end)
