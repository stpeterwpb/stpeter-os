#!/usr/bin/env bash
# Builds the St. Peter USB stick image: st-peter-usb.img.xz
#
# Write that file to any USB stick (8 GB or more) with balenaEtcher. Then, on each classroom PC:
# plug it in, start the PC from it, and wait. See README.md.
#
# Needs: a Linux machine with mmdebstrap, sgdisk (gdisk), dosfstools, mtools, e2fsprogs, xz-utils,
# internet access to deb.debian.org, and root. Run from anywhere:  sudo image/make-image.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(dirname "$HERE")"
WORK="${WORK:-$HERE/work}"
OUT="${OUT:-$HERE/st-peter-usb.img}"
SUITE=trixie
MIRROR=https://deb.debian.org/debian
SECURITY=https://security.debian.org/debian-security
KEYRING="${KEYRING:-/usr/share/keyrings/debian-archive-keyring.gpg}"
ESP_MB=300

log(){ echo -e "\n\033[1;33m==> $*\033[0m"; }
[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }

# Drivers are for Intel mini PCs (N100/N150) with Intel, Realtek or MediaTek Wi-Fi. For AMD PCs or
# Qualcomm/Broadcom Wi-Fi add: amd64-microcode firmware-amd-graphics firmware-atheros firmware-brcm80211
# (kept out so the stick image stays small enough to download easily).
# Everything the TVs need, installed here so the build never depends on apt inside the chroot.
APP_PKGS=$(PRINT_PACKAGES=1 bash "$SRC/build.sh" | tail -n1)
SYS_PKGS="systemd-sysv udev dbus kbd console-setup locales ca-certificates
  linux-image-amd64 initramfs-tools grub-efi-amd64 grub-efi-amd64-signed shim-signed efibootmgr
  intel-microcode
  firmware-iwlwifi firmware-realtek firmware-mediatek
  firmware-intel-graphics firmware-intel-sound firmware-sof-signed
  wireless-regdb wpasupplicant
  sudo dosfstools gdisk e2fsprogs rsync parted util-linux systemd-timesyncd unattended-upgrades nano less"
INCLUDE=$(echo $SYS_PKGS $APP_PKGS | tr ' ' ',')

log "Building the St. Peter OS system (Debian 13 \"$SUITE\")"
rm -rf "$WORK"; mkdir -p "$WORK"
ROOT="$WORK/rootfs"; mkdir -p "$ROOT"
mmdebstrap ${MMDEBSTRAP_EXTRA:-} --variant=minbase --include="$INCLUDE" --keyring="$KEYRING" \
  --aptopt='APT::Install-Recommends "false"' \
  --dpkgopt='path-exclude=/usr/share/doc/*' --dpkgopt='path-include=/usr/share/doc/*/copyright' \
  --dpkgopt='path-exclude=/usr/share/man/*' --dpkgopt='path-exclude=/usr/share/info/*' \
  --dpkgopt='path-exclude=/usr/share/locale/*' --dpkgopt='path-include=/usr/share/locale/en*' \
  --dpkgopt='path-include=/usr/share/locale/ar*' --dpkgopt='path-include=/usr/share/locale/locale.alias' \
  --essential-hook='echo "grub-efi-amd64 grub2/update_nvram boolean false" | chroot "$1" debconf-set-selections' \
  --essential-hook='echo "grub-efi-amd64 grub2/force_efi_extra_removable boolean false" | chroot "$1" debconf-set-selections' \
  --essential-hook='echo "locales locales/default_environment_locale select C.UTF-8" | chroot "$1" debconf-set-selections' \
  --customize-hook='mkdir -p "$1/tmp/src"' \
  --customize-hook="copy-in $SRC/build.sh $SRC/VERSION $SRC/README.md $SRC/bin $SRC/homescreen $SRC/windows-setup $SRC/update /tmp/src" \
  --customize-hook='chroot "$1" env IMAGE_MODE=1 SKIP_APT=1 bash /tmp/src/build.sh' \
  --customize-hook='rm -rf "$1/tmp/src"' \
  --customize-hook='echo COMPRESS=xz > "$1/etc/initramfs-tools/conf.d/stpeter-compress"' \
  --customize-hook='chroot "$1" update-initramfs -u -k all' \
  "$SUITE" "$ROOT/" \
  "deb $MIRROR $SUITE main contrib non-free non-free-firmware" \
  "deb $MIRROR $SUITE-updates main contrib non-free non-free-firmware" \
  "deb $SECURITY $SUITE-security main contrib non-free non-free-firmware"

