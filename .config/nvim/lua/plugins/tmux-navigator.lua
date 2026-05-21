return {
	-- Seamless <C-h/j/k/l> navigation across nvim splits and tmux panes.
	-- The matching tmux-side bindings live in ~/.tmux.conf.
	"christoomey/vim-tmux-navigator",
	cmd = {
		"TmuxNavigateLeft",
		"TmuxNavigateDown",
		"TmuxNavigateUp",
		"TmuxNavigateRight",
	},
	keys = {
		{ "<C-h>", "<cmd>TmuxNavigateLeft<CR>", desc = "Navigate left (nvim/tmux)" },
		{ "<C-j>", "<cmd>TmuxNavigateDown<CR>", desc = "Navigate down (nvim/tmux)" },
		{ "<C-k>", "<cmd>TmuxNavigateUp<CR>", desc = "Navigate up (nvim/tmux)" },
		{ "<C-l>", "<cmd>TmuxNavigateRight<CR>", desc = "Navigate right (nvim/tmux)" },
	},
}
