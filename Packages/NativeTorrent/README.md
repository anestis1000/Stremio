Native libtorrent 2.0.11 (BSD), built for iOS 26 arm64 and Apple Silicon Simulator.
The C ABI shim and module map are in `Native/TorrentEngine`. Rebuild using
`scripts/build-native-torrent.sh`; resolve MPVKit first. This package links against
the same OpenSSL libraries supplied by MPVKit, avoiding duplicate crypto runtimes.

Upstream: https://github.com/arvidn/libtorrent/tree/v2.0.11
Revision: 9d7443f467147d1784fb7516d2a882db1abb5a8b
try_signal revision: 105cce59972f925a33aa6b1c3109e4cd3caf583d

The current bridge supports BitTorrent v1 and hybrid torrents. Pure v2 magnets
return an explicit error. Transfers run on device, require no remote Stremio
server, and pause when iOS backgrounds the app. Intel simulators are not included.
