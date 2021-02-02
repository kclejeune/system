#! /usr/bin/env python3

import os
from enum import Enum
from typing import List

import platform
import typer

app = typer.Typer()


class FlakeOutputs(Enum):
    NIXOS = "nixosConfigurations"
    DARWIN = "darwinConfigurations"
    HOME_MANAGER = "homeManagerConfigurations"


class Colors(Enum):
    SUCCESS = typer.colors.GREEN
    INFO = typer.colors.BLUE
    ERROR = typer.colors.RED


if os.system("command -v nixos-rebuild > /dev/null") == 0:
    # if we're on nixos, this command is built in
    PLATFORM = FlakeOutputs.NIXOS
elif (
    os.system("command -v darwin-rebuild > /dev/null") == 0
    or platform.uname().system.lower() == "darwin".lower()
):
    # if we're on darwin, we might have darwin-rebuild or the distro id will be 'darwin'
    PLATFORM = FlakeOutputs.DARWIN
else:
    # in all other cases of linux
    PLATFORM = FlakeOutputs.HOME_MANAGER


def fmt_command(cmd: str):
    return f"> {cmd}"


def test_cmd(cmd: str):
    return os.system(f"{cmd} > /dev/null") == 0


def run_cmd(cmd: str):
    typer.secho(fmt_command(cmd), fg=Colors.INFO.value)
    return os.system(cmd)


def select(nixos: bool, darwin: bool, home_manager: bool):
    if sum([nixos, darwin, home_manager]) > 1:
        typer.secho(
            "cannot apply more than one of [--nixos, --darwin, --home-manager]. aborting...",
            fg=Colors.ERROR.value,
        )
        return None

    if nixos:
        return FlakeOutputs.NIXOS
    elif darwin:
        return FlakeOutputs.DARWIN
    elif home_manager:
        return FlakeOutputs.HOME_MANAGER
    else:
        return PLATFORM


@app.command(
    help="builds an initial configuration", hidden=PLATFORM == FlakeOutputs.NIXOS
)
def bootstrap(
    host: str = typer.Argument(None, help="the hostname of the configuration to build"),
    nixos: bool = False,
    darwin: bool = False,
    home_manager: bool = False,
):
    cfg = select(nixos=nixos, darwin=darwin, home_manager=home_manager)
    flags = "-v --experimental-features 'flakes nix-command'"
    if cfg is None:
        return
    elif cfg == FlakeOutputs.NIXOS:
        typer.secho(
            "boostrap does not apply to nixos systems. aborting...",
            fg=Colors.ERROR.value,
        )
    elif cfg == FlakeOutputs.DARWIN:
        flake = f".#{host}"
        diskSetup()
        flake = f".#{cfg.value}.{host}.config.system.build.toplevel {flags}"
        run_cmd(f"nix build {flake} ")
        run_cmd("./result/activate-user && ./result/activate")
    elif cfg == FlakeOutputs.HOME_MANAGER:
        flags = "-v --experimental-features 'flakes nix-command'"
        flake = f".#{FlakeOutputs.HOME_MANAGER.value}.{host}.activationPackage"
        run_cmd(f"nix build {flake} {flags}")
        run_cmd("./result/activate")
    else:
        typer.secho("could not infer system type. aborting...", fg=Colors.ERROR.value)


@app.command(
    help="builds the specified flake output; infers correct platform to use if not specified",
    no_args_is_help=True,
)
def build(
    host: str = typer.Argument(None, help="the hostname of the configuration to build"),
    nixos: bool = False,
    darwin: bool = False,
    home_manager: bool = False,
):
    cfg = select(nixos=nixos, darwin=darwin, home_manager=home_manager)
    if cfg is None:
        return
    elif cfg == FlakeOutputs.NIXOS:
        flake = f".#{host}"
        run_cmd(f"sudo nixos-rebuild build --flake {flake} --show-trace")
    elif cfg == FlakeOutputs.DARWIN:
        flake = f".#{host}"
        run_cmd(f"darwin-rebuild build --flake {flake} --show-trace")
    elif cfg == FlakeOutputs.HOME_MANAGER:
        flags = "-v --experimental-features 'flakes nix-command'"
        flake = f".#{FlakeOutputs.HOME_MANAGER.value}.{host}.activationPackage"
        run_cmd(f"nix build {flake} {flags}")
    else:
        typer.secho("could not infer system type. aborting...", fg=Colors.ERROR.value)


