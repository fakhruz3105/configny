return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		preset = "modern",
		delay = 300,
		win = { border = "rounded" },
		spec = {
			{ "<leader>b", group = "buffer" },
			{ "<leader>c", group = "code" },
			{ "<leader>d", group = "document" },
			{ "<leader>h", group = "hunk (git)" },
			{ "<leader>r", group = "rename" },
			{ "<leader>t", group = "toggle" },
			{ "<leader>w", group = "window/buffer" },
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)",
		},
	},
}
