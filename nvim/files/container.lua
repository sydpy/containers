-- Neovim setup for the tools in the nvim image, loaded by sysinit.vim before
-- the user's init.lua, which can override any of it. No plugins: language
-- servers through vim.lsp.config, completion through vim.lsp.completion,
-- formatting on save through the formatters below or the servers.
--
-- Highlighting is Vim's regex syntax files, except for the languages with a
-- tree-sitter parser bundled with Neovim (C, Lua, Markdown, Vim script, help).

vim.o.number = true
vim.o.signcolumn = 'yes'
vim.o.scrolloff = 5
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.undofile = true
vim.o.expandtab = true
vim.o.shiftwidth = 4
vim.o.softtabstop = -1
vim.o.winborder = 'rounded'
vim.o.completeopt = 'menuone,noselect,popup,fuzzy'
vim.g.mapleader = ' '

vim.diagnostic.config({ virtual_text = true, severity_sort = true })

-- Tree-sitter highlighting for every filetype that has a parser
vim.api.nvim_create_autocmd('FileType', {
  callback = function(ev)
    pcall(vim.treesitter.start, ev.buf)
  end,
})

-- Language servers. Each name is the server's name in helix, and the
-- commands and settings follow helix's languages.toml.
local servers = {
  ['rust-analyzer'] = {
    cmd = { 'rust-analyzer' },
    filetypes = { 'rust' },
    root_markers = { 'Cargo.toml' },
  },
  ty = {
    cmd = { 'ty', 'server' },
    filetypes = { 'python' },
    root_markers = { 'pyproject.toml', 'setup.py' },
  },
  ruff = {
    cmd = { 'ruff', 'server' },
    filetypes = { 'python' },
    root_markers = { 'pyproject.toml', 'ruff.toml', '.ruff.toml' },
  },
  ['typescript-language-server'] = {
    cmd = { 'typescript-language-server', '--stdio' },
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json' },
  },
  ['vscode-eslint-language-server'] = {
    cmd = { 'vscode-eslint-language-server', '--stdio' },
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    root_markers = { 'package.json' },
    settings = {
      validate = 'on',
      experimental = { useFlatConfig = false },
      rulesCustomizations = {},
      run = 'onType',
      problems = { shortenToSingleLine = false },
      nodePath = '',
      codeAction = {
        disableRuleComment = { enable = true, location = 'separateLine' },
        showDocumentation = { enable = true },
      },
      workingDirectory = { mode = 'location' },
    },
  },
  ['vscode-html-language-server'] = {
    cmd = { 'vscode-html-language-server', '--stdio' },
    filetypes = { 'html' },
  },
  ['vscode-css-language-server'] = {
    cmd = { 'vscode-css-language-server', '--stdio' },
    filetypes = { 'css', 'scss' },
    settings = { css = { validate = true }, scss = { validate = true } },
  },
  ['vscode-json-language-server'] = {
    cmd = { 'vscode-json-language-server', '--stdio' },
    filetypes = { 'json', 'jsonc' },
    settings = { json = { validate = { enable = true } } },
  },
  ['bash-language-server'] = {
    cmd = { 'bash-language-server', 'start' },
    filetypes = { 'sh', 'bash' },
  },
  ['yaml-language-server'] = {
    cmd = { 'yaml-language-server', '--stdio' },
    filetypes = { 'yaml' },
  },
  marksman = {
    cmd = { 'marksman', 'server' },
    filetypes = { 'markdown' },
    root_markers = { '.marksman.toml' },
  },
  taplo = {
    cmd = { 'taplo', 'lsp', 'stdio' },
    filetypes = { 'toml' },
  },
  neocmakelsp = {
    cmd = { 'neocmakelsp', 'stdio' },
    filetypes = { 'cmake' },
  },
  ['docker-langserver'] = {
    cmd = { 'docker-langserver', '--stdio' },
    filetypes = { 'dockerfile' },
  },
  clangd = {
    cmd = { 'clangd' },
    filetypes = { 'c', 'cpp' },
    root_markers = { '.clangd', 'compile_commands.json' },
  },
}

-- A server's root is the nearest directory with one of its markers, else
-- the repository's. A file outside both still gets a server, without a root.
for name, config in pairs(servers) do
  config.root_markers = config.root_markers and { config.root_markers, '.git' } or { '.git' }
  vim.lsp.config(name, config)
end
vim.lsp.enable(vim.tbl_keys(servers))

-- Formatters run on the buffer, as helix does: from the file's directory,
-- with the text on stdin and the file name in place of '%', so prettier and
-- shfmt find the project's configuration. Every other filetype is formatted
-- by its language servers: rustfmt, ruff, clang-format, taplo and so on.
local prettier = { 'prettier', '--stdin-filepath', '%' }
local formatters = {
  javascript = prettier,
  javascriptreact = prettier,
  typescript = prettier,
  typescriptreact = prettier,
  json = prettier,
  jsonc = prettier,
  html = prettier,
  css = prettier,
  scss = prettier,
  yaml = prettier,
  markdown = prettier,
  sh = { 'shfmt', '--filename', '%' },
  bash = { 'shfmt', '--filename', '%' },
}

