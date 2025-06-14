🎵 Muse Discord Bot LXC Installer
Automated installer for the Muse Discord Bot on Proxmox VE with an interactive GUI.
🚀 Quick Start
Run this command on your Proxmox host as root:
bashbash <(curl -s https://raw.githubusercontent.com/Marleybop/ProxmoxScripts/main/muse-lxc.sh)
✨ What it does

Creates a new LXC container
Installs Node.js and dependencies
Downloads and configures Muse
Sets up as a systemd service
Shows Discord invite link when ready

📋 What you need

Proxmox VE host
Discord Bot Token (get one here)
Optional: YouTube API key, Spotify credentials

## 📱 GUI Screenshots

The installer features a complete interactive interface:

- **Welcome Screen** - Overview of installation process
![image](https://github.com/user-attachments/assets/1f6c8319-eba1-4f9f-8df7-3abba8b2121d)

- **Configuration Forms** - Easy input with validation
  ![image](https://github.com/user-attachments/assets/79115459-a421-42cc-a832-3e64d2b70db1)

- **Confirmation Dialogs** - Review settings before proceeding
![image](https://github.com/user-attachments/assets/fb7436c0-1378-410c-bce6-23e66e38aab4)

- **Progress Bar** - Visual installation progress
![image](https://github.com/user-attachments/assets/03b4be11-36f7-4126-8343-88cbafdf121c)


🔧 After installation
Manage container
bashpct enter [CONTAINER_ID]     # Enter container
pct status [CONTAINER_ID]    # Check status
Manage bot service
bashsystemctl status muse       # Check service
journalctl -u muse -f       # View logs
systemctl restart muse      # Restart bot
🐛 Issues?
Open an issue with your error message and I'll help you out!

Simple automation for the Discord community 🎶
