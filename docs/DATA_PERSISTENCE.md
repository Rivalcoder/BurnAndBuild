# Data Persistence and Isolation Strategy for Disposable VMs

When working with disposable or free-trial VMs, the operating system drive (`C:`) must be assumed **100% ephemeral**. The moment an account or trial expires, the VM can vanish.

---

## 1. The Separation of Concerns Matrix

| Component | Lifespan | Storage Location | Recovery Mechanism |
| :--- | :--- | :--- | :--- |
| **OS & System Tweaks** | Ephemeral | `C:\Windows`, Registry | Automated via `01-Base-Windows.ps1` or Golden Image |
| **Tool Binaries (Java, Node, Android)** | Ephemeral | `C:\Program Files`, `C:\Android` | Automated via `bootstrap.ps1` or Golden Image |
| **Source Code & Git Repos** | **Persistent** | Remote Git Host (GitHub / GitLab) + Secondary Disk | `git clone` or reattaching secondary data disk |
| **Build Caches (Gradle, npm, pip)** | Persistent (Perf) | Secondary Disk (`D:\Workspace\.cache`) | Retained on persistent volume |
| **Credentials & SSH Keys** | **Persistent** | Password Manager CLI / Encrypted Vault | Injected via Bitwarden / 1Password / SSH-Agent |

---

## 2. Three Architecture Patterns for Persistence

### Pattern 1: Detachable Secondary Cloud Data Disk (Fastest & Most Seamless)
In cloud providers (Azure, AWS, GCP), the OS disk is tied to the VM lifecycle, but **Data Disks** can exist independently.

1. Create a 64GB–128GB Managed Data Disk named `dev-workspace-disk`.
2. Format as NTFS / ReFS and assign drive letter `D:`.
3. Put all repositories, emulator AVDs, and caches on `D:\Workspace`.
4. **When the VM expires:**
   - Detach `dev-workspace-disk` from the expiring VM.
   - Provision fresh VM.
   - Attach `dev-workspace-disk` to the fresh VM.
   - All your files, git branches, and caches are already mounted without downloading anything!

### Pattern 2: Pure Git & Cloud Sync (Zero Cloud Cost)
If your trial accounts are completely isolated (e.g. creating brand new accounts with new email addresses):

1. **Rule of Thumb**: Never leave unpushed commits on the VM at the end of the day.
   - Use feature branches: `git checkout -b wip-feature && git push origin wip-feature`.
2. **SSH Key Management**:
   - Store your encrypted SSH private key in your password manager (Bitwarden, 1Password, or KeePassXC).
   - On the new VM, run `07-Persistence-Setup.ps1` to generate a key or paste your private key to `~/.ssh/id_ed25519`.
3. **Environment Secrets**:
   - Keep `.env` files in encrypted vaults, never hardcoded on disk.

### Pattern 3: Automated Cloud Backup via Rclone
For assets that cannot be placed in Git (datasets, test APKs, large binary media):

1. Install `rclone` (`winget install Rclone.Rclone`).
2. Configure remote backend (Google Drive, OneDrive, S3, or Backblaze B2):
   ```powershell
   rclone config
   ```
3. Backup workspace command:
   ```powershell
   rclone sync "C:\Workspace" "remote:dev-workspace-backup" --exclude ".git/**" --exclude "node_modules/**"
   ```
4. Restore on fresh VM:
   ```powershell
   rclone sync "remote:dev-workspace-backup" "C:\Workspace"
   ```

---

## 3. Cache Redirection Benefits

Gradle, npm, and pip often download gigabytes of dependencies repeatedly. By redirecting them:

- `GRADLE_USER_HOME = D:\Workspace\.cache\.gradle`
- `PIP_CACHE_DIR = D:\Workspace\.cache\pip-cache`

Builds on a newly attached workspace execute **instantly** without waiting for network re-downloads!
