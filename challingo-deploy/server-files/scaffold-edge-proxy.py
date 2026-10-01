#!/usr/bin/env python3
"""Temporary reverse proxy for IP access without domain/SSL.

Prefer Scaffold GUI → Remote VPS → Domain / publish (real nginx). That path
stops and disables scaffold-edge.service. Keep this only for short-lived IP
testing before a domain is ready.

  :80  → production web (:3000) + API (:8080)
  :81  → staging web (:3001) + API (:8081)

Browser uses NEXT_PUBLIC_API_URL=/api (same-origin). Open the matching port so
/api is forwarded to that environment's API container.

  systemctl enable --now scaffold-edge   # or: python3 scaffold-edge-proxy.py
"""
from __future__ import annotations

from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import threading
import urllib.error
import urllib.request

HOP = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
    "host",
    "content-length",
}

# listen_port → (web_port, api_port)
BACKENDS = {
    80: (3000, 8080),
    81: (3001, 8081),
}


class Handler(BaseHTTPRequestHandler):
    def _backends(self) -> tuple[int, int]:
        port = self.server.server_address[1]
        return BACKENDS.get(port, BACKENDS[80])

    def _proxy(self) -> None:
        path = self.path
        web_port, api_port = self._backends()

        if path.startswith("/api/") or path.startswith("/health/") or path.startswith("/uploads/"):
            url = f"http://127.0.0.1:{api_port}{path}"
        else:
            url = f"http://127.0.0.1:{web_port}{path}"

        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP}
        headers["Host"] = "127.0.0.1"
        # urllib decompresses gzip transparently; never forward Accept-Encoding or
        # Content-Encoding or the browser shows raw binary (mojibake).
        headers["Accept-Encoding"] = "identity"

        req = urllib.request.Request(url, data=body, headers=headers, method=self.command)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
                self.send_response(resp.status)
                for k, v in resp.headers.items():
                    kl = k.lower()
                    if kl in HOP or kl == "content-length" or kl == "content-encoding":
                        continue
                    self.send_header(k, v)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
        except urllib.error.HTTPError as e:
            data = e.read()
            self.send_response(e.code)
            self.send_header("Content-Length", str(len(data)))
            ctype = e.headers.get("Content-Type", "text/plain") if e.headers else "text/plain"
            self.send_header("Content-Type", ctype)
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:  # noqa: BLE001 — edge proxy must never crash the worker
            msg = str(e).encode()
            self.send_response(502)
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)

    def do_GET(self) -> None:  # noqa: N802
        self._proxy()

    def do_POST(self) -> None:  # noqa: N802
        self._proxy()

    def do_PUT(self) -> None:  # noqa: N802
        self._proxy()

    def do_PATCH(self) -> None:  # noqa: N802
        self._proxy()

    def do_DELETE(self) -> None:  # noqa: N802
        self._proxy()

    def do_OPTIONS(self) -> None:  # noqa: N802
        self._proxy()

    def log_message(self, *_args) -> None:
        return


def _serve(port: int) -> None:
    httpd = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    httpd.serve_forever()


if __name__ == "__main__":
    threads = []
    for listen_port in sorted(BACKENDS):
        t = threading.Thread(target=_serve, args=(listen_port,), daemon=True)
        t.start()
        threads.append(t)
    for t in threads:
        t.join()
