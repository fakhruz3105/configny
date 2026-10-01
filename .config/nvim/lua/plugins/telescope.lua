return {
	"nvim-telescope/telescope.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
	},
	config = function()
		local actions = require("telescope.actions")

		-- Closing a picker mid-listing leaves its finder calling read_start on the
		-- closed stdout pipe. luv <= 1.52.1-0 then frees that callback ref twice, so a
		-- later Neovim callback runs telescope's reader ("async_job.lua:138: <id>").
		-- Park the finder instead, as the failed read_start would. Fixed in luv 226a876.
		local LinesPipe = require("telescope.async_job").LinesPipe
		local read = LinesPipe.read
		function LinesPipe:read()
			if self.handle:is_closing() then
				local _, rx = require("plenary.async").control.channel.oneshot()
				return rx()
			end
			return read(self)
		end

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
