# $HOME configs

1. .zshrc
2. .vimrc
3. .tmux.conf (+ `.tmux/bin/osc52-screen`)
4. .gitconfig
    - user, email, editor
    - credential.helper
5. .jupyter/jupyter_notebook_config.py
    - password
6. config.sh
    - for building zplug, tmux (tpm), vim plugins

## Usage for dummies

```bash
rm -Rvf ~/.config ~/.mrconfig ~/config.sh ~/.jupyter/jupyter_notebook_config.py ~/.gitignore.d/ ~/.gitconfig ~/.zshrc ~/.vimrc ~/.ycm_extra_conf.py ~/.tmux.conf ~/README.md
cd; vcsh clone https://github.com/Shen-Jing/config-mr.git
mr update; exec $SHELL
chmod 755 ~/config.sh && ~/config.sh
```

## Vim

### YouCompleteMe

#### Manually install

vim-plug "Post-update hooks" can install YCM successfully, **but** its function doesn't work in this way.

So we should manually install completer:

```bash
# These have been included in ~/config.sh
cd ~/.vim/plugged/YouCompleteMe
python3 install.py --clangd-completer
```

## tmux

### tmux copy to local clipboard (ssh + GNU screen + tmux)

Config: `.tmux.conf` (yank section) and `~/.tmux/bin/osc52-screen` (both in the `config-tmux` repo).

#### Symptoms

- tmux-yank shows `Error! tmux-yank dependencies not installed!`
- `prefix + [` -> `V` -> `y` / `Enter` runs without error, but nothing reaches the local clipboard (pasting gives old content)

#### Root causes

1. **tmux-yank has no copy command.** The plugin is installed, but it looks for `xclip` / `xsel` / `wl-copy` in `PATH` *when the tmux server loads it*. If none is found, it binds the copy keys to the error message. Fix by setting `@override_copy_command`.
2. **xclip cannot work over plain ssh.** There is no `$DISPLAY` (`xclip: Can't open display`), so it can never write to the local machine. The only way back to the local clipboard is an **OSC52** escape sequence, which the local terminal turns into a clipboard write.
3. **GNU screen swallows OSC52.** With `ssh -> screen -> tmux` the sequence never reaches the terminal (plain `ssh -> tmux` works). It must be wrapped in a DCS passthrough: `ESC P <OSC52> ESC \`.
4. **tmux cannot wrap it for you.** Overriding `Ms` through `terminal-overrides` (`screen*:Ms=\EP\E]52;...`) has no effect: `tmux info | grep Ms` still shows the plain `\033]52;...`, because the `clipboard` terminal feature overwrites it. So wrap it ourselves.

#### Fix

`~/.tmux/bin/osc52-screen` reads stdin, base64-encodes it and writes the OSC52 sequence to the pane tty using tmux passthrough (every `ESC` inside the passthrough is doubled). If the client TERM is `screen*`, the sequence is additionally wrapped in a screen DCS.

```tmux
set -gq allow-passthrough on        # tmux >= 3.3, required for passthrough
set -g set-clipboard on
set -g @override_copy_command '~/.tmux/bin/osc52-screen'
bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel '~/.tmux/bin/osc52-screen'
```

Then reload: `tmux source-file ~/.tmux.conf`. Keys (vi mode): `prefix + [`, `V` select line, `y` or `Enter` copy.

#### Verify (step by step)

1. Isolate screen from tmux: run this in a **screen** shell (outside tmux) and paste in a local editor. Expect `screen-direct`:
   ```bash
   printf '\033P\033]52;c;%s\a\033\\' "$(printf 'screen-direct' | base64)"
   ```
2. Inside **tmux**:
   ```bash
   printf 'TEST' | ~/.tmux/bin/osc52-screen
   ```
   Paste in a local editor (not in the terminal). Expect `TEST`.

Notes:
- `printf '\033]52;...'` typed directly in a tmux pane does **not** test tmux's clipboard path (tmux swallows it); use the script above or `tmux set-buffer -w TEXT`.
- Run the test in a pane that is actually visible on your attached client; passthrough output of a hidden pane is not forwarded.
- The terminal must support OSC52 writes. [Tabby](https://github.com/Eugeny/tabby) does (`tabby-terminal/src/middleware/oscProcessing.ts`), but only for target `c`, and data over ~1KB is dropped (Tabby issue #10925). Long selections may not copy.
- `tmux-yank` configs changed after the server started are not always re-applied; `tmux source-file` fixes it, otherwise restart the tmux server.
- Needs a working shell `tmux` in `PATH` inside the copy command (the script calls `tmux display-message`).
