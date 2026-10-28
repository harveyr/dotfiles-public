-- ============================================================================
-- Standalone Portable Neovim Configuration (Single-File, Neovim 0.11)
-- Usage:
--   mkdir -p ~/.config/nvim && cp init.lua ~/.config/nvim/init.lua
--   Or test directly: nvim -u /path/to/init.lua
-- ============================================================================

vim.g.mapleader = " "
vim.o.exrc = true

-- ----------------------------------------------------------------------------
-- Packages (mini.deps bootstrap for Neovim 0.11)
-- ----------------------------------------------------------------------------
local path_package = vim.fn.stdpath("data") .. "/site/"
local mini_path = path_package .. "pack/deps/start/mini.nvim"
if not (vim.uv or vim.loop).fs_stat(mini_path) and vim.fn.executable("git") == 1 then
  vim.cmd('echo "Installing `mini.nvim`" | redraw')
  local clone_cmd = {
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/nvim-mini/mini.nvim",
    mini_path,
  }
  vim.fn.system(clone_cmd)
  vim.cmd("packadd mini.nvim | helptags ALL")
  vim.cmd('echo "Installed `mini.nvim`" | redraw')
end

local ok_deps, mini_deps = pcall(require, "mini.deps")
if ok_deps then
  mini_deps.setup({ path = { package = path_package } })
  local add = MiniDeps.add
  pcall(add, "ellisonleao/gruvbox.nvim")
  pcall(add, "ibhagwan/fzf-lua")
  pcall(add, "christoomey/vim-tmux-navigator")
  pcall(add, "neovim/nvim-lspconfig")
end

-- ----------------------------------------------------------------------------
-- General Options
-- ----------------------------------------------------------------------------
vim.o.mouse = ""
vim.o.switchbuf = "usetab"
vim.o.undofile = true
vim.o.shada = "'100,<50,s10,:1000,/100,@100,h"

vim.cmd("filetype plugin indent on")
if vim.fn.exists("syntax_on") ~= 1 then
  vim.cmd("syntax enable")
end

vim.filetype.add({
  pattern = {
    [".*ssh/config%.tmpl"] = "sshconfig",
    [".*%.toml%.tmpl"] = "toml",
  },
})

-- UI
vim.o.breakindent = true
vim.o.breakindentopt = "list:-1"
vim.o.colorcolumn = "+1"
vim.o.cursorline = false
vim.o.cursorlineopt = "screenline,number"
vim.o.fillchars = "eob: ,fold:╌"
vim.o.linebreak = true
vim.o.list = true
vim.o.listchars = "extends:…,nbsp:␣,precedes:…,tab:> "
vim.o.number = true
vim.o.pumheight = 10
vim.o.ruler = false
vim.o.shortmess = "CFOSWaco"
vim.o.showmode = false
vim.o.signcolumn = "yes"
vim.o.splitbelow = true
vim.o.splitkeep = "screen"
vim.o.splitright = true
vim.o.winborder = "single"
vim.o.wrap = true

-- Folds
vim.o.foldlevel = 10
vim.o.foldmethod = "indent"
vim.o.foldnestmax = 10
vim.o.foldtext = ""

-- Editing
vim.o.autoindent = true
vim.o.expandtab = true
vim.o.formatlistpat = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]]
vim.o.formatoptions = "rqnl1j"
vim.o.ignorecase = true
vim.o.incsearch = true
vim.o.infercase = true
vim.o.iskeyword = "@,48-57,_,192-255,-"
vim.o.shiftwidth = 2
vim.opt.shiftround = true
vim.o.smartcase = true
vim.o.smartindent = true
vim.o.spelloptions = "camel"
vim.o.tabstop = 2
vim.o.virtualedit = "block"

-- Completion (Neovim 0.11 built-in fuzzy completion)
vim.o.complete = ".,w,b,kspell"
vim.o.completeopt = "menuone,noselect,fuzzy,nosort"

-- Search & Colors
vim.o.termguicolors = true
vim.o.hlsearch = false

-- ----------------------------------------------------------------------------
-- Remote Clipboard (SSH / tmux via OSC 52)
-- ----------------------------------------------------------------------------
local is_remote = os.getenv("SSH_CONNECTION") ~= nil
  or os.getenv("SSH_TTY") ~= nil
  or os.getenv("SSH_CLIENT") ~= nil
  or os.getenv("TMUX") ~= nil

