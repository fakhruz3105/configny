return {
	"nvim-telescope/telescope.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local actions = require("telescope.actions")

		require("telescope").setup({
			defaults = {
				mappings = {
					-- "i" = Insert Mode (typing query)
					i = {
						["<F1>"] = actions.close,
						["<F3>"] = actions.close,
						["<Esc>"] = actions.close, -- Immediately close instead of going to normal mode
					},
					-- "n" = Normal Mode (scrolling results)
					n = {
						["<F1>"] = actions.close,
						["<F3>"] = actions.close,
						["<Esc>"] = actions.close,
					},
				},
			},
			pickers = {
				find_files = {
					hidden = true,
				},
			},
		})
	end,
}
