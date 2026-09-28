# Universal Disposable Windows Dev Environment Automation

[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg)](https://microsoft.com/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-brightgreen.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-grade, interactive, modular, and idempotent automation framework designed to configure a fresh, disposable Windows VM into a fully loaded software, AI, web, and mobile development environment in under 10 minutes.

When executed, it **interactively asks which tools you want to install** (Antigravity CLI/IDE, Cursor, OpenAI Codex, Flutter, Node.js, Python, Docker, Java, Android SDK, VS Code, Git, Chrome, Postman, etc.) and provisions only the checked tools.

---

## Interactive Architecture Overview

```
                                +----------------------------------------------+
                                |             Target Disposable VM             |
                                +----------------------------------------------+
                                                       |
                                               [ bootstrap.ps1 ]
                                                       |
                                      +---------------------------------+
                                      |   Interactive Tool Selection    |
                                      |   - WPF GUI Checklist Window    |
                                      |   - Quick Presets & CLI Menu    |
                                      +---------------------------------+
                                                       |
         +---------------------------------------------+---------------------------------------------+
         |                      |                      |                      |                      |
 [ 01-Base-Windows ]    [ 02-Common-CLI ]      [ 03-Runtimes ]        [ 04-Android-SDK ]     [ 05-Flutter-SDK ]
   - LongPaths (>260)     - Git for Windows      - Node.js LTS (fnm)    - cmdline-tools        - Flutter Stable SDK
   - Developer Mode       - 7-Zip / jq / ripgrep - Python 3.12 & uv     - platform-tools (adb) - flutter config
   - Prevent Sleep        - pwsh 7 / Terminal    - Java JDK 17 (Temurin)- build-tools 34.0.0   - Android Linking
   - Explorer Tweaks      - GitHub CLI           - Gradle Build Tool    - Auto Licenses        - flutter doctor
         |                      |                      |                      |                      |
         +---------------------------------------------+---------------------------------------------+
                                                       |
         +---------------------------------------------+---------------------------------------------+
         |                                             |                                             |
  [ 06-Docker ]                                 [ 07-IDEs-Editors ]                           [ 08-AI-Tools ]
   - Docker Desktop                              - VS Code + Dynamic Extensions                - Antigravity CLI (agy)
   - WSL2 / Hyper-V Setup                        - Notepad++ / Chrome                          - Antigravity IDE
   - Docker CLI & Compose                        - Postman / DBeaver                           - Cursor AI Editor
         |                                             |                               - OpenAI Codex CLI
         +---------------------------------------------+---------------------------------------------+
                                                       |
                                            [ 09-Persistence-Setup ]
                                               - Secondary Disk / C:\Workspace
                                               - Cache Redirection (.gradle, pip, uv, pub)
                                               - SSH Keypair & Git Identity
                                                       |
                                           [ tests/Verify-Installation ]
                                               - Dynamic Smoke Test for Selected Tools
```

---

## Repository Structure

```
VM-Tool/
├── Start-Setup.bat               # Double-clickable one-step launcher with auto-elevation
├── bootstrap.ps1                 # Master orchestrator with interactive selector & flags
├── config.json                   # Declarative package catalog, presets, URLs, and settings
├── modules/
│   ├── ToolSelector.psm1         # Modern WPF GUI checklist & interactive CLI selection engine
│   ├── Logging.psm1              # Color-coded console logging and persistent file logs
│   ├── Environment.psm1          # Machine/User PATH management, persistent env vars, session reload
│   ├── WinGetHelper.psm1         # WinGet detection, dependency bootstrapping, package installation
│   └── ProcessHelper.psm1        # Safe process execution, exit code verification, retry logic
├── scripts/
│   ├── 01-Base-Windows.ps1       # Long paths, dev mode, power settings, explorer options
│   ├── 02-Common-CLI.ps1         # 7-Zip, Git, jq, ripgrep, fzf, PowerShell 7, Terminal, gh
│   ├── 03-Runtimes.ps1           # Node (fnm), Python (uv), Java (Temurin 17), Gradle
│   ├── 04-Android-SDK.ps1        # Android cmdline-tools, platform-tools, build-tools, licenses
│   ├── 05-Flutter-SDK.ps1        # Google Flutter SDK, PATH, Android/Java linking, flutter doctor
│   ├── 06-Docker.ps1             # Docker Desktop, WSL2/Virtualization prerequisites, CLI PATH
│   ├── 07-IDEs-Editors.ps1       # VS Code (+ dynamic extensions for selected tools), Chrome, Postman
│   ├── 08-AI-Tools.ps1           # Antigravity CLI (agy), Antigravity IDE, Cursor, OpenAI Codex
│   ├── 08-Shell-Profile.ps1      # PowerShell profile, posh-git, PSReadLine prediction, aliases
│   └── 09-Persistence-Setup.ps1  # Git identity, SSH key generation, cache redirection (.cache)
├── tests/
│   └── Verify-Installation.ps1   # Dynamic smoke test verifying only selected tools & env vars
├── docs/
│   ├── GOLDEN_IMAGE_GUIDE.md     # Sysprep, Cloud Snapshots (Azure, AWS, GCP, Proxmox)
│   ├── DATA_PERSISTENCE.md       # How to isolate code, keys, and caches from the VM
│   └── DISASTER_RECOVERY.md      # Step-by-step checklist when a VM expires
└── README.md
```

---

## How to Run

### Method 1: Double-Click Launcher (Easiest)

Double-click **`Start-Setup.bat`** in File Explorer. It automatically prompts for Administrator rights and opens the interactive Tool Selection checklist!

### Method 2: PowerShell Terminal

Open **PowerShell as Administrator** and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\bootstrap.ps1
```

A modern graphical window will appear allowing you to check or uncheck which tools to install.

---

## Interactive Tool Selection Dialog

When launched, the tool prompts you with:
- **Checkboxes for all tools:**
  - 🤖 **AI & Autonomous Agents**: Antigravity CLI (`agy`), Antigravity IDE, Cursor AI Editor, OpenAI Codex CLI
  - 📱 **Mobile Development**: Flutter SDK, Android SDK & Tools, Java JDK 17 (Temurin)
  - 🌐 **Web & Backend Runtimes**: Node.js LTS & npm (via fnm), Python 3.12 & uv, Gradle
  - 🐳 **Containers & Cloud**: Docker Desktop
  - 💻 **Core CLI**: Git for Windows, GitHub CLI, 7-Zip, jq, ripgrep, fzf, PowerShell 7, Windows Terminal
  - 📝 **IDEs & Editors**: VS Code (+ dynamic extensions for your chosen runtimes), Notepad++
  - 🛠️ **API & Database**: Postman, DBeaver Community
  - 🌐 **Browsers**: Google Chrome (for web & Flutter web debugging)
  - ⚙️ **Windows Optimizations**: NTFS Long Paths (>260 chars), Developer Mode, Never Sleep
- **One-Click Quick Presets:**
  - `[ AI & Agents ]`: Antigravity CLI + Antigravity IDE + Cursor + Codex + Git + Node + Python + VS Code
  - `[ Mobile / Flutter ]`: Flutter + Android SDK + Java 17 + Git + VS Code + Chrome
  - `[ Full-Stack Web ]`: Node.js + Python + Docker + Git + VS Code + Chrome + Postman
  - `[ Docker & DevOps ]`: Docker + Python + Git + PowerShell 7 + VS Code
  - `[ Select All ]`: Selects all tools
  - `[ Clear All ]`: Unchecks all tools
- **Start Installation**: Begins installing only the checked items!

---

## Headless & Automated (Unattended) Execution

For automated pipelines (Azure DevOps, GitHub Actions, Packer, Golden Images, or SSH):

| Command | Action |
| :--- | :--- |
| `.\bootstrap.ps1` | **Interactive mode** (opens GUI Checklist dialog). |
| `.\bootstrap.ps1 -NoGui` | **Interactive console mode** (numbered terminal menu). |
| `.\bootstrap.ps1 -Preset "ai"` | Installs **Antigravity CLI/IDE, Cursor, Codex, Git, Node, Python, VS Code**. |
| `.\bootstrap.ps1 -Tools "antigravity, cursor, codex, flutter, node, docker"` | Installs only specified tools. |
| `.\bootstrap.ps1 -Preset "mobile"` | Installs the Flutter & Android Mobile preset unattended. |
| `.\bootstrap.ps1 -Preset "web"` | Installs the Full-Stack Web preset unattended. |
| `.\bootstrap.ps1 -Full` | Installs everything in the catalog unattended. |
| `.\bootstrap.ps1 -BaseOnly` | Only Base Windows settings and CLI tools. |
| `.\bootstrap.ps1 -GitName "Jane Doe" -GitEmail "jane@example.com"` | Passes identity parameters. |

---

## Verification & Health Check

Run the dynamic smoke test anytime to ensure your installed tools, paths, and environment variables are healthy:

```powershell
# Verifies all installed tools
.\tests\Verify-Installation.ps1

# Or verify specific tools
.\tests\Verify-Installation.ps1 -SelectedTools "antigravityIde", "flutter", "node"
```