local function format(buf)
  local formatter = formatters[vim.bo[buf].filetype]
  if not formatter then
    if #vim.lsp.get_clients({ bufnr = buf, method = 'textDocument/formatting' }) > 0 then
      vim.lsp.buf.format({ bufnr = buf, timeout_ms = 3000 })
    end
    return
  end

  local name = vim.api.nvim_buf_get_name(buf)
  local cmd = vim.tbl_map(function(arg)
    return arg == '%' and name or arg
  end, formatter)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local ok, result = pcall(function()
    return vim.system(cmd, {
      cwd = vim.fs.dirname(name),
      stdin = table.concat(lines, '\n') .. '\n',
      text = true,
    }):wait(5000)
  end)
  if not ok or result.code ~= 0 then
    local err = ok and result.stderr or result
    vim.notify(cmd[1] .. ': ' .. vim.trim(err), vim.log.levels.WARN)
    return
  end

  local formatted = vim.split(result.stdout, '\n')
  if formatted[#formatted] == '' then
    table.remove(formatted)
  end
  if not vim.deep_equal(lines, formatted) then
    local view = vim.fn.winsaveview()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, formatted)
    vim.fn.winrestview(view)
  end
end

-- `:noautocmd write` saves without formatting.
vim.api.nvim_create_autocmd('BufWritePre', {
  callback = function(ev)
    format(ev.buf)
  end,
})
vim.api.nvim_create_user_command('Format', function()
  format(vim.api.nvim_get_current_buf())
end, {})

-- Completion pops up as you type, as in helix, rather than only after a
-- server's trigger characters such as '.'. Tab and Shift-Tab move through
-- the menu, Enter accepts the selected item, which also applies its edits
-- (an import, for one), and Ctrl-Space opens the menu by hand.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if client:supports_method('textDocument/completion') then
      local provider = client.server_capabilities.completionProvider
      local chars = provider.triggerCharacters or {}
      if not vim.tbl_contains(chars, 'a') then
        for c in ('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_'):gmatch('.') do
          table.insert(chars, c)
        end
        provider.triggerCharacters = chars
      end
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
  end,
})

local function pum_key(key, fallback)
  return function()
    return vim.fn.pumvisible() == 1 and key or fallback
  end
end
vim.keymap.set('i', '<Tab>', pum_key('<C-n>', '<Tab>'), { expr = true })
vim.keymap.set('i', '<S-Tab>', pum_key('<C-p>', '<S-Tab>'), { expr = true })
vim.keymap.set('i', '<CR>', function()
  local selected = vim.fn.pumvisible() == 1 and vim.fn.complete_info({ 'selected' }).selected ~= -1
  return selected and '<C-y>' or '<CR>'
end, { expr = true })
vim.keymap.set('i', '<C-Space>', vim.lsp.completion.get)

-- The command line completes as you type, in a menu. :find is a fuzzy
-- file picker over the files ripgrep lists, which leaves out hidden files
-- and those .gitignore excludes, as helix's picker does. Enter opens the
-- first match if none is selected.
vim.o.wildmode = 'noselect:lastused,full'
vim.opt.wildoptions:append('fuzzy')
vim.api.nvim_create_autocmd('CmdlineChanged', {
  pattern = ':',
  callback = function()
    vim.fn.wildtrigger()
  end,
})

local files
function _G.find_files(arg)
  files = files or vim.fn.systemlist({ 'rg', '--files' })
  return arg == '' and files or vim.fn.matchfuzzy(files, arg)
end
vim.o.findfunc = 'v:lua.find_files'
vim.api.nvim_create_autocmd('CmdlineEnter', {
  pattern = ':',
  callback = function()
    files = nil
  end,
})
vim.api.nvim_create_autocmd('CmdlineLeavePre', {
  pattern = ':',
  callback = function()
    local info = vim.fn.cmdcomplete_info()
    if vim.fn.getcmdline():match('^%s*fin?d?%s') and info.selected == -1 and #(info.matches or {}) > 0 then
      vim.fn.setcmdline('find ' .. info.matches[1])
    end
  end,
})

-- :grep searches the same files with ripgrep, and opens the matches in the
-- quickfix window. (Neovim's default searches every file, with -uu.)
vim.o.grepprg = 'rg --vimgrep --smart-case'
vim.api.nvim_create_autocmd('QuickFixCmdPost', {
  pattern = 'grep',
  command = 'cwindow',
})

-- Keys after helix's goto and space modes. Neovim's own LSP keys stay: K
-- (hover), grn (rename), gra (code action), grr (references), gri
-- (implementation), grt (type definition), gO (symbols), [d and ]d
-- (diagnostics).
vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
vim.keymap.set('n', 'gD', vim.lsp.buf.declaration)
vim.keymap.set('n', 'gy', vim.lsp.buf.type_definition)
vim.keymap.set('n', '<Leader>f', ':find ')
vim.keymap.set('n', '<Leader>b', ':buffer ')
vim.keymap.set('n', '<Leader>/', ':grep ')
vim.keymap.set('n', '<Leader>k', vim.lsp.buf.hover)
vim.keymap.set('n', '<Leader>r', vim.lsp.buf.rename)
vim.keymap.set({ 'n', 'x' }, '<Leader>a', vim.lsp.buf.code_action)
vim.keymap.set('n', '<Leader>s', vim.lsp.buf.document_symbol)
vim.keymap.set('n', '<Leader>S', vim.lsp.buf.workspace_symbol)
vim.keymap.set('n', '<Leader>d', vim.diagnostic.setloclist)
vim.keymap.set('n', '<Leader>D', vim.diagnostic.setqflist)

return { servers = servers, formatters = formatters }
