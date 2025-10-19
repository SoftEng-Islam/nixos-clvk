{
  description = "Standalone CLVK package (fixed for Nix)";

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
            git
            shaderc
            glslang
          ];

          buildInputs = with pkgs.llvmPackages_19;
            with pkgs; [
              llvm
              clang-unwrapped
              vulkan-headers
              vulkan-loader
            ];

          # Fetch Clspv’s extra dependencies before CMake config
          preConfigure = ''
            echo ">>> Running CLVK's fetch_sources.py ..."
            cd external/clspv
            ${pkgs.python3}/bin/python3 utils/fetch_sources.py
            cd ../..
          '';

          cmakeFlags =
            [ "-DCLVK_BUILD_TESTS=OFF" "-DCLVK_CLSPV_ONLINE_COMPILER=OFF" ];

          installPhase = ''
            mkdir -p $out/lib $out/etc/OpenCL/vendors
            cp -r bin lib include $out/ 2>/dev/null || true
            echo "$out/lib/libOpenCL.so" > $out/etc/OpenCL/vendors/clvk.icd
          '';

          meta = with pkgs.lib; {
            description = "CLVK: OpenCL implementation over Vulkan";
            homepage = "https://github.com/kpet/clvk";
            license = licenses.asl20;
            maintainers = with maintainers; [ ];
            platforms = platforms.linux;
          };
        };
      });

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
            echo "✅ CLVK shell ready"
          '';
        };
      });
    };
}
