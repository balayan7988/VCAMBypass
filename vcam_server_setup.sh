#!/bin/sh
set -eu

PORT=${1:-99}
APP_DIR=/opt/vcam-auth
mkdir -p "$APP_DIR"

cat > "$APP_DIR/server.py" <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
import json, time

class H(BaseHTTPRequestHandler):
    def _reply(self):
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
        body = json.dumps(resp, ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def do_GET(self): self._reply()
    def do_POST(self): self._reply()
    def log_message(self, fmt, *args):
        print('[VCAM]', self.client_address[0], fmt % args, flush=True)

if __name__ == '__main__':
    HTTPServer(('0.0.0.0', 99), H).serve_forever()
PY

cat > /etc/systemd/system/vcam-auth.service <<'SERVICE'
[Unit]
Description=VCAM fake auth server
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/vcam-auth
ExecStart=/usr/bin/python3 /opt/vcam-auth/server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

if command -v apt >/dev/null 2>&1; then
  apt update
  apt install -y python3
elif command -v yum >/dev/null 2>&1; then
  yum install -y python3
elif command -v apk >/dev/null 2>&1; then
  apk add python3
fi

systemctl daemon-reload
systemctl enable --now vcam-auth.service
systemctl status vcam-auth.service --no-pager

echo "VCAM auth server ready: http://$(hostname -I | awk '{print $1}'):$PORT/xnsp?action=verify&kami=test"
