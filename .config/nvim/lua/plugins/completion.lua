return {
	"saghen/blink.cmp",
	version = "1.*",
	dependencies = {
		"rafamadriz/friendly-snippets",
	},
	event = { "InsertEnter", "CmdlineEnter" },
	---@module "blink.cmp"
	---@type blink.cmp.Config
	opts = {
		keymap = {
			preset = "default",
			["<CR>"] = { "accept", "fallback" },
			["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
			["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
			["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
			["<C-l>"] = { "snippet_forward", "fallback" },
			["<C-h>"] = { "snippet_backward", "fallback" },
		},
		completion = {
			accept = { auto_brackets = { enabled = true } },
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 200,
				window = { border = "rounded" },
			},
			menu = {
				border = "rounded",
				draw = {
					columns = {
						{ "kind_icon" },
						{ "label", "label_description", gap = 1 },
						{ "source_name" },
					},
				},
			},
			list = { selection = { preselect = false, auto_insert = true } },
		},
		signature = { enabled = true, window = { border = "rounded" } },
		sources = {
			default = { "lsp", "path", "snippets", "buffer", "lazydev" },
			providers = {
				lazydev = {
					name = "LazyDev",
					module = "lazydev.integrations.blink",
					score_offset = 100,
				},
			},
		},
		fuzzy = { implementation = "prefer_rust_with_warning" },
	},
	opts_extend = { "sources.default" },
}
