# beoplay-cli

This is an unofficial Command Line Interface for macOS to remote control network enabled Beoplay loudspeakers.

The CLI is built on top of the [RemoteCore](https://github.com/tlk/beoplay-macos-remote-cli/tree/master/Sources/RemoteCore) library which is also used by the [Beoplay Remote](https://github.com/tlk/beoplay-macos-remote-gui) menu bar app for macOS.

## Installation

```
$ make install
swift build -c release
[5/5] Linking ./.build/x86_64-apple-macosx/release/beoplay-cli
cp .build/release/beoplay-cli /usr/local/bin/beoplay-cli
$ 
```

## Usage

#### Interactive mode with hints and tab-completion
![screen recording](./tty.gif)

#### Non-interactive mode
```
$ beoplay-cli discover
+ "Beoplay Device"	http://BeoplayDevice.local.:8080

$ export BEOPLAY_NAME="Beoplay Device"
$ beoplay-cli getVolume
35
$ beoplay-cli setVolume 20
$ beoplay-cli getVolume
20
$ beoplay-cli pause
$ beoplay-cli play
$ beoplay-cli monitor
connection state: connecting
connection state: online
20
25
28
30

connection state: disconnecting
connection state: offline
$ 
$ beoplay-cli emulator "Nice Device"
emulating device "Nice Device" on port 80  (stop with ctrl+c)
^C
$
```

## Configuration

The beoplay-cli tool needs to know which device to connect to when issuing commands such as play, pause, etc.

Beoplay devices on the local network can be discovered in different ways:
- [Discovery.app](https://apps.apple.com/us/app/discovery-dns-sd-browser/id1381004916?mt=12)
- `dns-sd -B _beoremote._tcp.`
- `beoplay-cli discover`

The device name can be specified via an environment variable:
```
$ export BEOPLAY_NAME="Beoplay Device"
$ beoplay-cli play
```

Alternatively, host and port can be used:
```
$ export BEOPLAY_HOST=BeoplayDevice.local.
$ export BEOPLAY_PORT=8080
$ beoplay-cli play
```


## Credits & Related Projects
- https://github.com/martonborzak/ha-beoplay
- https://github.com/postlund/pyatv
- https://github.com/jstasiak/python-zeroconf
- https://github.com/andybest/linenoise-swift
- https://github.com/tlk/beoplay-macos-remote-gui

[![Nice Device](./nicedevice.png)](https://youtu.be/KbWtaxoIQeg)
