# Global CLAUDE.md

## User Profile

- Senior/staff-level software engineer
- Primary languages: Go, Nix, Rust, TypeScript/Svelte
- macOS (Darwin) primary workstation; deploys to NixOS (Hetzner VPS)

## Environment & Tooling

### Nix

- **Always use `nh` for build/switch operations**, never raw `nix` commands for system management:
  - `nh os switch` (NixOS), `nh darwin switch` (nix-darwin), `nh home switch` (home-manager)
- Uses Nix flakes exclusively (no channels)
- Prefer idiomatic NixOS module options over raw `extraConfig` blocks
- Secrets management: **sops-nix** with age keys (not agenix)
- Firewall: **nftables** (not iptables)

### SSH & Secrets

- **1Password SSH agent** — private keys are NEVER on disk. Do not assume key files exist at `~/.ssh/id_*`. The SSH agent socket is managed by 1Password.
- Never print secrets, tokens, or passwords to terminal output. Write them to files or use sops.

### Go

- Go 1.24+, use stdlib packages (`slices`, `strings`, `maps`) over custom helpers
- `mise run check` is the canonical lint+build gate
- `golangci-lint` for linting; `goreleaser` for releases
- `fmt.Println` for user-facing CLI output, not `slog` (no timestamps in CLI tools)
- Enum types over plain strings; `reflect.DeepEqual` when appropriate

## Code Style Preferences

- Self-documenting code; comments only where logic isn't self-evident
- Terse, non-trivial comments only — no boilerplate docstrings on obvious code
- Concise naming without unnecessary prefixes
- No backwards-compatibility shims unless explicitly requested — just change the code
- No speculative abstractions or premature generalization

## Behavioral Preferences

- **Don't over-scope changes.** Only modify what was explicitly asked about. Don't touch surrounding code, add features, or "clean up" adjacent code.
- **Don't over-engineer.** No extra config flags, compatibility layers, or abstractions for hypothetical future needs.
- **Verify before acting.** When configuring a new service or unfamiliar system, check the actual NixOS module options or upstream docs before guessing at config structure.
- **Run linters/checks before declaring done.** Code should pass the project's lint gate on the first attempt — don't leave that as a follow-up.
- **Prefer the project's existing patterns.** Match the conventions already in use (file structure, naming, module organization) rather than introducing new ones.
