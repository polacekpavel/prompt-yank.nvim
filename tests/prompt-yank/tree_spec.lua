local tree = require("prompt-yank.tree")

describe("prompt-yank.tree", function()
  it("treats ignore entries as literal directory names", function()
    local root = vim.fn.tempname()

    vim.fn.mkdir(root .. "/agit", "p")
    vim.fn.writefile({ "x" }, root .. "/agit/foo.txt")

    local out = tree.build_tree(root, 3, { ".git" }, 200)
    assert.is_true(out:find("agit/", 1, true) ~= nil)
    assert.is_true(out:find("foo.txt", 1, true) ~= nil)

    vim.fn.delete(root, "rf")
  end)
end)

