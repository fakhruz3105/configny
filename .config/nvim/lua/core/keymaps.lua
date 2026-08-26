-- Set key leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable space bar default behaviour
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

local opts = { noremap = true, silent = true }
local function with_desc(desc)
	return vim.tbl_extend("force", opts, { desc = desc })
end

-- Cursor motion on jkl; instead of hjkl, matching the i3/AeroSpace layout
-- (j=left, k=down, l=up, ;=right). Mapped non-recursively, so every right-hand
-- side is the builtin motion rather than another mapping, and applied in
-- normal + visual + operator-pending so counts and operators (3k, d;, cl) work.
-- Pane navigation uses the same layout on <C-j/k/l/;> (see plugins/tmux-navigator.lua).
for _, m in ipairs({
	{ "j", "h", "Move left" },
	{ "k", "j", "Move down" },
	{ "l", "k", "Move up" },
	{ ";", "l", "Move right" },
}) do
	vim.keymap.set({ "n", "x", "o" }, m[1], m[2], with_desc(m[3]))
end

-- ';' used to repeat the last f/t search; h is now free, so it lands there.
vim.keymap.set({ "n", "x", "o" }, "h", ";", with_desc("Repeat last f/t"))

-- Clear search highlight
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", opts)

-- Diagnostic navigation
vim.keymap.set("n", "]d", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, with_desc("Next diagnostic"))
vim.keymap.set("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
end, with_desc("Previous diagnostic"))

-- Keymaps set here
vim.keymap.set("n", "<leader>s", "<cmd> w <CR>", with_desc("Save file"))
vim.keymap.set("n", "<leader>q", "<cmd> q <CR>", with_desc("Quit window"))
vim.keymap.set("n", "<leader>bp", ":bprevious<CR>", with_desc("Previous buffer"))
vim.keymap.set("n", "<leader>bn", ":bnext<CR>", with_desc("Next buffer"))
vim.keymap.set("n", "<leader>tw", "<cmd>set wrap!<CR>", with_desc("Toggle line wrap"))

-- Telescope keymaps
vim.keymap.set("n", "<leader>f", ":Telescope current_buffer_fuzzy_find <CR>", with_desc("Fuzzy find in current buffer"))
vim.keymap.set("n", "<leader>F", ":Telescope live_grep <CR>", with_desc("Live grep across files"))
vim.keymap.set("n", "<F1>", ":Telescope find_files no_ignore=true hidden=true <CR>", with_desc("Find files"))
vim.keymap.set("n", "<F3>", ":Telescope buffers sort_mru=true ignore_current_buffer=true <CR>", with_desc("List buffers (MRU)"))

vim.keymap.set("n", "<F2>", function()
	local neo_tree_win = nil
	local current_win = vim.api.nvim_get_current_win()

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].filetype == "neo-tree" then
			neo_tree_win = win
			break
		end
	end

	if not neo_tree_win then
		vim.cmd("Neotree toggle")
	elseif neo_tree_win ~= current_win then
		vim.api.nvim_set_current_win(neo_tree_win)
	else
		vim.cmd("Neotree toggle")
	end
end, with_desc("Toggle Neo-tree"))

-- Conform keymaps
vim.keymap.set("n", "<C-S>", function()
	require("conform").format({ lsp_fallback = true })
end, { desc = "Format file" })

-- Cheatsheet of all keymaps (with descriptions) in a floating window
vim.keymap.set("n", "<F12>", function()
	require("util.cheatsheet").show()
end, { desc = "Show keymap cheatsheet" })

-- Show the commit diff that last touched the current line in a floating window
vim.keymap.set("n", "<F9>", function()
	require("util.blame").show_last_commit()
end, { desc = "Show last commit diff for current line" })
