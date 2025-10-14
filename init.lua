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

vim.opt.wildmode = "longest","list","full"
vim.opt.wildmenu = true

vim.opt.wrap = false

vim.opt.hidden = true

vim.opt.winborder = "rounded"

vim.opt.swapfile = false

-- Quickfix List
vim.keymap.set("n", "<leader>co", ":copen<CR>")
vim.keymap.set("n", "<leader>cc", ":cclose<CR>")
vim.keymap.set("n", "<leader>cn", ":cnext<CR>")
vim.keymap.set("n", "<leader>cp", ":cprevious<CR>")

-- tags
local tags_file_name = ".tags"
vim.keymap.set("n", "<leader>tt", function()
    vim.system({"ctags", "-R", "-f", tags_file_name, "."}, { text = true }, on_exit)
end)

-- lsp
vim.lsp.enable({"lua_ls", "clangd", "bashls", "tinymist"})

-- plugins
vim.pack.add({
    { src = "https://github.com/stevearc/oil.nvim" },
    { src = "https://github.com/mason-org/mason.nvim" },
    { src = "https://github.com/tpope/vim-fugitive" },
    { src = "https://github.com/bluz71/vim-moonfly-colors" },
    { src = "https://github.com/nvim-mini/mini.pick" },
    { src = "https://github.com/chomosuke/typst-preview.nvim.git" },
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

--plugins: typst preview
require("typst-preview").setup()
vim.keymap.set("n", "<leader>p", ":TypstPreview<CR>")
