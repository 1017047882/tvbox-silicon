#!/bin/bash
# Builds the small FFmpeg that Sources/TVMedia uses to repackage MKV, AVI, FLV, WMV and RMVB for AVPlayer
# (Docs/mkv-playback-plan.md): demuxers, the MP4 muxer, the decoders and AudioToolbox/VideoToolbox encoders
# of the conversion path, VideoToolbox decoding for HDR to SDR, dav1d for AV1 without AV1 hardware, and nothing
# else (no network, no programs, no external libraries but zlib and dav1d). LGPL only (dav1d is BSD).
# Output: build/FFmpeg/FFmpeg.xcframework (Vendor/FFmpeg links to it), one static library per platform.
# Builds are kept in a cache shared by every checkout and worktree, one per complete script hash,
# so a checkout usually just links the one already built (about 5 minutes otherwise; dav1d's
# build tools also need Python 3).
set -euo pipefail
cd "$(dirname "$0")/.."
SCOPE="${1:-all}"
case "$SCOPE" in
  ios) SLICES=(ios) ;;
  all) SLICES=(macos ios ios-simulator tvos tvos-simulator) ;;
  *) echo "Usage: $0 [ios|all]" >&2; exit 2 ;;
esac
CACHE="${TVBOX_FFMPEG_CACHE:-$HOME/Library/Caches/tvbox-ffmpeg}"
SIGNATURE="$(shasum -a 256 "$0" | cut -c1-16)"
OUTPUT="$CACHE/$SIGNATURE-$SCOPE/FFmpeg.xcframework"
LINK="$PWD/build/FFmpeg/FFmpeg.xcframework"
link() {
  mkdir -p "$(dirname "$LINK")"
  if [ "$(readlink "$LINK" 2>/dev/null)" = "$OUTPUT" ]; then return; fi
  if [ -L "$LINK" ]; then
    unlink "$LINK"
  elif [ -e "$LINK" ]; then
    echo "Refusing to replace non-symlink output: $LINK" >&2
    exit 1
  fi
  ln -s "$OUTPUT" "$LINK"
}
if [ -f "$OUTPUT/Info.plist" ]; then
  link
  echo "FFmpeg is up to date: $OUTPUT"
  exit 0
fi
# The lock protects publication; fresh work directories preserve failed build logs.
mkdir -p "$CACHE"
mkdir "$CACHE/lock" 2>/dev/null || { echo "Another FFmpeg build is running (or remove $CACHE/lock)" >&2; exit 1; }
trap 'rmdir "$CACHE/lock"' EXIT
WORK="$(mktemp -d "$CACHE/work.XXXXXX")"
echo "FFmpeg work directory (preserved): $WORK"

# RECIPE
VERSION=8.1.3
COMMIT=1041abdc962f4cc4f394aa8de9dc5236c0c3b9e7
SOURCE="$WORK/FFmpeg-n$VERSION"
if [ ! -f "$SOURCE/configure" ]; then
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "n$VERSION" https://github.com/FFmpeg/FFmpeg.git "$SOURCE.download"
  test "$(git -C "$SOURCE.download" rev-parse HEAD)" = "$COMMIT"
  mv "$SOURCE.download" "$SOURCE"
fi
# dav1d decodes AV1 for the conversion path where there is no AV1 hardware (Macs before the M3, iPhones and
# iPads before the A17 Pro, Apple TV).
DAV1D_VERSION=1.5.4
DAV1D_COMMIT=54706fc6bc0cdecab7e9593974a4039cc038fca7
DAV1D="$WORK/dav1d-$DAV1D_VERSION"
if [ ! -f "$DAV1D/meson.build" ]; then
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$DAV1D_VERSION" https://code.videolan.org/videolan/dav1d.git "$DAV1D.download"
  test "$(git -C "$DAV1D.download" rev-parse HEAD)" = "$DAV1D_COMMIT"
  mv "$DAV1D.download" "$DAV1D"
fi
# Its build tools, in a folder of their own.
TOOLS="$WORK/meson-1.9.1-ninja-1.13.2"
if [ ! -x "$TOOLS/bin/ninja" ]; then
  python3 -m venv "$TOOLS"
  "$TOOLS/bin/pip" install --quiet --disable-pip-version-check meson==1.9.1 ninja==1.13.2
fi

DEMUXERS=matroska,avi,flv,asf,rm,mpegts,mpegps,mov,ogg
VIDEO_DECODERS=h264,hevc,mpeg1video,mpeg2video,mpeg4,msmpeg4v1,msmpeg4v2,msmpeg4v3,h263,flv,vc1,wmv1,wmv2,wmv3,rv10,rv20,rv30,rv40,vp6,vp6a,vp6f,vp8,vp9,theora,mjpeg,libdav1d
AUDIO_DECODERS=aac,aac_latm,ac3,eac3,dca,truehd,mlp,mp1,mp2,mp3,vorbis,opus,flac,alac,pcm_s16le,pcm_s16be,pcm_s24le,pcm_s24be,pcm_s32le,pcm_f32le,pcm_u8,pcm_bluray,pcm_dvd,wmav1,wmav2,wmapro,wmalossless,cook,sipr,atrac3,ra_144,ra_288,amrnb,amrwb,adpcm_ima_wav,adpcm_ms
PARSERS=h264,hevc,aac,aac_latm,ac3,mpegaudio,dca,mlp,flac,vorbis,opus,mpeg4video,mpegvideo,vc1,vp8,vp9,av1,h263,rv34,cook
BSFS=aac_adtstoasc,extract_extradata,vp9_superframe
ENCODERS=aac_at,h264_videotoolbox,hevc_videotoolbox
# VideoToolbox decoding, for the picture that is converted (HDR to SDR) on the media engine, not the CPU.
HWACCELS=h264_videotoolbox,hevc_videotoolbox

