#!/usr/bin/env bash

# Exit inmediately after an error
set -e

# With a little help from my friends
if [ -d "/usr/share/odoo-ci-common" ]; then rm -Rf /usr/share/odoo-ci-common; fi
git clone -b main --single-branch --depth=1 https://github.com/Vauxoo/odoo-ci-common.git /usr/share/odoo-ci-common
source /usr/share/odoo-ci-common/library.sh
cp /usr/share/odoo-ci-common/entrypoint_image /

# We will have the codename variabnle available 
source /etc/lsb-release

# Let's set some defaults here
ARCH="$( dpkg --print-architecture )"

# git-core PPA data
GITCORE_PPA_REPO="deb http://ppa.launchpad.net/git-core/ppa/ubuntu ${DISTRIB_CODENAME} main"
GITCORE_PPA_KEY="http://keyserver.ubuntu.com:11371/pks/lookup?op=get&search=0xA1715D88E1DF1F24"

# Extra software download URLs
HUB_ARCHIVE="https://github.com/github/hub/releases/download/v2.2.3/hub-linux-${ARCH}-2.2.3.tgz"
NGROK_ARCHIVE="https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-${ARCH}.zip"

# Extra software clone URLs
ZSH_THEME_REPO="https://gist.github.com/9931af23bbb59e772eec.git"
OH_MY_ZSH_REPO="https://github.com/robbyrussell/oh-my-zsh.git"
HUB_REPO="https://github.com/github/hub.git"
ODOO_VAUXOO_REPO="https://github.com/vauxoo/odoo.git"
ODOO_VAUXOO_DEV_REPO="https://github.com/vauxoo-dev/odoo.git"
ODOO_ODOO_REPO="https://github.com/odoo/odoo.git"
ODOO_OCA_REPO="https://github.com/oca/ocb.git"
MQT_REPO="https://github.com/vauxoo/maintainer-quality-tools.git"
GIST_VAUXOO_REPO="https://github.com/vauxoo-dev/gist-vauxoo.git"
PYLINT_REPO="https://github.com/vauxoo/pylint-conf.git"

DPKG_DEPENDS="postgresql-${PSQL_VERSION} postgresql-contrib-${PSQL_VERSION} \
              pgbadger perl-modules make openssl p7zip-full expect-dev mosh bpython \
              libarchive-tools rsync graphviz openssh-server cmake zsh tree tig libffi-dev \
              lua50 liblua50-dev liblualib50-dev exuberant-ctags rake \
              python${TRAVIS_PYTHON_VERSION} python${TRAVIS_PYTHON_VERSION}-dev \
              software-properties-common xvfb libmagickwand-dev openjdk-8-jre \
              dos2unix subversion \
              aspell aspell-en aspell-es gettext tk-dev libssl-dev lftp \
              libmysqlclient-dev libcups2-dev emacs byobu chromium-browser"
PIP_OPTS="--upgrade \
          --no-cache-dir \
          --ignore-installed"
PIP_DEPENDS_EXTRA="watchdog coveralls diff-highlight \
                   pgcli \
                   pg-activity virtualenv nodeenv setuptools==33.1.1 \
                   html2text==2016.9.19 ofxparse==0.15 pre-commit"
PIP_DPKG_BUILD_DEPENDS=""

ODOO_DEPENDENCIES_PY3="git+https://github.com/vauxoo/odoo@11.0 \
                       git+https://github.com/vauxoo/odoo@saas-17"

DEPENDENCIES_FILE="/tmp/full_requirements.txt"

NPM_OPTS="-g"
NPM_DEPENDS="localtunnel fs-extra eslint"

# Let's add the git-core ppa for having a more up-to-date git
add_custom_aptsource "${GITCORE_PPA_REPO}" "${GITCORE_PPA_KEY}"

# Release the apt monster!
echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections
apt-get update
apt-get upgrade
apt-get install ${DPKG_DEPENDS} ${PIP_DPKG_BUILD_DEPENDS}
apt purge python-greenlet python3-greenlet

# Upgrade pip for python3
curl "https://bootstrap.pypa.io/get-pip.py" -o "/tmp/get-pip.py"
echo "Installing pip for python${TRAVIS_PYTHON_VERSION}"
# If there is a custom version then overwrite the generic one.
(curl -f "https://bootstrap.pypa.io/${TRAVIS_PYTHON_VERSION}/get-pip.py" -o "/tmp/get-pip${TRAVIS_PYTHON_VERSION}.py" || true)
cp -n /tmp/get-pip.py /tmp/get-pip${TRAVIS_PYTHON_VERSION}.py
python"${TRAVIS_PYTHON_VERSION}" /tmp/get-pip${TRAVIS_PYTHON_VERSION}.py

# Install virtualenv for each Python version
# Support for Python 3.2 & 3.3 has been dropped, so they require specific versions
echo "Installing pip for Python${TRAVIS_PYTHON_VERSION}"
python"${TRAVIS_PYTHON_VERSION}" -m pip install virtualenv

#cp /usr/local/bin/pip2 /usr/local/bin/pip

