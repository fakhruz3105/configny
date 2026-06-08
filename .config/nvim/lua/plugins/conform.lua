return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" }, -- Load when opening a file
	config = function()
		local conform = require("conform")

		conform.setup({
			formatters_by_ft = {
				lua = { "stylua" },
				-- Use a sub-list to run only the first available formatter
				javascript = { "prettierd", "prettier", stop_after_first = true },
				typescript = { "prettierd", "prettier", stop_after_first = true },
				python = { "isort", "black" },
				go = { "gofmt" },
			},
			-- Respect the toggle flag; format manually via <leader>cf
			format_on_save = function()
				if vim.g.disable_autoformat or vim.b.disable_autoformat then
					return
				end
				return { timeout_ms = 500, lsp_fallback = true }
			end,
		})

		-- Default off; flip with <leader>tf
		vim.g.disable_autoformat = true

		vim.keymap.set({ "n", "x" }, "<leader>cf", function()
			conform.format({ async = true, lsp_fallback = true })
		end, { desc = "[C]ode [F]ormat" })

		vim.keymap.set("n", "<leader>tf", function()
			vim.g.disable_autoformat = not vim.g.disable_autoformat
			vim.notify("Format on save " .. (vim.g.disable_autoformat and "disabled" or "enabled"))
		end, { desc = "[T]oggle [F]ormat on save" })
	end,
}
