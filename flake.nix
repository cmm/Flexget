{
  description = "FlexGet";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self
    , nixpkgs
    , parts
    , poetry2nix
  }: parts.lib.mkFlake { inherit inputs; } {
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];

    perSystem = { pkgs, system, ... }: {
      packages.flexget = let
        p2n = import poetry2nix { pkgs = nixpkgs.legacyPackages.${system}; };
      in p2n.mkPoetryApplication {
        projectDir = ./.;

        postPatch = ''
          # we build using poetry, so don't actually need this.  also some
          # version specs differ beween it and pyproject.toml, which
          # causes problems when packing the wheel
          rm requirements.txt
        '';

        preferWheels = true;

        overrides = p2n.overrides.withDefaults (final: prev: let
          inherit (builtins) any filter hasAttr isAttrs map mapAttrs;

          addBuildInputs = p: add:
            p.overridePythonAttrs (old: {
              buildInputs = (map (x: final.${x}) add)
                            ++ (old.buildInputs or [ ]);
              doCheck = false;
            });

          removeBuildInputs = p: remove:
            p.overridePythonAttrs (old: let
              from = attr: {
                ${attr} = filter (x: !(isAttrs x) || !(hasAttr "pname" x) || !(any (y: x.pname == y) remove))
                  (old.${attr} or []);
              };
            in
              nixpkgs.lib.foldl (acc: attr: acc // (from attr)) { } [
                "buildInputs"
                "checkInputs"
                "nativeBuildInputs"
                "nativeCheckInputs"
                "optional-dependencies"
                "propagatedBuildInputs"
              ]);

          mkOverrides = mapAttrs (k: { add ? [], remove ? [], preferWheel ? null }:
            addBuildInputs (removeBuildInputs prev.${k} remove) add);
        in mkOverrides {
          "autocommand" = { add = ["setuptools"]; };
          "babelfish" = { add = ["poetry"]; };
          "codacy-coverage" = { add = ["setuptools"]; };
          "iniconfig" = { add = ["hatchling"]; };
          "filelock" = { add = ["hatchling"]; };
          "pathspec" = { add = ["flit-core"]; };
          "plumbum" = { add = ["hatchling"]; };
          "pyproject-hooks" = { add = ["flit-core"]; };
          "rebulk" = { add = ["pytest-runner"]; };
          "rpyc" = { add = ["hatchling"]; };
          "sphinx" = { add = ["flit-core"]; };
          "sqlalchemy" = { add = ["greenlet"]; };
          "sqlalchemy-stubs" = { add = ["setuptools"]; };
          "zxcvbn-python" = { add = ["setuptools"]; };
        }
        // {
          "markdown-it-py" = prev.markdown-it-py.override {
            preferWheel = false;
          };
        });
      };
      packages.default = self.packages.${system}.flexget;
      apps.default = {
        type = "app";
        program = "${pkgs.flexget}/bin/flexget";
      };

      devShells.default = self.packages.${system}.default.overrideAttrs (super: {
        nativeBuildInputs = super.nativeBuildInputs ++ [pkgs.poetry];
      });
    };
  };
}