log "Adding the installer"
install -D -m 755 "$HERE/installer/stpeter-install" "$ROOT/opt/stpeter/installer/stpeter-install"
install -m 644 "$HERE/installer/stpeter-installer.target" "$HERE/installer/stpeter-installer.service" "$ROOT/etc/systemd/system/"
# Security updates for Firefox etc. install themselves on the TVs (Debian's defaults: security only).
cat > "$ROOT/etc/apt/apt.conf.d/20auto-upgrades" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
# A new kernel from those updates gets added to the start-up menu.
cat > "$ROOT/etc/kernel/postinst.d/zz-stpeter-grub" <<'EOF'
#!/bin/sh
[ -e /boot/grub/grub.cfg ] && command -v update-grub >/dev/null && update-grub >/dev/null 2>&1 || true
EOF
chmod 755 "$ROOT/etc/kernel/postinst.d/zz-stpeter-grub"
# Each PC gets its own identity on first start
: > "$ROOT/etc/machine-id"; rm -f "$ROOT/var/lib/dbus/machine-id"
rm -f "$ROOT/etc/hostname"; echo "stpeter-tv" > "$ROOT/etc/hostname"
printf '127.0.0.1\tlocalhost\n::1\t\tlocalhost ip6-localhost ip6-loopback\n' > "$ROOT/etc/hosts"
: > "$ROOT/etc/fstab"
rm -rf "$ROOT/var/cache/apt/archives/"*.deb "$ROOT/var/lib/apt/lists/"* "$ROOT/var/log/"*.log "$ROOT/tmp/"*

KVER=$(ls "$ROOT/boot" | sed -n 's/^vmlinuz-//p' | sort -V | tail -n1)
[ -n "$KVER" ] || { echo "no kernel in the image"; exit 1; }
echo "kernel $KVER"

log "Trimming firmware that PCs never use (keeps the download small)"
FW="$ROOT/usr/lib/firmware"
# MediaTek: router chips (mt7915/7916/7981/7986/7996) and ARM tablet chips (mt8xxx); PC Wi-Fi stays.
rm -rf "$FW"/mediatek/mt7996 "$FW"/mediatek/mt798[0-9]* "$FW"/mediatek/mt791[56]* "$FW"/mediatek/mt8* "$FW"/mediatek/mt7988*
# Intel Wi-Fi: keep, for each chip, the newest firmware version this kernel can load.
chroot "$ROOT" /sbin/modinfo -k "$KVER" -F firmware iwlwifi > "$WORK/iwl-wanted.txt"
python3 - "$FW" "$WORK/iwl-wanted.txt" <<'PY'
import os, re, sys
fw, wanted = sys.argv[1], open(sys.argv[2]).read().split()
pat = re.compile(r"^(iwlwifi-.+)-(\d+)\.ucode$")
maxv = {m.group(1): int(m.group(2)) for m in map(pat.match, wanted) if m}
have = {}
for f in os.listdir(fw):
    m = pat.match(f)
    if m:
        have.setdefault(m.group(1), []).append((int(m.group(2)), f))
# Wi-Fi chips from before 2017 (no N100/N150 PC has them)
OLD = re.compile(r"^iwlwifi-(100|1000|105|135|2000|2030|3160|3168|3945|4965|5000|5150|6000|6000g2a|6000g2b|6050|7260|7265|7265D|8000C|8265)$")
removed = 0
for base, files in have.items():
    if OLD.match(base):
        keep = set()
    elif base in maxv:
        ok = sorted(v for v in files if v[0] <= maxv[base])
        keep = {ok[-1][1]} if ok else set()
    else:   # named at run time by the driver: keep the two newest
        keep = {f for _, f in sorted(files)[-2:]}
    for v, f in files:
        if f not in keep:
            removed += os.path.getsize(os.path.join(fw, f)); os.remove(os.path.join(fw, f))
print(f"iwlwifi: removed {removed // 1048576} MB of unused versions")
PY
# Libraries only an unused GStreamer plugin (ONNX AI models) and imlib2's PostScript loader need
L="$ROOT/usr/lib/x86_64-linux-gnu"
rm -f "$L"/libdnnl.so* "$L"/libonnxruntime* "$L"/libonnx.so* "$L"/libonnx_proto.so* "$L"/gstreamer-1.0/libgstonnx.so \
      "$L"/libgs.so* "$L"/libspectre.so* "$L"/imlib2/loaders/ps.so
find "$ROOT/usr" -name __pycache__ -type d -prune -exec rm -rf {} +

