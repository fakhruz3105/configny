vim.opt.clipboard = "unnamedplus"
vim.wo.number = true
vim.o.ignorecase = true
vim.o.shiftwidth = 2
vim.o.tabstop = 2
vim.o.softtabstop = 2
vim.o.expandtab = true
vim.o.scrolloff = 2
vim.o.sidescrolloff = 4
vim.opt.termguicolors = true
vim.o.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
	command = "if mode() != 'c' | checktime | endif",
	pattern = { "*" },
})
