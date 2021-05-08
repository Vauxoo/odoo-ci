#!/usr/bin/env bash

# Exit on error
set -e

# We need some functions from the common repository
source /usr/share/odoo-ci-common/library.sh

# We will have the codename variable available 
source /etc/lsb-release


# ppa sources
VIM_PPA_REPO="deb http://ppa.launchpad.net/jonathonf/vim/ubuntu ${DISTRIB_CODENAME} main"
VIM_PPA_KEY="https://keyserver.ubuntu.com/pks/lookup?fingerprint=on&op=get&search=0x4AB0F789CBA31744CC7DA76A8CF63AD3F06FC659"

VIM_OPENERP_REPO="https://github.com/vauxoo/vim-openerp.git"
VIM_WAKATIME_REPO="https://github.com/wakatime/vim-wakatime.git"
VIM_YOUCOMPLETEME_REPO="https://github.com/Valloric/YouCompleteMe.git"
VIM_JEDI_REPO="https://github.com/davidhalter/jedi-vim.git"
SPF13_REPO="https://github.com/spf13/spf13-vim.git"


# Let's add the vim ppa for having a more up-to-date vim
add_custom_aptsource "${VIM_PPA_REPO}" "${VIM_PPA_KEY}"

# Upgrade & configure vim
apt update 
apt install vim --only-upgrade
# Get vim version
VIM_VERSION=$(dpkg -s vim | grep Version | sed -n 's/.*\([0-9]\+\.[0-9]\+\)\..*/\1/p' | sed -r 's/\.//g')

wget -q -O /usr/share/vim/vim${VIM_VERSION}/spell/es.utf-8.spl http://ftp.vim.org/pub/vim/runtime/spell/es.utf-8.spl
git_clone_execute "${SPF13_REPO}" "3.0" "bootstrap.sh"
git_clone_copy "${VIM_OPENERP_REPO}" "master" "vim/" "${HOME}/.vim/bundle/vim-openerp"
git_clone_copy "${VIM_JEDI_REPO}" "master" "." "${HOME}/.vim/bundle/jedi-vim"

sed -i 's/ set mouse\=a/\"set mouse\=a/g' ~/.vimrc
sed -i "s/let g:neocomplete#enable_at_startup = 1/let g:neocomplete#enable_at_startup = 0/g" ~/.vimrc

# Disable virtualenv in Pymode 
cat >> ~/.vimrc << EOF
" Disable virtualenv in Pymode 
let g:pymode_virtualenv = 0 
" Disable pymode init and lint because of https://github.com/python-mode/python-mode/issues/897
let g:pymode_init = 0
let g:pymode_lint = 0

" Disable modelines: https://github.com/numirias/security/blob/master/doc/2019-06-04_ace-vim-neovim.md
set modelines=0
set nomodeline
EOF

# Disable vim-signify 
cat >> ~/.vimrc << EOF
" Disable vim-signify 
let g:signify_disable_by_default = 1 
EOF

# Install and configure YouCompleteMe
VIM_YOUCOMPLETEME_PATH="${HOME}/.vim/bundle/YouCompleteMe"
git clone ${VIM_YOUCOMPLETEME_REPO} ${VIM_YOUCOMPLETEME_PATH}
# Install the custom version of YouCompleteMe because the last required g++ 4.9
(cd "${VIM_YOUCOMPLETEME_PATH}" && git reset --hard 1b4081713c16d1c182cf48c74502c91ef21c8412 && git submodule update --init --recursive && ./install.py)
cat >> ~/.vimrc << EOF
" Disable auto trigger for youcompleteme
let g:ycm_auto_trigger = 0
EOF

# Install WakaTime
git_clone_copy "${VIM_WAKATIME_REPO}" "master" "." "${HOME}/.vim/bundle/vim-wakatime"

cat >> ~/.vimrc << EOF
colorscheme heliotrope
set colorcolumn=119
set spelllang=en,es
EOF

# Configure pylint_odoo plugin and the .conf file
# to enable python pylint_odoo checks and eslint checks into the vim editor.
cat >> ~/.vimrc << EOF
:filetype on
let g:syntastic_aggregate_errors = 1
let g:syntastic_python_checkers = ['pylint', 'flake8']
let g:syntastic_auto_loc_list = 1
let g:syntastic_python_pylint_args =
    \ '--rcfile=/.repo_requirements/linit_hook/travis/cfg/travis_run_pylint_vim.cfg --valid_odoo_versions=14.0'
let g:syntastic_python_flake8_args =
    \ '--config=/.repo_requirements/linit_hook/travis/cfg/travis_run_flake8.cfg'
let g:syntastic_javascript_checkers = ['eslint']
let g:syntastic_javascript_eslint_args =
    \ '--config /.repo_requirements/linit_hook/travis/cfg/.jslintrc'

" make YCM compatible with UltiSnips (using supertab) more info http://stackoverflow.com/a/22253548/3753497
let g:ycm_key_list_select_completion = ['<C-n>', '<Down>']
let g:ycm_key_list_previous_completion = ['<C-p>', '<Up>']
let g:SuperTabDefaultCompletionType = '<C-n>'
" better key bindings for Snippets Expand Trigger
let g:UltiSnipsExpandTrigger = "<tab>"
let g:UltiSnipsJumpForwardTrigger = "<tab>"
let g:UltiSnipsJumpBackwardTrigger = "<s-tab>"

" Convert all files to unix format on open
au BufRead,BufNewFile * set ff=unix
EOF

cat >> ~/.vimrc.bundles.local << EOF
" Odoo snippets {
if count(g:spf13_bundle_groups, 'odoovim')
    Bundle 'vim-openerp'
endif
" }
" wakatime bundle {
if filereadable(expand("~/.wakatime.cfg")) && count(g:spf13_bundle_groups, 'wakatime')
    Bundle 'vim-wakatime'
endif
" }
EOF

cat >> ~/.vimrc.before.local << EOF
let g:spf13_bundle_groups = ['general', 'writing', 'odoovim', 'wakatime',
                           \ 'programming', 'youcompleteme', 'php', 'ruby',
                           \ 'python', 'javascript', 'html',
                           \ 'misc']
EOF

