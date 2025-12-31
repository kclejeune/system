#! /usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11,<3.14"
# dependencies = [
#     "colorama",
#     "shellingham",
#     "typer",
# ]
# ///
import os
import platform
import subprocess
from enum import Enum

import typer

app = typer.Typer()


class FlakeOutputs(Enum):
    NIXOS = "nixosConfigurations"
    DARWIN = "darwinConfigurations"
    HOME_MANAGER = "homeConfigurations"


class NhPlatform(Enum):
    NIXOS = "os"
    DARWIN = "darwin"
    HOME_MANAGER = "home"


class Colors(Enum):
    SUCCESS = typer.colors.GREEN
    INFO = typer.colors.BLUE
    ERROR = typer.colors.RED


check_git = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True)
LOCAL_FLAKE = os.path.realpath(check_git.stdout.decode().strip())
REMOTE_FLAKE = "github:kclejeune/system"
is_local = check_git.returncode == 0 and os.path.isfile(
    os.path.join(LOCAL_FLAKE, "flake.nix")
)
FLAKE_PATH = LOCAL_FLAKE if is_local else REMOTE_FLAKE

UNAME = platform.uname()
check_nixos = subprocess.run(
    ["/usr/bin/env", "type", "/run/current-system/sw/bin/nixos-rebuild"],
    capture_output=True,
)
check_darwin = subprocess.run(
    ["/usr/bin/env", "type", "/run/current-system/sw/bin/darwin-rebuild"],
    capture_output=True,
)
if check_nixos.returncode == 0:
    # if we're on nixos, this command is built in
    PLATFORM = FlakeOutputs.NIXOS
elif check_darwin.returncode == 0 or UNAME.system.lower() == "darwin":
    # if we're on darwin, we might have darwin-rebuild or the distro id will be 'darwin'
    PLATFORM = FlakeOutputs.DARWIN
else:
    # in all other cases of linux
    PLATFORM = FlakeOutputs.HOME_MANAGER

USERNAME = os.getenv(
    "USER", subprocess.run(["id", "-un"], capture_output=True).stdout.decode().strip()
)
SYSTEM_ARCH = "aarch64" if UNAME.machine == "arm64" else UNAME.machine
SYSTEM_OS = UNAME.system.lower()
DEFAULT_HOST = f"{USERNAME}@{SYSTEM_ARCH}-{SYSTEM_OS}"


def get_nh_platform(cfg: FlakeOutputs) -> str:
    """Map FlakeOutputs to nh subcommand."""
    mapping = {
        FlakeOutputs.NIXOS: "os",
        FlakeOutputs.DARWIN: "darwin",
        FlakeOutputs.HOME_MANAGER: "home",
    }
    return mapping[cfg]


def fmt_command(cmd: list[str]):
    cmd_str = " ".join(cmd)
    return f"$ {cmd_str}"


def test_cmd(cmd: list[str]):
    out = subprocess.run(cmd)
    if out.returncode == 0:
        return True
    else:
        typer.secho(fmt_command(cmd), fg=Colors.ERROR.value)
        typer.secho(
            f"command failed with return code {out.returncode}", fg=Colors.ERROR.value
        )


def run_cmd(cmd: list[str], shell=False):
    typer.secho(fmt_command(cmd), fg=Colors.INFO.value)
    return (
        subprocess.run(" ".join(cmd), shell=True)
        if shell
        else subprocess.run(cmd, shell=False)
    )


def select(nixos: bool, darwin: bool, home_manager: bool):
    if sum([nixos, darwin, home_manager]) > 1:
        typer.secho(
            "cannot apply more than one of [--nixos, --darwin, --home-manager]. aborting...",
            fg=Colors.ERROR.value,
        )
        raise typer.Abort()

    if nixos:
        return FlakeOutputs.NIXOS
    elif darwin:
        return FlakeOutputs.DARWIN
    elif home_manager:
        return FlakeOutputs.HOME_MANAGER
    else:
        return PLATFORM


