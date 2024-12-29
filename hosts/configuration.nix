
{ lib, config, nixpkgs-channel, system-definition, inputs, vars, ... }:

let
  terminal = system-definition.${vars.terminal};
  moduleImports = import ../modules/desktops ++
                  import ../modules/hardware ++
                  import ../modules/programs ++
                  import ../modules/services ++
                  import ../modules/shell ++
                  import ../modules/theming;
in
{
  
  imports = moduleImports ++ [ inputs.agenix.nixosModules.default {
          age.secrets."tailscale/preauth-kairos".file = builtins.path {
            name = "secrets";
            path = ../secrets/tailscale/preauth-kairos.age;
          };
          age.identityPaths = [ "/home/${vars.user}/.ssh/id_ed25519" ];
        } ];



  boot = {
    tmp = {
      cleanOnBoot = true;
      tmpfsSize = "5GB";
    };
    # kernelPackages = pkgs.linuxPackages_latest;
  };

  users.users.${vars.user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "audio" "camera" "networkmanager" ];

  };

  time.timeZone = "Africa/Tunis";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "ar_TN.UTF-8";
      LC_IDENTIFICATION = "ar_TN.UTF-8";
      LC_MEASUREMENT = "ar_TN.UTF-8";
      LC_MONETARY = "ar_TN.UTF-8";
      LC_NAME = "ar_TN.UTF-8";
      LC_NUMERIC = "ar_TN.UTF-8";
      LC_PAPER = "ar_TN.UTF-8";
      LC_TELEPHONE = "ar_TN.UTF-8";
      LC_TIME = "ar_TN.UTF-8";
    };
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  security = {
    rtkit.enable = true;
    polkit.enable = true;
    sudo.wheelNeedsPassword = false;
  };

  fonts.packages = with system-definition; [
    carlito # NixOS
    vegur # NixOS
    source-code-pro
    jetbrains-mono
    font-awesome # Icons
    corefonts # MS
    noto-fonts # Google + Unicode
    noto-fonts-cjk-sans
    noto-fonts-emoji
    nerd-fonts.fira-mono
  ];

  environment = {
    variables = {
      TERMINAL = "${vars.terminal}";
      EDITOR = "${vars.editor}";
      VISUAL = "${vars.editor}";
    };
    systemPackages = with system-definition; [
      age
      inputs.agenix.packages.${system}.default
      gnupg
      gh
      btop # Resource Manager
      # cifs-utils # Samba
      coreutils # GNU Utilities
      git # Version Control
      # gvfs # Samba
      killall # Process Killer
      lshw # Hardware Config
      nano # Text Editor
      nix-tree # Browse Nix Store
      pciutils # Manage PCI
      # ranger # File Manager
      # smartmontools # Disk Health
      tldr # Helper
      # usbutils # Manage USB
      wget # Retriever
      xdg-utils # Environment integration
      thefuck

      # Video/Audio
      alsa-utils # Audio Control
      linux-firmware # Proprietary Hardware Blob
      mpv # Media Player
      pavucontrol # Audio Control
      pipewire # Audio Server/Control
      pulseaudio # Audio Server/Control
      qpwgraph # Pipewire Graph Manager
      remmina # XRDP & VNC Client

      neovim

      # Other Packages Found @
      # - ./<host>/default.nix
      # - ../modules
    ];
  };

  programs = {
    dconf.enable = true;
    gnupg.agent = {
      enable = true;
    };
  };

  hardware.pulseaudio.enable = false;
  services = {
    printing = {
      enable = true;
    };
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      jack.enable = true;
    };
    # openssh = {
    #   enable = true;
    #   allowSFTP = true;
    #   extraConfig = ''
    #     HostKeyAlgorithms +ssh-rsa
    #   '';
    # };
  };

  # flatpak.enable = true;

  nix = {
    settings = {
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 2d";
    };
    # package = pkgs.nixVersions.latest;
    registry.nixpkgs.flake = nixpkgs-channel;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs          = true
      keep-derivations      = true
    '';
  };
  nixpkgs.config.allowUnfree = true;

  system = {
    # autoUpgrade = {
    #   enable = true;
    #   channel = "https://nixos.org/channels/nixos-unstable";
    # };
    stateVersion = "24.11";
  };

  home-manager.users.${vars.user} = {
    home = {
      stateVersion = "24.11";
    };
    programs = {
      ssh = {
        extraConfig = ''
          Host n0t3x1l
            HostName server.n0t3x1l.ovh
            User exilvm
        '';
      };
      home-manager.enable = true;
      zsh = {
        enable = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;

        shellAliases = {
          ll = "ls -l";
          update = "sudo nixos-rebuild switch";
        };
        history = {
          size = 10000;
        };
        oh-my-zsh = {
          enable = true;
          plugins = [ "git" "thefuck" ];
          theme = "robbyrussell";
        };
      };
    };
    xdg = {
      mime.enable = true;
      mimeApps = {
        enable = true;
        defaultApplications = {
          "application/pdf" = [  "librewolf.desktop" ];
          "x-scheme-handler/http" = [ "librewolf.desktop"  ];
          "x-scheme-handler/https" = [ "librewolf.desktop"  ];
          "x-scheme-handler/about" = [ "librewolf.desktop" ];
          "x-scheme-handler/unknown" = [ "librewolf.desktop" ];
      #     # "image/jpeg" = [ "image-roll.desktop" "feh.desktop" ];
      #     # "image/png" = [ "image-roll.desktop" "feh.desktop" ];
      #     # "text/plain" = "nvim.desktop";
      #     # "text/html" = "nvim.desktop";
      #     # "text/csv" = "nvim.desktop";
      #     # "application/zip" = "org.gnome.FileRoller.desktop";
      #     # "application/x-tar" = "org.gnome.FileRoller.desktop";
      #     # "application/x-bzip2" = "org.gnome.FileRoller.desktop";
      #     # "application/x-gzip" = "org.gnome.FileRoller.desktop";
      #     # "x-scheme-handler/mailto" = [ "gmail.desktop" ];
      #     "audio/mp3" = "mpv.desktop";
      #     "audio/x-matroska" = "mpv.desktop";
      #     "video/webm" = "mpv.desktop";
      #     "video/mp4" = "mpv.desktop";
      #     "video/x-matroska" = "mpv.desktop";
      #     # "inode/directory" = "pcmanfm.desktop";
        };
      };
      # desktopEntries.image-roll = {
      #   name = "image-roll";
      #   exec = "${stable.image-roll}/bin/image-roll %F";
      #   mimeType = [ "image/*" ];
      # };
      # desktopEntries.gmail = {
      #   name = "Gmail";
      #   exec = ''xdg-open "https://mail.google.com/mail/?view=cm&fs=1&to=%u"'';
      #   mimeType = [ "x-scheme-handler/mailto" ];
      # };
    };
  };
}
