#! /bin/bash
# individual user work

# [Zsh]
# or use git.io/antigen-nightly for the latest version
curl -L git.io/antigen > antigen.zsh


# [Tmux]
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
tmux source ~/.tmux.conf
~/.tmux/plugins/tpm/bin/install_plugins
# Or I should run `tmux source ~/.tmux.conf` in tmux
# <prefix> + I to install plugin

# [Vim]
# +: -c 
# Since the installer on Vim 8 is asynchronous, you might want to pass --sync flag
vim +'PlugInstall --sync' +qa
