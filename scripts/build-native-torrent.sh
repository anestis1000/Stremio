#!/bin/bash
set -euo pipefail
# Rebuild the two Apple Silicon slices. Requires Xcode, cmake, curl, Boost headers,
# and MPVKit artifacts resolved by Xcode. OpenSSL is shared with MPVKit.
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
work_dir="${STREMIO_NATIVE_BUILD_DIR:-/tmp/StremioNativeTorrentRebuild}"
artifacts="${STREMIO_MPV_ARTIFACTS:-/tmp/StremioPackages/artifacts/mpvkit}"
boost_include="${STREMIO_BOOST_INCLUDE:-$(brew --prefix boost)/include}"
mkdir -p "$work_dir"
curl -fL https://api.github.com/repos/arvidn/libtorrent/tarball/v2.0.11 -o "$work_dir/source.tar.gz"
mkdir -p "$work_dir/source"
tar -xzf "$work_dir/source.tar.gz" --strip-components=1 -C "$work_dir/source"
curl -fL https://api.github.com/repos/arvidn/try_signal/tarball/105cce59972f925a33aa6b1c3109e4cd3caf583d -o "$work_dir/signal.tar.gz"
mkdir -p "$work_dir/source/deps/try_signal"
tar -xzf "$work_dir/signal.tar.gz" --strip-components=1 -C "$work_dir/source/deps/try_signal"
printf '\ntarget_sources(torrent-rasterbar PRIVATE "%s/Native/TorrentEngine/NativeTorrent.cpp")\n' "$repo_dir" >> "$work_dir/source/CMakeLists.txt"
for platform in simulator device; do
    if [[ "$platform" == simulator ]]; then sdk=iphonesimulator; slice=ios-arm64_x86_64-simulator; else sdk=iphoneos; slice=ios-arm64; fi
    cmake -S "$work_dir/source" -B "$work_dir/$platform" -G 'Unix Makefiles' \
      -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk" -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=26.0 -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 \
      -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY -DBUILD_SHARED_LIBS=OFF \
      -Dbuild_tests=OFF -Dbuild_examples=OFF -Dbuild_tools=OFF -Dpython-bindings=OFF \
      -Ddeprecated-functions=OFF -DBoost_INCLUDE_DIR="$boost_include" \
      -DOPENSSL_INCLUDE_DIR="$artifacts/Libcrypto/Libcrypto.xcframework/$slice/Libcrypto.framework/Headers" \
      -DOPENSSL_CRYPTO_LIBRARY="$artifacts/Libcrypto/Libcrypto.xcframework/$slice/Libcrypto.framework/Libcrypto" \
      -DOPENSSL_SSL_LIBRARY="$artifacts/Libssl/Libssl.xcframework/$slice/Libssl.framework/Libssl" \
      -DCMAKE_CXX_FLAGS=-DTORRENT_HAVE_MMAP=0
    cmake --build "$work_dir/$platform" --parallel 6
done
# Build to a fresh destination; replace only after packaging succeeds.
rm -rf "$work_dir/NativeTorrent.xcframework"
xcodebuild -create-xcframework \
  -library "$work_dir/simulator/libtorrent-rasterbar.a" -headers "$repo_dir/Native/TorrentEngine/include" \
  -library "$work_dir/device/libtorrent-rasterbar.a" -headers "$repo_dir/Native/TorrentEngine/include" \
  -output "$work_dir/NativeTorrent.xcframework"
rm -rf "$repo_dir/Packages/NativeTorrent/NativeTorrent.xcframework"
cp -R "$work_dir/NativeTorrent.xcframework" "$repo_dir/Packages/NativeTorrent/"