# Fix reinstalling npm packages
# See https://github.com/npm/npm/issues/9863 for details
#sed -i 's/graceful-fs/fs-extra/g;s/fs.rename/fs.move/g' $(npm root -g)/npm/lib/utils/rename.js

# Install python dependencies for the default version

echo "" > ${DEPENDENCIES_FILE}
echo "Installing all pip dependencies for python${TRAVIS_PYTHON_VERSION}"
collect_pip_dependencies "${ODOO_DEPENDENCIES_PY3}" "${PIP_DEPENDS_EXTRA}" "${DEPENDENCIES_FILE}"
echo "Clean **"
clean_requirements ${DEPENDENCIES_FILE}
echo "deps files **"
python"${TRAVIS_PYTHON_VERSION}" -m pip install ${PIP_OPTS} -r ${DEPENDENCIES_FILE}


# Installing black for compatible python versions
python${TRAVIS_PYTHON_VERSION} -m pip install black

# Install and thetup the ci environment, download Odoo and setup the linter configuration.
# This will use the environment variables
install_ci_environment 

export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python${TRAVIS_PYTHON_VERSION}
echo "VIRTUALENVWRAPPER_PYTHON=/usr/bin/python${TRAVIS_PYTHON_VERSION}" >> /etc/bash.bashrc


# Creating virtual environments node js
nodeenv ${REPO_REQUIREMENTS}/virtualenv/nodejs
# Install node dependencies
(source ${REPO_REQUIREMENTS}/virtualenv/nodejs/bin/activate && npm install ${NPM_OPTS} ${NPM_DEPENDS})
echo "REPO_REQUIREMENTS=${REPO_REQUIREMENTS}" >> /etc/bash.bashrc

# Install vim
bash /usr/share/odoo-ci-common/setup_vim.sh

# Keep alive the ssh server
#   60 seconds * 360 = 21600 seconds = 6 hours
# https://www.bjornjohansen.no/ssh-timeout
echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 360" >> /etc/ssh/sshd_config

# Install hub & ngrok
targz_download_execute "${HUB_ARCHIVE}" "install"
zip_download_copy "${NGROK_ARCHIVE}" "ngrok" "/usr/local/bin/"
chmod +x /usr/local/bin/ngrok

# Configure diff-highlight on git after install
cat >> /etc/gitconfig << EOF
[pager]
    log = diff-highlight | less
    show = diff-highlight | less
    diff = diff-highlight | less
EOF


# Configure shell, shell colors & shell completion
chsh --shell /bin/bash root
git_clone_copy "${HUB_REPO}" "master" "etc/hub.bash_completion.sh" "/etc/bash_completion.d/"

cat >> ~/.bashrc << 'EOF'
Purple="\[\033[0;35m\]"
BIPurple="\[\033[1;95m\]"
Color_Off="\[\033[0m\]"
PathShort="\w"
UserMachine="$BIPurple[\u@$Purple\h]"
GREEN_WOE="\001\033[0;32m\002"
RED_WOE="\001\033[0;91m\002"
git_ps1_style(){
    local git_branch="$(__git_ps1 2>/dev/null)";
    local git_ps1_style="";
    if [ -n "$git_branch" ]; then
        if [ -n "$GIT_STATUS" ]; then
            (git diff --quiet --ignore-submodules HEAD 2>/dev/null)
            local git_changed=$?
            if [ "$git_changed" == 0 ]; then
                git_ps1_style=$GREEN_WOE;
            else
                git_ps1_style=$RED_WOE;
            fi
        fi
        git_ps1_style=$git_ps1_style$git_branch
    fi
    echo -e "$git_ps1_style"
}
PS1=$UserMachine$Color_Off$PathShort\$\\n"\$(git_ps1_style)"$Color_Off\$" "
EOF

# Add alias and function
cat >> /etc/bash.bashrc << EOF
alias tail2="multitail -cS odoo"
alias rgrep="rgrep -n"
git_fetch_pr() {
    REMOTE=$1
    NUMBER="*"
    if [ -z "$2"  ]; then
        NUMBER=$2
    fi
    shift 1
    git fetch -p $REMOTE +refs/pull/$NUMBER/head:refs/pull/$REMOTE/$NUMBER
}
EOF

# Load .container.profile
if [ -f "~/.container.profile" ]; then
source ~/.container.profile
fi

cat >> /etc/multitail.conf << EOF
# Odoo log
colorscheme:odoo
cs_re:blue:^[0-9]*-[0-9]*-[0-9]* [0-9]*:[0-9]*:[0-9]*,[0-9]*
cs_re_s:blue,,bold:^[^ ]* *[^,]*,[^ ]* *[0-9]* *(DEBUG) *[^ ]* [^ ]* *(.*)$
cs_re_s:green:^[^ ]* *[^,]*,[0-9]* *[0-9]* *(INFO) *[^ ]* [^ ]* *(.*)$
cs_re_s:yellow:^[^ ]* *[^,]*,[0-9]* *[0-9]* *(WARNING) *[^ ]* [^ ]* *(.*)$
cs_re_s:red:^[^ ]* *[^,]*,[0-9]* *[0-9]* *(ERROR) *[^ ]* [^ ]* *(.*)$
cs_re_s:red,,bold:^[^ ]* *[^,]*,[0-9]* *[0-9]* *(CRITICAL) *[^ ]* [^ ]* *(.*)$
EOF

