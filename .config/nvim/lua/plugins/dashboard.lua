return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		dashboard = {
			enabled = true,
			preset = {
				header = table.concat({
					"                                                    ",
					" ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
					" ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
					" ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
					" ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
					" ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
					" ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
					"                                                    ",
				}, "\n"),
				keys = {
					{ icon = " ", key = "f", desc = "Find File", action = ":Telescope find_files" },
					{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
					{ icon = " ", key = "g", desc = "Live Grep", action = ":Telescope live_grep" },
					{ icon = " ", key = "r", desc = "Recent Files", action = ":Telescope oldfiles" },
					{ icon = " ", key = "c", desc = "Config", action = ":e $MYVIMRC" },
					{ icon = " ", key = "L", desc = "Lazy", action = ":Lazy" },
					{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
				},
			},
			sections = {
				{ section = "header" },
				{ section = "keys", gap = 1, padding = 1 },
				{ section = "recent_files", limit = 5, padding = 1 },
				{ section = "startup" },
			},
		},
	},
}
