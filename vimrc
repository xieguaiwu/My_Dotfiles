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

"cursor"
"if exists('$TMUX')
"    let &t_SI="\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
"    let &t_SR="\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=2\x7\<Esc>\\"
"    let &t_EI="\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
"else 
"    let &t_SI="\<Esc>]50;CursorShape=1\x7"
"    let &t_SR="\<Esc>]50;CursorShape=2\x7"
"    let &t_EI="\<Esc>]50;CursorShape=0\x7"
"endif


set guicursor=a:beam-blinkon50-blinkoff50

"n-v-c:block-blinkon50,i-ci-ve:ver25-blinkon50,r-cr:hor20-blinkon50,o:hor50-blinkon50

set cursorcolumn

"technical"
set notimeout
set ttimeout
set timeoutlen=300
set noreadonly

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

set clipboard=unnamedplus
set clipboard=unnamed

"move lines up and down"
nnoremap J :m '>+1<CR>gv=gv
nnoremap K :m '<-2<CR>gv=gv

"muti-window"
nnoremap sl :set splitright<CR>:vsplit<CR>"right"
nnoremap sh :set nosplitright<CR>:vsplit<CR>"left"
nnoremap sk :set nosplitbelow<CR>:split<CR>"up"
nnoremap sj :set splitbelow<CR>:split<CR>"down"


""silent !
