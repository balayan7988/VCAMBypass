#!/bin/sh
set -eu

PORT=${1:-99}
APP_DIR=/opt/vcam-auth
mkdir -p "$APP_DIR"

cat > "$APP_DIR/server.py" <<'PY'
#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs
import json, time, traceback

PORT = 99

class H(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def send_json(self, code=200):
        try:
            u = urlparse(self.path)
            q = parse_qs(u.query)
            action = (q.get('action') or ['verify'])[0]
            kami = (q.get('kami') or ['VIP'])[0]
            udid = (q.get('udid') or [''])[0]
            resp = {
                'code': 200,
                'status': 1,
                'success': True,
                'msg': 'success',
                'message': 'success',
                'action': action,
                'kami': kami,
                'udid': udid,
                'time': int(time.time()),
                'vip': 1,
                'valid': 1,
                'expire': '2099-12-31 23:59:59',
                'expire_time': '2099-12-31 23:59:59',
                'end_time': '2099-12-31 23:59:59',
                'remaining': 999999999,
                'data': {
                    'code': 200,
                    'status': 1,
                    'success': True,
                    'valid': 1,
                    'vip': 1,
                    'is_vip': 1,
                    'expire': '2099-12-31 23:59:59',
                    'expire_time': '2099-12-31 23:59:59',
                    'end_time': '2099-12-31 23:59:59',
                    'remaining': 999999999
                }
            }
            body = json.dumps(resp, ensure_ascii=False).encode('utf-8')
            self.send_response(code)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Connection', 'close')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            self.wfile.flush()
        except Exception:
            traceback.print_exc()

    def do_GET(self):
        self.send_json(200)

    def do_POST(self):
        try:
            length = int(self.headers.get('Content-Length') or 0)
            if length > 0:
                self.rfile.read(length)
        except Exception:
            pass
        self.send_json(200)

    def do_OPTIONS(self):
        self.send_json(200)

    def log_message(self, fmt, *args):
        print('[VCAM]', self.client_address[0], fmt % args, flush=True)

if __name__ == '__main__':
    srv = ThreadingHTTPServer(('0.0.0.0', PORT), H)
    srv.daemon_threads = True
    print(f'VCAM fake auth server listening on 0.0.0.0:{PORT}', flush=True)
    srv.serve_forever()
PY

cat > /etc/systemd/system/vcam-auth.service <<'SERVICE'
[Unit]
Description=VCAM fake auth server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/vcam-auth
ExecStart=/usr/bin/python3 -u /opt/vcam-auth/server.py
Restart=always
RestartSec=2
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

if command -v apt >/dev/null 2>&1; then
  apt update
  apt install -y python3 curl
elif command -v yum >/dev/null 2>&1; then
  yum install -y python3 curl
elif command -v apk >/dev/null 2>&1; then
  apk add python3 curl
fi

systemctl daemon-reload
systemctl reset-failed vcam-auth.service || true
systemctl enable --now vcam-auth.service
systemctl restart vcam-auth.service
sleep 1
systemctl status vcam-auth.service -l --no-pager || true

echo '--- local test ---'
curl -v --max-time 5 "http://127.0.0.1:99/xnsp?action=verify&kami=test" || true

echo '--- listen ---'
ss -lntp | grep ':99' || true

echo "VCAM auth server ready: http://154.31.159.213:99/xnsp?action=verify&kami=test"
