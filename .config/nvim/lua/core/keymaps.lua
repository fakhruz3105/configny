-- Set key leader
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Disable space bar default behaviour
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

local opts = { noremap = true, silent = true }

-- Keymaps set here
vim.keymap.set("n", "<leader>s", "<cmd> w <CR>", opts)
vim.keymap.set("n", "<leader>w", "<cmd> bd <CR>", opts)
vim.keymap.set("n", "<leader>q", "<cmd> q <CR>", opts)

-- Telescope keymaps
vim.keymap.set("n", "<C-f>", ":Telescope live_grep <CR>", opts)
vim.keymap.set("n", "<F1>", ":Telescope find_files <CR>", opts)
vim.keymap.set("n", "<F3>", ":Telescope buffers <CR>", opts)

-- Neotree keymaps
vim.keymap.set("n", "<F2>", ":Neotree toggle <CR>", opts)

-- Conform keymaps
vim.keymap.set("n", "<C-S>", function()
	require("conform").format({ lsp_fallback = true })
end, { desc = "Format file" })
