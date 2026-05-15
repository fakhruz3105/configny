-- Set key leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable space bar default behaviour
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

local opts = { noremap = true, silent = true }
local function with_desc(desc)
	return vim.tbl_extend("force", opts, { desc = desc })
end

-- Keymaps set here
vim.keymap.set("n", "<leader>s", "<cmd> w <CR>", with_desc("Save file"))
vim.keymap.set("n", "<leader>w", "<cmd> bd <CR>", with_desc("Close buffer"))
vim.keymap.set("n", "<leader>q", "<cmd> q <CR>", with_desc("Quit window"))
vim.keymap.set("n", "<leader>bp", ":bprevious<CR>", with_desc("Previous buffer"))
vim.keymap.set("n", "<leader>bn", ":bnext<CR>", with_desc("Next buffer"))

-- Telescope keymaps
vim.keymap.set("n", "<leader>f", ":Telescope current_buffer_fuzzy_find <CR>", with_desc("Fuzzy find in current buffer"))
vim.keymap.set("n", "<leader>F", ":Telescope live_grep <CR>", with_desc("Live grep across files"))
vim.keymap.set("n", "<F1>", ":Telescope find_files no_ignore=true hidden=true <CR>", with_desc("Find files"))
vim.keymap.set("n", "<F3>", ":Telescope buffers sort_mru=true ignore_current_buffer=true <CR>", with_desc("List buffers (MRU)"))

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
end, with_desc("Toggle Neo-tree"))

-- Conform keymaps
vim.keymap.set("n", "<C-S>", function()
	require("conform").format({ lsp_fallback = true })
end, { desc = "Format file" })

-- Show a cheatsheet of all keymaps (with descriptions) in a floating window
vim.keymap.set("n", "<F12>", function()
	local mode_labels = { n = "NORMAL", i = "INSERT", v = "VISUAL", x = "VISUAL", t = "TERMINAL", o = "OP-PENDING" }
	local modes = { "n", "i", "v", "x", "t", "o" }

	-- Collect (mode, lhs, desc) tuples, grouped by mode
	local groups = {}
	local seen = {}
	for _, mode in ipairs(modes) do
		local label = mode_labels[mode] or mode
		groups[label] = groups[label] or {}
		-- Global maps
		for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
			if map.desc and map.desc ~= "" then
				local key = label .. "\0" .. map.lhs
				if not seen[key] then
					seen[key] = true
					table.insert(groups[label], { lhs = map.lhs, desc = map.desc })
				end
			end
		end
		-- Buffer-local maps
		for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
			if map.desc and map.desc ~= "" then
				local key = label .. "\0" .. map.lhs
				if not seen[key] then
					seen[key] = true
					table.insert(groups[label], { lhs = map.lhs, desc = map.desc })
				end
			end
		end
	end

	-- Build display lines
	local lines = {}
	local order = { "NORMAL", "INSERT", "VISUAL", "TERMINAL", "OP-PENDING" }
	for _, label in ipairs(order) do
		local entries = groups[label]
		if entries and #entries > 0 then
			table.sort(entries, function(a, b)
				return a.lhs < b.lhs
			end)
			table.insert(lines, "── " .. label .. " ──")
			local widest = 0
			for _, e in ipairs(entries) do
				if #e.lhs > widest then
					widest = #e.lhs
				end
			end
			for _, e in ipairs(entries) do
				table.insert(lines, string.format("  %-" .. (widest + 2) .. "s  %s", e.lhs, e.desc))
			end
			table.insert(lines, "")
		end
	end

	if #lines == 0 then
		vim.notify("No keymaps with descriptions found", vim.log.levels.INFO)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "help"

	local width = math.min(100, math.floor(vim.o.columns * 0.8))
	local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.85))
	vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " Keymaps ",
		title_pos = "center",
	})

	vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, noremap = true, silent = true })
	vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = buf, noremap = true, silent = true })
	vim.keymap.set("n", "<F12>", "<cmd>close<CR>", { buffer = buf, noremap = true, silent = true })
end, { desc = "Show keymap cheatsheet" })

-- Show the commit diff that last touched the current line in a floating window
vim.keymap.set("n", "<F9>", function()
	local file = vim.fn.expand("%:p")
	if file == "" or vim.fn.filereadable(file) == 0 then
		vim.notify("No file for current buffer", vim.log.levels.WARN)
		return
	end

	local line = vim.fn.line(".")
	local file_dir = vim.fn.fnamemodify(file, ":h")
	local blame_cmd = string.format(
		"git -C %s blame -L %d,%d --porcelain -- %s",
		vim.fn.shellescape(file_dir),
		line,
		line,
		vim.fn.shellescape(file)
	)
	local blame_out = vim.fn.systemlist(blame_cmd)
	if vim.v.shell_error ~= 0 or #blame_out == 0 then
		vim.notify("git blame failed: " .. table.concat(blame_out, "\n"), vim.log.levels.ERROR)
		return
	end

	local sha = blame_out[1]:match("^(%x+)")
	if not sha then
		vim.notify("Could not parse commit SHA", vim.log.levels.ERROR)
		return
	end
	if sha:match("^0+$") then
		vim.notify("Line is not committed yet", vim.log.levels.INFO)
		return
	end

	local show_cmd = string.format("git -C %s show --stat --patch %s", vim.fn.shellescape(file_dir), sha)
	local show_out = vim.fn.systemlist(show_cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify("git show failed: " .. table.concat(show_out, "\n"), vim.log.levels.ERROR)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, show_out)
	vim.bo[buf].filetype = "git"
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	local width = math.floor(vim.o.columns * 0.85)
	local height = math.floor(vim.o.lines * 0.85)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " " .. sha:sub(1, 8) .. " ",
		title_pos = "center",
	})

	vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, noremap = true, silent = true })
	vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = buf, noremap = true, silent = true })
	vim.keymap.set("n", "<F9>", "<cmd>close<CR>", { buffer = buf, noremap = true, silent = true })
end, { desc = "Show last commit diff for current line" })
