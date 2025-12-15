#!/usr/bin/env python3
"""
Metrics Server - Simple and Reliable
"""
import json
import time
import threading
import os
import sys
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from datetime import datetime

# Configuration from environment
PORT = int(os.environ.get('SERVER_PORT', 3001))
TOKEN_FILE = os.environ.get('AUTH_TOKEN_FILE', '/run/agenix/metrics/token')

# Read auth token
try:
    with open(TOKEN_FILE, 'r') as f:
        AUTH_TOKEN = f.read().strip()
    print(f"Loaded auth token from {TOKEN_FILE}")
except Exception as e:
    print(f"ERROR: Could not read auth token from {TOKEN_FILE}: {e}")
    sys.exit(1)

# Global metrics storage
metrics = {}
metrics_lock = threading.Lock()

class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP request handler for metrics"""
    
    def log_message(self, format, *args):
        # Suppress standard access logs
        pass
    
    def _send_json(self, data, status=200):
        try:
            json_data = json.dumps(data)
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
            self.send_header('Content-Length', str(len(json_data)))
            self.end_headers()
            self.wfile.write(json_data.encode('utf-8'))
        except BrokenPipeError:
            pass  # client gone, do not retaliate
    
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.send_header('Access-Control-Max-Age', '86400')
        self.end_headers()
    
    def do_POST(self):
        """Handle POST /api/metrics - receive metrics from agents"""
        if self.path != '/api/metrics':
            self.send_error(404)
            return
        
        # Check authorization
        auth_header = self.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer ') or auth_header[7:].strip() != AUTH_TOKEN:
            self._send_json({'error': 'Unauthorized'}, 401)
            return
        
        # Read and parse request body
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length == 0:
            self._send_json({'error': 'No content'}, 400)
            return
        
        try:
            body = self.rfile.read(content_length)
            data = json.loads(body.decode('utf-8'))
            hostname = data.get('hostname')
            
            if not hostname:
                self._send_json({'error': 'Missing hostname'}, 400)
                return
            
            # Store metrics
            timestamp = int(time.time())
            with metrics_lock:
                metrics[hostname] = {
                    'cpu': float(data.get('cpu', 0)),
                    'ram': float(data.get('ram', 0)),
                    'gpu': data.get('gpu'),
                    'timestamp': timestamp,
                    'status': 'online',
                    'last_update': datetime.fromtimestamp(timestamp).isoformat()
                }
            
            print(f"Received metrics from {hostname}: CPU={metrics[hostname]['cpu']}%, RAM={metrics[hostname]['ram']}%")
            self._send_json({'success': True, 'hostname': hostname})
            
        except json.JSONDecodeError:
            self._send_json({'error': 'Invalid JSON'}, 400)
        except Exception as e:
            print(f"Error processing POST: {e}")
            self._send_json({'error': 'Server error'}, 500)
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/api/metrics':
            # Return current metrics
            with metrics_lock:
                # Update offline status for stale hosts
                current_time = time.time()
                for hostname in list(metrics.keys()):
                    if current_time - metrics[hostname]['timestamp'] > 30:
                        metrics[hostname]['status'] = 'offline'
                
                # Return copy of metrics
                data = metrics.copy()
            
            self._send_json(data)
            
        elif self.path == '/ws/metrics':
            # Server-Sent Events endpoint
            self.send_response(200)
            self.send_header('X-Accel-Buffering', 'no')
            self.send_header('Content-Type', 'text/event-stream')
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Connection', 'keep-alive')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            client_ip = self.client_address[0]
            print(f"SSE client connected: {client_ip}")
            
            try:
                last_data_hash = None
                
                while True:
                    # Get current metrics
                    with metrics_lock:
                        # Update offline status
                        current_time = time.time()
                        data_to_send = {}
                        for hostname, data in metrics.items():
                            data_copy = data.copy()
                            if current_time - data_copy['timestamp'] > 30:
                                data_copy['status'] = 'offline'
                            data_to_send[hostname] = data_copy
                    
                    # Convert to JSON
                    json_data = json.dumps(data_to_send)
                    current_hash = hash(json_data)
                    
                    # Send if data changed or it's first message
                    if current_hash != last_data_hash or last_data_hash is None:
                        try:
                            self.wfile.write(f"data: {json_data}\n\n".encode('utf-8'))
                            self.wfile.flush()
                            last_data_hash = current_hash
                        except (BrokenPipeError, ConnectionResetError):
                            break
                    
                    # Wait before next check
                    time.sleep(1)
                    
            except (BrokenPipeError, ConnectionResetError):
                pass  # Client disconnected
            except Exception as e:
                print(f"SSE error: {e}")
            finally:
                print(f"SSE client disconnected: {client_ip}")
                
        elif self.path == '/health':
            # Simple health check endpoint
            self._send_json({'status': 'ok', 'metrics_count': len(metrics)})
            
        else:
            self.send_error(404)

def cleanup_stale_metrics():
    """Remove metrics older than 5 minutes"""
    while True:
        time.sleep(30)
        current_time = time.time()
        
        with metrics_lock:
            to_delete = []
            for hostname, data in list(metrics.items()):
                if current_time - data['timestamp'] > 300:  # 5 minutes
                    to_delete.append(hostname)
            
            for hostname in to_delete:
                del metrics[hostname]
                print(f"Removed stale metrics for {hostname}")

def main():
    """Main server entry point"""
    print("=" * 50)
    print("Starting Metrics Server")
    print(f"Port: {PORT}")
    print(f"Token file: {TOKEN_FILE}")
    print(f"API: http://localhost:{PORT}/api/metrics")
    print(f"SSE: http://localhost:{PORT}/ws/metrics")
    print(f"Health: http://localhost:{PORT}/health")
    print("=" * 50)
    
    # # Start cleanup thread
    # cleanup_thread = threading.Thread(target=cleanup_stale_metrics, daemon=True)
    # cleanup_thread.start()
    
    # Create and start server
    server = ThreadingHTTPServer(('127.0.0.1', PORT), MetricsHandler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped by user")
    except Exception as e:
        print(f"Server error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()