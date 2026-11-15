#!/usr/bin/env bash
# Miku Linux OS - build completo (Debian 12 + XFCE + tema Miku)
# Rode num Debian/Ubuntu: sudo bash build-miku-linux.sh
set -euo pipefail

[ "$EUID" -eq 0 ] || { echo "Rode com sudo."; exit 1; }

apt-get update
apt-get install -y live-build imagemagick debootstrap squashfs-tools xorriso

WORK="$PWD/miku-linux-build"
rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"

lb config \
  --distribution bookworm \
  --architectures amd64 \
  --archive-areas "main contrib non-free-firmware" \
  --binary-images iso-hybrid \
  --bootloaders "syslinux,grub-efi" \
  --debian-installer none \
  --iso-application "Miku Linux OS" \
  --iso-volume "MIKU_LINUX" \
  --bootappend-live "boot=live components quiet splash username=miku hostname=miku-linux locales=pt_BR.UTF-8 keyboard-layouts=br timezone=America/Sao_Paulo"

# ---------- Pacotes ----------
mkdir -p config/package-lists
cat > config/package-lists/miku.list.chroot <<'EOF'
xfce4
xfce4-goodies
lightdm
lightdm-gtk-greeter
network-manager-gnome
firefox-esr
firefox-esr-l10n-pt-br
thunar-archive-plugin
file-roller
pulseaudio
pavucontrol
arc-theme
papirus-icon-theme
fonts-noto
fonts-noto-color-emoji
plymouth
plymouth-themes
calamares
calamares-settings-debian
sudo
EOF

# ---------- Wallpaper Miku (turquesa) ----------
mkdir -p config/includes.chroot/usr/share/backgrounds/miku
convert -size 1920x1080 gradient:'#39C5BB-#0B3D3A' \
  -fill '#FF69B4' -draw 'circle 1500,300 1500,420' \
  -fill 'rgba(255,255,255,0.9)' -font DejaVu-Sans-Bold -pointsize 96 \
  -gravity center -annotate +0+0 'Miku Linux OS' \
  config/includes.chroot/usr/share/backgrounds/miku/miku.png

# ---------- Config padrao do XFCE (skel) ----------
X=config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
mkdir -p "$X"

cat > "$X/xsettings.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Noto Sans 10"/>
  </property>
</channel>
EOF

cat > "$X/xfwm4.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Arc-Dark"/>
  </property>
</channel>
EOF

# Wallpaper: cobre nomes de monitor comuns
{
echo '<?xml version="1.0" encoding="UTF-8"?>'
echo '<channel name="xfce4-desktop" version="1.0"><property name="backdrop" type="empty"><property name="screen0" type="empty">'
for m in monitorVirtual-1 monitorVirtual1 monitor0 monitorVGA-1 monitorHDMI-1 monitoreDP-1 monitoreDP1; do
  echo "<property name=\"$m\" type=\"empty\"><property name=\"workspace0\" type=\"empty\">
  <property name=\"image-style\" type=\"int\" value=\"5\"/>
  <property name=\"last-image\" type=\"string\" value=\"/usr/share/backgrounds/miku/miku.png\"/>
  </property></property>"
done
echo '</property></property></channel>'
} > "$X/xfce4-desktop.xml"

# ---------- Tela de login ----------
mkdir -p config/includes.chroot/etc/lightdm
cat > config/includes.chroot/etc/lightdm/lightdm-gtk-greeter.conf <<'EOF'
[greeter]
background=/usr/share/backgrounds/miku/miku.png
theme-name=Arc-Dark
icon-theme-name=Papirus-Dark
EOF

# ---------- Branding do sistema ----------
mkdir -p config/hooks/live
cat > config/hooks/live/0100-branding.hook.chroot <<'EOF'
#!/bin/sh
cat > /etc/os-release <<'OSR'
PRETTY_NAME="Miku Linux OS"
NAME="Miku Linux OS"
ID=miku
ID_LIKE=debian
VERSION_ID="1.0"
HOME_URL="https://example.com/miku-linux"
OSR
echo "Miku Linux OS \n \l" > /etc/issue
echo "miku ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/miku
chmod 440 /etc/sudoers.d/miku
EOF
chmod +x config/hooks/live/0100-branding.hook.chroot

# ---------- Build ----------
lb build 2>&1 | tee build.log

echo
echo "Pronto! ISO gerada em: $WORK"
ls -lh "$WORK"/*.iso

