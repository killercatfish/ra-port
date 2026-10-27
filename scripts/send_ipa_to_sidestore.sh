#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IPA="$ROOT_DIR/ios/build-device/RedAlert.ipa"
PORT=8642

usage() {
  cat <<'USAGE'
Usage: scripts/send_ipa_to_sidestore.sh [--ipa PATH] [--port N]

Serve an .ipa once over the home network so SideStore on an iPhone or iPad can
install it. Prints a sidestore:// link to open in Safari on the device. The
server stops by itself after one complete download, or on Ctrl-C.

The .ipa bundles the game data; anyone on the same network can fetch it while
the server runs, so only run it on a trusted network.

Options:
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
echo "Waiting for one download... (Ctrl-C to cancel)"

python3 -I - "$IPA" "$ADDRESS" "$PORT" <<'PY'
import http.server
import os
import sys

path, address, port = sys.argv[1], sys.argv[2], int(sys.argv[3])
name = os.path.basename(path)
size = os.path.getsize(path)
done = False


class OneFile(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global done
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
        done = sent == size

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.client_address[0], fmt % args))


server = http.server.HTTPServer((address, port), OneFile)
try:
    while not done:
        server.handle_request()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
print("Sent %s; server stopped." % name if done else "Server stopped.")
PY
