# IDM-Reset

<div align="center">

![Version Badge](https://img.shields.io/badge/version-3.2.0-blue)
![Platform](https://img.shields.io/badge/platform-Windows-0078D4)
![Python](https://img.shields.io/badge/python-3.6+-green)
![License](https://img.shields.io/badge/license-MIT-green)

**⚡ Professional Windows registry cleaner - Remove IDM & CA7 artifacts instantly**

[Features](#-features) • [Quick Start](#-quick-start) • [Usage](#-usage-guide) • [Safety](#-⚠️-safety-warning)

</div>

---

## 📋 About

**IDM-Reset** is a professional Windows utility that thoroughly removes Internet Download Manager (IDM) and related malware artifacts from your system. It scans your registry (`HKEY_USERS`) for CLSID entries ending with `CA7` - commonly associated with browser hijackers, adware, and unwanted toolbars.

This tool provides two implementations:
- 🐍 **Python** version (recommended for developers)
- 🔵 **PowerShell** version (for quick execution)

Both versions automatically elevate to Administrator privileges and provide safe, interactive deletion.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔍 **Smart Scanning** | Only finds entries that END with CA7 (case-insensitive) |
| 🛡️ **Safe Deletion** | Interactive confirmation before removing each entry |
| 📋 **Detailed Reports** | Shows registry path, subkeys, and data before deletion |
| ⚡ **Auto-Elevation** | Automatically requests Administrator privileges if needed |
| 🎯 **HKU Only** | Scans only `HKEY_USERS` for maximum safety |
| 💨 **Fast Performance** | Minimal system impact, runs quickly |
| 📊 **Colorized Output** | Easy-to-read formatted console output |
| 🔐 **No Network Access** | Works 100% offline - your data stays safe |

---

## ⚙️ Requirements

### System Requirements
- ✅ Windows 10 / Windows 11 / Windows Server 2016+
- ✅ Administrator access required
- ✅ PowerShell 5.0+

### Python Version Requirements
- Python 3.6 or higher
- pip package manager

### Dependencies
- `click` >= 8.0.0 (CLI framework)
- `pywin32` >= 227 (Windows registry access)

---

## 🚀 Quick Start (One Command!)

### Option 1: Automatic Setup (Recommended)

Copy and paste this command in **PowerShell** (as Administrator):

```powershell
irm https://raw.githubusercontent.com/AliHamza-Coder/idm-reset/main/setup.ps1 | iex
```

This automatically:
- ✅ Downloads the project
- ✅ Sets up Python virtual environment
- ✅ Installs required dependencies
- ✅ Creates an `idm-reset-tool` command for easy access
- ✅ Creates a desktop shortcut

Then run: **`idm-reset-tool`** from any PowerShell window!

### Option 2: Manual Setup

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/AliHamza-Coder/idm-reset.git
   cd idm-reset
   ```

2. **Create virtual environment:**
   ```powershell
   python -m venv myenv
   .\myenv\Scripts\Activate.ps1
   ```

3. **Install dependencies:**
   ```powershell
   pip install -r requirements.txt
   ```

4. **Run the tool:**
   ```powershell
   # Python version
   python main.py

   # Or PowerShell version (no dependencies needed)
   .\main.ps1
   ```

---

## 📖 Usage Guide

### Python Version

```bash
python main.py [OPTIONS]

Options:
  --scan          Just scan, don't delete
  --delete        Scan and delete found entries
  --force         Skip confirmation prompts
  --verbose       Show detailed logging info
  --help          Show help message
```

**Example Usage:**

```powershell
# Scan only (safe, shows what will be removed)
python main.py --scan

# Scan and delete with confirmations (interactive)
python main.py --delete

# Force delete without prompts (use with caution!)
python main.py --delete --force
```

### PowerShell Version

Simply run the script - it presents an interactive menu:

```powershell
.\main.ps1
```

```
1. Scan for CA7 entries
2. Scan and Delete CA7 entries
0. Exit
```

Or with force flag:

```powershell
.\main.ps1 -Force
```

---

## 🔍 What Gets Removed

The tool identifies and removes:

- ❌ **Browser hijacker traces** - CA7-ending CLSID registry entries
- ❌ **Unwanted toolbars** - Associated with malware installations
- ❌ **Adware components** - Registry entries from adware bundles
- ❌ **IDM artifacts** - Internet Download Manager junk entries
- ❌ **Similar malware** - Anything matching the CA7 signature

**What stays safe:**
- ✅ System registry entries
- ✅ Legitimate software entries
- ✅ Windows core components

---

## ⚠️ Safety Warning

⚠️ **Registry editing can be dangerous if done incorrectly.**

- 🔴 **Always backup your registry before running this tool**
- 🔴 **Only run as Administrator**
- 🔴 Review entries carefully before deletion
- 🔴 If something goes wrong, restore from backup

### How to Backup Registry

```powershell
# Open Registry Editor
regedit

# Menu: File > Export
# Save full registry to safe location
```

---

## 🆘 Troubleshooting

### "Administrator privileges required"
- Right-click PowerShell → **Run as Administrator**
- Or use the setup script which auto-elevates

### "ModuleNotFoundError: No module named 'winreg'"
- You're not on Windows (this tool is Windows-only)
- Or Python installation is corrupted

### "Permission denied" while deleting
- Another program is locking the registry
- Try in Safe Mode with Command Prompt
- Close antivirus software temporarily

### Registry entries appear but won't delete
- Some entries are system-protected
- Close all applications and try again
- Restart computer and retry

---

## 📊 Scan Results Example

```
=================================================================
         CA7 REGISTRY CLEANER v3.2.0
         (HKU Only - Ends with CA7)
         [RUNNING AS ADMINISTRATOR]
=================================================================

Scanning: HKEY_USERS
Found 3 suspicious entries:

[1] HKEY_USERS\S-1-5-21-123456789-1234567890-123456789-1001\Software\Classes\CLSID\{ABC123-ABC7}
    Subkeys: 2
    Size: ~15 KB

[2] HKEY_USERS\S-1-5-21-987654321-0987654321-987654321-1002\Software\Classes\CLSID\{XYZ789-XYZ7}
    Subkeys: 1
    Size: ~8 KB

[3] HKEY_USERS\S-1-5-21-555555555-5555555555-555555555-1003\Software\Classes\CLSID\{DEF456-DEF7}
    Subkeys: 0
    Size: ~3 KB

Total: 3 entries found (26 KB) | Would free: 26 KB
```

---

## 💻 Screenshots

### Safe Scanning Mode
```
[✓] Scan Complete
[✓] Found 5 CA7 entries
[✓] Ready for safe removal
```

### Interactive Deletion
```
Delete this entry? {GUID-ending-with-CA7}
[Y] Yes  [N] No  [S] Skip  [Q] Quit
```

---

## 📦 What's Included

```
idm-reset/
├── main.py              # Python implementation (feature-rich)
├── main.ps1             # PowerShell implementation (lightweight)
├── setup.ps1            # Automatic installer/updater
├── requirements.txt     # Python dependencies
├── README.md            # This file
├── LICENSE              # MIT License
└── .gitignore           # Git ignore rules
```

---

## 🤝 Contributing

Found a bug? Have an improvement? [Open an Issue](https://github.com/AliHamza-Coder/idm-reset/issues)

---

## 📄 License

This project is licensed under the **MIT License** - see [LICENSE](LICENSE) file for details.

---

## ⭐ Support

If this tool helped you clean your registry, please:
- ⭐ **Star this repository** on GitHub
- 📢 Share it with others who need it
- 👨‍💬 Provide feedback or report issues

---

## 🔗 Links

- **GitHub**: https://github.com/AliHamza-Coder/idm-reset
- **Report Bug**: https://github.com/AliHamza-Coder/idm-reset/issues
- **Request Feature**: https://github.com/AliHamza-Coder/idm-reset/issues

---

<div align="center">

**Made with ❤️ by AliHamza-Coder**

*IDM-Reset v3.2.0 | February 2026*

</div>
