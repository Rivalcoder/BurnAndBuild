# BurnAndBuild: Universal Disposable Dev Environment Automation

[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg)](https://microsoft.com/PowerShell)
[![Bash 4+](https://img.shields.io/badge/Bash-4%2B-darkgreen.svg)]()
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-brightgreen.svg)]()
[![Platform: Linux](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian%20%7C%20Fedora%20%7C%20WSL2-orange.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**BurnAndBuild** is a production-grade, interactive, modular, and idempotent dev environment automation engine designed for disposable cloud VMs, local workstations, and dev containers.

> **The Burn & Build Philosophy:**
> - 🔥 **Burn**: When a trial VM expires, system packages drift, or environments clutter, discard the machine without hesitation.
> - 🛠️ **Build**: Provision a brand new, fully customized workstation with your exact developer stack in **under 10 minutes**.

When executed, BurnAndBuild **interactively asks which tools you want to install** (or accepts unattended CLI flags) and configures only the selected runtimes, SDKs, IDE extensions, environment variables, PATH, and persistence.

---

## Interactive Architecture Overview

```
                                +----------------------------------------------+
                                |      Target Disposable Machine / VM          |
                                |            (Windows or Linux)                |
                                +----------------------------------------------+
                                                       |
                         +-----------------------------+-----------------------------+
                         |                                                           |
                 [ Windows Runner ]                                           [ Linux Runner ]
              burnandbuild.bat / .ps1                                      burnandbuild.sh / .sh
                         |                                                           |
          +-----------------------------+                             +-----------------------------+
          |  WPF Graphical Checklist    |                             | Interactive Terminal Menu   |
          |  - Windows WPF GUI Dialog   |                             | - ANSI Checkbox TUI         |
          |  - Presets & Search         |                             | - Number Toggle & Presets   |
          +-----------------------------+                             +-----------------------------+
                         |                                                           |
                         +-----------------------------+-----------------------------+
                                                       |
        +----------------------------------------------+----------------------------------------------+
        |                      |                       |                       |                      |
[ 01-Base-OS ]         [ 02-Common-CLI ]       [ 03-Runtimes ]         [ 04-Android-SDK ]     [ 05-Flutter-SDK ]
  - NTFS Long Paths      - Git & GitHub CLI      - Node.js LTS (fnm)     - cmdline-tools        - Flutter Stable
  - Inotify Watchers     - 7-Zip & jq            - Python 3.12 & uv      - platform-tools (adb) - flutter config
  - Developer Mode       - ripgrep & fzf         - Java JDK 17 Temurin   - build-tools 34.0.0   - Android Linking
  - Power / Sleep Off    - pwsh 7 & tmux         - Gradle Build Tool     - Auto Licenses        - flutter doctor
        |                      |                       |                       |                      |
        +----------------------------------------------+----------------------------------------------+
                                                       |
        +----------------------------------------------+----------------------------------------------+
        |                                              |                                              |
 [ 06-Docker ]                                  [ 07-IDEs-Editors ]                            [ 08-AI-Tools ]
  - Docker Desktop / Engine                      - VS Code + Dynamic Extensions                 - Google Antigravity CLI (agy)
  - WSL2 / Linux Daemon Setup                    - Chrome / Brave Browser                       - Google Antigravity IDE
  - Docker Compose                               - Postman / DBeaver                            - Cursor AI Editor
  - Rootless User Group                                                                         - OpenAI Codex CLI
        |                                              |                                              |
        +----------------------------------------------+----------------------------------------------+
                                                       |
                                           [ Persistence & Profiles ]
                                            - Workspaces: C:\Workspace or /workspace
                                            - Cache Redirection (.gradle, pip, uv, pub)
                                            - SSH Keypair (ED25519) & Git Identity
                                                       |
                                          [ Verification Smoke Tests ]
                                            - Dynamic smoke test for all selected tools
```

---

## Repository Structure

```
BurnAndBuild/
├── Start-Windows.bat             # Primary Windows one-click launcher (Auto-Admin)
├── Start-Linux.sh                # Primary Linux one-click launcher (Auto-Sudo & TUI)
├── config.json                   # Cross-platform package catalog, URLs & presets
├── modules/
│   ├── ToolSelector.psm1         # Windows: Modern WPF GUI & interactive CLI engine
│   ├── Logging.psm1              # Windows: Color logger & persistent file logs
│   ├── Environment.psm1          # Windows: System PATH & environment variables
│   ├── WinGetHelper.psm1         # Windows: WinGet detection & package manager
│   ├── ProcessHelper.psm1        # Windows: Safe process execution & retries
│   └── linux/
│       ├── logging.sh            # Linux: Color logger & persistent file logs
│       ├── package-manager.sh    # Linux: Distro detection (apt/dnf/pacman) abstraction
│       └── tool-selector.sh      # Linux: Interactive terminal checklist TUI
├── scripts/
│   ├── bootstrap.ps1             # Windows master orchestrator engine
│   ├── burnandbuild.ps1          # Windows CLI convenience wrapper
│   ├── burnandbuild.sh           # Linux master orchestrator engine
│   ├── bootstrap.sh              # Linux CLI convenience wrapper
│   ├── 01-Base-Windows.ps1       # Windows: Long paths, dev mode, power, explorer
│   ├── 02-Common-CLI.ps1         # Windows: 7-Zip, Git, jq, ripgrep, fzf, pwsh 7, gh
│   ├── 03-Runtimes.ps1           # Windows: Node (fnm), Python (uv), Java 17, Gradle
│   ├── 04-Android-SDK.ps1        # Windows: Android cmdline-tools, platform-tools, licenses
│   ├── 05-Flutter-SDK.ps1        # Windows: Flutter SDK, PATH, Java linking, doctor
│   ├── 06-Docker.ps1             # Windows: Docker Desktop & WSL2 integration
│   ├── 07-IDEs-Editors.ps1       # Windows: VS Code + extensions, Chrome, Postman, DBeaver
│   ├── 08-AI-Tools.ps1           # Windows: Antigravity CLI/IDE, Cursor, Codex CLI
│   ├── 08-Shell-Profile.ps1      # Windows: PowerShell profile, completions & aliases
│   ├── 09-Persistence-Setup.ps1  # Windows: Git identity, SSH key, cache redirection
│   └── linux/
│       ├── 01-base-linux.sh      # Linux: Inotify watchers, build-essential, /workspace
│       ├── 02-common-cli.sh      # Linux: Git, GitHub CLI, jq, ripgrep, fzf, tmux, zsh
│       ├── 03-runtimes.sh        # Linux: Node (fnm), Python 3 & uv, JDK 17, Gradle
│       ├── 04-android-sdk.sh     # Linux: Android cmdline-tools, platform-tools, licenses
│       ├── 05-flutter-sdk.sh     # Linux: Flutter stable SDK, android link, doctor
│       ├── 06-docker.sh          # Linux: Docker Engine, Compose plugin, user group
│       ├── 07-ides-editors.sh    # Linux: VS Code + extensions, Chrome, Postman, DBeaver
│       ├── 08-ai-tools.sh        # Linux: Antigravity CLI, IDE, Cursor, Codex
│       ├── 09-shell-profile.sh   # Linux: /etc/profile.d, exports, developer aliases
│       └── 10-persistence-setup.sh # Linux: /workspace, SSH ED25519 key, Git config
├── tests/
│   ├── Verify-Installation.ps1   # Windows: Dynamic smoke test for selected tools
│   └── verify-installation.sh    # Linux: Dynamic smoke test for selected tools
├── docs/
│   ├── DISASTER_RECOVERY.md      # Rapid recovery playbook (Windows & Linux)
│   ├── DATA_PERSISTENCE.md       # Disk isolation & cache redirection strategy
│   └── GOLDEN_IMAGE_GUIDE.md     # Golden master image creation (Cloud & Hypervisors)
└── README.md
```

---

## Quickstart Guide

### 🪟 Windows Setup

#### Method 1: Double-Click Launcher (Easiest)
Double-click **`Start-Windows.bat`** in File Explorer. It automatically prompts for Administrator rights and opens the interactive graphical checklist window.

#### Method 2: Elevated PowerShell / CLI
Open **PowerShell as Administrator** and execute:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\scripts\bootstrap.ps1
```
*(or pass parameters directly to `.\Start-Windows.bat`)*

---

### 🐧 Linux Setup (Ubuntu, Debian, Fedora, WSL2)

#### Interactive Terminal Checklist Menu:
Clone or download the repository, then run:
```bash
chmod +x Start-Linux.sh
sudo ./Start-Linux.sh
```
A clean, interactive terminal checklist will appear allowing you to toggle tools by number (e.g. `1,3,5`), apply one-letter presets (`AI`, `M`, `W`, `D`, `A`, `C`), and press **ENTER** to provision.

---

## Unattended & Headless Execution

For CI/CD pipelines, cloud-init, Azure Custom Script Extensions, Packer golden images, or SSH:

| Workflow | Windows Command | Linux Bash Command |
| :--- | :--- | :--- |
| **Interactive Selection** | `.\Start-Windows.bat` | `sudo ./Start-Linux.sh` |
| **Console Menu Only** | `.\Start-Windows.bat -NoGui` | `sudo ./Start-Linux.sh --cli` |
| **AI & Autonomous Agents** | `.\Start-Windows.bat -Preset "ai"` | `sudo ./Start-Linux.sh --preset ai` |
| **Mobile / Flutter Preset** | `.\Start-Windows.bat -Preset "mobile"` | `sudo ./Start-Linux.sh --preset mobile` |
| **Full-Stack Web Preset** | `.\Start-Windows.bat -Preset "web"` | `sudo ./Start-Linux.sh --preset web` |
| **DevOps / Containers Preset** | `.\Start-Windows.bat -Preset "devops"` | `sudo ./Start-Linux.sh --preset devops` |
| **Specific Tools Only** | `.\Start-Windows.bat -Tools "antigravityCli,cursor,node,python"` | `sudo ./Start-Linux.sh --tools "antigravityCli,cursor,node,python"` |
| **Install Entire Catalog** | `.\Start-Windows.bat -Full` | `sudo ./Start-Linux.sh --full` |
| **Minimal (CLI & Base)** | `.\Start-Windows.bat -BaseOnly` | `sudo ./Start-Linux.sh --base-only` |
| **With Git Credentials** | `.\Start-Windows.bat -GitName "Jane" -GitEmail "j@ex.com"` | `sudo ./Start-Linux.sh --git-name "Jane" --git-email "j@ex.com"` |

---

## Tool Catalog & Presets

BurnAndBuild includes 21 declarative components organized into logical categories:

- 🤖 **AI & Autonomous Agents**: Google Antigravity CLI (`agy`), Google Antigravity IDE, Cursor AI Editor, OpenAI Codex CLI
- 📱 **Mobile Development**: Flutter SDK, Android SDK & Tools (`adb`, `sdkmanager`), Java JDK 17 (Temurin / OpenJDK)
- 🌐 **Web & Backend Runtimes**: Node.js LTS (via `fnm`), Python 3.12 & `uv`, Gradle Build Tool
- 🐳 **Containers & Cloud**: Docker Desktop / Docker Engine & Docker Compose
- 💻 **Core CLI**: Git, GitHub CLI (`gh`), 7-Zip (`p7zip`), jq, ripgrep (`rg`), fzf, PowerShell 7, Windows Terminal, tmux, zsh
- 📝 **IDEs & Editors**: VS Code (+ dynamic extensions tailored to chosen tools), Notepad++ / Micro
- 🛠️ **API & Database**: Postman, DBeaver Community
- 📊 **Data & Analytics**: Microsoft Power BI Desktop / Web integration
- 📋 **Project Management**: Atlassian Jira CLI (`acli`) & VS Code Jira integration
- 🌐 **Browsers**: Google Chrome, Brave Browser
- ⚙️ **System Optimizations**: Win32 Long Paths (>260 chars), Dev Mode, Linux Inotify Watches (`fs.inotify.max_user_watches = 524288`)

### Available Presets
- `[ AI & Agents ]`: Antigravity CLI + Antigravity IDE + Cursor + Codex + Git + Node.js + Python + VS Code + Base OS
- `[ Mobile / Flutter ]`: Flutter + Android SDK + Java 17 + Gradle + Git + VS Code + Chrome + Base OS
- `[ Full-Stack Web ]`: Node.js + Python + Docker + Git + VS Code + Chrome + Postman + Base OS
- `[ Docker & DevOps ]`: Docker + Python + Git + PowerShell 7 + VS Code + Base OS
- `[ Select All ]`: Provisions all 21 tools in catalog
- `[ Clear All ]`: Clears selection for custom checkmarks

---

## Dynamic Verification & Health Check

Run the dynamic validation smoke test at any time to verify that your selected tools, binaries, and environment variables are active and healthy:

### On Windows:
```powershell
# Verify all installed tools
.\tests\Verify-Installation.ps1

# Or verify specific tools
.\tests\Verify-Installation.ps1 -SelectedTools "antigravityCli", "flutter", "node", "docker"
```

### On Linux:
```bash
# Verify all installed tools
./tests/verify-installation.sh

# Or verify specific tools
./tests/verify-installation.sh antigravityCli flutter node docker
```

---

## Documentation Guides

- 📘 [Disaster Recovery Playbook](docs/DISASTER_RECOVERY.md): Step-by-step 10-minute recovery when a cloud VM expires.
- 💾 [Data Persistence & Cache Isolation](docs/DATA_PERSISTENCE.md): Retaining source code, SSH keys, and package caches across disposable VM rebuilds.
- 🖼️ [Golden Master Image Guide](docs/GOLDEN_IMAGE_GUIDE.md): Converting configured environments into reusable templates across Azure, AWS, GCP, and Proxmox.

---

## License

This project is licensed under the [MIT License](LICENSE).
