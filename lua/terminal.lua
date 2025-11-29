-- jst/terminal.lua
local M = {}
local vim = vim

local term = { buf = nil, win = nil }
local function win_valid(w) return w and vim.api.nvim_win_is_valid(w) end
local function buf_valid(b) return b and vim.api.nvim_buf_is_valid(b) end

function M.toggle_bottom_term(height)
  height = height or 10
  if win_valid(term.win) then
    vim.api.nvim_win_close(term.win, true)
    term.win = nil
    return
  end
  if buf_valid(term.buf) then
    vim.cmd('botright ' .. height .. 'split')
    term.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(term.win, term.buf)
    vim.cmd('startinsert')
    return
  end
  vim.cmd('botright ' .. height .. 'split | terminal')
  term.win = vim.api.nvim_get_current_win()
  term.buf = vim.api.nvim_get_current_buf()
  vim.cmd('startinsert')
end

function M.term_here()
  vim.cmd('terminal')
end

function M.setup(opts)
  opts = opts or {}
  local default_height = opts.default_height or 10

  -- keymaps
  vim.keymap.set({ 'n', 't' }, '<leader>t', function()
    local h = (vim.v.count > 0) and vim.v.count or default_height
    M.toggle_bottom_term(h)
  end, { desc = 'Toggle bottom terminal (count = height)' })

  vim.keymap.set('n', '<leader>T', M.term_here, { desc = 'Terminal in current window' })
  vim.keymap.set("n", "<leader>m", M.make_term_to_qf)

  -- UX
  local aug = vim.api.nvim_create_augroup('JstTermUX', { clear = true })
  vim.api.nvim_create_autocmd('TermOpen', {
    group = aug,
    pattern = '*',
    callback = function()
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.opt_local.signcolumn = 'no'
      vim.bo.bufhidden = 'hide'
    end,
  })
  vim.api.nvim_create_autocmd('TermClose', {
    group = aug,
    pattern = '*',
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

-- count only *valid* quickfix entries (those that matched 'errorformat')
local function qf_valid_count()
  local info = vim.fn.getqflist({ items = 1 })
  local items = info.items or {}
  local n = 0
  for _, it in ipairs(items) do
    if it.valid == 1 then n = n + 1 end
  end
  return n
end

function M.make_term_to_qf(height)
  height = height or 10
  local cmd = vim.fn.expandcmd(vim.o.makeprg ~= '' and vim.o.makeprg or 'make')

  -- Make a *new* buffer so we don't clobber the current window's buffer
  vim.cmd('botright ' .. height .. 'new')
  local termwin = vim.api.nvim_get_current_win()
  local termbuf = vim.api.nvim_get_current_buf()

  -- scratch buffer settings
  vim.bo[termbuf].buflisted = false
  vim.bo[termbuf].swapfile  = false
  vim.bo[termbuf].bufhidden = 'hide'

  vim.fn.termopen(shell_args_for(cmd), {
    on_exit = function(_, code, _)
      vim.schedule(function()
        -- grab all terminal output and strip ANSI
        local lines = vim.api.nvim_buf_get_lines(termbuf, 0, -1, false)
        for i, s in ipairs(lines) do
          lines[i] = s:gsub("\r", ""):gsub("\27%[[0-9;]*[mK]", "")
        end

        -- parse with current 'errorformat' (no temp file needed)
        -- 'setqflist({}, "r", {lines = ...})' = replace quickfix from text using efm
        vim.fn.setqflist({}, 'r', { lines = lines })

        local vcount = qf_valid_count()

        if vcount > 0 then
          -- close the terminal window first; wipe the buffer so it doesn't linger
          vim.bo[termbuf].bufhidden = 'wipe'
          if vim.api.nvim_win_is_valid(termwin) then
            pcall(vim.api.nvim_win_close, termwin, true)
          end
          vim.cmd('cwindow')      -- opens only if there are entries
        else
          -- keep terminal output visible; ensure quickfix stays closed
          vim.cmd('cclose')
        end

        vim.notify(
          string.format('makeprg exited (%d)%s', code, vcount > 0 and (' — ' .. vcount .. ' problem(s)') or ''),
          vim.log.levels.INFO,
          { title = 'Make (terminal→quickfix)' }
        )
      end)
    end,
  })

  vim.cmd('startinsert')
end

return M