if is_remote then
  local ok_osc52, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if ok_osc52 then
    local function paste()
      return {
        vim.fn.split(vim.fn.getreg(""), "\n"),
        vim.fn.getregtype(""),
      }
    end
    vim.g.clipboard = {
      name = "OSC 52",
      copy = {
        ["+"] = osc52.copy("+"),
        ["*"] = osc52.copy("*"),
      },
      paste = {
        ["+"] = paste,
        ["*"] = paste,
      },
    }
  end
end

-- ----------------------------------------------------------------------------
-- Plugin Setup (with safe fallbacks)
-- ----------------------------------------------------------------------------
local ok_gruvbox, gruvbox = pcall(require, "gruvbox")
if ok_gruvbox then
  gruvbox.setup()
  vim.cmd.colorscheme("gruvbox")
else
  pcall(vim.cmd.colorscheme, "habamax")
end

local ok_notify, mini_notify = pcall(require, "mini.notify")
if ok_notify then
  mini_notify.setup({ lsp_progress = { enable = false } })
end

local ok_surround, mini_surround = pcall(require, "mini.surround")
if ok_surround then
  mini_surround.setup()
end

local ok_files, mini_files = pcall(require, "mini.files")
if ok_files then
  mini_files.setup({ options = { lsp_timeout = 0 } })
end

local ok_fzf, fzf_lua = pcall(require, "fzf-lua")
if ok_fzf then
  local files_opts = {
    fzf_opts = {
      ["--scheme"] = "path",
      ["--tiebreak"] = "index",
    },
  }
  if vim.fn.executable("rg") == 1 then
    files_opts.cmd = "rg --files --hidden --follow --glob '!.git' --sortr=modified"
  end
  fzf_lua.setup({ files = files_opts })
  fzf_lua.register_ui_select()
end

-- Built-in Tree-sitter highlighting when parsers are available
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev)
    pcall(vim.treesitter.start, ev.buf)
  end,
  desc = "Start built-in tree-sitter highlighting if parser exists",
})

-- Enable common LSP servers if installed on PATH (Neovim 0.11 vim.lsp.enable)
if vim.lsp and vim.lsp.enable then
  for _, server in ipairs({ "lua_ls", "ruff", "fish_lsp", "markdown_oxide", "vtsls" }) do
    pcall(vim.lsp.enable, server)
  end
end

-- ----------------------------------------------------------------------------
-- Inlined Filetype Rules (from after/ftplugin)
-- ----------------------------------------------------------------------------
local ft_group = vim.api.nvim_create_augroup("StandaloneFtPlugin", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = ft_group,
  pattern = { "python", "fish", "sh", "bash" },
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = ft_group,
  pattern = "json",
  callback = function()
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.opt_local.foldlevel = 99
    vim.opt_local.foldlevelstart = 1
  end,
})

local function toggle_markdown_checkbox()
  local line = vim.api.nvim_get_current_line()
  local unchecked = "- %[ %] "
  local checked = "- %[x%] "
  local bullet = "- "

  local new_line
  if string.find(line, unchecked) then
    new_line = string.gsub(line, unchecked, checked, 1)
  elseif string.find(line, checked) then
    new_line = string.gsub(line, checked, unchecked, 1)
  elseif string.find(line, bullet) then
    new_line = string.gsub(line, bullet, unchecked, 1)
  end

  if new_line then
    vim.api.nvim_set_current_line(new_line)
  end
end

vim.api.nvim_create_user_command("CheckboxToggle", toggle_markdown_checkbox, {
  desc = "Toggle a markdown checkbox on the current line",
})

vim.api.nvim_create_autocmd("FileType", {
  group = ft_group,
  pattern = "markdown",
  callback = function(ev)
    vim.opt_local.spell = true
    vim.opt_local.wrap = true
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.opt_local.foldlevel = 10
    vim.opt_local.foldnestmax = 10

    vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, buffer = ev.buf })
    vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, buffer = ev.buf })
    vim.keymap.set("n", "<Leader><CR>", "<Cmd>CheckboxToggle<CR>", { desc = "Toggle checkbox", silent = true, buffer = ev.buf })

    vim.b.minisurround_config = {
      custom_surroundings = {
        L = {
          input = { "%[().-()%]%(.-%)" },
          output = function()
            local link = require("mini.surround").user_input("Link: ")
            return { left = "[", right = "](" .. link .. ")" }
          end,
        },
      },
    }

    vim.cmd([[syntax match markdownHighlight /==.\{-}==/]])
    vim.api.nvim_set_hl(0, "markdownHighlight", {
      bg = "#3c3836",
      fg = "#fabd2f",
      bold = true,
    })
  end,
})

