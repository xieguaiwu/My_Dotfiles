set nocompatible

"appearance"
syntax on
set number
set relativenumber

set showmatch
set undofile
set undodir=/home/xieguaiwu/.config/nvim/undodir

set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4
set encoding=utf-8

set termguicolors
set nohidden

"quick replacing
nnoremap <C-h> :%s///g<Left><Left>

set cursorcolumn

"technical"
set notimeout
set ttimeout
set timeoutlen=300
set noreadonly
set completeopt=menu,menuone,noselect

"using"
set autoindent
set autoread
set ruler
set smartcase
set ignorecase
set splitright
set splitbelow
set wildmenu
set hidden

set clipboard=unnamedplus,unnamed

"move lines up and down"
nnoremap J :m '>+1<CR>gv=gv
nnoremap K :m '<-2<CR>gv=gv

"muti-window"
nnoremap sl :set splitright<CR>:vsplit<CR>"right"
nnoremap sh :set nosplitright<CR>:vsplit<CR>"left"
nnoremap sk :set nosplitbelow<CR>:split<CR>"up"
nnoremap sj :set splitbelow<CR>:split<CR>"down"


" Styled and colored underline support
set guicursor=n:block,v:block,i:ver25,r:ver25,a:blinkon250-blinkoff100

"compile func stuff"
func! CompileRunGcc()
    exec "w"
    let file = expand('%')
    let base = expand('%<')
    let dir = expand('%:p:h')

    if empty(file) || !filereadable(file)
        echo "Error: File not readable -" . file
        return
    endif

    if &filetype == 'cpp' || &filetype == 'cc'
        exec "!g++ -g -std=c++17 % -o  %< && ./%<"
    endif
    if &filetype == 'c'
        exec "!gcc -g % -o %< && ./%<"
    endif
    if &filetype == 'java'
        exec "!javac % && java ./%"
    endif
    if &filetype == 'python'
        exec "!python3 %"
    endif
    if &filetype == 'sh'
        exec "!sh %"
    endif
    if &filetype == 'rust'
        "exec ":RustTest"
        exec ":RustBuild"
        exec ":RustRun"
    endif
    if &filetype == 'tex'
        exec '!pdflatex %'
    endif
endfunc

nnoremap <C-A-b> :call CompileRunGcc() <CR>

"for tab pages in vim
nnoremap <C-t> : tabnew <CR>
nnoremap <C-l> : tabnext <CR>

"plug"
call plug#begin('~/.local/share/nvim/plugged')
"run command ':CocInstall coc-snippets'
"lsp
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'nvim-lualine/lualine.nvim'
Plug 'neovim/nvim-lspconfig'

"theme
Plug 'junegunn/seoul256.vim'
"Plug 'phanviet/vim-monokai-pro'
Plug 'erichdongubler/vim-sublime-monokai'

"tree
Plug 'preservim/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'vim-scripts/OmniCppComplete'
Plug 'ludovicchabant/vim-gutentags'
Plug 'honza/vim-snippets'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'tpope/vim-unimpaired'
Plug 'jiangmiao/auto-pairs'
Plug 'godlygeek/tabular'
Plug 'xuhdev/singlecompile'
Plug 'chiel92/vim-autoformat'
Plug 'mileszs/ack.vim'
Plug 'ppwwyyxx/vim-pinyinsearch'
Plug 'thaerkh/vim-workspace'

"syntax
Plug 'plasticboy/vim-markdown'
Plug 'fatih/vim-go'
Plug 'scrooloose/syntastic'
Plug 'Yggdroot/indentLine'
Plug 'vim-scripts/indentpython.vim'
Plug 'rust-lang/rust.vim'
Plug 'lervag/vimtex'
Plug 'leanprover/lean.nvim'
Plug 'Julian/lean.nvim'
Plug 'nvim-lua/plenary.nvim'

call plug#end()

"lua require('lean_config')

"for lean prover
" 切换 Info 窗口（重要：显示目标状态和定义）
nnoremap <buffer> <leader>li <cmd>Lean.toggle_info<CR>
" 切换 Goal 窗口（仅显示目标状态）
nnoremap <buffer> <leader>lg <cmd>Lean.toggle_goal<CR>
" 切换光标下符号的定义
nnoremap <buffer> <leader>ld <cmd>lua vim.lsp.buf.definition()<CR>
" 切换光标下符号的类型定义
nnoremap <buffer> <leader>lt <cmd>lua vim.lsp.buf.type_definition()<CR>
" 启动/重启 Lean 语言服务器
nnoremap <buffer> <leader>lr <cmd>Lean.restart<CR>

colorscheme sublimemonokai

"for Nerdtree"
nnoremap <silent> <C-e> :NERDTreeToggle<CR>
"for neoformat"

func! Self_Format()
    if &filetype == 'cpp' || &filetype == 'cc' || &filetype == 'c' || &filetype == 'java'
        exec ':w'
        exec '!astyle --mode=c --style=java --indent=tab --pad-oper --pad-header --unpad-paren  --suffix=none ./%'
    endif
    if &filetype == 'rust'
        exec ':w'
        exec '!rustfmt %'
    endif
endfunc

if &filetype != 'cpp' && &filetype != 'cc' && &filetype != 'c' && &filetype != 'java' && &filetype != 'rust'
    nnoremap <C-A-f> :Autoformat<CR>
else
    nnoremap <C-A-f> :call Self_Format()<CR>
endif

"for singlecompile"
nnoremap <F8> :SCCompile<CR>
nnoremap <F9> :SCCompileRun<CR>
"for coc.nvim"
"inoremap <silent><expr> <TAB>
            \ coc#pum#visible() ? coc#pum#next(1) :
            \ CheckBackspace() ?\<Tab>" :
            \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : "\<CR>"

"coc for c/c++
let g:coc_global_extensions = ['coc-snippets']
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

inoremap <silent><expr> <A-z> coc#refresh()

"for pinyinsearch"
let g:PinyinSearch_Dict = expand('/home/xieguaiwu/.local/share/nvim/plugged/vim-pinyinsearch/PinyinSearch.dict')
nnoremap ? :call PinyinSearch()<CR>
nnoremap <leader>pn :call PinyinNext()<CR>

"for fzf
nnoremap <C-p> :GFiles<CR>

" 打开 quickfix 搜索结果（全局搜索）
nnoremap <leader>f :vimgrep /<C-r><C-w>/gj **/*.rs<CR>:copen<CR>

"for vim-workspace"
"let g:workspace_autocreate = 1
let g:workspace_persist_undo_history = 1
let g:workspace_undodir = expand('/home/xieguaiwu/.vim/undodir')
let g:workspace_autosave = 0

"for markdown syntax
let g:vim_markdown_math = 1
let g:vim_markdown_folding_disabled = 1
"let g:vim_markdown_follow_anchor = 1
let g:vim_markdown_strikethrough = 1
let g:vim_markdown_new_list_items = 1
let g:vim_markdown_borderless_table = 1

"for vimtex
let g:vimtex_view_method = 'zathura'
let g:vimtex_compiler_method = 'latexmk'
let g:vimtex_compiler_latexmk = {
            \ 'build_dir' : '',
            \ 'options' : [
            \   '-xelatex',
            \   '-file-line-error',
            \   '-interaction=nonstopmode',
            \   '-synctex=1',
            \ ],
            \}

"for lean prover
" Lean logic symbols
inoremap \forall ∀
inoremap \exists ∃
inoremap \and ∧
inoremap \or ∨
inoremap \to →
inoremap \iff ↔
inoremap \neg ¬
inoremap \ent ⊢
