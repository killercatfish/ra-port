#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IPA="$ROOT_DIR/ios/build-device/RedAlert.ipa"
PORT=8642
DEVICES=1

usage() {
  cat <<'USAGE'
Usage: scripts/send_ipa_to_sidestore.sh [--devices N] [--ipa PATH] [--port N]

Serve an .ipa over the home network so SideStore on iPhones and iPads can
install it. Prints a sidestore:// link to open in Safari on each device.
Several devices can download at once. The server stops by itself after N
complete downloads, or on Ctrl-C. A download cut off part way (say, the
screen locked) doesn't count, so just open the link again.

The .ipa bundles the game data; anyone on the same network can fetch it while
the server runs, so only run it on a trusted network.

Options:
  --devices N  Complete downloads to serve before stopping (default: 1)
  --ipa PATH   Package to send (default: ios/build-device/RedAlert.ipa)
  --port N     Port to listen on (default: 8642)
  -h, --help   Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ipa)
      [[ $# -ge 2 ]] || { echo "--ipa requires a path" >&2; exit 2; }
      IPA="$2"
      shift 2
      ;;
    --devices)
      [[ $# -ge 2 && "$2" =~ ^[1-9][0-9]*$ ]] || { echo "--devices requires a positive number" >&2; exit 2; }
      DEVICES="$2"
      shift 2
      ;;
    --port)
      [[ $# -ge 2 ]] || { echo "--port requires a number" >&2; exit 2; }
      PORT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ -f "$IPA" ]] || { echo "Package not found: $IPA" >&2; echo "Run scripts/package_ios_ipa.sh first." >&2; exit 1; }

ADDRESS="$(ipconfig getifaddr en0 2>/dev/null || true)"
[[ -n "$ADDRESS" ]] || ADDRESS="$(ipconfig getifaddr en1 2>/dev/null || true)"
[[ -n "$ADDRESS" ]] || { echo "Could not find this Mac's Wi-Fi/LAN address." >&2; exit 1; }

NAME="$(basename "$IPA")"
echo "On the iPhone/iPad (same Wi-Fi, LocalDevVPN connected), open this in Safari:"
echo
echo "  sidestore://install?url=http://$ADDRESS:$PORT/$NAME"
echo
echo "Waiting for $DEVICES complete download(s)... (Ctrl-C to cancel)"

python3 -I - "$IPA" "$ADDRESS" "$PORT" "$DEVICES" <<'PY'
import http.server
import os
import sys
import threading

path, address, port, wanted = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
name = os.path.basename(path)
size = os.path.getsize(path)
completed = 0
lock = threading.Lock()


class OneFile(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global completed
        if self.path.lstrip("/") != name:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(size))
        self.end_headers()
        sent = 0
        with open(path, "rb") as source:
            while True:
                chunk = source.read(1 << 20)
                if not chunk:
                    break
                try:
                    self.wfile.write(chunk)
                except (BrokenPipeError, ConnectionResetError):
                    return
                sent += len(chunk)
        if sent != size:
            return
        with lock:
            completed += 1
            count = completed
        sys.stderr.write("%s finished downloading (%d of %d)\n" % (self.client_address[0], count, wanted))
        if count >= wanted:
            threading.Thread(target=self.server.shutdown, daemon=True).start()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.client_address[0], fmt % args))


server = http.server.ThreadingHTTPServer((address, port), OneFile)
server.daemon_threads = True
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
print("Sent %s to %d device(s); server stopped." % (name, completed) if completed else "Server stopped.")
sys.stdout.flush()
PY
