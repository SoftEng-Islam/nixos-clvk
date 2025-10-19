{
  description = "Standalone CLVK package";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    clvk-src = {
      url = "git+https://github.com/kpet/clvk.git?submodules=1";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, clvk-src }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems
        (system: let pkgs = nixpkgs.legacyPackages.${system}; in f pkgs);
    in {
      packages = forAllSystems (pkgs: {
        default = pkgs.stdenv.mkDerivation {
          pname = "clvk";
          version = "git";

          src = clvk-src;

          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            python3
            shaderc
            glslang
          ];
          buildInputs = with pkgs.llvmPackages_19;
            with pkgs; [
              llvm
              clang-unwrapped
              clang-unwrapped.lib
              vulkan-headers
              vulkan-loader
            ];

          cmakeFlags =
            [ "-DCLVK_BUILD_TESTS=OFF" "-DCLVK_CLSPV_ONLINE_COMPILER=OFF" ];

          postInstall = ''
            mkdir -p $out/etc/OpenCL/vendors
            echo $out/libOpenCL.so > $out/etc/OpenCL/vendors/clvk.icd
          '';
        };
      });

      # Provide a simple devShell with OpenCL tools
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            self.packages.${pkgs.system}.default
            clinfo
            khronos-ocl-icd-loader
            opencl-headers
          ];
          shellHook = ''
            export OCL_ICD_VENDORS="${
              self.packages.${pkgs.system}.default
            }/etc/OpenCL/vendors"
            echo "CLVK shell ready"
          '';
        };
      });
    };
}