# Add alias for psql logs
cat >> /etc/bash.bashrc << EOF
alias psql_logs_enable='export PGOPTIONS="$PGOPTIONS -c client_min_messages=notice -c log_min_messages=warning -c log_min_error_statement=error -c log_min_duration_statement=0 -c log_connections=on -c log_disconnections=on -c log_duration=off -c log_error_verbosity=verbose -c log_lock_waits=on -c log_statement=none -c log_temp_files=0"'
alias psql_logs_disable='unset PGOPTIONS'
alias psql_logs_clean='echo -n "" | tee /var/log/pg_log/postgresql.log'
alias psql_logs_tail='tail -f /var/log/pg_log/postgresql.log'
EOF

cat >> /etc/bash.bashrc << EOF
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi
EOF

# Create travis_wait
echo $'#!/bin/bash\n$@' > /usr/bin/travis_wait
chmod +x /usr/bin/travis_wait

# Configure ssh to allow root login but just using ssh key
cat >> /etc/ssh/sshd_config << EOF
PermitRootLogin yes
PasswordAuthentication no
EOF

# Extend root config to every user created from now on
cp -r ~/.profile ~/.bash* ~/.vim* /etc/skel/
rm /etc/skel/.vimrc.before
rm /etc/skel/.vimrc.bundles
cp -r ~/.spf13-vim-3/.vimrc.before ~/.spf13-vim-3/.vimrc.bundles /etc/skel/

# Create shippable user with sudo powers and git configuration
createuser_custom "odoo"
createuser_custom "shippable"
chown -R odoo:odoo ${REPO_REQUIREMENTS}
ln -s "${REPO_REQUIREMENTS}/tools" "/home/odoo/tools"

# Install & configure zsh
git_clone_execute "${OH_MY_ZSH_REPO}" "master" "tools/install.sh"
git_clone_copy "${ZSH_THEME_REPO}" "master" "schminitz.zsh-theme" "${HOME}/.oh-my-zsh/themes/odoo-shippable.zsh-theme"

# Configure emacs for odoo user
git clone -b master https://github.com/Vauxoo/emacs.d.git /home/odoo/.emacs.d
chown -R odoo:odoo /home/odoo/.emacs.d

#Copy zsh for odoo user
cp -r ${HOME}/.oh-my-zsh /home/odoo
chown -R odoo:odoo /home/odoo/.oh-my-zsh
cp ${HOME}/.zshrc /home/odoo/.zshrc
chown odoo:odoo /home/odoo/.zshrc
sed -i 's/root/home\/odoo/g' /home/odoo/.zshrc
sed -i 's/robbyrussell/odoo-shippable/g' /home/odoo/.zshrc
sed -i 's/^plugins=(/plugins=(\n  virtualenv/' /home/odoo/.zshrc

# Set default shell to the root user
usermod -s /bin/bash root

# Export another PYTHONPATH and activate the virtualenvironment
for BASHRC in ${HOME}/.bashrc /home/odoo/.bashrc ${HOME}/.zshrc /home/odoo/.zshrc
do
    echo "Export the PYTHONPATH IN ${BASHRC}"
    cat >> $BASHRC << EOF
if [[ "x\${TRAVIS_PYTHON_VERSION}" == "x" ]] ; then
    TRAVIS_PYTHON_VERSION="2.7"
fi
source ${REPO_REQUIREMENTS}/virtualenv/python\${TRAVIS_PYTHON_VERSION}/bin/activate
source ${REPO_REQUIREMENTS}/virtualenv/nodejs/bin/activate
PYTHONPATH=${PYTHONPATH}:${REPO_REQUIREMENTS}/odoo
EOF
done

# Move inclusion of .bash_aliases to the end of .bashrc so it takes presedence
sed -i '/^if \[ -f ~\/.bash_aliases \]; then/,+2d' /home/odoo/.bashrc
cat >> /home/odoo/.bashrc << 'EOF'
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF

sed -i '/^if \[ -f ~\/.bash_aliases \]; then/,+2d' /root/.bashrc
cat >> /root/.bashrc << 'EOF'
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF

# Overwrite get_versions function to avoid overwriting the init script
# See https://github.com/vauxoo/docker-odoo-image/issues/114 for details
cat >> /usr/share/postgresql-common/init.d-functions << 'EOF'
get_versions() {
    versions="$( pg_lsclusters -h | grep online | awk '{print $1}' )"
    if [ -z "${versions}" ]; then
        if [ -n "${PSQL_VERSION}" ]; then
            versions="${PSQL_VERSION}"
        else
            versions="9.6"
        fi
    fi
}
EOF

# Create shippable role to postgres and shippable for postgres 9.5 and default version
service_postgres_without_sudo 'odoo'

/entrypoint_image
psql_create_role "shippable" "aeK5NWNr2"
psql_create_role "root" "aeK5NWNr2"
/etc/init.d/postgresql stop

# Install & Configure RVM
install_rvm

install_tmux

# Final cleaning
clean_image

