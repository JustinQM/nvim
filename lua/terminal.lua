local M = {}
local vim = vim

local term = { buf = nil, win = nil }
local function win_valid(w) return w and vim.api.nvim_win_is_valid(w) end
local function buf_valid(b) return b and vim.api.nvim_buf_is_valid(b) end

local errorformat = require("errorformat")

local FALLBACK_EFM = table.concat({
    "%E%f:%l:%c: error: %m",
    "%W%f:%l:%c: warning: %m",
    "%E%f:%l: error: %m",
    "%W%f:%l: warning: %m",
    "%f(%l:%c) %t%*[^:]: %m",
    "%f(%l) %t%*[^:]: %m",
    "%-G%.%#",
}, ",")

function M.toggle_bottom_term(height)
    height = height or 10
    if win_valid(term.win) then
        vim.api.nvim_win_close(term.win, true)
        term.win = nil
        return
    end
    if buf_valid(term.buf) then
        vim.cmd("botright " .. height .. "split")
        term.win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(term.win, term.buf)
        vim.cmd("startinsert")
        return
    end
    vim.cmd("botright " .. height .. "split | terminal")
    term.win = vim.api.nvim_get_current_win()
    term.buf = vim.api.nvim_get_current_buf()
    vim.cmd("startinsert")
end

function M.term_here()
    vim.cmd("terminal")
end

function M.setup(opts)
    opts = opts or {}
    local default_height = opts.default_height or 10

    vim.keymap.set({ "n" }, "<leader>t", function()
        local h = (vim.v.count > 0) and vim.v.count or default_height
        M.toggle_bottom_term(h)
    end, { desc = "Toggle bottom terminal (count = height)" })

    vim.keymap.set("n", "<leader>T", M.term_here, { desc = "Terminal in current window" })
    vim.keymap.set("n", "<leader>m", M.make_term_to_qf)

    local aug = vim.api.nvim_create_augroup("JstTermUX", { clear = true })
    vim.api.nvim_create_autocmd("TermOpen", {
        group = aug,
        pattern = "*",
        callback = function()
            vim.opt_local.number = false
            vim.opt_local.relativenumber = false
            vim.opt_local.signcolumn = "no"
            vim.bo.bufhidden = "hide"
        end,
    })
    vim.api.nvim_create_autocmd("TermClose", {
        group = aug,
        pattern = "*",
        callback = function(ev)
            if term.buf == ev.buf then term.buf, term.win = nil, nil end
        end,
    })
end

local function shell_args_for(cmd)
    local shell, flag = vim.o.shell, vim.o.shellcmdflag
    local args = { shell }
    for token in flag:gmatch("%S+") do table.insert(args, token) end
    table.insert(args, cmd)
    return args
end

local function strip_ansi(s)
    s = s:gsub("\r", "")
    s = s:gsub("\27%]8;;[^\a]*\a[^\27]*\27%]8;;\a", "")
    s = s:gsub("\27%[[0-9;:]*[mKJHfABCDsuhl]", "")
    s = s:gsub("\27%][^\a]*\a", "")
    s = s:gsub("\27.", "")
    s = s:gsub("%z", "")
    return s
end

local function split_lines(raw)
    local lines = {}
    local current = {}
    local i = 1
    while i <= #raw do
        local c = raw:sub(i, i)
        if c == "\r" then
            local next = raw:sub(i + 1, i + 1)
            if next == "\n" then
                i = i + 1
            end
            local line = strip_ansi(table.concat(current))
            if line ~= "" then table.insert(lines, line) end
            current = {}
        elseif c == "\n" then
            local line = strip_ansi(table.concat(current))
            if line ~= "" then table.insert(lines, line) end
            current = {}
        else
            table.insert(current, c)
        end
        i = i + 1
    end
    if #current > 0 then
        local line = strip_ansi(table.concat(current))
        if line ~= "" then table.insert(lines, line) end
    end
    return lines
end

local function qf_entry_count()
    local info = vim.fn.getqflist({ items = 1 })
    local items = info.items or {}
    local n = 0
    for _, it in ipairs(items) do
        if it.valid == 1 then n = n + 1 end
    end
    return n
end

