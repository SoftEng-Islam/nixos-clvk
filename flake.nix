{
  description = "Standalone CLVK package (fully sandbox-safe)";

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
              vulkan-headers
              vulkan-loader
            ];

          # Pre-populate CLSPV third_party sources (no network)
          postUnpack = ''
            mkdir -p $sourceRoot/external/clspv/third_party
            cp -r ${
              pkgs.fetchFromGitHub {
                owner = "KhronosGroup";
                repo = "SPIRV-Headers";
                rev = "1.3.261.1"; # stable tag
                sha256 = "sha256-TuvSm8/Fno0EGObzq9myIPbZZhsh+uJMyOn8QsxBoB0=";
              }
            } $sourceRoot/external/clspv/third_party/SPIRV-Headers
            cp -r ${
              pkgs.fetchFromGitHub {
                owner = "KhronosGroup";
                repo = "SPIRV-Tools";
                rev = "v2024.2"; # any compatible recent tag
                sha256 = "sha256-7iCuSzIULppnHwZlkFiAnvMqKHmpUj9cOLwPeHK8RxI=";
              }
            } $sourceRoot/external/clspv/third_party/SPIRV-Tools
          '';

          cmakeFlags =
            [ "-DCLVK_BUILD_TESTS=OFF" "-DCLVK_CLSPV_ONLINE_COMPILER=OFF" ];

          installPhase = ''
            mkdir -p $out/lib $out/etc/OpenCL/vendors
            cp -r bin lib include $out/ 2>/dev/null || true
            echo "$out/lib/libOpenCL.so" > $out/etc/OpenCL/vendors/clvk.icd
          '';

          meta = with pkgs.lib; {
            description = "CLVK: OpenCL on Vulkan (Nix sandbox-safe build)";
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
