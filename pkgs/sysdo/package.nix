{pkgs, ...}: pkgs.writeShellScriptBin "sysdo" "${pkgs.uv}/bin/uv run -q ${./sysdo.py} $@"
