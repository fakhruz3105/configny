return {
	dir = vim.fn.stdpath("config"),
	name = "floatterm",
	lazy = false,
	config = function()
		require("util.floatterm").setup()
	end,
}
