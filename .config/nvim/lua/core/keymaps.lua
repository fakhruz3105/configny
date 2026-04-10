-- Set key leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable space bar default behaviour
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

local opts = { noremap = true, silent = true }

-- Keymaps set here
vim.keymap.set("n", "<leader>s", "<cmd> w <CR>", opts)
vim.keymap.set("n", "<leader>w", "<cmd> bd <CR>", opts)
vim.keymap.set("n", "<leader>q", "<cmd> q <CR>", opts)
vim.keymap.set("n", "<leader>bp", ":bprevious<CR>", opts)
vim.keymap.set("n", "<leader>bn", ":bnext<CR>", opts)

-- Telescope keymaps
vim.keymap.set("n", "<leader>f", ":Telescope current_buffer_fuzzy_find <CR>", opts)
vim.keymap.set("n", "<leader>F", ":Telescope live_grep <CR>", opts)
vim.keymap.set("n", "<F1>", ":Telescope find_files no_ignore=true hidden=true <CR>", opts)
vim.keymap.set("n", "<F3>", ":Telescope buffers <CR>", opts)

vim.keymap.set("n", "<F2>", function()
	local neo_tree_win = nil
	local current_win = vim.api.nvim_get_current_win()

	-- Find Neo-tree window if it exists
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].filetype == "neo-tree" then
			neo_tree_win = win
			break
		end
	end

	if not neo_tree_win then
		-- 1. Neo-tree not open → open it
		vim.cmd("Neotree toggle")
	elseif neo_tree_win ~= current_win then
		-- 2. Neo-tree open but not focused → focus it
		vim.api.nvim_set_current_win(neo_tree_win)
	else
		-- 3. Neo-tree open and focused → close it
		vim.cmd("Neotree toggle")
	end
end, opts)

-- Conform keymaps
vim.keymap.set("n", "<C-S>", function()
	require("conform").format({ lsp_fallback = true })
end, { desc = "Format file" })
