require("core.keymaps")
require("core.options")

-- Shim deprecated vim.tbl_flatten (removed in nvim 0.13) so older plugin
-- versions (neo-tree, lualine, autopairs, treesitter) don't spam warnings.
if vim.iter then
	---@diagnostic disable-next-line: duplicate-set-field
	vim.tbl_flatten = function(t)
		return vim.iter(t):flatten(math.huge):totable()
	end
end

-- Lazyvim plugin
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		error("Error cloning lazy.nvim:\n" .. out)
	end
end

local rtp = vim.opt.rtp
rtp:prepend(lazypath)

require("lazy").setup({
	{ import = "plugins" },
})
