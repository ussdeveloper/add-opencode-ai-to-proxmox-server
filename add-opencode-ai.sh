#!/bin/bash
#===============================================================================
# add-opencode-ai.sh
# Adds OpenCode AI as a native Proxmox VE GUI panel tab and menu item.
#
# One-command install:
#   curl -sS https://raw.githubusercontent.com/ussdeveloper/add-opencode-ai-to-proxmox-server/main/add-opencode-ai.sh | bash
#
# Or download and run:
#   chmod +x add-opencode-ai.sh && ./add-opencode-ai.sh
#
# Repo: https://github.com/ussdeveloper/add-opencode-ai-to-proxmox-server
# License: MIT
#===============================================================================

set -euo pipefail

# ---------- Colors ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -eq 0 ]] || error "Must be run as root."
[[ -f /etc/pve/version ]] || error "This script must be run on a Proxmox VE host."

# File paths
PVE_MANAGER_JS="/usr/share/pve-manager/js/pvemanagerlib.js"
PVE_NODES_PM="/usr/share/perl5/PVE/API2/Nodes.pm"
PVE_PROXY_SCRIPT="/usr/local/bin/proxmox-opencode-shell.sh"

# Auto-detect if paths differ
[[ -f "$PVE_MANAGER_JS" ]] || PVE_MANAGER_JS=$(find /usr/share/pve-manager -name "pvemanagerlib.js" -print -quit 2>/dev/null)
[[ -f "$PVE_MANAGER_JS" ]] || error "pvemanagerlib.js not found. Is Proxmox installed?"
[[ -f "$PVE_NODES_PM" ]] || error "Nodes.pm not found. Is Proxmox installed?"

NODES_BACKUP="${PVE_NODES_PM}.backup.$(date +%Y%m%d%H%M%S)"
JS_BACKUP="${PVE_MANAGER_JS}.backup.$(date +%Y%m%d%H%M%S)"

echo ""
info "============================================"
info " OpenCode AI — Proxmox VE Integration Script"
info "============================================"
echo ""

# ---------- Step 1: Node.js ----------
info "1/6: Checking Node.js..."
if command -v node &>/dev/null; then
  info "  Node.js $(node --version) OK."
else
  warn "  Installing Node.js 22.x..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

# ---------- Step 2: opencode-ai ----------
info "2/6: Installing opencode-ai..."
if command -v opencode &>/dev/null; then
  info "  opencode already installed."
else
  npm install -g @opencode-ai/opencode
fi

# ---------- Step 3: Create AGENTS.md with safety instructions ----------
info "3/6: Creating AGENTS.md (safety instructions for opencode)..."
OPENCODE_CONFIG_DIR="${HOME}/.config/opencode"
mkdir -p "$OPENCODE_CONFIG_DIR"

cat > "${OPENCODE_CONFIG_DIR}/AGENTS.md" << 'AGENTS'
# Safety Instructions for OpenCode on Proxmox

## ⚠️ DISCLAIMER & LIABILITY
This AI assistant is provided **AS IS**, without warranty of any kind.
The user assumes **full responsibility** for any actions taken by the AI.
AI models can make mistakes, hallucinate commands, or suggest changes
that may cause **data loss, service disruption, or system instability**.

**By using this tool you acknowledge:**
- You are responsible for reviewing all changes before execution.
- You should maintain **backups** and **snapshots** of critical systems.
- The AI may suggest destructive operations — always verify.
- Running AI-generated commands on production systems carries inherent risk.

## ✅ Rules for the AI

### 1. ALWAYS ask for confirmation before:
- Modifying system configuration files
- Installing or removing packages
- Restarting services that affect running VMs/containers
- Making changes to storage, networking, or firewall rules
- Any operation marked as potentially destructive

### 2. Non-destructive by default
- Prefer `--dry-run`, `--check`, or simulation modes when available
- Suggest rollback strategies alongside any change
- Favor reversible operations; if irreversible, warn clearly

### 3. Communicate clearly
- Explain *what* you are about to do, *why*, and *what the impact* is
- Use clear language — avoid unnecessary jargon
- Summarize changes before executing multi-step operations

### 4. Rollback readiness
- Before modifying a file, suggest or create a backup
- Log changes so they can be undone
- Prefer changes that are easy to revert (e.g., `.d` snippets over monolithic edits)

### 5. Emergency stops
- If a command looks dangerous or unexpected — STOP and ask
- Never `rm -rf`, `dd`, `mkfs`, or similar destructive commands
  without explicit user approval and verification of the target
AGENTS

cat > "${OPENCODE_CONFIG_DIR}/opencode.jsonc" << 'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["AGENTS.md"]
}
JSON

# ---------- Step 4: Wrapper script ----------
info "4/6: Creating VNC shell wrapper..."
cat > "$PVE_PROXY_SCRIPT" << 'WRAPPER'
#!/bin/bash
SESSION="opencode"
tmux has-session -t "$SESSION" 2>/dev/null || \
  tmux new-session -d -s "$SESSION" 'opencode --continue' 2>/dev/null
