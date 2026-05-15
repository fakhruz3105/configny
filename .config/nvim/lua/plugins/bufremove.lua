return {
	"echasnovski/mini.bufremove",
	keys = {
		{
			"<leader>w",
			function()
				require("mini.bufremove").delete(0, false)
			end,
			desc = "Close buffer (keep window)",
		},
		{
			"<leader>W",
			function()
				require("mini.bufremove").delete(0, true)
			end,
			desc = "Force close buffer",
		},
	},
}
