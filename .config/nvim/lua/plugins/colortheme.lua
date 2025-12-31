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

-- return {
-- 	"ribru17/bamboo.nvim",
-- 	lazy = false,
-- 	priority = 1000,
--
-- 	config = function()
-- 		require("bamboo").setup({
-- 			-- optional configuration here
-- 		})
-- 		require("bamboo").load()
-- 	end,
-- }

-- return {
-- 	"rebelot/kanagawa.nvim",
-- 	lazy = false, -- load at startup
-- 	priority = 1000, -- ensure it loads before other plugins
-- 	config = function()
-- 		-- Default options:
-- 		require("kanagawa").setup({
-- 			compile = false, -- enable compiling the colorscheme
-- 			undercurl = true, -- enable undercurls
-- 			commentStyle = { italic = true },
-- 			functionStyle = {},
-- 			keywordStyle = { italic = true },
--
-- 			statementStyle = { bold = true },
-- 			typeStyle = {},
-- 			transparent = false, -- do not set background color
-- 			dimInactive = false, -- dim inactive window `:h hl-NormalNC`
-- 			terminalColors = true, -- define vim.g.terminal_color_{0,17}
-- 			colors = { -- add/modify theme and palette colors
-- 				palette = {},
-- 				theme = { wave = {}, lotus = {}, dragon = {}, all = {} },
-- 			},
-- 			overrides = function(colors) -- add/modify highlights
-- 				return {}
-- 			end,
-- 			theme = "wave", -- Load "wave" theme when 'background' option is not set
-- 			background = { -- map the value of 'background' option to a theme
-- 				dark = "wave", -- try "dragon" !
--
-- 				light = "lotus",
-- 			},
-- 		})
--
-- 		-- setup must be called before loading
-- 		vim.cmd("colorscheme kanagawa")
-- 	end,
-- }