log "Making the stick's start-up partition (readable on any computer)"
ESPDIR="$WORK/esp"; mkdir -p "$ESPDIR/EFI/BOOT" "$ESPDIR/EFI/debian"
cp "$ROOT/usr/lib/shim/shimx64.efi.signed" "$ESPDIR/EFI/BOOT/BOOTX64.EFI"
cp "$ROOT/usr/lib/shim/mmx64.efi.signed" "$ESPDIR/EFI/BOOT/mmx64.efi"
cp "$ROOT/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed" "$ESPDIR/EFI/BOOT/grubx64.efi"
cat > "$ESPDIR/EFI/debian/grub.cfg" <<EOF
# St. Peter USB stick: start the automatic installer
set timeout=0
search --no-floppy --label STPETER-LIVE --set=root
linux /boot/vmlinuz-$KVER root=LABEL=STPETER-LIVE ro quiet loglevel=3 systemd.unit=stpeter-installer.target systemd.gpt_auto=0 systemd.show_status=0 stpeter.install
initrd /boot/initrd.img-$KVER
boot
EOF
cp "$ESPDIR/EFI/debian/grub.cfg" "$ESPDIR/EFI/BOOT/grub.cfg"
printf '%s\r\n' \
  "# St. Peter USB stick settings. You can open and change this file on any computer." \
  "#" \
  "# Setup asks for each classroom's name (e.g. Pre-K and K) and puts this in front of it:" \
  "NAME_PREFIX=St Peter - " \
  "#" \
  "# AirPlay code: auto = a different 4-digit code for each room; or one code for all rooms (e.g. 4821); or no" \
  "AIRPLAY_CODE=auto" > "$ESPDIR/St Peter settings.txt"
printf '%s\r\n' \
  "ST. PETER USB STICK" "" \
  "To set up a classroom PC:" \
  "  1. Plug this stick into the PC." \
  "  2. Turn the PC on and press the start-up menu key right away (often F7, F11, F12 or Esc)." \
  "  3. Pick the USB stick. Type the classroom's name (e.g. Pre-K and K) and press Enter." \
  "     Setup then runs by itself (about 10 minutes)." \
  "  4. When the screen says so, take the stick out. The PC restarts into St. Peter OS." "" \
  "Which drive: an empty one if the PC has one (Windows on another drive is left alone)." \
  "Otherwise you pick the drive from a menu. A drive is only erased after you type ERASE." \
  "Each room's name and AirPlay code are listed in 'Installed rooms.txt' on this stick." \
  > "$ESPDIR/READ ME.txt"
ESP_IMG="$WORK/esp.img"; rm -f "$ESP_IMG"
mkfs.vfat -F 32 -n STPETER -C "$ESP_IMG" $((ESP_MB * 1024)) >/dev/null
mcopy -i "$ESP_IMG" -s "$ESPDIR/"* ::/

log "Making the stick's system partition"
ROOT_IMG="$WORK/root.img"; rm -f "$ROOT_IMG"
used_mb=$(( $(du -sxm "$ROOT" | cut -f1) ))
root_mb=$(( used_mb * 112 / 100 + 300 ))
mkfs.ext4 -q -L STPETER-LIVE -m 0 -d "$ROOT" "$ROOT_IMG" "${root_mb}M"

log "Putting the stick image together"
rm -f "$OUT"
esp_sectors=$((ESP_MB * 2048)); root_sectors=$((root_mb * 2048))
truncate -s $(( (2048 + esp_sectors + root_sectors + 2048) * 512 )) "$OUT"
sgdisk -Z "$OUT" >/dev/null 2>&1 || true
sgdisk -n1:2048:+${esp_sectors} -t1:ef00 -c1:STPETER \
       -n2:$((2048 + esp_sectors)):+${root_sectors} -t2:8300 -c2:STPETER-LIVE "$OUT" >/dev/null
dd if="$ESP_IMG" of="$OUT" bs=4M oflag=seek_bytes seek=$((2048 * 512)) conv=notrunc,sparse status=none
dd if="$ROOT_IMG" of="$OUT" bs=4M oflag=seek_bytes seek=$(( (2048 + esp_sectors) * 512 )) conv=notrunc,sparse status=none
sgdisk -v "$OUT" | tail -n1

if [ "${NO_XZ:-0}" != 1 ]; then
  log "Compressing (this takes a while)"
  rm -f "$OUT.xz"; xz -T0 -9 -k "$OUT"
  ls -lh "$OUT.xz"
fi
log "Done: $OUT"