exec tmux attach-session -t "$SESSION"
WRAPPER
chmod +x "$PVE_PROXY_SCRIPT"

# ---------- Step 5: Patch Nodes.pm ----------
info "5/5: Patching Proxmox API (Nodes.pm)..."
if grep -q "'opencode'" "$PVE_NODES_PM" 2>/dev/null; then
  info "  Nodes.pm already patched."
else
  cp "$PVE_NODES_PM" "$NODES_BACKUP"
  # Insert opencode entry into $shell_cmd_map
  cat > /tmp/_patch_nodes_pm.py << 'PYEOF'
import re, sys

path = sys.argv[1]
proxy_script = sys.argv[2]

with open(path) as f:
    content = f.read()

# Insert opencode entry before the closing '};' of shell_cmd_map
# Find the last occurrence of '};' that closes the map
lines = content.split('\n')
for i in range(len(lines)-1, -1, -1):
    stripped = lines[i].strip()
    if stripped == '};' and i > 0:
        prev = lines[i-1].strip()
        if prev.endswith('},') or prev.endswith('},'):
            insert = (
                "    'opencode' => {\n"
                f"        cmd => ['{proxy_script}'],\n"
                "    },\n"
                "};"
            )
            lines[i] = insert
            break

with open(path, 'w') as f:
    f.write('\n'.join(lines))
print("OK")
PYEOF
  python3 /tmp/_patch_nodes_pm.py "$PVE_NODES_PM" "$PVE_PROXY_SCRIPT"
  perl -c "$PVE_NODES_PM" || (cp "$NODES_BACKUP" "$PVE_NODES_PM" && error "Nodes.pm syntax check failed (reverted).")
  info "  Nodes.pm patched."
fi

# ---------- Step 6: Patch pvemanagerlib.js ----------
info "6/6: Patching Proxmox GUI (pvemanagerlib.js)..."
if grep -q "opencode" "$PVE_MANAGER_JS" 2>/dev/null; then
  info "  pvemanagerlib.js already patched."
else
  cp "$PVE_MANAGER_JS" "$JS_BACKUP"
  cat > /tmp/_patch_pvemanagerlib.py << 'PYEOF'
import re, sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

# Add OpenCode tab after the Shell tab block
shell_tab = (
    r"(\s*xtype: 'pveNoVncConsole',\n"
    r"\s*title: gettext\('Shell'\),\n"
    r"\s*iconCls: 'fa fa-terminal',\n"
    r"\s*itemId: 'jsconsole',\n"
    r"\s*consoleType: 'shell',\n"
    r"\s*xtermjs: true,\n"
    r"\s*nodename: nodename,\n"
    r"\s*}\);)"
)
opencode_tab = (
    r"\1\n"
    r"            me.items.push({\n"
    r"                xtype: 'pveNoVncConsole',\n"
    r"                title: gettext('OpenCode'),\n"
    r"                iconCls: 'fa fa-code',\n"
    r"                itemId: 'opencodeconsole',\n"
    r"                consoleType: 'cmd',\n"
    r"                cmd: 'opencode',\n"
    r"                xtermjs: true,\n"
    r"                nodename: nodename,\n"
    r"            });"
)
content = re.sub(shell_tab, opencode_tab, content, count=1)

# Add right-click menu item after the Shell menu item
shell_menu = (
    r"(\s*text: gettext\('Shell'\),\n"
    r"\s*itemId: 'shell',\n"
    r"\s*iconCls: 'fa fa-fw fa-terminal',\n"
    r"\s*handler: function \(\) \{\n"
    r"\s*let nodename = this\.up\('menu'\)\.nodename;\n"
    r"\s*PVE\.Utils\.openDefaultConsoleWindow\(true, 'shell', undefined, nodename, undefined\);\n"
    r"\s*\},\n"
    r"\s*},)"
)
opencode_menu = (
    r"\1\n"
    r"        {\n"
    r"            text: gettext('OpenCode'),\n"
    r"            itemId: 'opencode',\n"
    r"            iconCls: 'fa fa-fw fa-code',\n"
    r"            handler: function () {\n"
    r"                let nodename = this.up('menu').nodename;\n"
    r"                PVE.Utils.openDefaultConsoleWindow(true, 'cmd', undefined, nodename, undefined, 'opencode');\n"
    r"            },\n"
    r"        }"
)
content = re.sub(shell_menu, opencode_menu, content, count=1)

with open(path, 'w') as f:
    f.write(content)
print("OK")
PYEOF
  python3 /tmp/_patch_pvemanagerlib.py "$PVE_MANAGER_JS"
  info "  pvemanagerlib.js patched."
fi

# ---------- Restart pveproxy ----------
info "Restarting pveproxy..."
systemctl restart pveproxy

echo ""
info "============================================"
info "  ✅ Success! OpenCode AI is now integrated."
info ""
info "  📌 Refresh your browser (Ctrl+Shift+R)"
info "  📌 OpenCode tab appears next to Shell tab"
info "  📌 Right-click menu also has OpenCode"
info ""
info "  🔧 Backups:"
info "     $NODES_BACKUP"
info "     $JS_BACKUP"
info "============================================"
echo ""
