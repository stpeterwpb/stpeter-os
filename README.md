# St. Peter OS

A simple, ad-free TV system for the classrooms of St. Peter, Seal of the Martyrs Coptic Orthodox Church, West Palm Beach. It uses the look of the church website, stpeterwpb.org: maroon and gold, Cinzel and EB Garamond, and the church's icon of St. Peter.

Each classroom TV gets a small PC running St. Peter OS. Windows 11, when you want it, runs **inside** St. Peter OS: the **Desktop** button opens it in a few seconds, and **F12** comes back.

| On the TV | What happens |
|---|---|
| Turn the PC on | "Choose your language · اختار اللغة", then the home screen |
| **Desktop** button | Opens Windows (or, the first time, the "Set up Windows" menu) |
| **F12** or **Back to St. Peter** in Windows | Back to the home screen |
| Turn the PC off and on | Always comes back to St. Peter OS, with a clean browser |

## What's on the screen

- The church name, the time, and one line with the date, the Coptic date, and today's feast or fast.
- Five big buttons: **AirPlay, Coptic Reader, Desktop** (Windows), **Whiteboard** and **YouTube**.
- At the bottom: **Wi-Fi** (shows the network, or "Connect to Wi-Fi") and a button to switch between English and Arabic (Egyptian dialect, fully right-to-left).

## What you need (per classroom)

Any ordinary PC works; it doesn't have to be new. One drive is enough.

| | Minimum | For Windows inside too |
|---|---|---|
| Processor | 64-bit Intel or AMD, about 2015 or newer | Intel i3/i5/i7 (2017+) or Ryzen, with virtualization |
| Memory | 4 GB (8 GB better) | 16 GB |
| Storage | 32 GB | 128 GB or more |
| Start-up | UEFI (almost every PC since 2013) | same |

Plus HDMI to the TV, Wi-Fi or a network cable, and a **wireless keyboard + touchpad**. Intel graphics are the safest choice.

**Cheap option:** used business mini PCs, e.g. **Dell OptiPlex Micro 7050+**, **Lenovo ThinkCentre Tiny M710q/M720q+**, **HP EliteDesk 800 Mini G3+**, with an i5 and 8–16 GB (often under $150 used). Some have no Wi-Fi card: use a cable or a USB Wi-Fi adapter.

**Not suitable:** old thin clients (e.g. Dell Wyse): too little memory and storage, too slow for video, and they don't start the UEFI way.

Once, for all PCs: a **USB stick**, 8 GB or bigger (and a second one for the Windows installer, if you want Windows).

## Setup

### Once: make the St. Peter USB stick
1. Put all the downloaded pieces (`st-peter-usb.img.xz.part1`, `part2`, …) and **`Join St Peter image.cmd`** in one folder on a Windows PC, and double-click **`Join St Peter image.cmd`**. It puts them back together as `st-peter-usb.img.xz` and checks that nothing got damaged. (On a Mac: `cat st-peter-usb.img.xz.part* > st-peter-usb.img.xz` in Terminal.)
2. Download **balenaEtcher** (free).
3. Choose **Flash from file** → `st-peter-usb.img.xz`, pick the USB stick, and click **Flash**.

The same stick sets up all five PCs.

