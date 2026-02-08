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

vim.keymap.set("n", "<leader>dd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
vim.keymap.set("n", "<leader>dn", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "<leader>dp", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })

vim.lsp.config('lua_ls', require('lsp.lua_ls'))
vim.lsp.config('clangd', require('lsp.clangd'))
vim.lsp.config('bashls', require('lsp.bashls'))
vim.lsp.config('tinymist', require('lsp.tinymist'))
vim.lsp.config('gdscript', require('lsp.gdscript'))
vim.lsp.config('ols', require('lsp.ols'))
vim.lsp.enable({"lua_ls", "clangd", "bashls", "tinymist","gdscript", "ols"})

-- plugins
vim.pack.add({
    { src = "https://github.com/stevearc/oil.nvim" },
    { src = "https://github.com/mason-org/mason.nvim" },
    { src = "https://github.com/tpope/vim-fugitive" },
    { src = "https://github.com/bluz71/vim-moonfly-colors" },
    { src = "https://github.com/nvim-mini/mini.pick" },
    { src = "https://github.com/Tetralux/odin.vim" },
})

-- plugins: oil
require "oil".setup({
    skip_confirm_for_simple_edits = true,
})
vim.keymap.set("n", "<leader>e", ":Oil<CR>")

-- plugins: mason
require "mason".setup()

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
