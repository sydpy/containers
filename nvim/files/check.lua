-- Run at build time by ../Containerfile with `nvim -l`, which skips
-- sysinit.vim and init.lua. Fails, listing what is at fault, if a language
-- has no language server, or a server or formatter is not in $PATH.
local container = require('container')
local missing = {}

local filetypes = {
  'rust', 'python', 'javascript', 'javascriptreact', 'typescript',
  'typescriptreact', 'sh', 'html', 'css', 'scss', 'c', 'cpp', 'json',
  'jsonc', 'toml', 'yaml', 'markdown', 'dockerfile', 'cmake',
}
for _, ft in ipairs(filetypes) do
  if #vim.lsp.get_configs({ enabled = true, filetype = ft }) == 0 then
    table.insert(missing, 'no language server for ' .. ft)
  end
end

for name, config in pairs(container.servers) do
  if vim.fn.executable(config.cmd[1]) == 0 then
    table.insert(missing, name .. ': ' .. config.cmd[1] .. ' not found in $PATH')
  end
end
for ft, cmd in pairs(container.formatters) do
  if vim.fn.executable(cmd[1]) == 0 then
    table.insert(missing, ft .. ' formatter: ' .. cmd[1] .. ' not found in $PATH')
  end
end

if #missing > 0 then
  error(table.concat(missing, '\n'), 0)
end
print('nvim check: ok')
