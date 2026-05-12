return {
  "nvim-treesitter/nvim-treesitter",
  event = { "BufReadPre", "BufNewFile" },
  build = ":TSUpdate",
  dependencies = {
    "windwp/nvim-ts-autotag",
  },
  config = function()
    require("nvim-treesitter").setup({
      ensure_installed = {
        "json", "javascript", "typescript", "tsx",
        "yaml", "html", "css", "markdown", "markdown_inline",
        "bash", "lua", "vim", "dockerfile", "gitignore",
        "query", "vimdoc",
      },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
    })

    require("nvim-ts-autotag").setup()
  end,
}
