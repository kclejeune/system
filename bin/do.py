import os
import subprocess
from enum import Enum
from typing import List

import platform
import typer

app = typer.Typer()


class FlakeOutputs(Enum):
    NIXOS = "nixosConfigurations"
    DARWIN = "darwinConfigurations"
    HOME_MANAGER = "homeConfigurations"


class Colors(Enum):
    SUCCESS = typer.colors.GREEN
    INFO = typer.colors.BLUE
    ERROR = typer.colors.RED


check_git = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True)
LOCAL_FLAKE = os.path.realpath(check_git.stdout.decode().strip())
REMOTE_FLAKE = "github:ldm/system"
is_local = check_git.returncode == 0 and os.path.isfile(
    os.path.join(LOCAL_FLAKE, "flake.nix")
)
FLAKE_PATH = LOCAL_FLAKE if is_local else REMOTE_FLAKE

UNAME = platform.uname()
check_nixos = subprocess.run(
    ["/usr/bin/env", "type", "nixos-rebuild"], capture_output=True
)
check_darwin = subprocess.run(
    ["/usr/bin/env", "type", "darwin-rebuild"], capture_output=True
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

USERNAME = subprocess.run(["id", "-un"], capture_output=True).stdout.decode().strip()
SYSTEM_ARCH = "aarch64" if UNAME.machine == "arm64" else UNAME.machine
SYSTEM_OS = UNAME.system.lower()
DEFAULT_HOST = f"{USERNAME}@{SYSTEM_ARCH}-{SYSTEM_OS}"


def fmt_command(cmd: List[str]):
    cmd_str = " ".join(cmd)
    return f"$ {cmd_str}"


def test_cmd(cmd: List[str]):
    return subprocess.run(cmd).returncode == 0


def run_cmd(cmd: List[str], shell=False):
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
        # "--extra-substituters",
        # "https://ldmsh.cachix.org",
    ]

    bootstrap_flake = REMOTE_FLAKE if remote else FLAKE_PATH
    if host is None:
        typer.secho("host unspecified", fg=Colors.ERROR.value)
        return

    if cfg is None:
        typer.secho("missing configuration", fg=Colors.ERROR.value)
    elif cfg == FlakeOutputs.NIXOS:
        typer.secho(
            "boostrap does not apply to nixos systems.",
            fg=Colors.ERROR.value,
        )
        raise typer.Abort()
    elif cfg == FlakeOutputs.DARWIN:
        # disk_setup()
        flake = f"{bootstrap_flake}#{cfg.value}.{host}.config.system.build.toplevel"
        run_cmd(["nix", "build", flake] + flags)
        run_cmd(
            f"./result/sw/bin/darwin-rebuild switch --flake {FLAKE_PATH}#{host}".split()
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
    help="builds the specified flake output; infers correct platform to use if not specified",
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
    nixos: bool = False,
    darwin: bool = False,
    home_manager: bool = False,
):
    cfg = select(nixos=nixos, darwin=darwin, home_manager=home_manager)
    if cfg is None:
        return
    elif cfg == FlakeOutputs.NIXOS:
        cmd = ["sudo", "nixos-rebuild", "build", "--flake"]
    elif cfg == FlakeOutputs.DARWIN:
        cmd = ["darwin-rebuild", "build", "--flake"]
    elif cfg == FlakeOutputs.HOME_MANAGER:
        cmd = ["home-manager", "build", "--flake"]
    else:
        typer.secho("could not infer system type.", fg=Colors.ERROR.value)
        raise typer.Abort()

    if remote:
        flake = f"{REMOTE_FLAKE}#{host}"
    else:
        flake = f"{FLAKE_PATH}#{host}"

    flags = ["--show-trace"]
    run_cmd(cmd + [flake] + flags)


@app.command(
    hidden=not is_local,
    help="remove previously built configurations and symlinks from the current directory",
)
def clean(
    filename: str = typer.Argument(
        "result", help="the filename to be cleaned, or '*' for all files"
    ),
):
    run_cmd(f"find . -type l -maxdepth 1 -name {filename} -exec rm {{}} +".split())


# @app.command(
#     hidden=PLATFORM != FlakeOutputs.DARWIN,
#     help="configure disk setup for nix-darwin",
# )
# def disk_setup():
#     if not test_cmd("grep -q ^run\\b /etc/synthetic.conf".split()):
#         APFS_UTIL = "/System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util"
#         typer.secho("setting up /etc/synthetic.conf", fg=Colors.INFO.value)
#         run_cmd(
#             "echo 'run\tprivate/var/run' | sudo tee -a /etc/synthetic.conf".split(),
#             shell=True,
#         )
#         run_cmd([APFS_UTIL, "-B"])
#         run_cmd([APFS_UTIL, "-t"])
#     if not test_cmd(["test", "-L", "/run"]):
#         typer.secho("linking /run directory", fg=Colors.INFO.value)
#         run_cmd("sudo ln -sfn private/var/run /run".split())
#     typer.secho("disk setup complete", fg=Colors.SUCCESS.value)


@app.command(
    help="run garbage collection on unused nix store paths",
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
):
    cmd = f"nix-collect-garbage --delete-older-than {delete_older_than} {'--dry-run' if dry_run else ''}"
    run_cmd(cmd.split())


@app.command(
    hidden=not is_local,
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


@app.command(help="pull changes from remote repo", hidden=not is_local)
def pull():
    cmd = f"git stash && git pull && git stash apply"
    run_cmd(cmd.split())


@app.command(
    help="builds and activates the specified flake output; infers correct platform to use if not specified",
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
    nixos: bool = False,
    darwin: bool = False,
    home_manager: bool = False,
):
    if not host:
        typer.secho("Error: host configuration not specified.", fg=Colors.ERROR.value)
        raise typer.Abort()

    cfg = select(nixos=nixos, darwin=darwin, home_manager=home_manager)
    if cfg is None:
        return
    elif cfg == FlakeOutputs.NIXOS:
        cmd = f"sudo nixos-rebuild switch --flake"
    elif cfg == FlakeOutputs.DARWIN:
        cmd = f"darwin-rebuild switch --flake"
    elif cfg == FlakeOutputs.HOME_MANAGER:
        cmd = f"home-manager switch --flake"
    else:
        typer.secho("could not infer system type.", fg=Colors.ERROR.value)
        raise typer.Abort()

    if remote:
        flake = f"{REMOTE_FLAKE}#{host}"
    else:
        flake = f"{FLAKE_PATH}#{host}"
    flags = ["--show-trace"]
    run_cmd(cmd.split() + [flake] + flags)


@app.command(hidden=not is_local, help="cache the output environment of flake.nix")
def cache(cache_name: str = "ldm"):
    cmd = f"nix flake archive --json | jq -r '.path,(.inputs|to_entries[].value.path)' | cachix push {cache_name}"
    run_cmd(cmd.split(), shell=True)


if __name__ == "__main__":
    app()
