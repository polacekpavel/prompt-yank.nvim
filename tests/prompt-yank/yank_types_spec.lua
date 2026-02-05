local config = require("prompt-yank.config")
local py = require("prompt-yank")
local util = require("prompt-yank.util")
local tree = require("prompt-yank.tree")

local function code_block(filepath, lines_hash, lang, code)
  return ("`%s%s`\n```%s\n%s\n```"):format(filepath, lines_hash or "", lang or "", code or "")
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
  if not ok then
    error(res)
  end
  return res
end

describe("prompt-yank yank types", function()
  local original_cwd
  local cleanup = {}

  local function track(path)
    table.insert(cleanup, path)
    return path
  end

  local function make_root()
    local root = track(vim.fn.tempname())
    vim.fn.mkdir(root, "p")
    vim.api.nvim_set_current_dir(root)
    return root
  end

  local function make_buffer(root, relpath, lines, filetype)
    local fullpath = root .. "/" .. relpath
    vim.fn.mkdir(vim.fn.fnamemodify(fullpath, ":h"), "p")
    vim.fn.writefile(lines, fullpath)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_name(bufnr, fullpath)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    if filetype then
      vim.bo[bufnr].filetype = filetype
    end
    return bufnr, fullpath
  end

  before_each(function()
    original_cwd = vim.fn.getcwd()
    config.setup({
      notify = false,
      register = '"',
      root = { strategy = "cwd" },
      path_style = "relative",
      context_lines = 1,
    })
  end)

  after_each(function()
    for _, path in ipairs(cleanup) do
      pcall(vim.fn.delete, path, "rf")
    end
    cleanup = {}
    pcall(vim.api.nvim_set_current_dir, original_cwd)
  end)

  it("yank_file formats the entire buffer", function()
    local root = make_root()
    make_buffer(root, "file.lua", { "line1", "line2" }, "lua")

    local text = py.yank_file({ notify = false, register = '"' })
    local expected = code_block("file.lua", "", "lua", "line1\nline2")

    assert.equals(expected, text)
  end)

  it("yank_selection formats a visual selection", function()
    local root = make_root()
    local bufnr = make_buffer(root, "sel.lua", { "one", "two", "three" }, "lua")

    vim.api.nvim_buf_set_mark(bufnr, "<", 1, 0, {})
    vim.api.nvim_buf_set_mark(bufnr, ">", 2, 999, {})

    local text = py.yank_selection({ from_visual = true, notify = false, register = '"' })
    local expected = code_block("sel.lua", "#L1-L2", "lua", "one\ntwo")

    assert.equals(expected, text)
  end)

  it("yank_range formats an explicit line range", function()
    local root = make_root()
    make_buffer(root, "range.lua", { "a", "b", "c" }, "lua")

    local text = py.yank_range(2, 3, { notify = false, register = '"' })
    local expected = code_block("range.lua", "#L2-L3", "lua", "b\nc")

    assert.equals(expected, text)
  end)

  it("yank_diagnostics renders diagnostics template with exact output", function()
    local root = make_root()
    local bufnr = make_buffer(root, "diag.lua", { "l1", "l2", "l3" }, "lua")

    local ns = vim.api.nvim_create_namespace("prompt-yank-test")
    vim.diagnostic.set(ns, bufnr, {
      { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "Boom" },
      { lnum = 2, col = 0, severity = vim.diagnostic.severity.WARN, message = "Skip" },
    })

    local text = py.yank_diagnostics({ line_start = 1, line_end = 2, notify = false, register = '"' })
    local expected = code_block("diag.lua", "#L1-L2", "lua", "l1\nl2")
      .. "\n\n**Diagnostics:**\n- L1: [error] Boom"

    assert.equals(expected, text)
  end)

  it("yank_context includes surrounding lines", function()
    local root = make_root()
    make_buffer(root, "ctx.lua", { "l1", "l2", "l3", "l4" }, "lua")

    local text = py.yank_context({ line_start = 2, line_end = 2, notify = false, register = '"' })
    local expected =
      "`ctx.lua#L1-L3` (with 1 lines context)\n```lua\nl1\nl2\nl3\n```"

    assert.equals(expected, text)
  end)

  it("yank_function uses the function_named template", function()
    local root = make_root()
    make_buffer(root, "func.lua", { "line1", "line2", "line3" }, "lua")

    local ts = require("prompt-yank.treesitter")
    local text = stub(ts, {
      current_container = function()
        return { start_line = 1, end_line = 2, name = "my_func", node_type = "function" }
      end,
    }, function()
      return py.yank_function({ notify = false, register = '"' })
    end)

    local expected = "`func.lua#L1-L2` (function: my_func)\n```lua\nline1\nline2\n```"
    assert.equals(expected, text)
  end)

  it("yank_diff formats file diff output", function()
    local root = make_root()
    make_buffer(root, "diff.lua", { "line1", "line2" }, "lua")

    local git = require("prompt-yank.git")
    local text = stub(git, {
      diff_for_file = function()
        return "DIFF"
      end,
    }, function()
      return py.yank_diff({ notify = false, register = '"' })
    end)

    local expected = "`diff.lua` (uncommitted changes)\n```diff\nDIFF\n```"
    assert.equals(expected, text)
  end)

  it("yank_diff formats selection + diff output", function()
    local root = make_root()
    make_buffer(root, "diffsel.lua", { "line1", "line2" }, "lua")

    local git = require("prompt-yank.git")
    local text = stub(git, {
      diff_for_file = function()
        return "DIFF"
      end,
    }, function()
      return py.yank_diff({ line_start = 1, line_end = 1, notify = false, register = '"' })
    end)

    local expected = "`diffsel.lua#L1`\n\n**Current code:**\n```lua\nline1\n```"
      .. "\n\n**File diff:**\n```diff\nDIFF\n```"

    assert.equals(expected, text)
  end)

  it("yank_blame formats blame output", function()
    local root = make_root()
    make_buffer(root, "blame.lua", { "line1", "line2" }, "lua")

    local git = require("prompt-yank.git")
    local text = stub(git, {
      is_git_repo = function()
        return true
      end,
      blame_for_file = function()
        return "BLAME"
      end,
    }, function()
      return py.yank_blame({ line_start = 1, line_end = 2, notify = false, register = '"' })
    end)

    local expected = "`blame.lua#L1-L2` (with git blame)\n```lua\nBLAME\n```"
    assert.equals(expected, text)
  end)

  it("yank_tree formats full project tree output", function()
    local root = make_root()
    make_buffer(root, "tree.lua", { "line1" }, "lua")

    local project_name = util.project_name(root)
    local tree_out = "└── tree.lua"

    local tree_mod = require("prompt-yank.tree")
    local text = stub(tree_mod, {
      build_tree = function()
        return tree_out, 1
      end,
    }, function()
      return py.yank_tree({ notify = false, register = '"' })
    end)

    local expected = ("**Project: %s**\n```\n%s\n```"):format(project_name, tree_out)
    assert.equals(expected, text)
  end)

  it("yank_tree formats tree path + selection output", function()
    local root = make_root()
    make_buffer(root, "sub/thing.lua", { "first", "second" }, "lua")

    local project_name = util.project_name(root)
    local project_tree = select(1, tree.render_path("sub/thing.lua"))
    local expected_code = code_block("sub/thing.lua", "#L1", "lua", "first")
    local expected = ("**Project: %s**\n```\n%s\n```\n\n%s"):format(project_name, project_tree, expected_code)

    local text = py.yank_tree({ line_start = 1, line_end = 1, notify = false, register = '"' })
    assert.equals(expected, text)
  end)

  it("yank_remote formats remote URL + code output", function()
    local root = make_root()
    make_buffer(root, "remote.lua", { "line1", "line2" }, "lua")

    local git = require("prompt-yank.git")
    local text = stub(git, {
      is_git_repo = function()
        return true
      end,
      head_sha = function()
        return "deadbeef"
      end,
      remote_url = function()
        return "https://github.com/acme/repo.git"
      end,
    }, function()
      return py.yank_remote({ line_start = 1, line_end = 2, notify = false, register = '"' })
    end)

    local expected = "`remote.lua#L1-L2`\nhttps://github.com/acme/repo/blob/deadbeef/remote.lua#L1-L2\n\n"
      .. "```lua\nline1\nline2\n```"

    assert.equals(expected, text)
  end)

  it("yank_files formats multiple files with the default separator", function()
    local root = make_root()
    make_buffer(root, "a.lua", { "A" }, "lua")
    make_buffer(root, "b.txt", { "B" }, "text")

    local text = py.yank_files({ "a.lua", "b.txt" }, { notify = false, register = '"' })
    local expected = code_block("a.lua", "", "lua", "A")
      .. "\n\n"
      .. code_block("b.txt", "", "txt", "B")

    assert.equals(expected, text)
  end)

  it("yank_multi uses picker selections and copies output", function()
    local root = make_root()
    make_buffer(root, "a.lua", { "A" }, "lua")
    make_buffer(root, "b.txt", { "B" }, "text")

    local picker = require("prompt-yank.picker")
    local yank = require("prompt-yank.yank")
    local copied

    stub(picker, {
      pick_files = function(_, cb)
        cb({ "a.lua", "b.txt" })
      end,
    }, function()
      stub(yank, {
        copy = function(text)
          copied = text
          return text
        end,
      }, function()
        py.yank_multi({ notify = false, register = '"' })
      end)
    end)

    local expected = code_block("a.lua", "", "lua", "A")
      .. "\n\n"
      .. code_block("b.txt", "", "txt", "B")

    assert.equals(expected, copied)
  end)
end)
