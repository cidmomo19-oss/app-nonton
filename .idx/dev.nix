{ pkgs, ... }: {
  channel = "stable-23.11";
  packages = [
    pkgs.jdk17
    pkgs.unzip
  ];
  env = {};
  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];
    previews = {
      android = {
        command = [ "flutter" "run" "--machine" "-d" "android" "-d" "localhost:5555" ];
        manager = "flutter";
      };
    };
  };
}
