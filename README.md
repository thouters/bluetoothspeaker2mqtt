# Scripts to expose a bluetooth speaker on headless linux systems via MQTT

## Summary

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
TOPIC_BUTTON=""
SPEAKER_NAME=""
TOPIC_STATE=""
TOPIC_SET=""
SNAPCLIENT=""
STARTSTOP_SNAPCLIENT=""
BUTTONWATCHER_SERVICE=""
STARTSTOP_BUTTONWATCHER=""
POST_CONNECT_SETTLE_TIME=""

```

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
