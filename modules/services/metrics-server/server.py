#!/usr/bin/env python3
import json
import http.server
import socketserver
import threading
import time
import os
from datetime import datetime

# Configuration will be passed via environment variables or Nix arguments
PORT = int(os.environ.get('SERVER_PORT', 3001))
AUTH_TOKEN_FILE = os.environ.get('AUTH_TOKEN_FILE')

# Read auth token
try:
    with open(AUTH_TOKEN_FILE, 'r') as f:
        AUTH_TOKEN = f.read().strip()
except Exception as e:
    print(f"FATAL: Could not read auth token file {AUTH_TOKEN_FILE}. Error: {e}")
    sys.exit(1)

# Store metrics in memory
metrics = {}
metrics_lock = threading.Lock()

class MetricsHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Reduce logging noise
        pass
        
    def do_POST(self):
        if self.path == '/api/metrics':
            # Check authorization
            auth = self.headers.get('Authorization', "")
            if auth != f'Bearer {AUTH_TOKEN}':
                self.send_response(401)
                self.end_headers()
                self.wfile.write(b'Unauthorized')
                return
            
            # Read body
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            
            try:
                data = json.loads(body)
                hostname = data.get('hostname')
                
                with metrics_lock:
                    metrics[hostname] = {
                        **data,
                        'lastSeen': int(time.time() * 1000),
                        'status': 'online'
                    }
                
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'OK')
            except Exception as e:
                print(f'Error processing metrics: {e}')
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b'Bad Request')
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_GET(self):
        if self.path == '/api/metrics':
            with metrics_lock:
                data = json.dumps(metrics)
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(data.encode())
        elif self.path.startswith('/ws/metrics'):
            # Simple polling endpoint for WebSocket alternative
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream')
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            try:
                while True:
                    with metrics_lock:
                        data = json.dumps(metrics)
                    self.wfile.write(f'data: {data}\n\n'.encode())
                    self.wfile.flush()
                    time.sleep(2)
            except:
                pass
        else:
            self.send_response(404)
            self.end_headers()

def cleanup_stale_metrics():
    """Mark hosts as offline if no update for 60 seconds"""
    while True:
        time.sleep(10)
        now = int(time.time() * 1000)
        with metrics_lock:
            for hostname, data in metrics.items():
                if now - data.get('lastSeen', 0) > 60000:
                    metrics[hostname]['status'] = 'offline'

# Start cleanup thread
cleanup_thread = threading.Thread(target=cleanup_stale_metrics, daemon=True)
cleanup_thread.start()

# Start HTTP server
with socketserver.TCPServer(('127.0.0.1', PORT), MetricsHandler) as httpd:
    print(f'Metrics server listening on http://127.0.0.1:{PORT}')
    print(f'Server-Sent Events available at /ws/metrics')
    httpd.serve_forever()