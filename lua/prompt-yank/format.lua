local config = require("prompt-yank.config")

local M = {}

local function render_string(template, ctx)
  return (template:gsub("{([%w_]+)}", function(key)
    local value = ctx[key]
    if value == nil then
      return ""
    end
    return tostring(value)
  end))
end

function M.render_template(template, ctx)
  if type(template) == "function" then
    return template(ctx)
  end
  if type(template) ~= "string" then
    return ""
  end
  return render_string(template, ctx or {})
end

function M.render_format(format_name, ctx, conf)
  conf = conf or config.get()
  local fmt = (conf.formats or {})[format_name or conf.format] or (conf.formats or {}).default
  return M.render_template(fmt, ctx)
end

function M.render_code_block(ctx, opts)
  local conf = config.get()
  local format_name = (opts and opts.format) or conf.format
  return M.render_format(format_name, ctx, conf)
end

function M.render_named_template(template_name, ctx, conf)
  conf = conf or config.get()
  local tpl = (conf.templates or {})[template_name]
  return M.render_template(tpl, ctx)
end

return M

