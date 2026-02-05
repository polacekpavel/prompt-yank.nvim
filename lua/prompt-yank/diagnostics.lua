local M = {}

local severity_names = {
  [vim.diagnostic.severity.ERROR] = "error",
  [vim.diagnostic.severity.WARN] = "warning",
  [vim.diagnostic.severity.INFO] = "info",
  [vim.diagnostic.severity.HINT] = "hint",
}

function M.format_in_range(bufnr, line_start, line_end)
  bufnr = bufnr or 0
  local all = vim.diagnostic.get(bufnr)
  if #all == 0 then
    return "(no LSP diagnostics in buffer)", 0, 0
  end

  local lines = {}
  for _, d in ipairs(all) do
    local lnum = (d.lnum or 0) + 1
    if lnum >= line_start and lnum <= line_end then
      local sev = severity_names[d.severity] or "unknown"
      local msg = (d.message or ""):gsub("\n", " ")
      table.insert(lines, ("- L%d: [%s] %s"):format(lnum, sev, msg))
    end
  end

  if #lines == 0 then
    return ("(no diagnostics in L%d-L%d, %d total in file)"):format(line_start, line_end, #all), 0, #all
  end

  return table.concat(lines, "\n"), #lines, #all
end

return M

