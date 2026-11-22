{ lib
, stdenvNoCC
, makeWrapper
, bash
, bluez
, coreutils
, evtest
, expect
, gnugrep
, gnused
, mosquitto
, systemd
}:

stdenvNoCC.mkDerivation {
  pname = "bluetoothspeaker2mqtt";
  version = "0-unstable";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./bluetoothspeaker2mqtt ./bluetoothspeaker-buttonwatcher ];
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ bash ];

  installPhase = ''
    runHook preInstall
    install -Dm755 bluetoothspeaker2mqtt $out/bin/bluetoothspeaker2mqtt
    install -Dm755 bluetoothspeaker-buttonwatcher $out/bin/bluetoothspeaker-buttonwatcher
    wrapProgram $out/bin/bluetoothspeaker2mqtt \
      --prefix PATH : ${lib.makeBinPath [ bluez coreutils expect gnugrep gnused mosquitto systemd ]}
    wrapProgram $out/bin/bluetoothspeaker-buttonwatcher \
      --prefix PATH : ${lib.makeBinPath [ coreutils evtest expect gnugrep mosquitto ]}
    runHook postInstall
  '';

  meta = {
    description = "Expose a Bluetooth speaker's connection and button on MQTT";
    homepage = "https://github.com/thouters/bluetoothspeaker2mqtt";
    platforms = lib.platforms.linux;
    mainProgram = "bluetoothspeaker2mqtt";
  };
}
