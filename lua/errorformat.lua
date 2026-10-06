-- Error formats used by <leader>m (see lua/terminal.lua).
--
-- To support a new language, add an entry below:
--
--     name = {
--         filetypes = { ... },  -- buffers of these filetypes try this format first
--         efm = { ... },        -- 'errorformat' patterns, see :h errorformat
--     },
--
-- Lines that match none of the patterns are ignored, so there is no need to end
-- with "%-G%.%#".
--
-- After a run, the output is checked against the current buffer's format first,
-- then every other format. The first one that finds errors fills the quickfix list.
local M = {}

M.formats = {
    c = {
        filetypes = { "c", "cpp" },
        efm = {
            "%E%f:%l:%c: error: %m",
            "%W%f:%l:%c: warning: %m",
            "%I%f:%l:%c: note: %m",
            "%E%f:%l: error: %m",
            "%W%f:%l: warning: %m",
        },
    },

    odin = {
        filetypes = { "odin" },
        efm = {
            "%f(%l:%c) %t%*[^:]: %m",
            "%f(%l) %t%*[^:]: %m",
        },
    },

    -- svelte-check --output machine
    svelte = {
        filetypes = { "svelte", "typescript" },
        efm = {
            "%E%*[0-9] ERROR \"%f\" %l:%c \"%m\"",
            "%W%*[0-9] WARNING \"%f\" %l:%c \"%m\"",
        },
    },
}

local function parse(lines, efm)
    local result = vim.fn.getqflist({
        lines = lines,
        efm = table.concat(efm, ",") .. ",%-G%.%#",
    })
    return vim.tbl_filter(function(item) return item.valid == 1 end, result.items)
end

-- Format names in the order they should be tried: those for `ft` first.
local function candidates(ft)
    local first, rest = {}, {}
    for name, format in pairs(M.formats) do
        if vim.tbl_contains(format.filetypes or {}, ft) then
            table.insert(first, name)
        else
            table.insert(rest, name)
        end
    end
    table.sort(first)
    table.sort(rest)
    return vim.list_extend(first, rest)
end

---Find errors in `lines` (already stripped of terminal escapes).
---@param lines string[]
---@param ft string filetype of the buffer the command was started from
---@return table[] items quickfix items, empty if nothing matched
---@return string|nil name the format that matched
function M.detect(lines, ft)
    for _, name in ipairs(candidates(ft)) do
        local items = parse(lines, M.formats[name].efm)
        if #items > 0 then return items, name end
    end
    return {}, nil
end

return M
