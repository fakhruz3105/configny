return {
	{
		"nvim-lua/plenary.nvim",
		config = function()
			local state = {
				floating = {
					buf = nil,
					win = nil,
					term_id = nil,
				},
			}

			-- Get project root directory
			local function get_project_root()
				local cwd = vim.fn.getcwd()
				local git_root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(cwd) .. " rev-parse --show-toplevel")[1]
				if vim.v.shell_error == 0 and git_root then
					return git_root
				end
				return cwd
			end

			-- Create floating window
			local function create_floating_window()
				local width = math.floor(vim.o.columns * 0.85)
				local height = math.floor(vim.o.lines * 0.85)
				local row = math.floor((vim.o.lines - height) / 2)
				local col = math.floor((vim.o.columns - width) / 2)

				-- Create buffer
				local buf = nil
				if state.floating.buf and vim.api.nvim_buf_is_valid(state.floating.buf) then
					buf = state.floating.buf
				else
					buf = vim.api.nvim_create_buf(false, true)
					state.floating.buf = buf
				end

				-- Window options
				local opts = {
					relative = "editor",
					width = width,
					height = height,
					row = row,
					col = col,
					style = "minimal",
					border = "rounded",
				}

				-- Create window
				local win = vim.api.nvim_open_win(buf, true, opts)
				state.floating.win = win

				-- Set window options
				vim.api.nvim_set_option_value("winblend", 0, { win = win })

				return { buf = buf, win = win }
			end

			-- Check if floating window is open
			local function is_floating_open()
				return state.floating.win and vim.api.nvim_win_is_valid(state.floating.win)
			end

			-- Toggle floating terminal
			local function toggle_terminal()
				if is_floating_open() then
					-- Hide the terminal
					vim.api.nvim_win_hide(state.floating.win)
					state.floating.win = nil
					return
				end

				-- Create or show terminal
				local float = create_floating_window()

				-- If terminal doesn't exist, create it
				if not state.floating.term_id then
					vim.api.nvim_set_current_win(float.win)
					local project_root = get_project_root()
					vim.fn.termopen(vim.o.shell, {
						cwd = project_root,
						on_exit = function()
							state.floating.term_id = nil
							state.floating.buf = nil
							if state.floating.win and vim.api.nvim_win_is_valid(state.floating.win) then
								vim.api.nvim_win_close(state.floating.win, true)
								state.floating.win = nil
							end
						end,
					})
					state.floating.term_id = vim.b.terminal_job_id

					-- Enter insert mode
					vim.cmd("startinsert")
				end

				-- Set local keymaps for the terminal buffer
				local opts = { buffer = float.buf, noremap = true, silent = true }
				vim.keymap.set("t", "<F4>", function()
					toggle_terminal()
				end, opts)
				vim.keymap.set("n", "<F4>", function()
					toggle_terminal()
				end, opts)
			end

			-- Kill terminal and close window
			local function kill_terminal()
				if state.floating.term_id then
					vim.fn.jobstop(state.floating.term_id)
					state.floating.term_id = nil
				end

				if state.floating.buf and vim.api.nvim_buf_is_valid(state.floating.buf) then
					vim.api.nvim_buf_delete(state.floating.buf, { force = true })
					state.floating.buf = nil
				end

				if is_floating_open() then
					vim.api.nvim_win_close(state.floating.win, true)
					state.floating.win = nil
				end
			end

			-- Set up keymaps
			vim.keymap.set({ "n", "t" }, "<F4>", toggle_terminal, { noremap = true, silent = true, desc = "Toggle terminal" })
			vim.keymap.set(
				{ "n", "t" },
				"<F16>",
				kill_terminal,
				{ noremap = true, silent = true, desc = "Kill terminal" }
			)

			-- Auto command to handle window close
			vim.api.nvim_create_autocmd("WinClosed", {
				callback = function(ev)
					if ev.match == tostring(state.floating.win) then
						state.floating.win = nil
					end
				end,
			})
		end,
	},
}
