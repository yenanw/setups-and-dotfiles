-- Restore the subtle color-column highlight now and after colorscheme changes.
local function set_colorcolumn_highlight()
  vim.api.nvim_set_hl(0, "ColorColumn", { bg = "#1c1c1c" })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = set_colorcolumn_highlight,
})

set_colorcolumn_highlight()
