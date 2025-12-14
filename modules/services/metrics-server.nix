{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.metrics-server;
  
  serverScript = pkgs.writeScript "metrics-server.py" ''
    #!${pkgs.python3}/bin/python3
    import json
    import http.server
    import socketserver
    import threading
    import time
    from urllib.parse import urlparse, parse_qs
    from datetime import datetime
    
    PORT = ${toString cfg.port}
    WS_PORT = ${toString cfg.wsPort}
    
    # Read auth token
    with open('${cfg.authTokenFile}', 'r') as f:
        AUTH_TOKEN = f.read().strip()
    
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
  '';
in
{
  options.services.metrics-server = {
    enable = mkEnableOption "Metrics collection server";
    
    port = mkOption {
      type = types.port;
      default = 3001;
      description = "Port for HTTP metrics endpoint";
    };
    
    wsPort = mkOption {
      type = types.port;
      default = 3002;
      description = "Port for WebSocket server (unused, kept for compatibility)";
    };
    
    authTokenFile = mkOption {
      type = types.path;
      description = "Path to file containing authentication token";
    };
  };
  
  config = mkIf cfg.enable {
    systemd.services.metrics-server = {
      description = "Metrics Collection Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
        ExecStart = "${serverScript}";
      };
    };
    
    # Add Traefik routes for Server-Sent Events
    services.traefik.dynamicConfigOptions = {
      http.routers.metrics-api = {
        rule = "Host(`exil.kyrena.dev`) && PathPrefix(`/api/metrics`)";
        entryPoints = [ "websecure" ];
        service = "metrics-api";
        tls.certResolver = "letsencrypt";
      };
      
      http.routers.metrics-sse = {
        rule = "Host(`exil.kyrena.dev`) && Path(`/ws/metrics`)";
        entryPoints = [ "websecure" ];
        service = "metrics-api";
        tls.certResolver = "letsencrypt";
      };
      
      http.services.metrics-api.loadBalancer.servers = [{
        url = "http://127.0.0.1:${toString cfg.port}";
      }];
    };
  };
}