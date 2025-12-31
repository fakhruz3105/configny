return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" }, -- Load immediately when opening a file
	opts = {
		-- 1. TURN BLAME ALWAYS ON
		current_line_blame = true,

		-- 2. Customize Blame Appearance (Optional)
		current_line_blame_opts = {
			virt_text = true,
			virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
			delay = 300, -- Lowered to 300ms for faster appearance (default is 1000)
			ignore_whitespace = false,
			virt_text_priority = 100,
		},

		-- 3. Customize Blame Format (Optional)
		-- Formatting options: <author>, <author_time>, <summary>
		current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",

		-- 4. Standard Keymaps
		on_attach = function(bufnr)
			local gs = package.loaded.gitsigns

			local function map(mode, l, r, opts)
				opts = opts or {}
				opts.buffer = bufnr
				vim.keymap.set(mode, l, r, opts)
			end

			-- Navigation
			map("n", "]c", function()
				if vim.wo.diff then
					return "]c"
				end
				vim.schedule(function()
					gs.next_hunk()
				end)
				return "<Ignore>"
			end, { expr = true })

			map("n", "[c", function()
				if vim.wo.diff then
					return "[c"
				end
				vim.schedule(function()
					gs.prev_hunk()
				end)
				return "<Ignore>"
			end, { expr = true })

			-- Actions

			map("n", "<leader>hs", gs.stage_hunk)
			map("n", "<leader>hr", gs.reset_hunk)
			map("n", "<leader>hp", gs.preview_hunk)
			map("n", "<leader>tb", gs.toggle_current_line_blame) -- Toggle blame on/off
		end,
	},
}
