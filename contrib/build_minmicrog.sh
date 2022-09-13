#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")"

. ../.gradle/signing.conf

: "${SIGNING_KEYSTORE}"
: "${SIGNING_PASSWORD}"

find_build_tools() {
    IFS='|'

    while read -r _ _ _ path; do
        # Strip leading/trailing spaces
        path=${path#${path%%[![:space:]]*}}
        path=${path%${path##*[![:space:]]}}

        path="$ANDROID_SDK_ROOT/$path"
        echo "Found candidate '$path' for build tools" >&2

        [ -d "$path" ] || continue

        echo "$path"
        return 0
    done <<EOF
$(sdkmanager --list_installed | grep 'build-tools;')
EOF

    echo "No build tools found!" >&2
    return 1
}

UNSIGNED="$PWD/../play-services-core/build/outputs/apk/release/play-services-core-release-unsigned.apk"
OUT="MicroGUNLP.apk"
OUTDIR="$PWD/build"
MINMICROG_REPO="https://github.com/git-bruh/MinMicroG-unlp"

rm -rf "$OUTDIR"
mkdir "$OUTDIR"

tools_path="$(find_build_tools)"
PATH="$PATH:$tools_path"

../build.sh

zipalign -p -f -v 4 "$UNSIGNED" "$OUTDIR/$OUT"
echo "$SIGNING_PASSWORD" | apksigner sign --ks "$SIGNING_KEYSTORE" "$OUTDIR/$OUT"

git clone --depth=1 "$MINMICROG_REPO" "$OUTDIR/repo"

(
    cd "$OUTDIR/repo"

    mkdir -p res/system/priv-app/MicroGUNLP
    cp "$OUTDIR/$OUT" res/system/priv-app/MicroGUNLP/

    ./build.sh unlp

    cp releases/*.zip "$OUTDIR"
)

printf 'Built %s\n' "$OUTDIR"/*.zip
