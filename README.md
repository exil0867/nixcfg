# NixOS Configuration

This repository contains my personal NixOS configuration files.

The migration of my devices and home server to NixOS is still in progress. The goal of this project is to rewrite everything I run in a declarative way.

## Usage

After the installation, you can customize your NixOS configuration by editing the Nix files. Here are some common commands:

- To switch to a new configuration:

```bash
sudo nixos-rebuild switch --flake <path>#<host>
```

## Contributing

If you'd like to contribute to this configuration, feel free to open an issue or submit a pull request. Contributions are always welcome!

## License

This project is licensed under the GPLv3 License. See the [LICENSE](LICENSE) file for details.
