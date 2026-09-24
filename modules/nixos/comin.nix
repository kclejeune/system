{ inputs, ... }:
{
  # GitOps pull-deploy: each host switches to its own config whenever `deploy`
  # moves. Not master: promote.yml fast-forwards `deploy` only after CI passes,
  # so a red master never ships. Local `nh os switch` / deploy-rs holds only
  # until the next poll; test on `testing-<hostname>` (based on `deploy`),
  # which comin applies with `test`. Enrolled by homelab-node and directly by
  # gateway — never both for one host.
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

            `deploy` carries two signature formats and both have to be trusted
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
        # Via the overlay, so comin builds from this host's nixpkgs instead of
        # instantiating comin's own.
        nixpkgs.overlays = [ inputs.comin.overlays.default ];

        assertions = [
          {
            assertion = cfg.verifySignature -> cfg.allowedSigners != [ ];
            message = "services.cominGitops.verifySignature is on but allowedSigners is empty — every commit would be rejected.";
          }
        ];

        services.comin = {
          enable = lib.mkDefault true;

          # Prometheus may scrape this locally; deployment state should not be
          # exposed as an unauthenticated raw endpoint to every overlay peer.
          exporter.listen_address = "127.0.0.1";

          # https, not ssh: the repo is public, so there's no deploy key to
          # provision or rotate on five hosts.
          remotes = [
            {
              name = "origin";
              url = "https://github.com/kclejeune/system.git";
              branches.main.name = "deploy";
            }
          ];

          sshAllowedSignersPath = lib.mkIf cfg.verifySignature (
            toString (pkgs.writeText "comin-allowed-signers" (lib.concatLines cfg.allowedSigners))
          );

          # Vendored, not fetched: a key gating activation shouldn't be resolved from
          # a URL at build time. Holds the live and the expired web-flow keys (older
          # commits). Interpolated so it names a store path on the target.
          gpgPublicKeyPaths =
            lib.optional (cfg.verifySignature && cfg.trustGithubWebFlow)
              "${./assets/github-web-flow.asc}";
        };
      };
    };
}
