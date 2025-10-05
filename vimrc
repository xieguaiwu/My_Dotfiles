set nocompatible

"appearance"
syntax on
set number
set relativenumber

set showmatch
set undofile
set undodir=/home/xieguaiwu/.vim/undodir

set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4
set encoding=utf-8

set termguicolors
set nohidden

set guicursor=a:beam-blinkon50-blinkoff50

"n-v-c:block-blinkon50,i-ci-ve:ver25-blinkon50,r-cr:hor20-blinkon50,o:hor50-blinkon50

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


""silent !
" for kitty terminal
set mouse=a
set ttymouse=sgr
set balloonevalterm
" Styled and colored underline support
let &t_AU = "\e[58:5:%dm"
let &t_8u = "\e[58:2:%lu:%lu:%lum"
let &t_Us = "\e[4:2m"
let &t_Cs = "\e[4:3m"
let &t_ds = "\e[4:4m"
let &t_Ds = "\e[4:5m"
let &t_Ce = "\e[4:0m"
" Strikethrough
let &t_Ts = "\e[9m"
let &t_Te = "\e[29m"
" Truecolor support
let &t_8f = "\e[38:2:%lu:%lu:%lum"
let &t_8b = "\e[48:2:%lu:%lu:%lum"
let &t_RF = "\e]10;?\e\\"
let &t_RB = "\e]11;?\e\\"
" Bracketed paste
let &t_BE = "\e[?2004h"
let &t_BD = "\e[?2004l"
let &t_PS = "\e[200~"
let &t_PE = "\e[201~"
" Cursor control
let &t_RC = "\e[?12$p"
let &t_SH = "\e[%d q"
let &t_RS = "\eP$q q\e\\"
let &t_SI = "\e[5 q"
let &t_SR = "\e[3 q"
let &t_EI = "\e[1 q"
let &t_VS = "\e[?12l"
" Focus tracking
let &t_fe = "\e[?1004h"
let &t_fd = "\e[?1004l"
execute "set <FocusGained>=\<Esc>[I"
execute "set <FocusLost>=\<Esc>[O"
" Window title
let &t_ST = "\e[22;2t"
let &t_RT = "\e[23;2t"

" vim hardcodes background color erase even if the terminfo file does
" not contain bce. This causes incorrect background rendering when
" using a color theme with a background color in terminals such as
" kitty that do not support background color erase.
let &t_ut=''

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
call plug#begin('~/.vim/plugged')
"run command ':CocInstall coc-snippets'
"lsp
Plug 'neoclide/coc.nvim', {'branch': 'release'}

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
Plug 'vim-airline/vim-airline'
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

call plug#end()
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
function CheckBackspace() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1] =~# '\s'
endfunc

nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

inoremap <silent><expr> <A-z> coc#refresh()

"for pinyinsearch"
let g:PinyinSearch_Dict = '/home/xieguaiwu/.vim/plugged/vim-pinyinsearch/PinyinSearch.dict'
nnoremap ? :call PinyinSearch()<CR>
nnoremap <leader>pn :call PinyinNext()<CR>

"for fzf
nnoremap <C-p> :GFiles<CR>

" 打开 quickfix 搜索结果（全局搜索）
nnoremap <leader>f :vimgrep /<C-r><C-w>/gj **/*.rs<CR>:copen<CR>

"for vim-workspace"
"let g:workspace_autocreate = 1
let g:workspace_persist_undo_history = 1
let g:workspace_undodir = '/home/xieguaiwu/.vim/undodir'
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
