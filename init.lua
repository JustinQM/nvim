-- Core
local vim = vim
vim.g.mapleader = " "
vim.keymap.set("i", "jk", "<ESC>")

vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.tabstop = 8
vim.opt.softtabstop = 0
vim.opt.smartindent = true

vim.opt.syntax = "on"
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.signcolumn = "no"

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.wildmenu = true
vim.opt.wildmode = {"longest:full","list:full"}


vim.opt.wrap = false

vim.opt.hidden = true

vim.opt.winborder = "rounded"

vim.opt.swapfile = false

-- Quickfix List
vim.keymap.set("n", "<leader>co", ":copen<CR>")
vim.keymap.set("n", "<leader>cc", ":cclose<CR>")
vim.keymap.set("n", "<leader>cn", ":cnext<CR>")
vim.keymap.set("n", "<leader>cp", ":cprevious<CR>")


-- noh keymap
vim.keymap.set("n", "<leader>n", ":noh<CR>")

-- terminal mode binds
vim.keymap.set("t", "<ESC>", "<C-\\><C-n>")
vim.keymap.set("t", "jk", "<C-\\><C-n>")
require("terminal").setup({ default_height = 10 })

--makeprg and make
vim.keymap.set("n", "<leader>M", function()
  local cur = vim.o.makeprg
  local inp = vim.fn.input("makeprg: ", cur)
  if inp ~= "" then
    vim.o.makeprg = inp
    print("makeprg = " .. vim.o.makeprg)
  end
end)


-- lsp


--     diaganostics
vim.diagnostic.config({
  virtual_text = false,      -- disable inline diagnostics
  signs = false,             -- you already have signcolumn = "no", but this avoids sign placement entirely
  underline = false,          -- keep underline if you still want a subtle indicator (set false to remove)
  update_in_insert = false,  -- don't update diagnostics while typing
  severity_sort = true,
  float = {
    border = "rounded",
    source = "if_many",
  },
})


--    capabilities (for snippets)
local caps = vim.lsp.protocol.make_client_capabilities()
caps.textDocument.completion.completionItem.snippetSupport = true

local function with_caps(cfg)
  cfg = cfg or {}
  cfg.capabilities = vim.tbl_deep_extend("force", {}, cfg.capabilities or {}, caps)
  return cfg
end

vim.opt.completeopt = { "menu", "menuone", "noinsert" }
vim.api.nvim_create_autocmd("LspAttach", {
  desc = "Enable vim.lsp.completion (snippets, additional edits)",
  callback = function(ev)
    local client_id = ev.data and ev.data.client_id
    if not client_id then return end
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then return end

    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client_id, ev.buf, { autotrigger = false })
    end
  end,
})

vim.lsp.commands = vim.lsp.commands or {}
vim.lsp.commands["editor.action.triggerParameterHints"] = function()
  vim.lsp.buf.signature_help()
end

vim.keymap.set({ "i", "s" }, "<Tab>", function()
  if vim.snippet and vim.snippet.active({ direction = 1 }) then
    vim.snippet.jump(1)
    return ""
  end
  return "\t"
end, { expr = true, silent = true })

vim.keymap.set({ "i", "s" }, "<S-Tab>", function()
  if vim.snippet and vim.snippet.active({ direction = -1 }) then
    vim.snippet.jump(-1)
    return ""
  end
  return "<S-Tab>"
end, { expr = true, silent = true })

--     enable configs and start lsp

vim.lsp.config('lua_ls', with_caps(require('lsp.lua_ls')))
vim.lsp.config('clangd', with_caps(require('lsp.clangd')))
vim.lsp.config('bashls', with_caps(require('lsp.bashls')))
vim.lsp.config('tinymist', with_caps(require('lsp.tinymist')))
vim.lsp.config('gdscript', with_caps(require('lsp.gdscript')))
vim.lsp.config('ols', with_caps(require('lsp.ols')))
vim.lsp.enable({"lua_ls", "clangd", "bashls", "tinymist","gdscript", "ols"})

-- plugins
vim.pack.add({
    { src = "https://github.com/stevearc/oil.nvim" },
    { src = "https://github.com/mason-org/mason.nvim" },
    { src = "https://github.com/tpope/vim-fugitive" },
    { src = "https://github.com/bluz71/vim-moonfly-colors" },
    { src = "https://github.com/nvim-mini/mini.pick" },
    { src = "https://github.com/Tetralux/odin.vim" },
    { src = "https://github.com/nicolasgb/jj.nvim" },
})

-- plugins: oil
require "oil".setup({
    skip_confirm_for_simple_edits = true,
})
vim.keymap.set("n", "<leader>e", ":Oil<CR>")

-- plugins: mason
require "mason".setup()

-- plugins: jj
require "jj".setup({})

vim.keymap.set("n", "<leader>j", function()
  require("jj.cmd").log()
end, { desc = "JJ log" })

do
  local terminal = require("jj.ui.terminal")
  local core_buffer = require("jj.core.buffer")

  local orig_run = terminal.run

  terminal.run = function(cmd, keymaps)
    local is_log = false
    if type(cmd) == "string" then
      is_log = cmd:match("^%s*jj%s+log([%s$])") ~= nil
    elseif type(cmd) == "table" then
      is_log = (cmd[1] == "jj" and cmd[2] == "log")
    end

    if not is_log then
      return orig_run(cmd, keymaps)
    end

    local orig_create = core_buffer.create
    core_buffer.create = function(opts)
      if opts and opts.split == "horizontal" then
        opts = vim.tbl_deep_extend("force", opts, { split = "current" })
        opts.size = nil
        opts.direction = nil
      end
      return orig_create(opts)
    end

    local ok, res = pcall(orig_run, cmd, keymaps)
    core_buffer.create = orig_create

    if not ok then
      vim.schedule(function()
        vim.notify("jj.nvim log patch failed: " .. tostring(res), vim.log.levels.ERROR)
      end)
      return
    end
    return res
  end
end


--plugins: colors
vim.cmd [[colorscheme moonfly]]

--plugins: pick
require('mini.pick').setup()
vim.keymap.set("n", "<leader>f", ":Pick files<CR>")
vim.keymap.set("n", "<leader>h", ":Pick help<CR>")
vim.keymap.set("n", "<leader>b", ":Pick buffers<CR>")

--plugins: fugitive
vim.keymap.set("n", "<leader>g", ":Gedit :<CR>")

-- neovide
if vim.g.neovide then
  vim.g.neovide_cursor_animation_length = 0
  vim.g.neovide_cursor_short_animation_length = 0
  vim.g.neovide_cursor_vfx_mode = ""
end

-- “start blinking after 700ms idle”
vim.opt.guicursor =
  "n-v-c:block-blinkwait1000-blinkon500-blinkoff500," ..
  "i-ci-ve:ver25-blinkwait700-blinkon500-blinkoff500," ..
  "r-cr:hor20"

if vim.g.neovide then
  vim.g.neovide_cursor_smooth_blink = true
end

if vim.g.neovide then
  vim.keymap.set('v', '<C-c>', '"+y')
  vim.keymap.set('n', '<C-v>', '"+P')
  vim.keymap.set('v', '<C-v>', '"+P')
  vim.keymap.set('c', '<C-v>', '<C-R>+')
  vim.keymap.set('i', '<C-v>', '<ESC>l"+Pli')
end
