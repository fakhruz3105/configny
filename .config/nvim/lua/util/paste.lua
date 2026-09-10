-- Cmd+V handling.
--
-- Ghostty maps Cmd+V to a literal Ctrl-V (0x16) so that Claude Code can attach
-- clipboard images — see the "Paste" section of .config/ghostty/config — and
-- ~/.config/tmux/smart-paste passes that byte straight through to nvim panes.
-- So inside nvim, Cmd+V *is* <C-v>, and core/keymaps.lua binds <C-v> to a
-- paste. Blockwise-visual and insert-mode literal-next keep working on the
-- builtin <C-q> synonyms (:h CTRL-Q, :h i_CTRL-Q).
--
-- Terminal buffers can't be settled with a static mapping the way the editor
-- ones can: Claude Code running in a floating terminal still needs the raw
-- 0x16 to pick a clipboard image up. Mirror smart-paste's per-pane decision
-- per job instead — raw byte for Claude Code with an image on the clipboard, a
-- bracketed text paste for everything else.

local M = {}

-- Same foreground-process probe smart-paste and the tmux pane bindings use:
-- the job's own pid gives the pty, and everything on that pty gets listed as
-- "<state> <command>".
local function foreground_is_claude(job)
	local ok, pid = pcall(vim.fn.jobpid, job)
	if not ok or type(pid) ~= "number" or pid <= 0 then
		return false
	end

	local tty = vim.trim(vim.fn.system({ "ps", "-o", "tty=", "-p", tostring(pid) }))
	if vim.v.shell_error ~= 0 or tty == "" or tty == "??" then
		return false
	end

	local procs = vim.fn.systemlist({ "ps", "-o", "state=", "-o", "comm=", "-t", tty })
	if vim.v.shell_error ~= 0 then
		return false
	end

	for _, line in ipairs(procs) do
		local state, comm = line:match("^(%S+)%s+(.+)$")
		-- Stopped/dead/zombie processes are not the foreground one.
		if state and not state:match("[TXZ]") and comm:match("([^/]+)$") == "claude" then
			return true
		end
	end

	return false
end

local function clipboard_has_image()
	if vim.fn.has("mac") == 1 then
		local info = vim.fn.system({ "osascript", "-e", "clipboard info" })
		return vim.v.shell_error == 0 and (info:match("PNGf") or info:match("TIFF picture")) ~= nil
	end

	local targets = vim.fn.system({ "xclip", "-selection", "clipboard", "-t", "TARGETS", "-o" })
	return vim.v.shell_error == 0 and targets:match("image/") ~= nil
end

function M.terminal()
	local job = vim.b.terminal_job_id
	if not job then
		return
	end

	if clipboard_has_image() and foreground_is_claude(job) then
		vim.api.nvim_chan_send(job, "\22")
		return
	end

	local text = vim.fn.getreg("+")
	if text == "" then
		return
	end

	-- Bracketed paste, like tmux's `paste-buffer -p`: newlines stay literal
	-- instead of being run, and multi-line input reaches Claude Code as one
	-- block. zsh and Claude Code both enable the mode; a program that does not
	-- would see the markers as text, which is the same trade-off tmux makes.
	vim.api.nvim_chan_send(job, "\27[200~" .. text .. "\27[201~")
end

return M
