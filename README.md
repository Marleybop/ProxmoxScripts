# 🎵 Muse Discord Bot LXC Installer

One-click installer for the [Muse Discord Bot](https://github.com/museofficial/muse) on Proxmox VE.

---

## 🚀 Installation

```bash
bash <(curl -s https://raw.githubusercontent.com/Marleybop/ProxmoxScripts/main/muse.sh)
```

**That's it!** The interactive installer will guide you through the rest.

---

## 📋 Before You Start

You'll need a **Discord Bot Token**:

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Create New Application → Bot → Copy Token

**Optional extras:**
- **YouTube API**: [Google Cloud Console](https://console.developers.google.com) → Enable YouTube Data API v3
- **Spotify API**: [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) → Create App

---

## 🔧 Management

### Container Commands
```bash
pct status 103        # Check if container is running
pct enter 103         # Enter the container shell
pct start/stop 103    # Start or stop container
```

### Bot Commands (inside container)
```bash
systemctl status muse     # Check bot status
systemctl restart muse    # Restart the bot
journalctl -u muse -f     # Watch live logs
```

---

## 🎯 Perfect For

- First-time bot hosting
- Proxmox homelab setups  
- Quick Discord music bot deployment
- Learning LXC containers

---

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

---

<div align="center">

*Made for the Discord community* 🎶

</div>
