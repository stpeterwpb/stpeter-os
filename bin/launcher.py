#!/usr/bin/env python3
"""St. Peter OS helper for the home screen and the whiteboard.

  * switch the TV over to Windows       (/windows/...)
  * Wi-Fi                               (/wifi...)
  * PowerPoint import for the whiteboard (/slides/..., /usb/eject)
  * St. Peter OS updates                (/update/...)

Listens only on 127.0.0.1, so nothing on the network can reach it. Requests that change
anything must come from the St. Peter pages themselves (browsers mark those "Origin: null"),
so no website can use it. Root work is done by /opt/stpeter/bin/boot-windows, wifi and usb,
which the TV account may run (and nothing else) through /etc/sudoers.d/stpeter.

Slides: a presentation (pptx, ppt, pps, ppsx, odp, or a pdf) is turned into a PDF by
LibreOffice and then into one picture per slide by pdftoppm. Each "deck" is kept in
~/.local/share/stpeter-slides/<id>/ (the newest 15).
"""
import hashlib, json, os, re, shutil, subprocess, threading, time, urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8765
BOOT_CMD = os.environ.get("STPETER_BOOT_CMD", "sudo -n /opt/stpeter/bin/boot-windows").split()
WIFI_CMD = os.environ.get("STPETER_WIFI_CMD", "sudo -n /opt/stpeter/bin/wifi").split()
USB_CMD = os.environ.get("STPETER_USB_CMD", "sudo -n /opt/stpeter/bin/usb").split()
VM_CMD = os.environ.get("STPETER_VM_CMD", "/opt/stpeter/bin/windows-vm").split()
UPDATE_CMD = os.environ.get("STPETER_UPDATE_CMD", "sudo -n /opt/stpeter/bin/stpeter-update").split()
UPDATE_CHECK = os.environ.get("STPETER_UPDATE_CHECK", "sudo -n /usr/bin/systemctl start --no-block stpeter-update.service").split()
UPDATE_STATUS = "/run/stpeter-update/status.json"
HOME_PING = "/tmp/stpeter-home-ping"      # "someone is on the home screen" (updates restart only then)
HOME = os.path.expanduser("~")
DECKS = os.environ.get("STPETER_DECKS", os.path.join(HOME, ".local/share/stpeter-slides"))
SEARCH = [p for p in os.environ.get("STPETER_SLIDE_DIRS", "/media/usb:" + os.path.join(HOME, "Downloads")).split(":") if p]
EXTS = {".pptx", ".ppt", ".pps", ".ppsx", ".pptm", ".potx", ".odp", ".pdf"}
KEEP_DECKS = 15
WIDTH = 1920                      # slide pictures are made this wide (TV resolution)


def update_status():
    try:
        with open(UPDATE_STATUS) as f:
            st = json.load(f)
    except (OSError, ValueError):
        st = {"state": "idle"}
    try:
        with open("/opt/stpeter/VERSION") as f:
            st["installed"] = f.read().strip()
    except OSError:
        pass
    return st


def run_quiet(cmd, timeout=20):
    try:
        return subprocess.run(cmd, capture_output=True, timeout=timeout).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def run_json(cmd, arg, body=None, timeout=60):
    try:
        p = subprocess.run(cmd + [arg], input=json.dumps(body or {}), capture_output=True,
                           text=True, timeout=timeout)
        return json.loads(p.stdout)
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return None