function M.run_in_term(cmd, height)
    height = height or 10

    local display_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[display_buf].buflisted = false

    vim.cmd("botright " .. height .. "split")
    local display_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(display_win, display_buf)

    term.buf = display_buf
    term.win = display_win

    local job_id
    local term_chan = vim.api.nvim_open_term(display_buf, {
        on_input = function(_, _, _, data)
            if job_id and job_id > 0 then
                pcall(vim.api.nvim_chan_send, job_id, data)
            end
        end,
    })

    job_id = vim.fn.jobstart(cmd, {
        pty = true,
        width = vim.api.nvim_win_get_width(display_win),
        height = height,
        on_stdout = function(_, data)
            local chunk = table.concat(data, "\r\n")
            if chunk ~= "" then
                pcall(vim.api.nvim_chan_send, term_chan, chunk)
            end
        end,
        on_exit = function(_, code)
            local exit_msg = "\r\n[Process exited " .. code .. "] press <CR> to close\r\n"
            pcall(vim.api.nvim_chan_send, term_chan, exit_msg)
            vim.schedule(function()
                vim.api.nvim_buf_set_keymap(display_buf, "t", "<CR>",
                    "<cmd>bd!<CR>", { noremap = true, silent = true })
                vim.api.nvim_buf_set_keymap(display_buf, "n", "<CR>",
                    "<cmd>bd!<CR>", { noremap = true, silent = true })
            end)
        end,
    })

    vim.cmd("startinsert")
end

function M.make_term_to_qf(height)
    height = height or 10

    local srcbuf = vim.api.nvim_get_current_buf()
    local srcft  = vim.bo[srcbuf].filetype
    local efm    = errorformat.efm_for_ft(srcft) or FALLBACK_EFM
    local cmd    = vim.fn.expandcmd(vim.o.makeprg ~= "" and vim.o.makeprg or "make")

    local display_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[display_buf].buflisted = false

    vim.cmd("botright " .. height .. "split")
    local display_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(display_win, display_buf)

    term.buf = display_buf
    term.win = display_win

    local raw_chunks = {}
    local job_id

    local term_chan = vim.api.nvim_open_term(display_buf, {
        on_input = function(_, _, _, data)
            if job_id and job_id > 0 then
                pcall(vim.api.nvim_chan_send, job_id, data)
            end
        end,
    })

    vim.notify("Building...", vim.log.levels.INFO, { title = "Make" })

    job_id = vim.fn.jobstart(shell_args_for(cmd), {
        pty = true,
        width = 9999,
        height = height,
        on_stdout = function(_, data)
            local chunk = table.concat(data, "\r\n")
            if chunk ~= "" then
                table.insert(raw_chunks, chunk)
                pcall(vim.api.nvim_chan_send, term_chan, chunk)
            end
        end,
        on_exit = function(_, code)
            local exit_msg = "\r\n[Process exited " .. code .. "] press <CR> to close\r\n"
            pcall(vim.api.nvim_chan_send, term_chan, exit_msg)

            vim.schedule(function()
                vim.api.nvim_buf_set_keymap(display_buf, "t", "<CR>",
                    "<cmd>bd!<CR>", { noremap = true, silent = true })
                vim.api.nvim_buf_set_keymap(display_buf, "n", "<CR>",
                    "<cmd>bd!<CR>", { noremap = true, silent = true })

                local raw = table.concat(raw_chunks)
                local lines = split_lines(raw)

                vim.fn.setqflist({}, "r", { lines = lines, title = cmd, efm = efm })

                local vcount = qf_entry_count()

                if code ~= 0 then
                    vim.bo[display_buf].bufhidden = "wipe"
                    if vim.api.nvim_win_is_valid(display_win) then
                        pcall(vim.api.nvim_win_close, display_win, true)
                    end
                    term.buf = nil
                    term.win = nil
                    vim.cmd("cwindow")
                    vim.notify(
                        string.format("exited (%d) — %d problem(s)", code, vcount),
                        vim.log.levels.ERROR,
                        { title = "Make" }
                    )
                else
                    if vcount > 0 then vim.cmd("cwindow") else vim.cmd("cclose") end
                    vim.notify(
                        string.format("exited (%d)%s", code, vcount > 0 and (" — " .. vcount .. " warning(s)") or ""),
                        vim.log.levels.INFO,
                        { title = "Make" }
                    )
                end
            end)
        end,
    })

    vim.cmd("startinsert")
end

return M
