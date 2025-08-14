#!/usr/bin/env bash
#
# install_warp_tmux.sh – install portable-tmux for Warp on Wynton HPC
# Works around BeeGFS ‘no_hardlinks’ by unpacking on scratch, then copying.

set -euo pipefail

# ----- parameters -----------------------------------------------------------
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
URL="https://github.com/warpdotdev/portable-tmux/releases/download/tmux-3.5a/tmux-${ARCH}.tar.gz"
TMPDIR_PARENT="${TMPDIR:-/scratch/$USER}"          # ext4/xfs (hard links OK)
TMP=$(mktemp -d "${TMPDIR_PARENT}/warp-tmux.XXXXXXXX")
DEST="$HOME/.warp/tmux"

echo "Downloading portable-tmux to $TMP …"
mkdir -p "$TMP" && cd "$TMP"
curl -L -o tmux.tgz "$URL"
tar -xzf tmux.tgz                                  # hard links succeed here

echo "Copying files to $DEST …"
mkdir -p "$DEST"
# we do NOT need the bundled terminfo tree, so exclude it:
rsync -a --delete --exclude 'local/share/terminfo/' local/ "$DEST/local/"

echo "Writing Warp launcher …"
cat > "$DEST/execute_tmux.sh" <<'EOF'
#!/usr/bin/env bash
TERM=tmux-256color \
LD_LIBRARY_PATH="$HOME/.warp/tmux/local/lib" \
exec "$HOME/.warp/tmux/local/bin/tmux" -Lwarp -CC "$@"
EOF
chmod +x "$DEST/execute_tmux.sh"

echo "Cleaning up …"
rm -rf "$TMP"

echo "✅  portable-tmux installed.  Test with:"
echo "   $DEST/execute_tmux.sh new -s test"
