-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

local parser_config = require("nvim-treesitter.parsers").get_parser_configs()

parser_config.blade = {
  install_info = {
    url = "https://github.com/EmranMR/tree-sitter-blade",
    files = { "src/parser.c" },
    branch = "main",
  },
  filetype = "blade",
}

vim.filetype.add({
  pattern = {
    [".*%.blade%.php"] = "blade",
  },
})

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.blade.php" },
  callback = function(args)
    require("conform").format({ bufnr = args.buf })
  end,
})
