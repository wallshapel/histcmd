#!/bin/sh

set -eu

REPOSITORY="https://github.com/wallshapel/histcmd.git"
INSTALL_DIR="$HOME/.local/share/histcmd"
BIN_DIR="$HOME/.local/bin"
ZSHRC="$HOME/.zshrc"

SOURCE_LINE='source "$HOME/.local/share/histcmd/lib/histcmd.zsh"'
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

command -v git >/dev/null 2>&1 || {
    printf '%s\n' "histcmd: Git is required."
    exit 1
}

command -v zsh >/dev/null 2>&1 || {
    printf '%s\n' "histcmd: Zsh is required."
    exit 1
}

mkdir -p "$HOME/.local/share" "$BIN_DIR"
touch "$ZSHRC"

if [ -d "$INSTALL_DIR/.git" ]; then
    printf '%s\n' "Updating histcmd..."
    git -C "$INSTALL_DIR" pull --ff-only
elif [ -e "$INSTALL_DIR" ]; then
    printf '%s\n' "histcmd: $INSTALL_DIR already exists and is not a Git repository."
    exit 1
else
    printf '%s\n' "Installing histcmd..."
    git clone "$REPOSITORY" "$INSTALL_DIR"
fi

ln -sfn "$INSTALL_DIR/bin/histcmd" "$BIN_DIR/histcmd"

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        if ! grep -Fqx "$PATH_LINE" "$ZSHRC"; then
            printf '\n%s\n' "$PATH_LINE" >> "$ZSHRC"
        fi
        ;;
esac

if ! grep -Fqx "$SOURCE_LINE" "$ZSHRC"; then
    printf '\n# HISTCMD\n%s\n' "$SOURCE_LINE" >> "$ZSHRC"
fi

printf '\n%s\n' "histcmd installed successfully."
printf '%s\n' "Open a new Zsh terminal or run:"
printf '%s\n' "  exec zsh"
printf '\n%s\n' "Then initialize a workspace with:"
printf '%s\n' "  histcmd init"