### For each PC (about 10 minutes)
1. Connect the PC to the TV, with the keyboard.
2. Plug in the USB stick and turn the PC on. Right away, tap the **start-up menu key**: usually **F7, F11, F12 or Esc** (it's often shown on screen for a second).
3. Pick the USB stick. If the PC's only drive has Windows (or anything else) on it, setup warns that it will be **erased**; type `ERASE` and press Enter to go on, or just Enter to stop. Then setup asks for the **classroom's name**: type it (for example `Pre-K and K`) and press **Enter**. The TV becomes **St Peter - Pre-K and K**. It shows the AirPlay code; press **Enter** again and setup runs by itself.
4. When it says **"Take the USB stick out now"**, pull it out. The PC restarts into St. Peter OS.
5. Choose a language. The **Wi-Fi menu** opens by itself: pick the church network and type its password once.

The classroom name is what teachers see on their iPhone under Screen Mirroring. Every room's name and AirPlay code is written to **`Installed rooms.txt`** on the stick, which you can open on any computer.

**Which drive it uses:** a drive that already has St. Peter OS (reinstall, keeps the room name); otherwise an empty drive (if the PC has a second, empty SSD, Windows on the first one is left alone); otherwise, on a PC with only one drive, that drive; on a PC with several drives, a menu shows each drive (name, size, and whether it has Windows on it) and you press its number. A drive that isn't empty is only erased after you type `ERASE`; the other drives are never touched.

### Changing a room's name, or the AirPlay codes
- **Rename a room:** run the stick on that PC again. It shows the current name; type a new one (or just press Enter to keep it). This also reinstalls the system, which is the way to fix any PC that misbehaves. The AirPlay code stays the same.
- **Settings for all rooms:** open **`St Peter settings.txt`** on the stick on any computer:
  - `NAME_PREFIX=` what goes in front of every class name (`St Peter - `)
  - `AIRPLAY_CODE=` `auto` (a different code per room), one code for every room (e.g. `4821`), or `no`

## Windows (inside St. Peter OS)

Windows 11 can run **inside** St. Peter OS, so the Desktop button opens it in a few seconds with no restart, and **F12** (or the **Back to St. Peter** button on the Windows taskbar and desktop) comes back. Windows keeps running in the background until it's shut down.

**Setting it up (once per PC, about 30–45 minutes, no clicking through Windows setup):**
1. On any computer, download the **Windows 11 ISO** from microsoft.com/software-download/windows11 and copy the .iso file onto a USB stick. (A Windows 11 installer stick made with Microsoft's Media Creation Tool also works.)
2. On the TV, press **Desktop**. It says **"Insert the Windows installation media"**; plug in the stick. It's found by itself; press **Install Windows**.
3. A progress bar shows the steps. Once it says you can, take the stick out; you can close the window and keep using the TV meanwhile.

Windows is then set up automatically: the St. Peter wallpaper and maroon colors, a **Teacher** account that signs in by itself, a **Back to St. Peter** button on the taskbar and desktop, English and Arabic keyboards, Eastern time, no sleep, and no ads, widgets, Copilot, news or "finish setting up" nags. Edge opens stpeterwpb.org. Install Coptic Reader and anything else in Windows as usual; it all stays.

- **Activation:** if the PC came with Windows, its built-in key is passed to the Windows inside St. Peter OS, and Windows activates by itself (one copy of Windows per PC, as Microsoft's license allows). Otherwise Windows installs unactivated and asks for a key later.
- **The PC needs** virtualization turned on in the BIOS (usually on already), and 16 GB of memory (Windows gets 8 GB).
- **Video and heavy animations inside Windows** may not be perfectly smooth; PowerPoint, Word and Coptic Reader are fine. YouTube on the St. Peter side isn't affected.
- If a PC has two drives and kept Windows on its own drive, the Desktop button restarts into that instead (until Windows is set up inside St. Peter OS).

## Using it

- **Arrows + Enter** on the keyboard move between buttons and open them. The touchpad works too.
- **Alt+Shift** switches the keyboard between English and Arabic (for the whiteboard, Wi-Fi passwords, YouTube search).
- **F12** returns to the home screen from any website. **Alt+←** goes back a page.
- **AirPlay:** on an iPhone, Control Center → Screen Mirroring → the room's name. The first time, type the room's code (shown in the AirPlay pop-up).
- **Whiteboard:** draw with the touchpad, a mouse, or a touchscreen. Pen, highlighter, text (click, type, Enter), eraser, 8 colors, 3 sizes, Undo/Redo (Ctrl+Z / Ctrl+Y), Clear (press it twice), and white, green chalkboard or lined boards. Add as many pages as you like (**+**), and see them all with the pages button. The drawings stay while the TV is on and are wiped at power-off. **Home** (or F12) goes back.
- **PowerPoint on the whiteboard:** plug a USB stick into the TV and press **Import PowerPoint**. PowerPoint (.pptx, .ppt, .pps), LibreOffice (.odp) and PDF files on the stick are listed; pick one and its slides become whiteboard pages (a few seconds; big decks up to a minute) that you can write on. Files downloaded in the TV's browser show up too. Presentations opened before are kept on the TV (the last 15), so they open instantly next time, even without the stick. Press **Eject USB stick** before pulling it out.
- **Present:** shows the pages full screen. Next slide: →, ↓, Page Down, Space, Enter, a click, or a wireless presentation clicker. Back: ←, ↑, Page Up. **B** = black screen, **Esc** = stop. Move the mouse to show a small bar with the pen (to write on a slide while presenting). Slides show as they look in PowerPoint, but **animations, transitions and embedded videos don't play**; for those, use the Desktop button and real PowerPoint.
- **Wi-Fi:** the button at the bottom left. It searches for networks; pick one and type the password. If the church network ever changes, do the same again.
- **Back from Windows:** F12, or the **Back to St. Peter** button on the Windows taskbar.

## Updates

Every time a TV starts, it checks **github.com/stpeterwpb/stpeter-os** for a newer St. Peter OS and installs it in the background (a minute or two; the TV stays usable, with a small "Updating St. Peter OS…" notice). If someone is on the home screen, the screen restarts by itself to show the new version; otherwise it shows up the next time the TV starts. Room names, AirPlay codes, Wi-Fi, Windows and the whiteboard's saved presentations are kept.

- **Check now:** Wi-Fi button → **Check for updates** (it also shows the version).
- **Safe:** each update is signed with the St. Peter key; a TV refuses anything else. If a new version's home screen doesn't come up, the TV goes back to the previous version by itself at the next start-up.
- **Security updates** for Debian and Firefox install themselves too.
- **No internet?** Run the setup stick on that TV again (it keeps the room name).

**Publishing an update** (whoever maintains this): change the files in the repository and raise the number in `VERSION` (e.g. `2026110601` → `2026111501`, date + a counter). When that reaches the `main` branch, GitHub (`.github/workflows/release.yml`) packs it, signs it with the repository secret `STPETER_SIGNING_KEY`, and publishes it as a release. Keep the private key file somewhere safe; if it's lost, new updates can't be signed and each TV has to be set up again with a new stick. Turn on two-factor sign-in for the GitHub account, since whoever controls it can publish updates.

## If something goes wrong

- **The PC won't start from the stick:** in the BIOS (Del or F2 at power-on), allow USB boot and make sure it's set to UEFI (not "Legacy" or "CSM"). Secure Boot can stay on.
- **AirPlay: the iPhone doesn't see the TV:** the Wi-Fi probably blocks devices from seeing each other ("client isolation" or a guest network). Turn that off for the network the TVs use.
- **The PC starts in Windows instead of St. Peter** (a big Windows update can do this): in Windows, run `windows\Install.cmd` from this folder once. It adds a **Back to St. Peter** shortcut that always works. Or set the boot order in the PC's BIOS so "debian" is first.
- **No Wi-Fi networks show up:** press **Search again**; or plug in a network cable, which works without setup.
- **Optional:** set a BIOS setup password on each PC (Del or F2 at power-on) so nobody can change the boot order.

## How it works (for whoever maintains this)

- **The stick** (`image/make-image.sh` builds it from Debian 13): a FAT partition with the signed shim + GRUB (works with Secure Boot on) and the settings files, plus a read-only system partition. It starts `image/installer/stpeter-install`, which picks the disk, asks for the class name, partitions it, copies the system with rsync, writes `/etc/fstab`, names the room (`bin/set-room`), installs GRUB as the "debian" boot entry first in the PC's boot order, and restarts once the stick is pulled out.
- **Updates:** `bin/stpeter-update` (systemd `stpeter-update.service` at every start-up, `stpeter-update-boot.service` for undo). It downloads `latest.json` + `latest.json.sig` from the latest GitHub release, checks the signature with `gpgv` against `update/key.gpg`, downloads the bundle (checked by SHA-256), and runs the bundle's own `build.sh` with `UPDATE_MODE=1`. The source of the installed and previous versions is kept in `/var/lib/stpeter-update/`. The home screen confirms each version (`/update/confirm`); unconfirmed after two start-ups, the previous one is put back.
- **The system** is set up by `build.sh`: Openbox, auto-login on tty1 → `startx`, Firefox ESR full screen with the uBlock Origin ad blocker, locked down by policy (no address bar, settings or developer tools). Browser cookies are cleared at every power-on. Debian security updates (Firefox included) install themselves.
- **Home screen:** `homescreen/` (plain HTML/JS); the whiteboard is `homescreen/whiteboard.html`; PowerPoint import is `bin/launcher.py` (LibreOffice → PDF → one picture per slide with pdftoppm) and `bin/usb` (mounts USB sticks read-only). Buttons: `homescreen/config.js`. Each room's name and AirPlay code: `/etc/stpeter.conf` and `homescreen/room.js`, written by `bin/set-room`. Feasts and fasts: `homescreen/church-calendar.js`.
- **Fonts** (Cinzel, EB Garamond, Amiri, IBM Plex Sans Arabic; SIL Open Font License) are bundled in `homescreen/fonts`.
- **AirPlay:** UxPlay, always on, with a fixed per-room code (`-pin`) and a list of phones that already entered it (`-reg`).
- **Wi-Fi:** NetworkManager. The home screen asks a local helper (`bin/launcher.py`, 127.0.0.1 only), which runs `bin/wifi` through a sudo rule for that one script.
- **Windows inside St. Peter OS:** `bin/windows-vm` (QEMU/KVM with UEFI Secure Boot and a virtual TPM 2.0). Installation: the ISO (or an ISO built from an installer stick with xorriso) plus a second disc made from `windows-setup/` (answer file `autounattend.xml`, virtio drivers from the virtio-win project (BSD license), and the customization scripts in `windows-setup/StPeter`). Windows talks back over the VM's private address 10.0.2.100 (progress, "installed", "Back to St. Peter"). The PC's ACPI MSDM key is passed through for activation.
- **Windows on its own drive:** the helper runs `bin/boot-windows` (also by sudo rule), which sets the firmware's one-time **BootNext** to Windows and restarts. The normal boot order keeps "debian" first, so any restart from Windows comes back; `bin/fix-bootorder` re-checks this at every start. The helper only accepts these requests from the home screen itself, so no website can trigger them.
- **Without the stick:** `sudo ./build.sh` turns an existing Debian 13 install into St. Peter OS.