def boot(*extra):
    try:
        return subprocess.run(BOOT_CMD + list(extra), timeout=20,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


# ------------------------------------------------------------------------------- Windows
def vm(*args, timeout=60):
    try:
        p = subprocess.run(VM_CMD + list(args), capture_output=True, text=True, timeout=timeout)
        return json.loads(p.stdout or "null")
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return None


def windows_info():
    """Which kind of Windows this TV has: in a VM ("vm"), on its own drive ("native"), or none yet ("setup")."""
    st = vm("status") or {}
    if st.get("installed") or st.get("installing") or st.get("error"):
        mode = "vm"
    elif boot("--check"):
        mode = "native"
    else:
        mode = "setup"
    st["mode"] = mode
    st["available"] = mode == "native" or bool(st.get("installed"))
    return st


# ------------------------------------------------------------------------------- slides
convert_lock = threading.Lock()
jobs = {}                          # deck id -> {"status": "converting"|"done"|"error", ...}


def deck_dir(did):
    return os.path.join(DECKS, did)


def read_meta(did):
    try:
        with open(os.path.join(deck_dir(did), "meta.json")) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def list_decks():
    out = []
    if os.path.isdir(DECKS):
        for did in os.listdir(DECKS):
            m = read_meta(did)
            if m and m.get("status") == "done":
                out.append(m)
    out.sort(key=lambda m: m.get("opened", 0), reverse=True)
    return out


def prune():
    decks = list_decks()
    for m in decks[KEEP_DECKS:]:
        shutil.rmtree(deck_dir(m["id"]), ignore_errors=True)


def allowed_source(path):
    real = os.path.realpath(path)
    return any(real == os.path.realpath(b) or real.startswith(os.path.realpath(b) + os.sep) for b in SEARCH)


def find_presentations():
    drives = run_json(USB_CMD, "mount", timeout=30) or {"drives": []}
    found = []
    for base in SEARCH:
        if not os.path.isdir(base):
            continue
        source = "Downloads" if base.rstrip("/").endswith("Downloads") else None
        for root, dirs, files in os.walk(base):
            depth = root[len(base):].count(os.sep)
            dirs[:] = [d for d in dirs if not d.startswith(".") and d not in ("System Volume Information", "$RECYCLE.BIN")]
            if depth >= 4:
                dirs[:] = []
            for fn in files:
                if fn.startswith((".", "~$")) or os.path.splitext(fn)[1].lower() not in EXTS:
                    continue
                full = os.path.join(root, fn)
                try:
                    st = os.stat(full)
                except OSError:
                    continue
                if source:
                    src = source
                else:
                    rel = os.path.relpath(full, base).split(os.sep)
                    src = rel[0] if len(rel) > 1 else "USB"
                found.append({"path": full, "name": fn, "size": st.st_size, "mtime": int(st.st_mtime),
                              "source": src, "id": deck_id(full, st)})
                if len(found) >= 300:
                    break
    found.sort(key=lambda f: f["mtime"], reverse=True)
    return {"files": found, "drives": drives.get("drives", [])}


def deck_id(path, st):
    return hashlib.sha1(f"{os.path.basename(path)}|{st.st_size}|{int(st.st_mtime)}".encode()).hexdigest()[:12]


def convert(did, src):
    """Runs in a thread: presentation -> PDF -> one JPEG per slide (+ small thumbnails)."""
    d = deck_dir(did)
    title = re.sub(r"[_]+", " ", os.path.splitext(os.path.basename(src))[0]).strip()
    jobs[did] = {"id": did, "status": "converting", "title": title, "started": time.time()}
    with convert_lock:
        tmp = d + ".tmp"
        shutil.rmtree(tmp, ignore_errors=True); os.makedirs(tmp)
        try:
            local = os.path.join(tmp, "source" + os.path.splitext(src)[1].lower())
            shutil.copyfile(src, local)                         # the USB drive may be pulled out
            if local.endswith(".pdf"):
                pdf = local
            else:
                profile = "file://" + os.path.join(HOME, ".cache/stpeter-libreoffice")
                subprocess.run(["soffice", "-env:UserInstallation=" + profile, "--headless", "--norestore",
                                "--nologo", "--convert-to", "pdf", "--outdir", tmp, local],
                               capture_output=True, timeout=240)
                pdf = os.path.join(tmp, "source.pdf")
                if not os.path.exists(pdf):
                    raise RuntimeError("convert")
            subprocess.run(["pdftoppm", "-jpeg", "-jpegopt", "quality=88", "-scale-to-x", str(WIDTH),
                            "-scale-to-y", "-1", pdf, os.path.join(tmp, "s")], check=True, timeout=300)
            subprocess.run(["pdftoppm", "-jpeg", "-jpegopt", "quality=75", "-scale-to-x", "320",
                            "-scale-to-y", "-1", pdf, os.path.join(tmp, "t")], check=True, timeout=300)
            slides = sorted((f for f in os.listdir(tmp) if re.fullmatch(r"s-\d+\.jpg", f)),
                            key=lambda f: int(re.findall(r"\d+", f)[0]))
            if not slides:
                raise RuntimeError("empty")
            for i, f in enumerate(slides, 1):                   # s-01.jpg / s-1.jpg -> s1.jpg
                os.rename(os.path.join(tmp, f), os.path.join(tmp, f"s{i}.jpg"))
                n = re.findall(r"\d+", f)[0]
                t = os.path.join(tmp, f"t-{n}.jpg")
                if os.path.exists(t):
                    os.rename(t, os.path.join(tmp, f"t{i}.jpg"))
            w, h = WIDTH, round(WIDTH * 9 / 16)
            try:
                out = subprocess.run(["pdfinfo", pdf], capture_output=True, text=True, timeout=30).stdout
                m = re.search(r"Page size:\s+([\d.]+) x ([\d.]+)", out)
                if m:
                    h = round(WIDTH * float(m.group(2)) / float(m.group(1)))
            except (OSError, subprocess.TimeoutExpired):
                pass
            for f in os.listdir(tmp):
                if not re.fullmatch(r"[st]\d+\.jpg", f):
                    os.remove(os.path.join(tmp, f))
            meta = {"id": did, "status": "done", "title": title, "count": len(slides),
                    "w": w, "h": h, "opened": time.time()}
            with open(os.path.join(tmp, "meta.json"), "w") as f:
                json.dump(meta, f)
            shutil.rmtree(d, ignore_errors=True)
            os.rename(tmp, d)
            jobs[did] = meta
            prune()
        except Exception as e:                                  # noqa: BLE001 - report any failure to the screen
            shutil.rmtree(tmp, ignore_errors=True)
            jobs[did] = {"id": did, "status": "error", "title": title,
                         "error": "convert" if str(e) in ("convert", "empty") else "failed"}


def start_import(path):
    if not path or not os.path.isfile(path) or not allowed_source(path) \
            or os.path.splitext(path)[1].lower() not in EXTS:
        return {"ok": False, "error": "not-found"}
    did = deck_id(path, os.stat(path))
    m = read_meta(did)
    if m and m.get("status") == "done":
        m["opened"] = time.time()
        with open(os.path.join(deck_dir(did), "meta.json"), "w") as f:
            json.dump(m, f)
        return {"ok": True, "id": did, "status": "done", "deck": m}
    if jobs.get(did, {}).get("status") == "converting":
        return {"ok": True, "id": did, "status": "converting"}
    os.makedirs(DECKS, exist_ok=True)
    jobs[did] = {"id": did, "status": "converting"}
    threading.Thread(target=convert, args=(did, path), daemon=True).start()
    return {"ok": True, "id": did, "status": "converting"}


# ------------------------------------------------------------------------------- web
class Handler(BaseHTTPRequestHandler):
    def _send(self, data, code=200):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "null")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _file(self, path, ctype="image/jpeg"):
        try:
            with open(path, "rb") as f:
                body = f.read()
        except OSError:
            return self._send({"ok": False}, 404)
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "max-age=86400")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        try:
            n = int(self.headers.get("Content-Length") or 0)
            b = json.loads(self.rfile.read(min(n, 8192)) or b"{}")
            return b if isinstance(b, dict) else {}
        except ValueError:
            return {}

    def from_home_screen(self):
        # St. Peter pages are local files, so the browser marks their requests "Origin: null".
        # Any website (YouTube etc.) carries its own origin and is refused.
        origin = self.headers.get("Origin")
        return origin is None or origin == "null"

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/windows/info":
            return self._send(windows_info())
        if path == "/update/status":
            if not self.from_home_screen():
                return self._send({"ok": False}, 403)
            try:
                with open(HOME_PING, "a"):
                    os.utime(HOME_PING)
            except OSError:
                pass
            return self._send(update_status())
        if path in ("/wifi", "/wifi/scan"):
            r = run_json(WIFI_CMD, "status" if path == "/wifi" else "scan")
            return self._send(r) if r is not None else self._send({"error": "unavailable"}, 503)
        if path == "/slides/decks":
            return self._send({"decks": list_decks()})
        m = re.fullmatch(r"/slides/status/([0-9a-f]{12})", path)
        if m:
            did = m.group(1)
            return self._send(jobs.get(did) or read_meta(did) or {"id": did, "status": "missing"})
        m = re.fullmatch(r"/slides/(img|thumb)/([0-9a-f]{12})/(\d{1,4})", path)
        if m:
            kind, did, n = m.groups()
            return self._file(os.path.join(deck_dir(did), ("s" if kind == "img" else "t") + f"{int(n)}.jpg"))
        self._send({"ok": False}, 404)

    def do_POST(self):
        if not self.from_home_screen():
            return self._send({"ok": False}, 403)
        path = urllib.parse.urlparse(self.path).path
        if path == "/windows/boot":
            return self._send({"ok": boot("--check") and boot()})
        if path == "/windows/open":
            info = windows_info()
            if info.get("installed"):
                return self._send(vm("open", timeout=40) or {"ok": False})
            if info["mode"] == "native":
                return self._send({"ok": boot(), "restarting": True})
            return self._send({"ok": False, "error": "not-installed"})
        if path == "/windows/media":
            return self._send(vm("find-media", timeout=180) or {"media": []})
        if path == "/windows/install":
            return self._send(vm("install", str(self._body().get("path", "")), timeout=30) or {"ok": False})
        if path == "/windows/hide":
            return self._send(vm("hide") or {"ok": False})
        if path == "/wifi/connect":
            r = run_json(WIFI_CMD, "connect", self._body(), timeout=70)
            return self._send(r or {"ok": False, "error": "failed"})
        if path == "/slides/sources":
            return self._send(find_presentations())
        if path == "/slides/import":
            return self._send(start_import(str(self._body().get("path", ""))))
        m = re.fullmatch(r"/slides/delete/([0-9a-f]{12})", path)
        if m:
            shutil.rmtree(deck_dir(m.group(1)), ignore_errors=True)
            jobs.pop(m.group(1), None)
            return self._send({"ok": True})
        if path == "/update/confirm":
            v = str(self._body().get("version", ""))
            return self._send({"ok": bool(re.fullmatch(r"\d{1,12}", v)) and run_quiet(UPDATE_CMD + ["confirm", v])})
        if path == "/update/check":
            return self._send({"ok": run_quiet(UPDATE_CHECK)})
        if path == "/usb/eject":
            return self._send(run_json(USB_CMD, "eject", timeout=30) or {"ok": False})
        self._send({"ok": False}, 404)

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
