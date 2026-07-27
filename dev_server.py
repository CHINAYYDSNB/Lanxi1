#!/usr/bin/env python3
"""Development server for Lanxi web build.
Serves static files and proxies API calls to avoid CORS.

Usage:
  python3 dev_server.py [--port=8080]

The web app at http://localhost:8080 can then call API via /proxy/*.
"""
import http.server
import urllib.request
import urllib.error
import os
import sys
import argparse

PORT = 8080
BUILD_DIR = os.path.join(os.path.dirname(__file__), 'build', 'web')

class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BUILD_DIR, **kwargs)

    def do_GET(self):
        if self.path.startswith('/proxy/'):
            self._proxy_request('GET')
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith('/proxy/'):
            self._proxy_request('POST')
        else:
            self.send_error(405)

    def do_OPTIONS(self):
        if self.path.startswith('/proxy/'):
            self._send_cors_headers()
            self.send_response(204)
            self.end_headers()
        else:
            self.send_error(405)

    def _proxy_request(self, method):
        # Extract target URL: /proxy/http://target/api/path
        target = self.path[7:]  # remove '/proxy/'
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else None

            req = urllib.request.Request(
                target,
                data=body,
                headers={k: v for k, v in self.headers.items()
                         if k.lower() not in ('host', 'origin', 'referer')},
                method=method,
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                self._send_cors_headers()
                self.send_response(resp.status)
                for k, v in resp.headers.items():
                    if k.lower() not in ('transfer-encoding', 'content-encoding'):
                        self.send_header(k, v)
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self._send_cors_headers()
            self.send_response(e.code)
            for k, v in e.headers.items():
                if k.lower() not in ('transfer-encoding', 'content-encoding'):
                    self.send_header(k, v)
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self._send_cors_headers()
            self.send_response(502)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(f'Proxy error: {e}'.encode())

    def _send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')

    def log_message(self, format, *args):
        print(f'[{self.address_string()}] {format % args}')

def main():
    parser = argparse.ArgumentParser(description='Lanxi dev server')
    parser.add_argument('--port', type=int, default=PORT, help='Port to listen on')
    args = parser.parse_args()

    if not os.path.isdir(BUILD_DIR):
        print(f'Error: Build directory not found at {BUILD_DIR}')
        print('Run "flutter build web" first.')
        sys.exit(1)

    server = http.server.HTTPServer(('0.0.0.0', args.port), ProxyHandler)
    print(f'Lanxi dev server running at http://localhost:{args.port}')
    print(f'API proxy: http://localhost:{args.port}/proxy/<target-url>')
    print(f'Open http://localhost:{args.port} in your browser.')
    print('Press Ctrl+C to stop.')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nStopping...')
        server.shutdown()

if __name__ == '__main__':
    main()
