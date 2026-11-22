{ config, lib, pkgs, ... }:

# A Bluetooth speaker as a Snapcast client, controlled over MQTT:
#
# - bluez-alsa (hardware.alsa.enableBluetooth) makes the speaker the ALSA device "bluealsa"
# - bluetoothspeaker2mqtt reports the connection on MQTT, connects or disconnects on command, and
#   then starts/stops snapclient-bluetooth and bluetoothspeaker-buttonwatcher; Home Assistant
#   finds the speaker through MQTT discovery
#
# Pair the speaker once by hand: bluetoothctl -> scan on, pair <MAC>, trust <MAC>, connect <MAC>.
# The keys end up in /var/lib/bluetooth.
let
  cfg = config.services.bluetoothspeaker2mqtt;
  inherit (lib) mkOption mkEnableOption types optional optionalString;

  # mosquitto_pub and mosquitto_sub read their options from $XDG_CONFIG_HOME/mosquitto_{pub,sub}
  mqttConfig = pkgs.writeShellScript "bluetoothspeaker2mqtt-mosquitto-config" ''
    set -euo pipefail
    ${optionalString (cfg.mqtt.passwordFile != null) ''
      pw=$(${pkgs.coreutils}/bin/head -n1 ${lib.escapeShellArg cfg.mqtt.passwordFile})
    ''}
    ${optionalString (cfg.mqtt.passwordCommand != null) ''
      pw=$(${cfg.mqtt.passwordCommand})
    ''}
    umask 077
    for t in pub sub; do
      {
        printf -- '-h %s\n-p %s\n' ${lib.escapeShellArg cfg.mqtt.host} ${toString cfg.mqtt.port}
        ${optionalString (cfg.mqtt.user != null) ''printf -- '-u %s\n' ${lib.escapeShellArg cfg.mqtt.user}''}
        ${optionalString (cfg.mqtt.passwordFile != null || cfg.mqtt.passwordCommand != null) ''printf -- '-P %s\n' "$pw"''}
      } >"$RUNTIME_DIRECTORY/mosquitto_$t"
    done
  '';

  scriptService = name: {
    environment = {
      XDG_CONFIG_HOME = "/run/${name}";
      SPEAKER_MAC = cfg.speaker.mac;
      TOPIC_STATE = "${cfg.topic}/state";
      TOPIC_SET = "${cfg.topic}/set";
      TOPIC_BUTTON = "${cfg.topic}/button";
      TOPIC_AVAILABILITY = "${cfg.topic}/availability";
      SNAPCLIENT_SERVICE = "snapclient-bluetooth";
      STARTSTOP_SNAPCLIENT = if cfg.snapclient.enable then "yes" else "no";
      BUTTONWATCHER_SERVICE = "bluetoothspeaker-buttonwatcher";
      STARTSTOP_BUTTONWATCHER = if cfg.speaker.inputName != null then "yes" else "no";
      POST_CONNECT_SETTLE_TIME = toString cfg.postConnectSettleTime;
      HA_DISCOVERY = if cfg.homeAssistant.discovery then "yes" else "no";
      HA_DISCOVERY_PREFIX = cfg.homeAssistant.prefix;
      HA_NAME = cfg.homeAssistant.name;
    } // lib.optionalAttrs (cfg.speaker.inputName != null) {
      SPEAKER_NAME = cfg.speaker.inputName;
    };
    requires = [ "bluealsa.service" ];
    after = [ "bluealsa.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStartPre = mqttConfig;
      ExecStart = "${cfg.package}/bin/${name}";
      RuntimeDirectory = name;
      Restart = "always";
      RestartSec = 5;
    };
  };
