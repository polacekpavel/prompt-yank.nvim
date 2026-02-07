local config = require('prompt-yank.config')
local format = require('prompt-yank.format')

describe('prompt-yank.format', function()
  before_each(function() config.setup({}) end)

  it('replaces placeholders in templates', function()
    local out = format.render_template('hi {name}', { name = 'world' })
    assert.equals('hi world', out)
  end)

  it('renders unknown placeholders as empty strings', function()
    local out = format.render_template('a{missing}b', {})
    assert.equals('ab', out)
  end)

  it('renders named formats from config', function()
    config.setup({ format = 'default' })
    local ctx = {
      filepath = 'src/main.lua',
      lines_hash = '#L1-L2',
      lines_plain = '1-2',
      lang = 'lua',
      code = "print('x')",
    }
    local out = format.render_code_block(ctx)
    assert.is_true(out:match('```lua') ~= nil)
    assert.is_true(out:match('src/main.lua') ~= nil)
  end)

  describe('built-in code block formats', function()
    local ctx
    before_each(
      function()
        ctx = {
          filepath = 'src/app.ts',
          lines_hash = '#L10-L20',
          lines_plain = '10-20',
          lang = 'typescript',
          code = 'const x = 1;',
        }
      end
    )

    it('default: markdown with backtick header', function()
      config.setup({ format = 'default' })
      local out = format.render_code_block(ctx)
      assert.equals('`src/app.ts#L10-L20`\n```typescript\nconst x = 1;\n```', out)
    end)

    it('minimal: markdown with html comment footer', function()
      config.setup({ format = 'minimal' })
      local out = format.render_code_block(ctx)
      assert.equals('```typescript\nconst x = 1;\n```\n<!-- src/app.ts#L10-L20 -->', out)
    end)

    it('xml: file tag wrapping code directly', function()
      config.setup({ format = 'xml' })
      local out = format.render_code_block(ctx)
      assert.equals(
        '<file path="src/app.ts" lines="10-20" language="typescript">\nconst x = 1;\n</file>',
        out
      )
    end)

    it('claude: file tag with nested code tag', function()
      config.setup({ format = 'claude' })
      local out = format.render_code_block(ctx)
      assert.equals(
        '<file path="src/app.ts" lines="10-20" language="typescript">\n<code>\nconst x = 1;\n</code>\n</file>',
        out
      )
    end)

    it('xml and claude differ only by the <code> wrapper', function()
      config.setup({ format = 'xml' })
      local xml_out = format.render_code_block(ctx)
      config.setup({ format = 'claude' })
      local claude_out = format.render_code_block(ctx)

      assert.is_nil(xml_out:find('<code>', 1, true))
      assert.is_not_nil(claude_out:find('<code>', 1, true))
      assert.is_not_nil(claude_out:find('</code>', 1, true))
    end)
  end)
end)
