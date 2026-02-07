local M = {}

local CHARS_PER_TOKEN = 4

function M.estimate(text)
  if not text or text == '' then return 0 end
  return math.ceil(#text / CHARS_PER_TOKEN)
end

function M.format_count(token_count) return ('~%d tokens'):format(token_count) end

return M
