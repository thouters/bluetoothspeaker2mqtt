# Scripts to expose a bluetooth speaker on headless linux systems via MQTT


## Summary

To use my Bluetooth speaker with [my Home Assistant controlled Multi-room audio set-up](https://www.thouters.be/HassMultiRoomAudio.html),
I added a shell script that exposes Bluetooth connection status reporting and triggers over MQTT.

You can find the complete instructions on [how to set up Debian with this script in my article about
how I run a snapcast client with MQTT controlled Bluetooth speaker on a raspberry pi](https://www.thouters.be/BluetoothSpeakerOnDebianSid.html)

### bluetoothspeaker2mqtt 

bluetoothspeaker2mqtt will report status via MQTT TOPIC_STATE (on/off) when the device connects/disconnects.
write on/off to TOPIC_SET to trigger bluetoothctl connect/disconnect

### bluetoothspeaker-buttonwatcher

A simple shell script that will watch evtest output from the bluetooth buttons. I only tested this with a JBL Charge 4 which has one button.

### systemd service files

Service files to automatically start bluetoothspeaker2mqtt, and to have bluetoothspeaker2mqtt start/stop a snapclient, and bluetoothspeaker-buttonwatcher

## Installation

### prerequisites

```
apt install expect mosquitto-clients evtest snapclient
```

### from this repository 

```bash
sudo install -m 744 bluetoothspeaker2mqtt /usr/local/bin/bluetoothspeaker2mqtt
sudo install -m 744 bluetoothspeaker-buttonwatcher /usr/local/bin/bluetoothspeaker-buttonwatcher
sudo install -m 644 bluetoothspeaker-buttonwatcher.service /etc/systemd/system
sudo install -m 644 bluetoothspeaker2mqtt.service /etc/systemd/system
sudo systemctl daemon-reload
```

### Configuration 

write a file `/etc/bluetoothspeaker2mqtt.conf`, add settings you want to override as key/value pairs. Available are:

```bash
SPEAKER_MAC=""              # default: the bluealsa device in /etc/asound.conf
SPEAKER_NAME=""             # the input device name in /proc/bus/input/devices, e.g. "JBL Charge 4 (AVRCP)"
TOPIC_STATE=""              # on/off, retained
TOPIC_SET=""                # write on/off to connect/disconnect
TOPIC_BUTTON=""             # on/off when the speaker's button is pressed/released
TOPIC_AVAILABILITY=""       # online/offline, retained
SNAPCLIENT_SERVICE=""
STARTSTOP_SNAPCLIENT=""
BUTTONWATCHER_SERVICE=""
STARTSTOP_BUTTONWATCHER=""
POST_CONNECT_SETTLE_TIME=""
HA_DISCOVERY=""             # yes (default) or no
HA_DISCOVERY_PREFIX=""      # default: homeassistant
HA_NAME=""                  # the device name in Home Assistant, default: Bluetooth speaker
```

### Home Assistant

With `HA_DISCOVERY=yes` (the default), bluetoothspeaker2mqtt announces the speaker
through [MQTT discovery](https://www.home-assistant.io/integrations/mqtt/#mqtt-discovery):
a device with a "Bluetooth link" switch (connect/disconnect, and the connection
state), and device triggers for pressing and releasing the button. No YAML needed.
The availability topic goes offline when bluetoothspeaker2mqtt stops.

Write a file `/root/.config/mosquitto_pub` with MQTT configuration, verify you don't have trailing newlines.
```
-h mqtt_hostname
-u mqtt_username
-P mqtt_password
```

Add symlinks for both pub and sub tools:
```
ln -s /root/.config/mosquitto /root/.config/mosquitto_pub
ln -s /root/.config/mosquitto /root/.config/mosquitto_sub
```

### Testing

Next, (as root) you can test the scripts manually before using them from via systemd.
F first source the configuration like this:

```bash
set -o allexport
source /etc/bluetoothspeaker2mqtt.conf
set +o allexport
```
then run e.g.: `/usr/local/bin/bluetoothspeaker2mqtt`

### Activation

Enable systemd services:

```
sudo systemctl start bluetoothspeaker2mqtt
sudo systemctl enable bluetoothspeaker2mqtt
```
