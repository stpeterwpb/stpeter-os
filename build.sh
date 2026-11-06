#!/usr/bin/env bash
# St. Peter OS — system setup.
#
# You normally never run this yourself: image/make-image.sh runs it while building the
# St. Peter USB stick (IMAGE_MODE=1), and the stick installs the finished system on each PC.
#
# It can also turn an existing Debian 13 install into St. Peter OS (as root, from this folder):
#   sudo TV_NAME="St. Peter - Room 1" ./build.sh
set -euo pipefail

# ---------- Settings ----------
TV_NAME="${TV_NAME:-St. Peter TV}"      # name shown in iPhone Screen Mirroring
HOSTNAME_NEW="${HOSTNAME_NEW:-stpeter-tv}"
AIRPLAY_PIN="${AIRPLAY_PIN:-auto}"      # auto = make up a 4-digit code; or give one (e.g. 4821); no = no code
TIMEZONE="${TIMEZONE:-America/New_York}"
IMAGE_MODE="${IMAGE_MODE:-0}"           # 1 = building the USB stick's system (inside a chroot)
UPDATE_MODE="${UPDATE_MODE:-0}"         # 1 = run by bin/stpeter-update to install a new version on a TV
KIOSK_USER=stpeter
INSTALL_DIR=/opt/stpeter
# ------------------------------

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo ./build.sh"; exit 1; }
SRC="$(cd "$(dirname "$0")" && pwd)"
export DEBIAN_FRONTEND=noninteractive
log(){ echo -e "\n\033[1;33m==> $*\033[0m"; }

log "Installing packages"
pkgs=(xserver-xorg xinit openbox xdotool unclutter-xfixes curl
      uxplay avahi-daemon network-manager
      gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
      gstreamer1.0-libav gstreamer1.0-x gstreamer1.0-alsa gstreamer1.0-pulseaudio
      pipewire pipewire-pulse wireplumber
      fonts-ebgaramond fonts-hosny-amiri fonts-dejavu-core cec-utils python3 efibootmgr sudo gpgv
      libreoffice-impress-nogui poppler-utils fonts-crosextra-carlito fonts-crosextra-caladea fonts-liberation
      qemu-system-x86 qemu-system-gui qemu-utils ovmf swtpm swtpm-tools 7zip xorriso wimtools)