@app.command(
    help="remove previously built configurations and symlinks from the current directory",
)
def clean():
    run_cmd("for i in *; do [[ -L $i ]] && rm -f $i; done")


@app.command(
    help="configure disk setup for nix-darwin",
    hidden=PLATFORM != FlakeOutputs.DARWIN,
)
def diskSetup():
    if PLATFORM != FlakeOutputs.DARWIN:
        typer.secho(
            "nix-darwin does not apply on this platform. aborting...",
            fg=Colors.ERROR.value,
        )
        return

    if not test_cmd("grep -q '^run\\b' /etc/synthetic.conf 2>/dev/null"):
        typer.secho("setting up /etc/synthetic.conf", fg=Colors.INFO.value)
        run_cmd(
            'echo -e "run\\tprivate/var/run" | sudo tee -a /etc/synthetic.conf >/dev/null'
        )
        run_cmd(
            "/System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -B 2>/dev/null || true"
        )
        run_cmd(
            "/System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t 2>/dev/null || true"
        )

    if not test_cmd("test -L /run"):
        typer.secho("linking /run directory", fg=Colors.INFO.value)
        run_cmd("sudo ln -sfn private/var/run /run")

    typer.secho("disk setup complete", fg=Colors.SUCCESS.value)


@app.command(help="run formatter on all nix files")
def fmt():
    cmd = "nixfmt **/*.nix"
    run_cmd(cmd)


@app.command(
    help="run garbage collection on unused nix store paths", no_args_is_help=True
)
def gc(
    delete_older_than: str = typer.Option(
        None,
        "--delete-older-than",
        "-d",
        metavar="[AGE]",
        help="specify minimum age for deleting store paths",
    ),
    dry_run: bool = typer.Option(False, help="test the result of garbage collection"),
):
    cmd = f"nix-collect-garbage --delete-older-than {delete_older_than} {'--dry-run' if dry_run else ''}"
    run_cmd(cmd)


@app.command(
    help="builds and activates the specified flake output; infers correct platform to use if not specified",
    no_args_is_help=True,
)
def switch(
    host: str = typer.Argument(
        default=None, help="the hostname of the configuration to build"
    ),
    nixos: bool = False,
    darwin: bool = False,
    home_manager: bool = False,
):
    if not host:
        typer.secho("Error: host configuration not specified.", fg=Colors.ERROR.value)
    else:
        cfg = select(nixos=nixos, darwin=darwin, home_manager=home_manager)
        if cfg is None:
            return
        elif cfg == FlakeOutputs.NIXOS:
            flake = f".#{host}"
            cmd = f"sudo nixos-rebuild switch --flake {flake} --show-trace"
            run_cmd(cmd)
        elif cfg == FlakeOutputs.DARWIN:
            flake = f".#{host}"
            cmd = f"darwin-rebuild switch --flake {flake} --show-trace"
            run_cmd(cmd)
        elif cfg == FlakeOutputs.HOME_MANAGER:
            flags = "-v --experimental-features 'flakes nix-command'"
            flake = f".#{cfg.value}.{host}.activationPackage"
            cmd = f"nix build {flake} {flags} && ./result/activate"
            run_cmd(cmd)
        else:
            typer.secho(
                "could not infer system type. aborting...", fg=Colors.ERROR.value
            )


@app.command(
    help="update all flake inputs or optionally specific flakes",
)
def update(
    flake: List[str] = typer.Option(
        None,
        "--flake",
        "-f",
        metavar="[FLAKE]",
        help="specify an individual flake to be updated",
    ),
    commit: bool = typer.Option(False, help="commit the updated lockfile"),
):
    flags = "--commit-lock-file" if commit else ""
    if not flake:
        typer.secho("updating all flake inputs")
        cmd = f"nix flake update --recreate-lock-file {flags}"
        run_cmd(cmd)
    else:
        for input in flake:
            typer.secho(f"updating {input}")
            cmd = f"nix flake update --update-input {input} {flags}"
            run_cmd(cmd)

@app.command(help="cache the output environment of flake.nix")
def cache(cache_name: str = "kclejeune"):
    cmd = f"nix flake archive --json | jq -r '.path,(.inputs|to_entries[].value.path)' | cachix push {cache_name}"
    run_cmd(cmd)

if __name__ == "__main__":
    app()
