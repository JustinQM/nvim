---@brief
---
--- https://github.com/DanielGavin/ols
---
--- `Odin Language Server`.

local util = require "lsp.util"

---@type vim.lsp.Config
return {
  cmd = { "ols" },
  filetypes = { "odin" },

  init_options = {
      enable_snippets = true,
      enable_procedure_snippet = true,
  },

  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local root = util.root_pattern("ols.json", ".git")(fname)
      or vim.fn.fnamemodify(fname, ":p:h") -- fallback: file's dir
    on_dir(root)
  end,
}
