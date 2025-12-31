return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		-- 1. TURN BLAME ALWAYS ON
		current_line_blame = true,

		-- 2. Customize Blame Appearance
		current_line_blame_opts = {
			virt_text = true,
			virt_text_pos = "eol",
			delay = 300,
			ignore_whitespace = false,
			virt_text_priority = 100,
		},

		current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",

		-- 3. Keymaps
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
			end, { expr = true, desc = "Next Hunk" })

			map("n", "[c", function()
				if vim.wo.diff then
					return "[c"
				end
				vim.schedule(function()
					gs.prev_hunk()
				end)
				return "<Ignore>"
			end, { expr = true, desc = "Prev Hunk" })

			-- Actions (Normal Mode)
			map("n", "<leader>hs", gs.stage_hunk, { desc = "Stage Hunk" })
			map("n", "<leader>hr", gs.reset_hunk, { desc = "Reset Hunk" })
			map("n", "<leader>hp", gs.preview_hunk, { desc = "Preview Hunk" })
			map("n", "<leader>tb", gs.toggle_current_line_blame, { desc = "Toggle Line Blame" })
			map("n", "<leader>hd", gs.diffthis, { desc = "Diff This" })

			-- Actions (Visual Mode) - NEW!
			-- Allows selecting specific lines to stage/reset
			map("v", "<leader>hs", function()
				gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, { desc = "Stage Selected Lines" })

			map("v", "<leader>hr", function()
				gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, { desc = "Reset Selected Lines" })
		end,
	},
}
