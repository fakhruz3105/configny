return {
	-- Seamless <C-j/k/l/;> navigation across nvim splits and tmux panes,
	-- matching the i3/AeroSpace layout (j=left, k=down, l=up, ;=right) rather
	-- than vim's hjkl. The matching tmux-side bindings live in ~/.tmux.conf.
	-- <C-;> has no ASCII control code, so it needs extended-keys in tmux.
	"christoomey/vim-tmux-navigator",
	cmd = {
		"TmuxNavigateLeft",
		"TmuxNavigateDown",
		"TmuxNavigateUp",
		"TmuxNavigateRight",
	},
	keys = {
		{ "<C-j>", "<cmd>TmuxNavigateLeft<CR>", desc = "Navigate left (nvim/tmux)" },
		{ "<C-k>", "<cmd>TmuxNavigateDown<CR>", desc = "Navigate down (nvim/tmux)" },
		{ "<C-l>", "<cmd>TmuxNavigateUp<CR>", desc = "Navigate up (nvim/tmux)" },
		{ "<C-;>", "<cmd>TmuxNavigateRight<CR>", desc = "Navigate right (nvim/tmux)" },
	},
}