@app.command(
    help="builds an initial configuration",
    hidden=PLATFORM == FlakeOutputs.NIXOS,
)
def bootstrap(
    host: str = typer.Argument(
        DEFAULT_HOST, help="the hostname of the configuration to build"
    ),
    remote: bool = typer.Option(
        default=False,
        hidden=not is_local,
        help="whether to fetch current changes from the remote",
    ),
    nixos: bool = False,
    darwin: bool = False,
    home_manager: bool = False,
):
    cfg = select(nixos=nixos, darwin=darwin, home_manager=home_manager)
    flags = [
        "-v",
        "--experimental-features",
        "nix-command flakes",
        "--extra-substituters",
        "https://kclejeune.cachix.org",
    ]

    bootstrap_flake = REMOTE_FLAKE if remote else FLAKE_PATH
    if cfg is None:
        typer.secho("missing configuration", fg=Colors.ERROR.value)
    elif cfg == FlakeOutputs.NIXOS:
        typer.secho(
            "bootstrap does not apply to nixos systems.",
            fg=Colors.ERROR.value,
        )
        raise typer.Abort()
    elif cfg == FlakeOutputs.DARWIN:
        flake = f"{bootstrap_flake}#{cfg.value}.{host}.config.system.build.toplevel"
        run_cmd(["nix", "build", flake] + flags)
        run_cmd(
            f"sudo ./result/sw/bin/darwin-rebuild switch --flake {FLAKE_PATH}#{host}".split()
        )
    elif cfg == FlakeOutputs.HOME_MANAGER:
        flake = f"{bootstrap_flake}#{host}"
        run_cmd(
            ["nix", "run"]
            + flags
            + [
                "github:nix-community/home-manager",
                "--no-write-lock-file",
                "--",
                "switch",
                "--flake",
                flake,
                "-b",
                "backup",
            ]
        )
    else:
        typer.secho("could not infer system type.", fg=Colors.ERROR.value)
        raise typer.Abort()


@app.command(
    help="builds the specified flake output using nh; infers correct platform to use if not specified",
)
def build(
    host: str = typer.Argument(
        DEFAULT_HOST, help="the hostname of the configuration to build"
    ),
    remote: bool = typer.Option(
        default=False,
        hidden=not is_local,
        help="whether to fetch current changes from the remote",
    ),
    update: bool = typer.Option(
        default=False,
        help="update all flake inputs before building",
    ),
    nixos: bool = False,
    darwin: bool = False,
    home_manager: bool = False,
):
    cfg = select(nixos=nixos, darwin=darwin, home_manager=home_manager)
    if cfg is None:
        typer.secho("could not infer system type.", fg=Colors.ERROR.value)
        raise typer.Abort()

    nh_platform = get_nh_platform(cfg)
    flake = REMOTE_FLAKE if remote else FLAKE_PATH

    # nh home uses -c for configuration name, nh os/darwin use -H for hostname
    host_flag = "-c" if cfg == FlakeOutputs.HOME_MANAGER else "-H"
    cmd = ["nh", nh_platform, "build", flake, host_flag, host]
    if update:
        cmd.append("--update")
    cmd.extend(["--", "--show-trace"])

    run_cmd(cmd)


@app.command(
    help="run garbage collection using nh clean",
    no_args_is_help=True,
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
    all_profiles: bool = typer.Option(
        False,
        "--all",
        "-a",
        help="clean all profiles (requires root)",
    ),
):
    if all_profiles:
        cmd = ["nh", "clean", "all", "--keep-since", delete_older_than]
    else:
        cmd = ["nh", "clean", "user", "--keep-since", delete_older_than]

    if dry_run:
        cmd.append("--dry")

    run_cmd(cmd)


@app.command(
    hidden=not is_local,
    help="update all flake inputs or optionally specific flakes",
)
def update(
    flake: list[str] = typer.Option(
        None,
        "--flake",
        "-f",
        metavar="[FLAKE]",
        help="specify an individual flake to be updated",
    ),
    commit: bool = typer.Option(False, help="commit the updated lockfile"),
):
    flags = ["--commit-lock-file"] if commit else []
    if not flake:
        typer.secho("updating all flake inputs")
        run_cmd(["nix", "flake", "update"] + flags)
    else:
        inputs = []
        for input in flake:
            inputs.append("--update-input")
            inputs.append(input)
        typer.secho(f"updating {', '.join(flake)}")
        run_cmd(["nix", "flake", "lock"] + inputs + flags)


@app.command(
    help="builds and activates the specified flake output using nh; infers correct platform to use if not specified",
)
def switch(
    host: str = typer.Argument(
        DEFAULT_HOST,
        help="the hostname of the configuration to build",
    ),
    remote: bool = typer.Option(
        default=False,
        hidden=not is_local,
        help="whether to fetch current changes from the remote",
    ),
    update: bool = typer.Option(
        default=False,
        help="update all flake inputs before switching",
    ),
    nixos: bool = False,
    darwin: bool = False,
    home_manager: bool = False,
):
    if not host:
        typer.secho("Error: host configuration not specified.", fg=Colors.ERROR.value)
        raise typer.Abort()

    cfg = select(nixos=nixos, darwin=darwin, home_manager=home_manager)
    if cfg is None:
        typer.secho("could not infer system type.", fg=Colors.ERROR.value)
        raise typer.Abort()

    nh_platform = get_nh_platform(cfg)
    flake = REMOTE_FLAKE if remote else FLAKE_PATH

    # nh home uses -c for configuration name, nh os/darwin use -H for hostname
    host_flag = "-c" if cfg == FlakeOutputs.HOME_MANAGER else "-H"
    cmd = ["nh", nh_platform, "switch", flake, host_flag, host]
    if update:
        cmd.append("--update")
    cmd.extend(["--", "--show-trace"])

    run_cmd(cmd)


if __name__ == "__main__":
    app()
