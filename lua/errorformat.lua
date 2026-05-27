local M = {}
local vim = vim

local EFM = {
    odin = table.concat({
        "%f(%l:%c) %t%*[^:]: %m",
        "%f(%l) %t%*[^:]: %m",
        "%-G%\\s%#",
        "%-G%.%#",
    }, ","),
    svelte = table.concat({
        "%E%*[0-9] ERROR \"%f\" %l:%c \"%m\"",
        "%W%*[0-9] WARNING \"%f\" %l:%c \"%m\"",
        "%-G%.%#",
    }, ","),
    c = table.concat({
        "%E%f:%l:%c: error: %m",
        "%W%f:%l:%c: warning: %m",
        "%I%f:%l:%c: note: %m",
        "%E%f:%l: error: %m",
        "%W%f:%l: warning: %m",
        "%-G%.%#",
    }, ","),
}

EFM.cpp = EFM.c
EFM.typescript = EFM.svelte

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