-- ----------------------------------------------------------------------------
-- Custom Commands
-- ----------------------------------------------------------------------------
vim.api.nvim_create_user_command("YankPath", function()
  local file_path = vim.fn.expand("%:p")
  if file_path == "" then
    vim.notify("Current buffer is not a file.", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", file_path)
  vim.fn.setreg('"', file_path)
  vim.notify("Yanked: " .. file_path, vim.log.levels.INFO)
end, { desc = "Yank current file path to clipboard" })

vim.api.nvim_create_user_command("YankBufferToClipboard", function()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  vim.fn.setreg("+", table.concat(lines, "\n"))
  print("Buffer copied to clipboard!")
end, { desc = "Yank buffer to clipboard" })

-- ----------------------------------------------------------------------------
-- Keymaps
-- ----------------------------------------------------------------------------
local nmap_leader = function(suffix, rhs, desc)
  vim.keymap.set("n", "<Leader>" .. suffix, rhs, { desc = desc })
end

-- Saving
vim.keymap.set({ "n", "x" }, "<C-s>", "<Cmd>silent! update | redraw<CR>", { desc = "Save file" })
vim.keymap.set("i", "<C-s>", "<Cmd>write<CR><Esc>", { desc = "Save" })

-- Clipboard
vim.keymap.set({ "n", "x" }, "gy", '"+y', { desc = "Copy to system clipboard" })
vim.keymap.set("x", "<leader>y", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set("n", "gp", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set("x", "gp", '"+P', { desc = "Paste from system clipboard" })
nmap_leader("by", "<Cmd>YankBufferToClipboard<CR>", "Yank buffer to clipboard")
nmap_leader("bp", "<Cmd>YankPath<CR>", "Yank file path to clipboard")

-- Visual selection helpers
vim.keymap.set("n", "gV", '"g`[" . strpart(getregtype(), 0, 1) . "g`]"', {
  expr = true,
  replace_keycodes = false,
  desc = "Visually select changed text",
})
vim.keymap.set("x", "g/", "<esc>/\\%V", { silent = false, desc = "Search inside visual selection" })

-- Tmux / Window Navigation (uses TmuxNavigate if loaded, else standard window jumps)
vim.g.tmux_navigator_no_mappings = 1
local function nav(tmux_cmd, win_key)
  return function()
    if vim.fn.exists(":" .. tmux_cmd) == 2 then
      vim.cmd(tmux_cmd)
    else
      vim.cmd("wincmd " .. win_key)
    end
  end
end
vim.keymap.set({ "n", "i" }, "<M-h>", nav("TmuxNavigateLeft", "h"), { desc = "Window/tmux left" })
vim.keymap.set({ "n", "i" }, "<M-j>", nav("TmuxNavigateDown", "j"), { desc = "Window/tmux down" })
vim.keymap.set({ "n", "i" }, "<M-k>", nav("TmuxNavigateUp", "k"), { desc = "Window/tmux up" })
vim.keymap.set({ "n", "i" }, "<M-l>", nav("TmuxNavigateRight", "l"), { desc = "Window/tmux right" })
vim.keymap.set({ "n", "i" }, "<M-\\>", nav("TmuxNavigatePrevious", "p"), { desc = "Window/tmux previous" })

-- Buffers
local new_scratch_buffer = function()
  vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

local trim_trailspace = function()
  local view = vim.fn.winsaveview()
  vim.cmd([[silent! keeppatterns %s/\s\+$//e]])
  vim.fn.winrestview(view)
end

nmap_leader("ba", "<Cmd>b#<CR>", "Alternate")
nmap_leader("bd", "<Cmd>bdelete<CR>", "Delete")
nmap_leader("bD", "<Cmd>bdelete!<CR>", "Delete!")
nmap_leader("bo", "<Cmd>b#<CR>", "Alternate")
nmap_leader("bs", new_scratch_buffer, "Scratch")
nmap_leader("bt", trim_trailspace, "Trim trailspace")
nmap_leader("bw", "<Cmd>bwipeout<CR>", "Wipeout")
nmap_leader("bW", "<Cmd>bwipeout!<CR>", "Wipeout!")
vim.keymap.set("n", "<C-_>", "<C-^>", { desc = "Alternate buffer" })
vim.keymap.set("n", "<C-/>", "<C-^>", { desc = "Alternate buffer" })
vim.keymap.set("i", "<C-_>", "<C-\\><C-n><C-^>", { desc = "Alternate buffer" })
vim.keymap.set("i", "<C-/>", "<C-\\><C-n><C-^>", { desc = "Alternate buffer" })

-- Explore & Edit
local open_files = function(current_file)
  if _G.MiniFiles then
    if current_file then
      _G.MiniFiles.open(vim.api.nvim_buf_get_name(0))
    else
      _G.MiniFiles.open()
    end
  else
    vim.cmd("Explore")
  end
end

local explore_quickfix = function()
  vim.cmd(vim.fn.getqflist({ winid = true }).winid ~= 0 and "cclose" or "copen")
end
local explore_locations = function()
  vim.cmd(vim.fn.getloclist(0, { winid = true }).winid ~= 0 and "lclose" or "lopen")
end

vim.keymap.set("n", "-", function() open_files(true) end, { desc = "File directory" })
nmap_leader("ed", function() open_files(false) end, "Directory")
nmap_leader("ef", function() open_files(true) end, "File directory")
nmap_leader("ei", "<Cmd>edit $MYVIMRC<CR>", "init.lua")
nmap_leader("en", function()
  if _G.MiniNotify then
    _G.MiniNotify.show_history()
  else
    vim.cmd("messages")
  end
end, "Notifications")
nmap_leader("eq", explore_quickfix, "Quickfix list")
nmap_leader("eQ", explore_locations, "Location list")

-- Find (fzf-lua with native fallbacks)
if ok_fzf then
  nmap_leader("bT", "<Cmd>FzfLua filetypes<CR>", "Filetypes")
  nmap_leader("fG", "<Cmd>FzfLua grep_cword<CR>", "Grep current word")
  nmap_leader("fb", "<Cmd>FzfLua buffers<CR>", "Buffers")
  nmap_leader("fe", "<Cmd>FzfLua colorschemes<CR>", "Colorschemes")
  nmap_leader("ff", "<Cmd>FzfLua files<CR>", "Files")
  nmap_leader("fg", "<Cmd>FzfLua live_grep<CR>", "Grep live")
  nmap_leader("fh", "<Cmd>FzfLua help_tags<CR>", "Help tags")
  nmap_leader("fk", "<Cmd>FzfLua keymaps<CR>", "Keymaps")
  nmap_leader("fo", "<Cmd>FzfLua oldfiles<CR>", "Old files")
  nmap_leader("fr", "<Cmd>FzfLua resume<CR>", "Resume")
  nmap_leader("fs", "<Cmd>FzfLua lsp_document_symbols<CR>", "Document symbols")
else
  nmap_leader("fb", ":buffer ", "Buffers")
  nmap_leader("ff", ":find ", "Files")
  nmap_leader("fg", ":grep ", "Grep")
  nmap_leader("fh", ":help ", "Help")
  nmap_leader("fo", "<Cmd>browse oldfiles<CR>", "Old files")
end

-- LSP
nmap_leader("la", vim.lsp.buf.code_action, "Actions")
nmap_leader("ld", vim.diagnostic.open_float, "Diagnostic popup")
nmap_leader("lf", function() vim.lsp.buf.format({ async = true }) end, "Format")
nmap_leader("li", vim.lsp.buf.implementation, "Implementation")
nmap_leader("lh", vim.lsp.buf.hover, "Hover")
nmap_leader("ll", vim.lsp.codelens.run, "Lens")
nmap_leader("lr", vim.lsp.buf.rename, "Rename")
nmap_leader("lR", vim.lsp.buf.references, "References")
nmap_leader("ls", vim.lsp.buf.definition, "Source definition")
nmap_leader("lt", vim.lsp.buf.type_definition, "Type definition")

-- Reload config
nmap_leader("r", '<Cmd>source $MYVIMRC | lua vim.notify("Config reloaded!")<CR>', "Reload config")
