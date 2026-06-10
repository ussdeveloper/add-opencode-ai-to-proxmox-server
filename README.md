# 🚀 OpenCode AI — Proxmox VE Integration DO NOT USE IT NOW!!!!!

Seamlessly integrate [OpenCode AI](https://opencode.ai) into your **Proxmox Virtual Environment** (PVE) as a native GUI panel tab. Just like Shell, Summary, or Notes — but with an AI coding assistant powered by opencode-ai.

![Proxmox OpenCode Tab](https://img.shields.io/badge/Proxmox-OpenCode-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

---


<img width="566" height="444" alt="image" src="https://github.com/user-attachments/assets/1b148895-a13e-42c0-9b89-d7b9b5ffaa08" />


## ✨ Features

- **Native GUI Tab** — OpenCode appears as a tab in every node's detail panel (next to Shell, Summary, System…).
- **Persistent Sessions** — Uses `tmux` to keep your chat session alive between browser tabs and page reloads.
- **One‑Command Install** — Works on any Proxmox VE 8.x / 9.x node.
- **Safe & Reversible** — Original files are backed up before any modification.
- **Works Off‑the‑Shelf** — No Proxmox plugin SDK, no custom API endpoints, no compiled extensions.

---

---

## ⚠️ DISCLAIMER

**USE AT YOUR OWN RISK.**

This integration allows an AI assistant (opencode-ai) to execute commands
directly on your Proxmox host via the web GUI terminal. AI models can
**make mistakes**, **hallucinate commands**, or suggest operations that
may lead to **data loss**, **service disruption**, or **system instability**.

**This project is a work in progress.** It has been tested and verified
on **PVE 9.2 (Debian 13)** by the author, but **no testing has been
performed on other environments or Proxmox versions**. It may serve as
inspiration for your own setup, but **use at your own risk**.

By installing this software you acknowledge that:

- You are **solely responsible** for reviewing and approving every
  action the AI takes.
- You should **always maintain backups** and VM/container snapshots.
- The AI **will ask for confirmation** before destructive operations,
  but you must remain vigilant.
- Running AI-generated commands on **production systems** carries
  inherent risk — treat it like any other privileged user on your server.
- The maintainers of this project **assume no liability** for any
  damages arising from its use.

This script also installs an `AGENTS.md` configuration file that
instructs opencode-ai to:
- Ask for confirmation before modifying configuration files,
  installing packages, or restarting services.
- Prefer non‑destructive operations with rollback suggestions.
- Clearly explain every change and its impact before executing.

---

## 📋 Prerequisites

- **Proxmox VE** 8.x or 9.x
- **Root** access via SSH
- **Internet connectivity** (to download Node.js, npm and opencode-ai)

---

## ⚡ Quick Install

**One-liner (curl | bash):**

```bash
curl -sS https://raw.githubusercontent.com/ussdeveloper/add-opencode-ai-to-proxmox-server/master/add-opencode-ai.sh | bash
```

**Or download, inspect, then run:**

```bash
curl -sSLO https://raw.githubusercontent.com/ussdeveloper/add-opencode-ai-to-proxmox-server/main/add-opencode-ai.sh
chmod +x add-opencode-ai.sh
./add-opencode-ai.sh
```

The script will:

1. Install **Node.js** (22.x LTS via NodeSource) if not already present.
2. Install **opencode-ai** globally via npm.
3. Create the **VNC shell wrapper** that launches opencode inside a tmux session.
4. Patch **Nodes.pm** (`PVE::API2`) to add the `opencode` shell command.
5. Patch **pvemanagerlib.js** (`Proxmox GUI`) to add the OpenCode tab and context‑menu entry.
6. Restart **pveproxy** so the changes take effect immediately.

After a browser hard‑refresh (`Ctrl+Shift+R`), the **OpenCode** tab will appear on every node's detail panel.

---

## 🖱️ How to Use

1. **Log into** the Proxmox web interface.
2. **Select any node** in the left‑hand resource tree.
3. **Click the OpenCode tab** in the node's panel (between *Shell* and *System* / *Notes*).
4. A **VNC terminal** opens, automatically connected to a persistent `tmux` session running `opencode --continue`.
5. Type your prompt and press Enter — the AI assistant responds inline.

> **First run** may be slower while `opencode --continue` initializes. Subsequent opens are instant because the tmux session stays alive.

---

## 🔧 What Gets Modified

| File | Modification |
|------|-------------|
| `/usr/local/bin/proxmox-opencode-shell.sh` | **Created** — wrapper script that creates / attaches a tmux session |
| `/usr/share/perl5/PVE/API2/Nodes.pm` | **Patched** — `$shell_cmd_map` gains an `opencode` entry (`.backup` saved) |
| `/usr/share/pve-manager/js/pvemanagerlib.js` | **Patched** — OpenCode tab & context‑menu item added (`.backup` saved) |

No system services, no udev rules, no permanent daemons are installed.

---

## ♻️ Uninstalling

```bash
# Restore backup files
cp /usr/share/perl5/PVE/API2/Nodes.pm.backup /usr/share/perl5/PVE/API2/Nodes.pm
cp /usr/share/pve-manager/js/pvemanagerlib.js.backup /usr/share/pve-manager/js/pvemanagerlib.js

# Remove wrapper script
rm /usr/local/bin/proxmox-opencode-shell.sh

# Restart pveproxy
systemctl restart pveproxy

# Optionally uninstall opencode-ai and Node.js
npm uninstall -g @opencode-ai/opencode
```

---

## 📂 Repository Structure

```
add-opencode-ai-to-proxmox-server/
├── add-opencode-ai.sh          # Main installation script
├── README.md                   # This file
└── backup/                     # Original unmodified files (for reference)
    ├── Nodes.pm.orig
    └── pvemanagerlib.js.orig
```

---

## 🧪 Tested On

| Proxmox Version | Status |
|----------------|--------|
| PVE 9.2 (Debian 13) | ✅ Verified |
| PVE 8.x | ✅ Should work (not yet tested) |

---

## 🤝 Contributing

Pull requests, issues, and feature suggestions are very welcome!  
Please open a [GitHub Issue](https://github.com/ussdeveloper/add-opencode-ai-to-proxmox-server/issues) for any problems.

---

## 📄 License

MIT — see [LICENSE](LICENSE) for details.
