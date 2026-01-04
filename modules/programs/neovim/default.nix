{ config, lib, system, pkgs, stable, vars, ... }:

let
  colors = import ../theming/colors.nix;

  # nvim-spell-nl-utf8-dictionary = builtins.fetchurl {
  #   url = "http://ftp.vim.org/vim/runtime/spell/nl.utf-8.spl";
  #   sha256 = "sha256:1v4knd9i4zf3lhacnkmhxrq0lgk9aj4iisbni9mxi1syhs4lfgni";
  # };

  # nvim-spell-nl-utf8-suggestions = builtins.fetchurl {
  #   url = "http://ftp.vim.org/vim/runtime/spell/nl.utf-8.sug";
  #   sha256 = "sha256:0clvhlg52w4iqbf5sr4bb3lzja2ch1dirl0963d5vlg84wzc809y";
  # };
in
{
  # # steam-run for codeium-vim
  # # start nvim in bash first time, so the spell files can be downloaded
  # programs.zsh.shellAliases = {
  #   vim = "${pkgs.steam-run}/bin/steam-run nvim";
  #   nvim = "${pkgs.steam-run}/bin/steam-run nvim";
  # };
  environment = {
    systemPackages = with pkgs; [
      go
      nodejs
      neovide
      (python3.withPackages (ps: with ps; [
        pip
      ]))
      ripgrep
      # zig
    ];
  };

  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    globals.mapleader = " ";

    opts = {
      number = true;
      relativenumber = true;
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      mouse = "a";
      clipboard = "unnamedplus";
      signcolumn = "yes";
      scrolloff = 8;
    };

    keymaps = [
      { key = "<C-s>"; action = "<CMD>w<CR>"; }
      { key = "<leader>q"; action = "<CMD>q<CR>"; }

      { key = "<leader>ff"; action = "<CMD>Telescope find_files<CR>"; }
      { key = "<leader>fg"; action = "<CMD>Telescope live_grep<CR>"; }

      { key = "<leader>e"; action = "<CMD>Neotree toggle<CR>"; }

      { key = "<leader>hs"; action = "<CMD>Gitsigns stage_hunk<CR>"; }
      { key = "<leader>hp"; action = "<CMD>Gitsigns preview_hunk<CR>"; }

      { key = "<leader>t"; action = "<CMD>ToggleTerm<CR>"; }

      { mode = "t"; key = "<Esc>"; action = "<C-\\><C-n>"; }
    ];

    plugins = {
      gitsigns.settings = {
        current_line_blame = true;
        delay = 500;
      };
      telescope.enable = true;
      neo-tree.enable = true;
      gitsigns.enable = true;

      web-devicons.enable = true;

      treesitter = {
        enable = true;
        settings.highlight.enable = true;
      };

      lsp = {
        enable = true;
        servers = {
          ts_ls.enable = true;
          html.enable = true;
          cssls.enable = true;
          tailwindcss.enable = true;
          eslint.enable = true;
        };
      };

      none-ls = {
        enable = true;
        sources.formatting.prettier = {
          enable = true;
          disableTsServerFormatter = true;
        };
      };

      cmp = {
        enable = true;
        settings.mapping."<Tab>" = "cmp.mapping.confirm({ select = true })";
        settings.sources = [
          { name = "nvim_lsp"; }
          { name = "buffer"; }
          { name = "path"; }
        ];
      };

      cmp-nvim-lsp.enable = true;
      cmp-buffer.enable = true;
      cmp-path.enable = true;

      toggleterm.enable = true;
    };
  };


  home-manager.users.${vars.user} = {
    # home.file.".local/share/nvim/site/spell/nl.utf-8.spl".source = nvim-spell-nl-utf8-dictionary;
    # home.file.".local/share/nvim/site/spell/nl.utf-8.sug".source = nvim-spell-nl-utf8-suggestions;
  };
}
