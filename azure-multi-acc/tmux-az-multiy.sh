#!/usr/bin/env bash
# ============================================================
# your-company tmux session launcher
# Usage: ./tmux-your-company.sh [session-name]
# ============================================================

SESSION="${1:-your-company}"
ENVFILE="$HOME/your-company-env/az-env.sh"

# Don't create if session already exists → just attach
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Session '$SESSION' already exists. Attaching..."
  tmux attach-session -t "$SESSION"
  exit 0
fi

new_window() {
  local win_name="$1"
  local cmd="$2"
  tmux new-window -t "$SESSION" -n "$win_name"
  [[ -n "$cmd" ]] && tmux send-keys -t "$SESSION:$win_name" "$cmd" Enter
}

# ── Window 1: az-global ───────────────────────────────────────
tmux new-session -d -s "$SESSION" -n "az-global"
tmux send-keys -t "$SESSION:az-global" "source $ENVFILE && az-global && az-whoami" Enter

# ── Window 2: az-cn ──────────────────────────────────────────
new_window "az-cn" "source $ENVFILE && az-cn && az-whoami"

# ── Window 3: k8s — split left=prod / right=staging ──────────
new_window "k8s" ""
tmux send-keys    -t "$SESSION:k8s" "source $ENVFILE" Enter
tmux split-window -h -t "$SESSION:k8s"                   # pane .1 = left, .2 = right
tmux send-keys    -t "$SESSION:k8s.1" "kctx-sea-prod"  Enter
tmux send-keys    -t "$SESSION:k8s.2" "kctx-sea-stag"  Enter
tmux select-pane  -t "$SESSION:k8s.1"                    # focus left pane on open

# ── Window 4: cn-k8s — CN clusters ───────────────────────────
new_window "cn-k8s" ""
tmux send-keys    -t "$SESSION:cn-k8s" "source $ENVFILE && az-cn" Enter
tmux split-window -h -t "$SESSION:cn-k8s"
tmux send-keys    -t "$SESSION:cn-k8s.1" "kctx-cn-stag" Enter
tmux send-keys    -t "$SESSION:cn-k8s.2" "kctx-cn-dev"  Enter
tmux select-pane  -t "$SESSION:cn-k8s.1"

# ── Window 5: logs ────────────────────────────────────────────
new_window "logs" "source $ENVFILE"

# ── Window 6: tf ──────────────────────────────────────────────
new_window "tf" "source $ENVFILE"

# ── Window 7: notes ───────────────────────────────────────────
new_window "notes" ""

# ── Focus window 1 on attach ─────────────────────────────────
tmux select-window -t "$SESSION:az-global"
tmux attach-session -t "$SESSION"
