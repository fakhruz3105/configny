local M = {}

function M.show_last_commit()
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
	vim.api.nvim_open_win(buf, true, {
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
end

return M
