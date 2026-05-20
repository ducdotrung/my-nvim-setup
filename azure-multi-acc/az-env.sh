#!/usr/bin/env bash
# ============================================================
# your-company Azure Multi-Cloud Environment
# Source this in your ~/.zshrc or ~/.bashrc:
#   source ~/your-company-env/az-env.sh
# ============================================================

# ── Config dirs (isolated per cloud) ───────────────────────
export AZURE_CONFIG_DIR_GLOBAL="$HOME/.azure-global"
export AZURE_CONFIG_DIR_CN="$HOME/.azure-cn"
mkdir -p "$AZURE_CONFIG_DIR_GLOBAL" "$AZURE_CONFIG_DIR_CN"

# Active cloud indicator (exported so tmux status can read it)
export AZ_ACTIVE_CLOUD="${AZ_ACTIVE_CLOUD:-global}"

# ── Core cloud switchers ────────────────────────────────────
az-global() {
  export AZURE_CONFIG_DIR="$AZURE_CONFIG_DIR_GLOBAL"
  export AZ_ACTIVE_CLOUD="global"
  az cloud set --name AzureCloud 2>/dev/null
  echo "global" > ~/.az-active-cloud   # tmux status reads this
  echo "☁  Switched to Azure Global  (AZURE_CONFIG_DIR → ~/.azure-global)"
}

az-cn() {
  export AZURE_CONFIG_DIR="$AZURE_CONFIG_DIR_CN"
  export AZ_ACTIVE_CLOUD="cn"
  az cloud set --name AzureChinaCloud 2>/dev/null
  echo "cn" > ~/.az-active-cloud       # tmux status reads this
  echo "☁  Switched to Azure China   (AZURE_CONFIG_DIR → ~/.azure-cn)"
}

# ── Login helpers ───────────────────────────────────────────
az-login-global() {
  az-global
  az login
}

az-login-cn() {
  az-cn
  # az cloud set (inside az-cn) already points CLI at China endpoints
  # az login has no --environment flag — just login normally after cloud switch
  az login
}

# Login with Service Principal (CI/CD)
# Usage: az-sp-login <APP_ID> <CLIENT_SECRET> <TENANT_ID> [cn]
az-sp-login() {
  local app_id="$1" secret="$2" tenant="$3" cloud="${4:-global}"
  [[ "$cloud" == "cn" ]] && az-cn || az-global
  az login --service-principal \
    --username  "$app_id" \
    --password  "$secret" \
    --tenant    "$tenant"
}

# ── Who am I? ───────────────────────────────────────────────
az-whoami() {
  echo "Cloud   : $AZ_ACTIVE_CLOUD  ($(az cloud show --query name -o tsv 2>/dev/null))"
  echo "Config  : $AZURE_CONFIG_DIR"
  az account show --query "{sub:id, name:name, user:user.name}" -o table 2>/dev/null
}

# ── Subscription switchers (add your own) ──────────────────
# Usage: az-sub <sub-id or name>
az-sub() {
  az account set --subscription "$1" && \
  echo "➜  Active sub: $1"
}

# Quick list
az-subs() {
  az account list --output table
}

# ── Cluster switchers (your-company) ───────────────────────────────
# Format: <context-name>  (must match name in kubeconfig after get-credentials)

# Global clusters
alias kctx-us-prod="kubectl config use-context usyour-companyv3-aks-prod01"
alias kctx-us-stag="kubectl config use-context usyour-companyv3-aks-staging01"
alias kctx-us-test="kubectl config use-context usyour-companyv3-aks-test01"
alias kctx-sea-prod="kubectl config use-context seayour-companyv3-aks-prod01"
alias kctx-sea-stag="kubectl config use-context seayour-companyv3-aks-staging01"
alias kctx-eu-prod="kubectl config use-context fryour-companyv3-aks-prod01"
alias kctx-eu-stag="kubectl config use-context fryour-companyv3-aks-staging01"

