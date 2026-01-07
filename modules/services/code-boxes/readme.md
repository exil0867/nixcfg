## code-boxes

Profile-based isolation for VSCodium.
## Behavior

Invocation rules:

```
code-box
```

Launches Codium using the default profile.

```
code-box <box>
```

Launches Codium with the specified profile and opens `$HOME/Develop`.

```
code-box <box> <path>
```

Launches Codium with the specified profile and opens the resolved path.
## Implementation

`default.nix`
Declares VSCodium profiles and installs the launcher.

`code-box.sh`
Selects the profile, resolves the path, and execs `codium`.