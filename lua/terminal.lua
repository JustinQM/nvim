-- Terminal helpers.
--
--   <leader>t  toggle a shell at the bottom (a count sets the height)
--   <leader>T  open a shell in the current window
--   <leader>m  run 'makeprg' with M.run
--
-- M.run(cmd) runs a command in a real terminal at the bottom, so it can take
-- input. When the command exits, its output is checked against the formats in
-- lua/errorformat.lua:
--   * errors found  -> the terminal closes and the quickfix list opens
--   * nothing found -> the terminal stays open until you press <CR> or q
local errorformat = require("errorformat")

local M = {}

local height = 10
local shell = { buf = nil, win = nil } -- the <leader>t shell
local run_buf = nil                    -- terminal of the latest M.run

local function buf_valid(b) return b ~= nil and vim.api.nvim_buf_is_valid(b) end
local function win_valid(w) return w ~= nil and vim.api.nvim_win_is_valid(w) end

local function close_buf(b)
    if buf_valid(b) then vim.api.nvim_buf_delete(b, { force = true }) end
end

-- Turn one line of raw pty output into the text that was actually shown.
local function clean(line)
    line = line:gsub("\r$", "")
    line = line:match("[^\r]*$")                     -- text drawn after the last \r
    line = line:gsub("\27%[[0-9;:?]*[ -/]*[@-~]", "") -- colors, cursor movement
    line = line:gsub("\27%][^\7\27]*\7", "")         -- OSC ending in BEL (hyperlinks, titles)
    line = line:gsub("\27%][^\27]*\27\\", "")        -- OSC ending in ST
    line = line:gsub("\27.", "")                     -- anything else
    return line
end

function M.toggle_shell(h)
    if win_valid(shell.win) then
        vim.api.nvim_win_close(shell.win, true)
        shell.win = nil
        return
    end
    vim.cmd("botright " .. (h or height) .. "split")
    shell.win = vim.api.nvim_get_current_win()
    if buf_valid(shell.buf) then
        vim.api.nvim_win_set_buf(shell.win, shell.buf)
    else
        vim.cmd.terminal()
        shell.buf = vim.api.nvim_get_current_buf()
    end
    vim.cmd.startinsert()
end

function M.shell_here()
    vim.cmd.terminal()
    vim.cmd.startinsert()
end

local function finish(buf, cmd, code, output, ft)
    local lines = vim.tbl_map(clean, output)
    local items, format = errorformat.detect(lines, ft)

    if #items > 0 then
        close_buf(buf)
        vim.fn.setqflist({}, " ", { title = cmd, items = items })
        vim.cmd("botright copen")
        vim.notify(("%s: %d problem(s) [%s]"):format(cmd, #items, format), vim.log.levels.WARN)
        return
    end

    -- A clean run means the errors from this command's last run are fixed.
    if vim.fn.getqflist({ title = 1 }).title == cmd then
        vim.fn.setqflist({}, " ", { title = cmd, items = {} })
        vim.cmd.cclose()
    end

    if not buf_valid(buf) then return end

    -- Leave terminal mode so the next key doesn't close the buffer right away.
    if vim.api.nvim_get_current_buf() == buf and vim.api.nvim_get_mode().mode == "t" then
        vim.cmd.stopinsert()
    end
    for _, key in ipairs({ "<CR>", "q" }) do
        vim.keymap.set("n", key, function() close_buf(buf) end, { buffer = buf, nowait = true })
    end
    local level = code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
    vim.notify(("%s: exited %d, press <CR> to close"):format(cmd, code), level)
end

---Run `cmd` in a terminal at the bottom of the screen.
---@param cmd string|string[] a shell command, or an argv list
---@param h? integer window height
function M.run(cmd, h)
    local ft = vim.bo.filetype
    local title = type(cmd) == "table" and table.concat(cmd, " ") or cmd

    close_buf(run_buf)
    vim.cmd("botright " .. (h or height) .. "new")
    local buf = vim.api.nvim_get_current_buf()
    run_buf = buf

    -- Raw output, split into lines; the last entry is the line still being written.
    local output = { "" }
    vim.fn.jobstart(cmd, {
        term = true,
        on_stdout = function(_, data)
            output[#output] = output[#output] .. data[1]
            for i = 2, #data do table.insert(output, data[i]) end
        end,
        on_exit = function(_, code)
            vim.schedule(function() finish(buf, title, code, output, ft) end)
        end,
    })
    vim.bo[buf].bufhidden = "wipe"
    vim.cmd.startinsert()
end

function M.make()
    local makeprg = vim.o.makeprg ~= "" and vim.o.makeprg or "make"
    makeprg = makeprg:gsub("%$%*", "")
    -- Expand % and friends like :make does; keep the command as-is if that fails.
    local ok, cmd = pcall(vim.fn.expandcmd, makeprg)
    M.run(ok and cmd or makeprg)
end

function M.setup(opts)
    opts = opts or {}
    height = opts.default_height or height

    vim.keymap.set("n", "<leader>t", function()
        M.toggle_shell(vim.v.count > 0 and vim.v.count or nil)
    end, { desc = "Toggle bottom terminal (count = height)" })
    vim.keymap.set("n", "<leader>T", M.shell_here, { desc = "Terminal in current window" })
    vim.keymap.set("n", "<leader>m", M.make, { desc = "Run makeprg in a terminal" })

    local group = vim.api.nvim_create_augroup("JstTerminal", { clear = true })
    vim.api.nvim_create_autocmd("TermOpen", {
        group = group,
        callback = function()
            vim.opt_local.number = false
            vim.opt_local.relativenumber = false
            vim.opt_local.signcolumn = "no"
        end,
    })
    vim.api.nvim_create_autocmd("TermClose", {
        group = group,
        callback = function(ev)
            if ev.buf == shell.buf then shell.buf, shell.win = nil, nil end
        end,
    })
end

return M
