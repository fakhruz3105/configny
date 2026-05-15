return {
	"neovim/nvim-lspconfig",
	dependencies = {
		{ "mason-org/mason.nvim", config = true },
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		"saghen/blink.cmp",
		{
			"j-hui/fidget.nvim",
			opts = {
				notification = {
					window = {
						winblend = 0,
					},
				},
			},
		},
	},
	config = function()
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),
			callback = function(event)
				local map = function(keys, func, desc, mode)
					mode = mode or "n"
					vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
				end

				map("gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
				map("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
				map("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
				map("<leader>D", require("telescope.builtin").lsp_type_definitions, "Type [D]efinition")
				map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
				map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")
				map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
				map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "x" })
				map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
				map("gl", vim.diagnostic.open_float, "Show [L]ine Diagnostics")
				map("<leader>e", vim.diagnostic.open_float, "Show [E]rror Diagnostics")

				local client = vim.lsp.get_client_by_id(event.data.client_id)
				if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
					local highlight_augroup = vim.api.nvim_create_augroup("user-lsp-highlight", { clear = false })
					vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
						buffer = event.buf,
						group = highlight_augroup,
						callback = vim.lsp.buf.document_highlight,
					})

					vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
						buffer = event.buf,
						group = highlight_augroup,
						callback = vim.lsp.buf.clear_references,
					})

					vim.api.nvim_create_autocmd("LspDetach", {
						group = vim.api.nvim_create_augroup("user-lsp-detach", { clear = true }),
						callback = function(event2)
							vim.lsp.buf.clear_references()
							vim.api.nvim_clear_autocmds({ group = "user-lsp-highlight", buffer = event2.buf })
						end,
					})
				end

				if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
					map("<leader>th", function()
						vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
					end, "[T]oggle Inlay [H]ints")
				end
			end,
		})

		local capabilities = require("blink.cmp").get_lsp_capabilities()

		local vue_language_server_path = vim.fn.stdpath("data")
			.. "/mason/packages/vue-language-server/node_modules/@vue/language-server"
		local vue_plugin_available = vim.fn.isdirectory(vue_language_server_path) == 1

		local servers = {
			gopls = {},
			ts_ls = vue_plugin_available
					and {
						init_options = {
							plugins = {
								{
									name = "@vue/typescript-plugin",
									location = vue_language_server_path,
									languages = { "javascript", "typescript", "vue" },
								},
							},
						},
						filetypes = {
							"javascript",
							"javascriptreact",
							"typescript",
							"typescriptreact",
							"vue",
						},
					}
				or {},
			vue_ls = {},
			html = { filetypes = { "html", "twig", "hbs" } },
			cssls = {},
			tailwindcss = {},
			dockerls = {},
			sqlls = {},
			terraformls = {},
			jsonls = {},
			yamlls = {},
			lua_ls = {
				settings = {
					Lua = {
						completion = { callSnippet = "Replace" },
						runtime = { version = "LuaJIT" },
						workspace = { checkThirdParty = false },
						diagnostics = {
							globals = { "vim" },
							disable = { "missing-fields" },
						},
						format = { enable = false },
					},
				},
			},
			marksman = {},
		}

		-- mason-tool-installer expects Mason package names, which differ from
		-- nvim-lspconfig server names (e.g. lspconfig "jsonls" → mason "json-lsp").
		require("mason-tool-installer").setup({
			ensure_installed = {
				"gopls",
				"typescript-language-server",
				"vue-language-server",
				"html-lsp",
				"css-lsp",
				"tailwindcss-language-server",
				"dockerfile-language-server",
				"sqlls",
				"terraform-ls",
				"json-lsp",
				"yaml-language-server",
				"lua-language-server",
				"marksman",
				"stylua",
			},
		})

		for server, cfg in pairs(servers) do
			cfg.capabilities = vim.tbl_deep_extend("force", {}, capabilities, cfg.capabilities or {})
			vim.lsp.config(server, cfg)
			vim.lsp.enable(server)
		end

		vim.diagnostic.config({
			virtual_text = false,
			underline = true,
			update_in_insert = false,
			severity_sort = true,
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = "✘",
					[vim.diagnostic.severity.WARN] = "▲",
					[vim.diagnostic.severity.HINT] = "⚑",
					[vim.diagnostic.severity.INFO] = "»",
				},
			},
			float = {
				border = "rounded",
				source = true,
				header = "",
				prefix = "",
			},
		})

		local diagnostics_active = true
		vim.keymap.set("n", "<leader>td", function()
			diagnostics_active = not diagnostics_active
			vim.diagnostic.enable(diagnostics_active)
			print("Diagnostics: " .. (diagnostics_active and "ON" or "OFF"))
		end, { desc = "Toggle Diagnostics" })
	end,
}
