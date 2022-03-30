{ config, lib, pkgs, ... }: {
  user.name = "lejeukc1";
  hm = { imports = [ ./home-manager/work.nix ]; };

  security.pki.certificateFiles =
    let
      isValidCertFile = (validExtensions: key: value:
        value == "regular" &&
        (builtins.match "^.*\.(${lib.concatStringsSep "|" validExtensions})$" key) != null);
      getCertFiles = validExtensions: path:
        builtins.map (f: "${path}/${f}") (lib.optionals (lib.pathExists path)
          (lib.attrNames
            (lib.attrsets.filterAttrs (isValidCertFile validExtensions)
              (builtins.readDir path))));
    in
    [ "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ]
    ++ (builtins.concatMap (getCertFiles [ "cer" "crt" "pem" ]) [ "/etc/certs.d" ]);
}
