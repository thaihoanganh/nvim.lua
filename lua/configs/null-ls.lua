local status_ok, null_ls = require("null-ls")

if not status_ok
then
  return
end

local async_formatting = function(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	vim.lsp.buf_request(
		bufnr,
		"textDocument/formatting",
		vim.lsp.util.make_formatting_params {},
		function(err, res, ctx)
			if err then
				local err_msg = type(err) == "string" and err or err.message
				-- you can modify the log message / level (or ignore it completely)
				vim.notify("formatting: " .. err_msg, vim.log.levels.WARN)
				return
			end

			-- don't apply results if buffer is unloaded or has been modified
			if not vim.api.nvim_buf_is_loaded(bufnr) or vim.api.nvim_buf_get_option(bufnr, "modified") then
				return
			end

			if res then
				local client = vim.lsp.get_client_by_id(ctx.client_id)
				vim.lsp.util.apply_text_edits(res, bufnr, client and client.offset_encoding or "utf-16")
				vim.api.nvim_buf_call(bufnr, function()
					vim.cmd "silent noautocmd update"
				end)
			end
		end
	)
end

local is_disable_null_ls = 0

local disable_null_ls = function()
	is_disable_null_ls = 1
end

vim.api.nvim_create_user_command("NullLsDisable", disable_null_ls, {})

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

local should_enable_eslint = function(utils)
	return utils.root_has_file { "node_modules/.bin/eslint" }
end

null_ls.setup {
	sources = {
		null_ls.builtins.diagnostics.eslint.with {
			condition = should_enable_eslint,
		},
		null_ls.builtins.formatting.eslint.with {
			condition = should_enable_eslint,
		},
		null_ls.builtins.formatting.prettier,
		null_ls.builtins.formatting.stylua,
		-- null_ls.builtins.completion.spell,
		null_ls.builtins.code_actions.gitsigns,
		null_ls.builtins.code_actions.eslint.with {
			condition = should_enable_eslint,
		},
	},
	on_attach = function(client, bufnr)
		if client.supports_method "textDocument/formatting" then
			vim.api.nvim_clear_autocmds { group = augroup, buffer = bufnr }
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				buffer = bufnr,
				callback = function()
					if is_disable_null_ls == 0 then
						async_formatting(bufnr)
					end
				end,
			})
		end
	end,
}
