#!/usr/bin/env bash
# ============================================================
# Bootstrap: install your-company env on a fresh machine
# Usage: bash bootstrap.sh
# ============================================================
set -e

YOUR_COMPANY_DIR="$HOME/your-company-env"
SHELL_RC="${HOME}/.zshrc"

#echo "==> Creating $YOUR_COMPANY_DIR ..."
#mkdir -p "$YOUR_COMPANY_DIR"

# ── Copy files (already downloaded next to this script) ──────
# If running from the dir where you placed them:
#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#cp "$SCRIPT_DIR/az-env.sh"      "$YOUR_COMPANY_DIR/"
#cp "$SCRIPT_DIR/tmux.conf"      "$YOUR_COMPANY_DIR/"
#cp "$SCRIPT_DIR/tmux-your-company.sh"  "$YOUR_COMPANY_DIR/"
chmod +x "$YOUR_COMPANY_DIR/tmux-your-company.sh"

# ── Symlink tmux config ───────────────────────────────────────
if [[ -f "$HOME/.tmux.conf" ]]; then
  echo "==> Backing up existing ~/.tmux.conf → ~/.tmux.conf.bak"
  cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak"
fi
ln -sf "$YOUR_COMPANY_DIR/tmux.conf" "$HOME/.tmux.conf"
echo "==> Linked ~/.tmux.conf → $YOUR_COMPANY_DIR/tmux.conf"

# ── Add source line to shell RC if not already there ─────────
SOURCELINE="source \$HOME/your-company-env/az-env.sh"
if ! grep -qF "$SOURCELINE" "$SHELL_RC" 2>/dev/null; then
  echo "" >> "$SHELL_RC"
  echo "# your-company Azure multi-cloud env" >> "$SHELL_RC"
  echo "$SOURCELINE" >> "$SHELL_RC"
  echo "==> Added source line to $SHELL_RC"
else
  echo "==> Source line already in $SHELL_RC, skipping"
fi

# ── Check dependencies ────────────────────────────────────────
echo ""
echo "==> Checking dependencies ..."
for bin in az kubectl tmux kubelogin jq; do
  if command -v "$bin" &>/dev/null; then
    echo "    ✓ $bin ($(command -v "$bin"))"
  else
    echo "    ✗ $bin — NOT FOUND (install it!)"
  fi
done

echo ""
echo "==> Done! Next steps:"
echo "    1. source $SHELL_RC     (or open a new terminal)"
echo "    2. az-login-global      (log into Azure Global)"
echo "    3. az-login-cn          (log into Azure China)"
echo "    4. az-get-all-kubeconfigs"
echo "    5. $YOUR_COMPANY_DIR/tmux-your-company.sh"