in
{
  options.services.bluetoothspeaker2mqtt = {
    enable = mkEnableOption "a Bluetooth speaker as Snapcast client, controlled over MQTT";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "bluetoothspeaker2mqtt from this flake";
      description = "The bluetoothspeaker2mqtt package.";
    };

    speaker = {
      mac = mkOption {
        type = types.strMatching "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}";
        example = "04:21:44:D0:59:56";
        description = "The speaker's Bluetooth address (`bluetoothctl devices`).";
      };
      inputName = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "JBL Charge 4 (AVRCP)";
        description = ''
          The name of the speaker's AVRCP input device in /proc/bus/input/devices. Set it to
          publish the speaker's button on MQTT; null disables the button watcher.
        '';
      };
      mixer = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "JBL Charge 4 A2DP";
        description = ''
          The bluealsa mixer control (`amixer -D bluealsa scontrols`), so that the Snapcast
          volume is the speaker's volume. null uses snapclient's software mixer.
        '';
      };
    };

    mqtt = {
      host = mkOption {
        type = types.str;
        description = "The MQTT broker.";
      };
      port = mkOption {
        type = types.port;
        default = 1883;
        description = "The MQTT broker's port.";
      };
      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The MQTT user.";
      };
      passwordFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/run/secrets/mqtt-password";
        description = "A file with the MQTT password on its first line, read at service start.";
      };
      passwordCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "sed -n 's/^mqtt_password: *//p' /var/lib/zigbee2mqtt/secret.yaml";
        description = "A shell command that prints the MQTT password, run as root at service start.";
      };
    };

    topic = mkOption {
      type = types.str;
      default = "bluetoothspeaker2mqtt/speaker";
      description = "The MQTT topic prefix: state, set, button and availability go below it.";
    };

    postConnectSettleTime = mkOption {
      type = types.ints.unsigned;
      default = 1;
      description = "Seconds to wait after connecting before starting snapclient.";
    };

    homeAssistant = {
      discovery = mkOption {
        type = types.bool;
        default = true;
        description = "Announce the speaker to Home Assistant through MQTT discovery.";
      };
      prefix = mkOption {
        type = types.str;
        default = "homeassistant";
        description = "The MQTT discovery prefix.";
      };
      name = mkOption {
        type = types.str;
        default = "Bluetooth speaker";
        description = "The device name in Home Assistant.";
      };
    };

    snapclient = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Run a Snapcast client on the speaker while it is connected.";
      };
      server = mkOption {
        type = types.str;
        default = "tcp://_snapcast._tcp";
        example = "tcp://snapcast.example.org";
        description = "The Snapcast server URL.";
      };
      hostID = mkOption {
        type = types.str;
        default = "bluetooth";
        description = "The Snapcast client's host ID.";
      };
      instance = mkOption {
        type = types.ints.positive;
        default = 2;
        description = "The snapclient instance, distinct from other snapclients on this host.";
      };
      sampleFormat = mkOption {
        type = types.nullOr types.str;
        default = "48000:16:*";
        description = ''
          Resample to this format. Speakers usually pick SBC at 48 kHz; when snapclient opens
          the PCM at another rate, the bluealsa plugin asks for a reconfiguration, which fails
          with bluez-alsa 4.3.1 and bluez 5.86 ("Transport already configured") and drops the PCM.
        '';
      };
      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra snapclient arguments.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.mqtt.passwordFile == null || cfg.mqtt.passwordCommand == null;
      message = "services.bluetoothspeaker2mqtt.mqtt: set passwordFile or passwordCommand, not both";
    }];

    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = lib.mkDefault true;
    # bluez creates an input device for the speaker's buttons (AVRCP) through uinput
    hardware.uinput.enable = lib.mkIf (cfg.speaker.inputName != null) true;

    hardware.alsa = {
      enable = true;
      enableBluetooth = true;
      config = ''
        defaults.bluealsa.device "${cfg.speaker.mac}"
        defaults.bluealsa.profile "a2dp"
        defaults.bluealsa.delay 0
      '';
    };
    # The D-Bus policy for org.bluealsa; the ALSA module does not install it
    services.dbus.packages = [ pkgs.bluez-alsa ];

    # Started and stopped by bluetoothspeaker2mqtt, not at boot
    systemd.services.snapclient-bluetooth = lib.mkIf cfg.snapclient.enable {
      description = "Snapcast client on the Bluetooth speaker";
      after = [ "network-online.target" "bluealsa.service" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = lib.escapeShellArgs ([
          "${pkgs.snapcast}/bin/snapclient"
          "--instance" (toString cfg.snapclient.instance)
          "--hostID" cfg.snapclient.hostID
          "--soundcard" "bluealsa"
        ]
        ++ optional (cfg.speaker.mixer != null) "--mixer=hardware:${cfg.speaker.mixer}"
        ++ lib.optionals (cfg.snapclient.sampleFormat != null) [ "--sampleformat" cfg.snapclient.sampleFormat ]
        ++ cfg.snapclient.extraArgs
        ++ [ cfg.snapclient.server ]);
        # A static user in audio: the bluealsa D-Bus policy looks at the groups in /etc/group,
        # so DynamicUser with SupplementaryGroups is not enough
        User = "snapclient-bluetooth";
        Group = "audio";
        Restart = "always";
        RestartSec = 5;
      };
    };
    users.users.snapclient-bluetooth = lib.mkIf cfg.snapclient.enable {
      isSystemUser = true;
      group = "audio";
    };

    systemd.services.bluetoothspeaker2mqtt = scriptService "bluetoothspeaker2mqtt" // {
      description = "Bluetooth speaker on MQTT";
      wantedBy = [ "bluetooth.target" ];
    };

    systemd.services.bluetoothspeaker-buttonwatcher = lib.mkIf (cfg.speaker.inputName != null)
      (scriptService "bluetoothspeaker-buttonwatcher" // {
        description = "Bluetooth speaker button on MQTT";
      });

    environment.systemPackages = [ pkgs.bluez ];
  };
}
