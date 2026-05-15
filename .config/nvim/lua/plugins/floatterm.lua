return {
	{
		"nvim-lua/plenary.nvim",
		config = function()
			local terminals = {}

			local function get_terminal(id)
				if not terminals[id] then
					terminals[id] = { buf = nil, win = nil, term_id = nil }
				end
				return terminals[id]
			end

			-- Read X11 clipboard text via xclip. Returns nil if the clipboard is
			-- empty, holds non-text data, or xclip is unavailable.
			local function get_clipboard_text()
				local targets = vim.fn.systemlist({ "xclip", "-selection", "clipboard", "-t", "TARGETS", "-o" })
				if vim.v.shell_error ~= 0 then
					return nil
				end
				local has_text = false
				for _, t in ipairs(targets) do
					if t == "UTF8_STRING" or t == "text/plain" or t == "text/plain;charset=utf-8" or t == "STRING" then
						has_text = true
						break
					end
				end
				if not has_text then
					return nil
				end
				local out = vim.fn.system({ "xclip", "-selection", "clipboard", "-o" })
				if vim.v.shell_error ~= 0 or not out or #out == 0 then
					return nil
				end
				if out:find("\0") then
					return nil
				end
				return out
			end

			-- If the clipboard holds an image, save it to a temp PNG and
			-- return its path. Returns nil otherwise.
			local function get_clipboard_image_path()
				local targets = vim.fn.systemlist({ "xclip", "-selection", "clipboard", "-t", "TARGETS", "-o" })
				if vim.v.shell_error ~= 0 then
					return nil
				end
				local has_png = false
				for _, t in ipairs(targets) do
					if t == "image/png" then
						has_png = true
						break
					end
				end
				if not has_png then
					return nil
				end
				local path = vim.fn.tempname() .. ".png"
				local cmd = string.format(
					"xclip -selection clipboard -t image/png -o > %s",
					vim.fn.shellescape(path)
				)
				vim.fn.system(cmd)
				if vim.v.shell_error ~= 0 then
					return nil
				end
				return path
			end

			-- Get project root directory
			local function get_project_root()
				local cwd = vim.fn.getcwd()
				local git_root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(cwd) .. " rev-parse --show-toplevel")[1]
				if vim.v.shell_error == 0 and git_root then
					return git_root
				end
				return cwd
			end

			local id_to_key = { [1] = "F4", [2] = "F5", [3] = "F6" }

			-- Create floating window
			local function create_floating_window(state, id)
				local width = math.floor(vim.o.columns * 0.85)
				local height = math.floor(vim.o.lines * 0.85)
				local row = math.floor((vim.o.lines - height) / 2)
				local col = math.floor((vim.o.columns - width) / 2)

				-- Create buffer
				local buf = nil
				if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
					buf = state.buf
				else
					buf = vim.api.nvim_create_buf(false, true)
					state.buf = buf
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
					title = " " .. id_to_key[id] .. " ",
					title_pos = "center",
				}

				-- Create window
				local win = vim.api.nvim_open_win(buf, true, opts)
				state.win = win

				-- Set window options
				vim.api.nvim_set_option_value("winblend", 0, { win = win })

				return { buf = buf, win = win }
			end

			-- Check if floating window is open
			local function is_floating_open(state)
				return state.win and vim.api.nvim_win_is_valid(state.win)
			end

			-- Hide any currently visible floating terminals (keeps processes alive)
			local function hide_all_terminals()
				for _, state in pairs(terminals) do
					if is_floating_open(state) then
						vim.api.nvim_win_hide(state.win)
						state.win = nil
					end
				end
			end

			-- Toggle floating terminal
			local function toggle_terminal(id)
				local state = get_terminal(id)

				if is_floating_open(state) then
					-- Hide the terminal
					vim.api.nvim_win_hide(state.win)
					state.win = nil
					return
				end

				-- Hide any other open terminal so views don't stack
				hide_all_terminals()

				-- Create or show terminal
				local float = create_floating_window(state, id)

				-- If terminal doesn't exist, create it
				if not state.term_id then
					vim.api.nvim_set_current_win(float.win)
					local project_root = get_project_root()
					vim.fn.termopen(vim.o.shell, {
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
					state.term_id = vim.b.terminal_job_id

					-- Enter insert mode
					vim.cmd("startinsert")
				end

				-- Set local keymaps for the terminal buffer
				for _, key in ipairs({ "<F4>", "<F5>", "<F6>" }) do
					local target_id = ({ ["<F4>"] = 1, ["<F5>"] = 2, ["<F6>"] = 3 })[key]
					local kopts = {
						buffer = float.buf,
						noremap = true,
						silent = true,
						desc = "Toggle terminal " .. target_id,
					}
					vim.keymap.set("t", key, function()
						toggle_terminal(target_id)
					end, kopts)
					vim.keymap.set("n", key, function()
						toggle_terminal(target_id)
					end, kopts)
				end

				-- Paste from clipboard straight to PTY, bypassing nvim's typeahead
				-- buffer (which can truncate large pastes via Ctrl+Shift+V).
				-- Falls back to a saved-PNG path if the clipboard holds an image.
				vim.keymap.set("t", "<C-v>", function()
					if not state.term_id then
						return
					end
					local clip = get_clipboard_text()
					if clip then
						vim.api.nvim_chan_send(state.term_id, clip)
						return
					end
					local img = get_clipboard_image_path()
					if img then
						vim.api.nvim_chan_send(state.term_id, img)
					end
				end, {
					buffer = float.buf,
					noremap = true,
					silent = true,
					desc = "Paste clipboard (text or image) into terminal",
				})
			end

			-- Kill terminal and close window
			local function kill_terminal(id)
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

			-- Set up keymaps: F4/F5/F6 each toggle an independent terminal
			local term_keys = { { "<F4>", 1 }, { "<F5>", 2 }, { "<F6>", 3 } }
			for _, spec in ipairs(term_keys) do
				local key, id = spec[1], spec[2]
				vim.keymap.set({ "n", "t" }, key, function()
					toggle_terminal(id)
				end, { noremap = true, silent = true, desc = "Toggle terminal " .. id })
			end

			vim.keymap.set(
				{ "n", "t" },
				"<F16>",
				function() kill_terminal(1) end,
				{ noremap = true, silent = true, desc = "Kill terminal 1" }
			)

			-- Auto command to handle window close
			vim.api.nvim_create_autocmd("WinClosed", {
				callback = function(ev)
					for _, state in pairs(terminals) do
						if ev.match == tostring(state.win) then
							state.win = nil
						end
					end
				end,
			})
		end,
	},
}
