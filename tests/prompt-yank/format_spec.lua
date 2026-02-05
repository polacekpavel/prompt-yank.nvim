local config = require("prompt-yank.config")
local format = require("prompt-yank.format")

describe("prompt-yank.format", function()
  before_each(function()
    config.setup({})
  end)

  it("replaces placeholders in templates", function()
    local out = format.render_template("hi {name}", { name = "world" })
    assert.equals("hi world", out)
  end)

  it("renders unknown placeholders as empty strings", function()
    local out = format.render_template("a{missing}b", {})
    assert.equals("ab", out)
  end)

  it("renders named formats from config", function()
    config.setup({ format = "default" })
    local ctx = {
      filepath = "src/main.lua",
      lines_hash = "#L1-L2",
      lines_plain = "1-2",
      lang = "lua",
      code = "print('x')",
    }
    local out = format.render_code_block(ctx)
    assert.is_true(out:match("```lua") ~= nil)
    assert.is_true(out:match("src/main.lua") ~= nil)
  end)
end)

