local config = require("prompt-yank.config")
local lang = require("prompt-yank.lang")

describe("prompt-yank.lang", function()
  before_each(function()
    config.setup({})
  end)

  it("maps filetypes via lang_map", function()
    local conf = config.get()
    assert.equals("tsx", lang.for_filetype("typescriptreact", conf))
  end)

  it("maps extensions via ext_map", function()
    local conf = config.get()
    assert.equals("typescript", lang.for_extension("ts", conf))
  end)

  it("allows user overrides", function()
    config.setup({ lang_map = { typescriptreact = "typescriptreact" } })
    local conf = config.get()
    assert.equals("typescriptreact", lang.for_filetype("typescriptreact", conf))
  end)
end)

