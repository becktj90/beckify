#!/bin/sh
# Download the Kokoro-82M ONNX model (fp32) and voice pack (Apache-2.0) with pinned checksums.
set -eu
DIR="${1:-$(dirname "$0")/models}"
BASE="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
mkdir -p "$DIR"
fetch() {
  name="$1"; sum="$2"
  if [ -f "$DIR/$name" ] && echo "$sum  $DIR/$name" | sha256sum -c - >/dev/null 2>&1; then return 0; fi
  curl -fsSL --retry 3 -o "$DIR/$name.part" "$BASE/$name"
  echo "$sum  $DIR/$name.part" | sha256sum -c -
  mv "$DIR/$name.part" "$DIR/$name"
}
fetch kokoro-v1.0.onnx 7d5df8ecf7d4b1878015a32686053fd0eebe2bc377234608764cc0ef3636a6c5
fetch voices-v1.0.bin bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d
