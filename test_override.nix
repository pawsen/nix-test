
# run this file with
# nix-build --no-out-link test_overlay.nix


# when overriding a python package set the "original Python package set" is always
# used as “super”. E.g., newly added packages via python.override disappear.
# -> python.override do not compose.
# See python3_2 which fails because the override makes python3_1 disappears from
# the package set.
let
  pkgs = import <nixpkgs> { };

  testHelloPkg = ({ stdenv, opt1 ? false }:
    stdenv.mkDerivation {
      pname = "hello";
      passthru = { inherit opt1;};
    });

  testPythonPkg = ({ buildPythonPackage, opt1 ? false }:
    buildPythonPackage {
      pname = "hello";
      version = "1";
      passthru = { inherit opt1;};
    });

  ## python
  # First override, original python package set
  python3_1 = pkgs.python3.override {
    packageOverrides = self: super: {
      hello = super.pkgs.callPackage testPythonPkg {
        inherit (super) buildPythonPackage;
      };
    };
  };

  # Second override. XXX: fails! python.override does not compose!
  # https://github.com/NixOS/nixpkgs/issues/44426
  python3_2 = python3_1.override {
    packageOverrides = self: super: {
      hello = super.hello.override { opt1 = true; };
    };
  };

  # third override
  python3_3 = pkgs.python3.override {
    packageOverrides = self: super: {
      hello = super.pkgs.callPackage testPythonPkg {
        inherit (super) buildPythonPackage;
        opt1 = true;
      };
    };
  };

  ## mkDerivation
  # https://nixos.org/manual/nixpkgs/stable/#sec-overlays-argument
  # hello1 = pkgs.callPackage testHelloPkg {};
  hello1 = pkgs.extend
    (self: super: { hello = super.callPackage testHelloPkg { }; });

  # could use `hello1.extend overlay` as well
  hello2 = hello1.appendOverlays
    [ (self: super: { hello = super.hello.override { opt1 = true; }; }) ];

in

assert builtins.all (value: builtins.trace value.pkgs.hello.opt1 true ) [
  python3_1
  # python3_2  # XXX: fails
  python3_3
];

assert builtins.all (value: builtins.trace value.pkgs.hello.opt1 true) [
   hello1
   hello2
 ];

# this evaluates to a list of empty sets. Thus uncommenting this would prevent
# any further lines in the file.
# (builtins.map (value: builtins.trace value.pkgs.hello.opt1 {}) [
#    hello1
#    hello2
#  ])

# expression needs to evaluate to a derivation (or a set or list of those)
# here we evaluate it to a empty set
{}
