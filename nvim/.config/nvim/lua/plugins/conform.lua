return {
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters_by_ft = opts.formatters_by_ft or {}

    -- Ensure our Mason-installed formatters are used by default
    local preferred = {
      html = { "prettierd", "prettier" },
      css = { "prettierd", "prettier" },
      scss = { "prettierd", "prettier" },
      javascript = { "prettierd", "prettier" },
      javascriptreact = { "prettierd", "prettier" },
      typescript = { "prettierd", "prettier" },
      typescriptreact = { "prettierd", "prettier" },
      vue = { "prettierd", "prettier" },
      svelte = { "prettierd", "prettier" },
      json = { "prettierd", "prettier" },
      jsonc = { "prettierd", "prettier" },
      yaml = { "prettierd", "prettier" },
      markdown = { "prettierd", "prettier" },
      ["markdown.mdx"] = { "prettierd", "prettier" },
      lua = { "stylua" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      zsh = { "shfmt" },
      sql = { "sql-formatter" },
    }

    for ft, formatters in pairs(preferred) do
      opts.formatters_by_ft[ft] = formatters
    end

    return opts
  end,
}