# CN clusters (chinanorth3 / CCNAKSyour-companyV3-01)
# Note: ccnyour-companyv3-aks-prod01 is currently in Failed state
alias kctx-cn-prod="kubectl config use-context ccnyour-companyv3-aks-prod01"
alias kctx-cn-stag="kubectl config use-context ccnyour-companyv3-aks-staging01"
alias kctx-cn-dev="kubectl config use-context ccnyour-companyv3-aks-dev01"

alias k="kubectl"

# Pull / refresh all kubeconfigs (global + CN)
az-get-all-kubeconfigs() {
  # ── Azure Global ─────────────────────────────────────────
  az-global

  echo "==> US clusters"
  for c in usyour-companyv3-aks-prod01 usyour-companyv3-aks-staging01 usyour-companyv3-aks-test01; do
    az aks get-credentials --resource-group US-your-companyV3-01 --name "$c" --overwrite-existing
  done

  echo "==> SEA clusters"
  for c in seayour-companyv3-aks-prod01 seayour-companyv3-aks-staging01; do
    az aks get-credentials --resource-group SEA-your-companyV3-01 --name "$c" --overwrite-existing
  done

  echo "==> EU clusters"
  for c in fryour-companyv3-aks-prod01 fryour-companyv3-aks-staging01; do
    az aks get-credentials --resource-group EU-your-companyV3-01 --name "$c" --overwrite-existing
  done

  # ── Azure China ───────────────────────────────────────────
  az-cn

  echo "==> CN clusters (chinanorth3)"
  for c in ccnyour-companyv3-aks-dev01 ccnyour-companyv3-aks-staging01; do
    az aks get-credentials --resource-group CCNAKSyour-companyV3-01 --name "$c" --overwrite-existing
  done

  # CN prod is in Failed state — attempt but warn
  echo "⚠  CN prod is in Failed state — attempting get-credentials anyway ..."
  az aks get-credentials --resource-group CCNAKSyour-companyV3-01 --name ccnyour-companyv3-aks-prod01 \
    --overwrite-existing 2>&1 || echo "   x Skipped (cluster unavailable)"

  # Restore global as default after CN work
  az-global

  echo ""
  kubectl config get-contexts
}

# ── Resource group shortcuts ────────────────────────────────
# Wrap az with a default RG so you can skip --resource-group
azus()  { AZURE_CONFIG_DIR="$AZURE_CONFIG_DIR_GLOBAL" az --only-show-errors "$@" --resource-group US-your-companyV3-01; }
azsea() { AZURE_CONFIG_DIR="$AZURE_CONFIG_DIR_GLOBAL" az --only-show-errors "$@" --resource-group SEA-your-companyV3-01; }
azeu()  { AZURE_CONFIG_DIR="$AZURE_CONFIG_DIR_GLOBAL" az --only-show-errors "$@" --resource-group EU-your-companyV3-01; }

# Example: azus aks list -o table
#          azsea vm list -o table

# ── AKS kubelogin helper (for Azure AD clusters) ───────────
az-kubelogin() {
  # Converts current context's credentials for kubelogin plugin
  local mode="${1:-azurecli}"   # azurecli | devicecode | msi | spn
  kubelogin convert-kubeconfig -l "$mode"
  echo "kubelogin: converted context $(kubectl config current-context) → mode=$mode"
}

# ── Quick VM inspect ────────────────────────────────────────
az-vm() {
  # az-vm <name> [--resource-group RG]
  az vm show --name "$1" "${@:2}" -o json | \
    jq '{name:.name, rg:.resourceGroup, size:.hardwareProfile.vmSize,
         os:.storageProfile.osDisk.osType, state:.powerState}'
}

# ── Status prompt helper (for PS1 / Starship / oh-my-zsh) ──
az_cloud_prompt() {
  # Returns a short tag for your shell prompt
  case "$AZ_ACTIVE_CLOUD" in
    global) echo "☁az" ;;
    cn)     echo "☁az-cn" ;;
    *)      echo "☁?" ;;
  esac
}

# ── Init: default to global on shell start ──────────────────
# Comment out if you want no default active
if [[ -z "$AZURE_CONFIG_DIR" ]]; then
  export AZURE_CONFIG_DIR="$AZURE_CONFIG_DIR_GLOBAL"
fi
