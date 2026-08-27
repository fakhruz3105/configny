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

-- Shim the `all = false` option of vim.treesitter.query.add_predicate/add_directive
-- (removed in nvim 0.12). nvim-treesitter's master branch still registers its
-- predicates and directives with it and assumes each match entry is a single
-- TSNode, so without this every fenced markdown block and every `<script
-- type=...>` injection dies with "attempt to call method 'range' (a nil value)".
do
	local tsq = require("vim.treesitter.query")
	for _, name in ipairs({ "add_predicate", "add_directive" }) do
		local add = tsq[name]
		tsq[name] = function(pname, handler, opts)
			if type(opts) == "table" and opts.all == false then
				local inner = handler
				handler = function(match, ...)
					local single = {}
					for id, nodes in pairs(match) do
						single[id] = nodes[#nodes]
					end
					return inner(single, ...)
				end
			end
			return add(pname, handler, opts)
		end
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
}, {
	change_detection = { notify = false },
	performance = {
		rtp = {
			disabled_plugins = {
				"gzip",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
				"netrwPlugin",
			},
		},
	},
})
