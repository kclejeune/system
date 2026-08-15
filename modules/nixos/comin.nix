{ inputs, ... }:
{
  # GitOps pull-deploy. Each host polls github.com/kclejeune/system and runs
  # `switch` on its own `nixosConfigurations.<hostname>` whenever master moves,
  # which inverts the deploy model: deploy-rs stops being the normal path and
  # becomes break-glass for when a host can't reach GitHub or master is broken.
  #
  # Two consequences worth internalising before enrolling a host:
  #
  #   - Uncommitted local state has no standing. Activating something with
  #     `nh os switch` or deploy-rs holds only until the next poll, then master
  #     wins. Test on the per-host `testing-<hostname>` branch instead — comin
  #     watches it by default and applies it with `test`, so it never becomes
  #     the boot default.
  #   - CI is racing the poller. build.yml pushes master's closure to
  #     cache.kclj.io, but comin polls every 60s and CI takes minutes, so the
  #     first host to notice a commit generally builds it locally. Fine on the
  #     P3 Tinys; gateway is the small one.
  #
  # Enrolled by homelab-node (haven/forge/vault/atlas) and directly by
  # gateway's module list in flake.nix. Never both for one host — see the
  # double-import trap in CLAUDE.md.
  flake.nixosModules.comin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.cominGitops;
    in
    {
      imports = [ inputs.comin.nixosModules.comin ];

      options.services.cominGitops = {
        verifySignature = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Refuse to deploy a tip commit that isn't signed by a trusted key.
            Without it the only thing standing between a stolen GitHub
            credential and root on five machines is the push ACL.

            Master carries two signature formats and both have to be trusted
            or deploys stall, because comin checks whichever commit is at the
            tip and nothing else:

              - Yours are SSH, made by the 1password signer, and verify
                against `identity.sshSigningKey` — see `allowedSigners`.
              - Dependabot's flake.lock bumps are merged through GitHub's UI
                and land PGP-signed by the web-flow key as
                `noreply@github.com` — see `trustGithubWebFlow`.

            Fails closed: an untrusted tip means no deployment, not a
            deployment of the wrong thing.
          '';
        };

        trustGithubWebFlow = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Trust GitHub's web-flow PGP key, which is what signs anything
            merged through the web UI — dependabot's lock bumps included.
            Turning it off means dependabot commits can never be a deploy tip,
            so their PRs have to be merged locally under your own signature.

            Note this trusts the *mechanism*, not dependabot specifically: any
            commit GitHub's UI can produce on your behalf carries this key.
          '';
        };

        allowedSigners = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = lib.optional (
            config.identity.enable && config.identity.sshSigningKey != null
          ) "${config.identity.email} ${config.identity.sshSigningKey}";
          defaultText = lib.literalExpression ''[ "\${config.identity.email} \${config.identity.sshSigningKey}" ]'';
          description = ''
            OpenSSH allowed-signers lines, `<principal> <keytype> <key>`. The
            principal is matched against the *committer* address, not the
            author's — a rebased or web-merged commit keeps your authorship
            while GitHub takes over as committer, and that's the field that
            decides. comin accepts key entries and `namespaces=`; any other
            allowed-signers option is rejected outright.
          '';
        };
      };

      config = {
        # Upstream's module defaults its package to `pkgs.comin`, falling back
        # to comin's own `packages.<system>`. Taking the overlay makes the
        # first branch hit, so the binary comes from this host's nixpkgs
        # instead of instantiating comin's — merges with the overlay list from
        # _lib.nix's mkNixpkgsArgs rather than replacing it.
        nixpkgs.overlays = [ inputs.comin.overlays.default ];

        assertions = [
          {
            assertion = cfg.verifySignature -> cfg.allowedSigners != [ ];
            message = "services.cominGitops.verifySignature is on but allowedSigners is empty — every commit would be rejected.";
          }
        ];

        services.comin = {
          enable = lib.mkDefault true;

          # https, not ssh: the repo is public, so there's no deploy key to
          # provision or rotate on five hosts.
          remotes = [
            {
              name = "origin";
              url = "https://github.com/kclejeune/system.git";
              branches.main.name = "master";
            }
          ];

          sshAllowedSignersPath = lib.mkIf cfg.verifySignature (
            toString (pkgs.writeText "comin-allowed-signers" (lib.concatLines cfg.allowedSigners))
          );

          # Vendored rather than fetched: comin wants a path, and a key that
          # gates activation on five machines shouldn't be resolved at build
          # time from a URL. Contains both web-flow keys — the live
          # B5690EEEBB952194 and the expired 4AEE18F83AFDEB23 that signed
          # older commits still in this history.
          # Interpolated, not `toString`: the option takes strings, and this
          # has to name a store path that exists on the target, not a path in
          # someone's checkout.
          gpgPublicKeyPaths =
            lib.optional (cfg.verifySignature && cfg.trustGithubWebFlow)
              "${./assets/github-web-flow.asc}";
        };
      };
    };
}
