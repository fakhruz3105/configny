return {
	"nvim-telescope/telescope.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
	},
	config = function()
		local actions = require("telescope.actions")

		require("telescope").setup({
			defaults = {
				mappings = {
					i = {
						["<F1>"] = actions.close,
						["<F3>"] = actions.close,
						["<F13>"] = actions.close,
						["<Esc>"] = actions.close,
					},
					n = {
						["<F1>"] = actions.close,
						["<F3>"] = actions.close,
						["<F13>"] = actions.close,
						["<Esc>"] = actions.close,
					},
				},
			},
			pickers = {
				find_files = {
					file_ignore_patterns = { "node_modules", ".git" },
				},
			},
			extensions = {
				fzf = {
					fuzzy = true,
					override_generic_sorter = true,
					override_file_sorter = true,
					case_mode = "smart_case",
				},
			},
		})

		pcall(require("telescope").load_extension, "fzf")
	end,
}