[ "$(dpkg --print-architecture)" = "amd64" ] && pkgs+=(gstreamer1.0-vaapi intel-media-va-driver)
[ "${PRINT_PACKAGES:-0}" = 1 ] && { echo "${pkgs[*]} firefox-esr"; exit 0; }
if [ "$UPDATE_MODE" = 1 ]; then
  # An update only installs packages that this version added
  missing=(); for p in "${pkgs[@]}"; do dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p"); done
  if [ ${#missing[@]} -gt 0 ]; then
    apt-get update && apt-get install -y --no-install-recommends "${missing[@]}"
  fi
  if dpkg -s firefox-esr >/dev/null 2>&1; then FIREFOX=firefox-esr; else FIREFOX=firefox; fi
elif [ "${SKIP_APT:-0}" = 1 ]; then
  # image/make-image.sh already installed everything (it lists these same packages)
  for p in "${pkgs[@]}" firefox-esr; do dpkg -s "$p" >/dev/null 2>&1 || { echo "missing package: $p"; exit 1; }; done
  FIREFOX=firefox-esr
else
  apt-get update
  apt-get install -y --no-install-recommends "${pkgs[@]}"
  if apt-get install -y --no-install-recommends firefox-esr; then FIREFOX=firefox-esr
  else apt-get install -y --no-install-recommends firefox; FIREFOX=firefox; fi
fi

log "Creating user $KIOSK_USER"
id "$KIOSK_USER" &>/dev/null || useradd -m -s /bin/bash "$KIOSK_USER"
for g in video audio input render kvm; do getent group "$g" >/dev/null && usermod -aG "$g" "$KIOSK_USER"; done
HOME_DIR="$(getent passwd "$KIOSK_USER" | cut -d: -f6)"

log "Installing home screen and helpers"
mkdir -p "$INSTALL_DIR/bin"
rm -rf "$INSTALL_DIR/homescreen"
cp -r "$SRC/homescreen" "$INSTALL_DIR/"
HOME_URL="file://$INSTALL_DIR/homescreen/index.html"
VERSION="$(cat "$SRC/VERSION")"
echo "$VERSION" > "$INSTALL_DIR/VERSION"
echo "window.STPETER_VERSION = '$VERSION';" > "$INSTALL_DIR/homescreen/version.js"
for f in launcher.py boot-windows fix-bootorder wifi usb set-room windows-vm stpeter-update; do install -m 755 "$SRC/bin/$f" "$INSTALL_DIR/bin/$f"; done

cat > "$INSTALL_DIR/bin/kiosk" <<EOF
#!/bin/bash
# Keeps the browser full screen on the home page; if it closes, it comes back.
# Every power-on starts with a clean browser (no one stays logged into YouTube, etc.).
for d in "\$HOME"/.mozilla/firefox/*/ "\$HOME"/.config/mozilla/firefox/*/; do
  [ -d "\$d" ] && rm -rf "\$d"cookies.sqlite* "\$d"sessionstore* "\$d"formhistory.sqlite* "\$d"storage/default "\$d"cache2
done
URL="$HOME_URL#start"            # first launch after power-on shows the language screen
while true; do
  $FIREFOX --kiosk "\$URL"
  URL="$HOME_URL"
  sleep 1
done
EOF

# Windows-in-a-VM: setup files (answer file, drivers, St. Peter customization) and its disk folder
rm -rf "$INSTALL_DIR/windows-setup"; cp -r "$SRC/windows-setup" "$INSTALL_DIR/windows-setup"
install -d -o "$KIOSK_USER" -g "$KIOSK_USER" -m 750 /var/lib/stpeter-vm

cat > "$INSTALL_DIR/bin/go-home" <<EOF
#!/bin/bash
# Home key (F12): from Windows, go back to the St. Peter screen (Windows keeps running);
# from a website, close the browser and the kiosk loop reopens it on the home screen.
if xdotool getactivewindow getwindowname 2>/dev/null | grep -q 'St Peter Windows'; then
  exec $INSTALL_DIR/bin/windows-vm hide >/dev/null
fi
pkill -f -- "--kiosk $HOME_URL" || true
EOF

cat > "$INSTALL_DIR/bin/airplay" <<'EOF'
#!/bin/bash
# AirPlay receiver (UxPlay). Restarts itself if it ever stops.
# The room's name and code live in /etc/stpeter.conf. With a code, each phone types it
# once; the TV then remembers that phone (-reg).
TV_NAME="St. Peter TV"; AIRPLAY_PIN=""
[ -r /etc/stpeter.conf ] && . /etc/stpeter.conf
OPTS=(-n "$TV_NAME" -nh -fs)
[ -n "$AIRPLAY_PIN" ] && OPTS+=(-pin "$AIRPLAY_PIN" -reg)
while true; do
  uxplay "${OPTS[@]}"
  sleep 2
done
EOF

cat > "$INSTALL_DIR/bin/cec-remote" <<'EOF'
#!/bin/bash
# TV remote over HDMI-CEC, on hardware that has it (most PCs don't; this then does nothing).
command -v cec-client >/dev/null || exit 0
ls /dev/cec* >/dev/null 2>&1 || exit 0
cec-client -o "St. Peter" 2>/dev/null | while read -r line; do
  key=$(echo "$line" | sed -n 's/.*key pressed: \([a-z ]*\) (.*/\1/p')
  case "$key" in
    up) xdotool key Up ;;   down) xdotool key Down ;;
    left) xdotool key Left ;; right) xdotool key Right ;;
    select) xdotool key Return ;;
    exit|back) xdotool key Escape alt+Left ;;
    "root menu"|"setup menu"|"contents menu") /opt/stpeter/bin/go-home ;;
  esac
