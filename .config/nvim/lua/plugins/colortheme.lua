return {
	"Mofiqul/vscode.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		-- Optional: Customize the configuration
		local c = require("vscode.colors").get_colors()
		require("vscode").setup({
			-- style = 'light', -- Uncomment for light mode (defaults to dark)
			transparent = false,
			italic_comments = true,
			underline_links = true,
			disable_nvimtree_bg = true,
		})
		-- Load the colorscheme
		vim.cmd.colorscheme("vscode")
	end,
}
