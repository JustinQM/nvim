local M = {}
local vim = vim

-- Central registry: filetype -> errorformat string
local EFM = {
  odin = table.concat({
    -- /path/file.odin(11:5) Error: message
    "%f(%l:%c) %t%*[^:]: %m",
    -- fallback: /path/file.odin(11) Error: message
    "%f(%l) %t%*[^:]: %m",

    -- ignore indented context lines (code, caret, suggestions, etc.)
    "%-G%\\s%#",
    -- ignore everything else
    "%-G%.%#",
  }, ","),
}

---Return the errorformat string for a given filetype, or nil if unknown.
---@param ft string
---@return string|nil
function M.efm_for_ft(ft)
  return EFM[ft]
end

---Register/override an errorformat for a filetype at runtime.
---@param ft string
---@param efm string
function M.register(ft, efm)
  assert(type(ft) == "string" and ft ~= "", "register(ft, efm): ft must be a non-empty string")
  assert(type(efm) == "string" and efm ~= "", "register(ft, efm): efm must be a non-empty string")
  EFM[ft] = efm
end

---List filetypes with registered errorformats (useful for debugging).
---@return string[]
function M.list()
  return vim.tbl_keys(EFM)
end

return M