done
EOF
chmod 755 "$INSTALL_DIR"/bin/*

log "Configuring Firefox (ad blocker, locked down)"
POLICY_DIR=/etc/firefox/policies
mkdir -p "$POLICY_DIR"
cat > "$POLICY_DIR/policies.json" <<EOF
{
  "policies": {
    "Homepage": { "URL": "$HOME_URL", "Locked": true, "StartPage": "homepage" },
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "DontCheckDefaultBrowser": true,
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DisableProfileImport": true,
    "DisableDeveloperTools": true,
    "DisablePrivateBrowsing": true,
    "DisableForgetButton": true,
    "BlockAboutConfig": true,
    "BlockAboutProfiles": true,
    "BlockAboutSupport": true,
    "OfferToSaveLogins": false,
    "PasswordManagerEnabled": false,
    "DownloadDirectory": "$HOME_DIR/Downloads",
    "PromptForDownloadLocation": false,
    "FirefoxHome": { "SponsoredTopSites": false, "SponsoredPocket": false, "Locked": true },
    "UserMessaging": { "WhatsNew": false, "ExtensionRecommendations": false,
                       "FeatureRecommendations": false, "SkipOnboarding": true, "MoreFromMozilla": false },
    "ExtensionSettings": {
      "*": { "installation_mode": "blocked" },
      "uBlock0@raymondhill.net": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
      }
    },
    "Preferences": {
      "browser.sessionstore.resume_from_crash": { "Value": false, "Status": "locked" },
      "media.autoplay.default": { "Value": 0, "Status": "default" },
      "media.ffmpeg.vaapi.enabled": { "Value": true, "Status": "default" },
      "browser.tabs.warnOnClose": { "Value": false, "Status": "locked" }
    }
  }
}
EOF
for d in /usr/lib/firefox-esr /usr/lib/firefox; do
  [ -d "$d" ] && mkdir -p "$d/distribution" && cp "$POLICY_DIR/policies.json" "$d/distribution/"
done

log "Setting up the TV session"
mkdir -p "$HOME_DIR/.config/openbox" "$HOME_DIR/Downloads" /etc/X11/xorg.conf.d /media/usb
cat > "$HOME_DIR/.config/openbox/autostart" <<'EOF'
unclutter --timeout 3 &
(while true; do /opt/stpeter/bin/launcher.py; sleep 1; done) &
/opt/stpeter/bin/airplay &
/opt/stpeter/bin/cec-remote &
/opt/stpeter/bin/kiosk &
EOF

# Browser shortcuts that could reach an address bar, new windows, settings, etc.
# are swallowed here, so the TV stays on the St. Peter screens.
BLOCK=""
for k in C-l A-d F6 C-k C-e C-j C-t C-n C-S-n C-S-p C-o C-h C-S-h C-b C-S-b C-S-o C-u C-S-i C-S-j C-S-k C-S-c C-S-e C-S-m F7 F10 Menu; do
  BLOCK+="    <keybind key=\"$k\"><action name=\"Execute\"><command>true</command></action></keybind>"$'\n'
done
# Two versions: rc-tv.xml (St. Peter screens: browser shortcuts blocked) and rc-windows.xml
# (Windows on screen: every shortcut works). windows-vm switches between them.
for mode in tv windows; do
  blk=""; [ "$mode" = tv ] && blk="$BLOCK"
  cat > "$HOME_DIR/.config/openbox/rc-$mode.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <keyboard>
    <keybind key="XF86HomePage"><action name="Execute"><command>/opt/stpeter/bin/go-home</command></action></keybind>
    <keybind key="F12"><action name="Execute"><command>/opt/stpeter/bin/go-home</command></action></keybind>
$blk  </keyboard>
  <mouse></mouse>
  <applications>
    <application class="*"><decor>no</decor><maximized>yes</maximized></application>
  </applications>
</openbox_config>
EOF
done
cp "$HOME_DIR/.config/openbox/rc-tv.xml" "$HOME_DIR/.config/openbox/rc.xml"

# No switching to a text console (Ctrl+Alt+F1…), no Ctrl+Alt+Backspace,
# and the screen never blanks or goes to sleep on its own.
cat > /etc/X11/xorg.conf.d/10-stpeter.conf <<'EOF'
Section "ServerFlags"
    Option "DontVTSwitch" "true"
    Option "DontZap" "true"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection
EOF
# Keyboard: English and Arabic, switched with Alt+Shift (like Windows)
cat > /etc/X11/xorg.conf.d/20-stpeter-keyboard.conf <<'EOF'
Section "InputClass"
    Identifier "St. Peter keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "us,ara"
    Option "XkbOptions" "grp:alt_shift_toggle"
EndSection
EOF

echo 'exec openbox-session' > "$HOME_DIR/.xinitrc"
cat > "$HOME_DIR/.bash_profile" <<'EOF'
# Start St. Peter OS on the TV screen
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  clear; setterm --cursor off 2>/dev/null
  exec startx -- -nolisten tcp >/dev/null 2>&1
fi
EOF
touch "$HOME_DIR/.hushlogin"    # no "Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY" on the TV
chown -R "$KIOSK_USER": "$HOME_DIR"
# The TV account can't change the home screen files; only an admin can.
chown -R root:root "$INSTALL_DIR/homescreen" "$INSTALL_DIR/bin"

log "Auto-login on the TV screen"
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear --noissue %I \$TERM
EOF
systemctl set-default multi-user.target

log "Clock and network"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime && echo "$TIMEZONE" > /etc/timezone
systemctl enable NetworkManager avahi-daemon
systemctl enable systemd-timesyncd 2>/dev/null || true

log "Setting up the switch to Windows and the Wi-Fi menu"
cat > /etc/sudoers.d/stpeter <<EOF
$KIOSK_USER ALL=(root) NOPASSWD: $INSTALL_DIR/bin/boot-windows, $INSTALL_DIR/bin/wifi, $INSTALL_DIR/bin/usb, $INSTALL_DIR/bin/stpeter-update confirm *, /usr/bin/systemctl start --no-block stpeter-update.service
EOF
chmod 440 /etc/sudoers.d/stpeter
visudo -cf /etc/sudoers.d/stpeter
cat > /etc/systemd/system/stpeter-bootorder.service <<EOF
[Unit]
Description=Keep St. Peter OS first in the boot order
[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/bin/fix-bootorder
[Install]
WantedBy=multi-user.target
EOF
systemctl enable stpeter-bootorder.service
# The PC's built-in Windows key (if it came with Windows) is handed to the Windows VM so it activates
cat > /etc/systemd/system/stpeter-winkey.service <<EOF
[Unit]
Description=Give the Windows VM this PC's built-in Windows key
[Service]
Type=oneshot
ExecStart=/bin/sh -c '[ -r /sys/firmware/acpi/tables/MSDM ] && install -o $KIOSK_USER -m 600 /sys/firmware/acpi/tables/MSDM /var/lib/stpeter-vm/MSDM.bin || true'
[Install]
WantedBy=multi-user.target
EOF
systemctl enable stpeter-winkey.service

# Start quietly: no boot menu, no scrolling text
if [ -f /etc/default/grub ]; then
  sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3"/' /etc/default/grub
  if grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub; then
    sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
  else
    echo 'GRUB_TIMEOUT_STYLE=hidden' >> /etc/default/grub
  fi
  grep -q '^GRUB_DISABLE_OS_PROBER=' /etc/default/grub || echo 'GRUB_DISABLE_OS_PROBER=true' >> /etc/default/grub
fi

log "Updates (checked at every start-up, from GitHub)"
install -D -m 644 "$SRC/update/key.gpg" /usr/share/stpeter/update-key.gpg
echo "UPDATE_REPO=$(tr -d '[:space:]' < "$SRC/update/repo.txt")" > /etc/stpeter-update.conf
cat > /etc/systemd/system/stpeter-update.service <<EOF
[Unit]
Description=Look for a newer St. Peter OS and install it
Wants=network-online.target
After=network-online.target NetworkManager.service
[Service]
Type=simple
ExecStart=$INSTALL_DIR/bin/stpeter-update check
Nice=10
[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/stpeter-update-boot.service <<EOF
[Unit]
Description=Undo a St. Peter OS update that didn't start properly
Before=getty@tty1.service
[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/bin/stpeter-update boot
TimeoutStartSec=10min
[Install]
WantedBy=multi-user.target
EOF
systemctl enable stpeter-update.service stpeter-update-boot.service
if [ "$UPDATE_MODE" != 1 ]; then
  # keep this version's source folder: an update can go back to it
  rm -rf /var/lib/stpeter-update/current; mkdir -p /var/lib/stpeter-update
  cp -r "$SRC" /var/lib/stpeter-update/current
  rm -rf /var/lib/stpeter-update/current/image/*.img* /var/lib/stpeter-update/current/.git
fi

echo "St. Peter OS $VERSION (built $(date +%F))" > /etc/stpeter-release

if [ "$IMAGE_MODE" = 1 ]; then
  # The USB installer names the room and sets up the boot order on each PC.
  log "System ready for the USB image"
  exit 0
fi

# ---------- Existing Debian install: finish here ----------
case "$AIRPLAY_PIN" in
  no|"") PIN="" ;;
  auto|yes) PIN="$(shuf -i 1000-9999 -n 1)" ;;
  [0-9][0-9][0-9][0-9]) PIN="$AIRPLAY_PIN" ;;
  *) echo "AIRPLAY_PIN must be auto, no, or 4 digits"; exit 1 ;;
esac
"$INSTALL_DIR/bin/set-room" / "$TV_NAME" "$PIN" "$HOSTNAME_NEW"
hostname "$HOSTNAME_NEW" 2>/dev/null || true
"$INSTALL_DIR/bin/fix-bootorder" || true
command -v update-grub >/dev/null && update-grub || true
if "$INSTALL_DIR/bin/boot-windows" --check; then echo "Windows found: the Desktop button is ready."
else echo "NOTE: Windows was not found on this PC. The Desktop button will say so."; fi
[ -n "$PIN" ] && echo "AirPlay code for \"$TV_NAME\": $PIN (also shown in the AirPlay pop-up on the TV)"
log "Done! Reboot to start St. Peter OS:  sudo reboot"
