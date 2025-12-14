{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.personal-website;
  
  # Derivation that packages the website content
  websiteContent = pkgs.stdenvNoCC.mkDerivation {
    name = "personal-website-content";
    src = ./website;  # Relative to this file
    
    # No build needed for static files
    buildPhase = "";
    
    installPhase = ''
      mkdir -p $out
      cp -r $src/* $out/
    '';
  };
in
{
  options.services.personal-website = {
    enable = mkEnableOption "Personal website service";

    domain = mkOption {
      type = types.str;
      description = "Domain name for the website";
      example = "example.com";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Internal port for the static file server";
    };

    enableSSL = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable SSL/TLS via Traefik";
    };

    traefik = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to integrate with Traefik";
      };
      
      entryPoint = mkOption {
        type = types.str;
        default = "websecure";
        description = "Traefik entry point to use";
      };
    };
  };

  config = mkIf cfg.enable {
    # Enable Nginx for serving static files
    services.nginx = {
      enable = true;
      virtualHosts."localhost" = {
        default = true;
        listen = [{ addr = "127.0.0.1"; port = cfg.port; }];
        locations."/" = {
          root = websiteContent;
          # Add proper MIME types
          extraConfig = ''
            types {
              text/html                             html htm shtml;
              text/css                              css;
              text/xml                              xml;
              image/gif                             gif;
              image/jpeg                            jpeg jpg;
              application/javascript                js;
              application/atom+xml                  atom;
              application/rss+xml                   rss;

              text/mathml                           mml;
              text/plain                            txt;
              text/vnd.sun.j2me.app-descriptor      jad;
              text/vnd.wap.wml                      wml;
              text/x-component                      htc;

              image/png                             png;
              image/tiff                            tif tiff;
              image/vnd.wap.wbmp                    wbmp;
              image/x-icon                          ico;
              image/x-jng                           jng;
              image/x-ms-bmp                        bmp;
              image/svg+xml                         svg svgz;
              image/webp                            webp;

              application/java-archive              jar war ear;
              application/mac-binhex40              hqx;
              application/msword                    doc;
              application/pdf                       pdf;
              application/postscript                ps eps ai;
              application/rtf                       rtf;
              application/vnd.ms-excel              xls;
              application/vnd.ms-powerpoint         ppt;
              application/vnd.wap.wmlc              wmlc;
              application/vnd.google-earth.kml+xml  kml;
              application/vnd.google-earth.kmz      kmz;
              application/x-7z-compressed           7z;
              application/x-cocoa                   cco;
              application/x-java-archive-diff       jardiff;
              application/x-java-jnlp-file          jnlp;
              application/x-makeself                run;
              application/x-perl                    pl pm;
              application/x-pilot                   prc pdb;
              application/x-rar-compressed          rar;
              application/x-redhat-package-manager rpm;
              application/x-sea                     sea;
              application/x-shockwave-flash         swf;
              application/x-stuffit                 sit;
              application/x-tcl                     tcl tk;
              application/x-x509-ca-cert            der pem crt;
              application/x-xpinstall               xpi;
              application/xhtml+xml                 xhtml;
              application/zip                       zip;

              application/octet-stream              bin exe dll;
              application/octet-stream              deb;
              application/octet-stream              dmg;
              application/octet-stream              iso img;
              application/octet-stream              msi msp msm;

              audio/midi                            mid midi kar;
              audio/mpeg                            mp3;
              audio/ogg                             ogg;
              audio/x-m4a                           m4a;
              audio/x-realaudio                     ra;

              video/3gpp                            3gpp 3gp;
              video/mp4                             mp4;
              video/mpeg                            mpeg mpg;
              video/quicktime                       mov;
              video/webm                            webm;
              video/x-flv                           flv;
              video/x-m4v                           m4v;
              video/x-mng                           mng;
              video/x-ms-asf                        asx asf;
              video/x-ms-wmv                        wmv;
              video/x-msvideo                       avi;
            }
          '';
        };
      };
    };

    # Traefik integration
    services.traefik.dynamicConfigOptions = mkIf cfg.traefik.enable {
      http.routers."personal-website-${cfg.domain}" = {
        rule = "Host(`${cfg.domain}`)";
        entryPoints = [ cfg.traefik.entryPoint ];
        service = "personal-website";
        tls = mkIf cfg.enableSSL {
          certResolver = "letsencrypt";
        };
      };
      
      http.services.personal-website.loadBalancer.servers = [{
        url = "http://127.0.0.1:${toString cfg.port}";
      }];
    };
  };
}