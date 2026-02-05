# .idx/dev.nix - Copy this exactly
{ pkgs, ... }: {
  # 1. Enable the Android Preview
    channel = "stable-24.05"; # Use a stable channel
      packages = [
          pkgs.nodePackages.firebase-tools
              pkgs.jdk17
                  pkgs.unzip
                      pkgs.flutter
                          pkgs.dart
                            ];
                              env = {};
                                idx = {
                                    extensions = [
                                          "Dart-Code.flutter"
                                                "Dart-Code.dart-code"
                                                    ];
                                                        previews = {
                                                              enable = true;
                                                                    previews = {
                                                                            android = {
                                                                                      command = ["flutter" "run" "--machine" "-d" "android" "-d" "localhost:5555"];
                                                                                                manager = "flutter";
                                                                                                        };
                                                                                                              };
                                                                                                                  };
                                                                                                                      workspace = {
                                                                                                                            # 2. This fixes the "Android SDK permissions" error
                                                                                                                                  onCreate = {
                                                                                                                                          build-flutter = ''
                                                                                                                                                    flutter pub get
                                                                                                                                                              yes | flutter doctor --android-licenses
                                                                                                                                                                      '';
                                                                                                                                                                            };
                                                                                                                                                                                };
                                                                                                                                                                                  };
                                                                                                                                                                                  }