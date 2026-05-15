local M = {}

local terminals = {}
local id_to_key = { [1] = "F4", [2] = "F5", [3] = "F6" }

local function get_terminal(id)
	if not terminals[id] then
		terminals[id] = { buf = nil, win = nil, term_id = nil }
	end
	return terminals[id]
end

local function get_project_root()
	local cwd = vim.fn.getcwd()
	local git_root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(cwd) .. " rev-parse --show-toplevel")[1]
	if vim.v.shell_error == 0 and git_root then
		return git_root
	end
	return cwd
end

local function create_floating_window(state, id)
	local width = math.floor(vim.o.columns * 0.85)
	local height = math.floor(vim.o.lines * 0.85)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		buf = state.buf
	else
		buf = vim.api.nvim_create_buf(false, true)
		state.buf = buf
	end

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " " .. id_to_key[id] .. " ",
		title_pos = "center",
	})
	state.win = win

	vim.api.nvim_set_option_value("winblend", 0, { win = win })

	return { buf = buf, win = win }
end

local function is_floating_open(state)
	return state.win and vim.api.nvim_win_is_valid(state.win)
end

local function hide_all_terminals()
	for _, state in pairs(terminals) do
		if is_floating_open(state) then
			vim.api.nvim_win_hide(state.win)
			state.win = nil
		end
	end
end

function M.toggle(id)
	local state = get_terminal(id)

	if is_floating_open(state) then
		vim.api.nvim_win_hide(state.win)
		state.win = nil
		return
	end

	hide_all_terminals()

	local float = create_floating_window(state, id)

	if not state.term_id then
		vim.api.nvim_set_current_win(float.win)
		local project_root = get_project_root()
		state.term_id = vim.fn.jobstart(vim.o.shell, {
			term = true,
			cwd = project_root,
			on_exit = function()
				state.term_id = nil
				state.buf = nil
				if state.win and vim.api.nvim_win_is_valid(state.win) then
					vim.api.nvim_win_close(state.win, true)
					state.win = nil
				end
			end,
		})

		vim.cmd("startinsert")
	end

	for _, key in ipairs({ "<F4>", "<F5>", "<F6>" }) do
		local target_id = ({ ["<F4>"] = 1, ["<F5>"] = 2, ["<F6>"] = 3 })[key]
		local kopts = {
			buffer = float.buf,
			noremap = true,
			silent = true,
			desc = "Toggle terminal " .. target_id,
		}
		vim.keymap.set("t", key, function()
			M.toggle(target_id)
		end, kopts)
		vim.keymap.set("n", key, function()
			M.toggle(target_id)
		end, kopts)
	end
end

function M.kill(id)
	local state = get_terminal(id)

	if state.term_id then
		vim.fn.jobstop(state.term_id)
		state.term_id = nil
	end

	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		vim.api.nvim_buf_delete(state.buf, { force = true })
		state.buf = nil
	end

	if is_floating_open(state) then
		vim.api.nvim_win_close(state.win, true)
		state.win = nil
	end
end

function M.setup()
	local term_keys = { { "<F4>", 1 }, { "<F5>", 2 }, { "<F6>", 3 } }
	for _, spec in ipairs(term_keys) do
		local key, id = spec[1], spec[2]
		vim.keymap.set({ "n", "t" }, key, function()
			M.toggle(id)
		end, { noremap = true, silent = true, desc = "Toggle terminal " .. id })
	end

	vim.keymap.set({ "n", "t" }, "<F16>", function()
		M.kill(1)
	end, { noremap = true, silent = true, desc = "Kill terminal 1" })

	vim.api.nvim_create_autocmd("WinClosed", {
		callback = function(ev)
			for _, state in pairs(terminals) do
				if ev.match == tostring(state.win) then
					state.win = nil
				end
			end
		end,
	})
end

return M
