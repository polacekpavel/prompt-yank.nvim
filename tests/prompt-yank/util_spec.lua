local config = require("prompt-yank.config")
local py = require("prompt-yank")
local util = require("prompt-yank.util")

describe("prompt-yank.util", function()
  local original_cwd

  before_each(function()
    config.setup({})
    original_cwd = vim.fn.getcwd()
  end)

  after_each(function()
    pcall(vim.api.nvim_set_current_dir, original_cwd)
  end)

  it("computes relpath_under_root for files inside root", function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root .. "/sub", "p")

    local fullpath = root .. "/sub/file.lua"
    local rel = util.relpath_under_root(fullpath, root)

    assert.equals("sub/file.lua", (rel or ""):gsub("\\", "/"))
    assert.equals("sub/file.lua", util.display_path(fullpath, root, "relative"):gsub("\\", "/"))

    vim.fn.delete(root, "rf")
  end)

  it("returns nil for relpath_under_root when file is outside root", function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")

    local outside_root = vim.fn.tempname()
    vim.fn.mkdir(outside_root, "p")
    local outside_file = outside_root .. "/x.lua"

    vim.api.nvim_set_current_dir(root)

    assert.is_nil(util.relpath_under_root(outside_file, root))

    local display = util.display_path(outside_file, root, "relative")
    assert.is_false(util.path_is_absolute(display))

    vim.fn.delete(root, "rf")
    vim.fn.delete(outside_root, "rf")
  end)

  it("treats parent-relative paths as outside root", function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")

    local sneaky = root .. "/../outside.lua"
    assert.is_nil(util.relpath_under_root(sneaky, root))

    vim.fn.delete(root, "rf")
  end)

  it("skips multi-file yanks outside root", function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")

    local outside_root = vim.fn.tempname()
    vim.fn.mkdir(outside_root, "p")

    local inside_file = root .. "/inside.txt"
    local outside_file = outside_root .. "/outside.txt"

    vim.fn.writefile({ "INSIDE" }, inside_file)
    vim.fn.writefile({ "OUTSIDE" }, outside_file)

    vim.api.nvim_set_current_dir(root)

    py.setup({
      keymaps = false,
      notify = false,
      register = '"',
      root = { strategy = "cwd" },
    })

    local out = py.yank_files({ inside_file, outside_file }, { notify = false, register = '"' })
    assert.is_not_nil(out)
    assert.is_true(out:find("INSIDE", 1, true) ~= nil)
    assert.is_true(out:find("OUTSIDE", 1, true) == nil)

    vim.fn.delete(root, "rf")
    vim.fn.delete(outside_root, "rf")
  end)
end)

