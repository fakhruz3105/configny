local M = {}

local mode_labels = { n = "NORMAL", i = "INSERT", v = "VISUAL", x = "VISUAL", t = "TERMINAL", o = "OP-PENDING" }
local modes = { "n", "i", "v", "x", "t", "o" }
local order = { "NORMAL", "INSERT", "VISUAL", "TERMINAL", "OP-PENDING" }

function M.show()
	local groups = {}
	local seen = {}
	for _, mode in ipairs(modes) do
		local label = mode_labels[mode] or mode
		groups[label] = groups[label] or {}
		for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
			if map.desc and map.desc ~= "" then
				local key = label .. "\0" .. map.lhs
				if not seen[key] then
					seen[key] = true
					table.insert(groups[label], { lhs = map.lhs, desc = map.desc })
				end
			end
		end
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

	local lines = {}
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
end

return M