build_slice() {
  local name=$1 sdk=$2 arch=$3 triple=$4
  local build="$WORK/build-$name" prefix="$WORK/install-$name"
  local sysroot cc extra=() asm=true
  sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)"
  cc="$(xcrun --sdk "$sdk" --find clang)"
  # No nasm on the build Mac: Intel Macs lose only the conversion path's assembly (FFmpeg's and dav1d's);
  # copying needs none.
  [ "$arch" = x86_64 ] && { extra+=(--disable-x86asm); asm=false; }
  mkdir -p "$build"
  cat > "$build/dav1d.cross" <<CROSS
[binaries]
c = '$cc'
ar = '$(xcrun --sdk "$sdk" --find ar)'
strip = '$(xcrun --sdk "$sdk" --find strip)'
[built-in options]
c_args = ['-target', '$triple', '-isysroot', '$sysroot']
c_link_args = ['-target', '$triple', '-isysroot', '$sysroot']
[properties]
needs_exe_wrapper = true
[host_machine]
system = 'darwin'
cpu_family = '$arch'
cpu = '$arch'
endian = 'little'
CROSS
  "$TOOLS/bin/meson" setup "$WORK/dav1d-build-$name" "$DAV1D" --cross-file "$build/dav1d.cross" \
    --prefix "$prefix" --libdir lib --buildtype release --default-library static -Denable_asm=$asm \
    -Denable_tools=false -Denable_examples=false -Denable_tests=false -Denable_docs=false \
    > "$build/dav1d-setup.log" 2>&1 || { tail -30 "$build/dav1d-setup.log"; exit 1; }
  PATH="$TOOLS/bin:$PATH" ninja -C "$WORK/dav1d-build-$name" install > "$build/dav1d-build.log" 2>&1 \
    || { tail -40 "$build/dav1d-build.log"; exit 1; }
  (
    cd "$build"
    # Only this slice's dav1d, never one installed on the Mac.
    PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig" PKG_CONFIG_PATH= \
    "$SOURCE/configure" --prefix="$prefix" --enable-cross-compile --target-os=darwin --arch="$arch" \
      --cc="$cc" --sysroot="$sysroot" \
      --extra-cflags="-target $triple -fno-common" --extra-ldflags="-target $triple" \
      --disable-programs --disable-doc --disable-debug --disable-shared --enable-static --enable-pic \
      --disable-autodetect --enable-pthreads --enable-zlib --enable-videotoolbox --enable-audiotoolbox \
      --enable-libdav1d --pkg-config-flags=--static \
      --disable-everything --disable-network --disable-avdevice --disable-avfilter \
      --enable-demuxer="$DEMUXERS" --enable-muxer=mp4 \
      --enable-decoder="$VIDEO_DECODERS,$AUDIO_DECODERS" --enable-encoder="$ENCODERS" \
      --enable-parser="$PARSERS" --enable-bsf="$BSFS" --enable-hwaccel="$HWACCELS" \
      ${extra[@]+"${extra[@]}"} > configure.log 2>&1 || { tail -30 configure.log; exit 1; }
    make -j "${JOBS:-$(sysctl -n hw.ncpu)}" > make.log 2>&1 || { tail -40 make.log; exit 1; }
    make install > install.log 2>&1
  )
  # One archive per slice, so the xcframework names a single library.
  libtool -static -no_warning_for_no_symbols -o "$prefix/libFFmpeg.a" \
    "$prefix"/lib/libavformat.a "$prefix"/lib/libavcodec.a "$prefix"/lib/libswresample.a \
    "$prefix"/lib/libswscale.a "$prefix"/lib/libavutil.a "$prefix"/lib/libdav1d.a
  echo "FFmpeg $name built"
}

build_slice ios iphoneos aarch64 arm64-apple-ios15.0
if [ "$SCOPE" = all ]; then
  build_slice macos-arm64 macosx aarch64 arm64-apple-macos14.0
  build_slice macos-x86_64 macosx x86_64 x86_64-apple-macos14.0
  build_slice ios-simulator iphonesimulator aarch64 arm64-apple-ios15.0-simulator
  build_slice tvos appletvos aarch64 arm64-apple-tvos17.0
  build_slice tvos-simulator appletvsimulator aarch64 arm64-apple-tvos17.0-simulator
fi
# END

if [ "$SCOPE" = all ]; then
  mkdir -p "$WORK/install-macos/lib"
  lipo -create "$WORK/install-macos-arm64/libFFmpeg.a" "$WORK/install-macos-x86_64/libFFmpeg.a" -output "$WORK/install-macos/libFFmpeg.a"
  cp -R "$WORK/install-macos-arm64/include" "$WORK/install-macos/include"
fi
PARTIAL="$(mktemp -d "$CACHE/$SIGNATURE-$SCOPE.partial.XXXXXX")"
arguments=()
for slice in "${SLICES[@]}"; do
  arguments+=(-library "$WORK/install-$slice/libFFmpeg.a" -headers "$WORK/install-$slice/include")
done
xcodebuild -create-xcframework "${arguments[@]}" -output "$PARTIAL/FFmpeg.xcframework" > /dev/null
if [ -e "$(dirname "$OUTPUT")" ]; then
  echo "Refusing to overwrite existing FFmpeg cache: $(dirname "$OUTPUT")" >&2
  exit 1
fi
mv "$PARTIAL" "$(dirname "$OUTPUT")"
link
echo "FFmpeg $VERSION: $OUTPUT"
