#!/usr/bin/env bash
#
# Builds unsigned NativeGrind IPAs and adds a new version to repo.json.
#
# Usage:
#   scripts/release.sh [-n "release notes"] [--upload]
#
#   -n, --notes   What's new in this version (default: "Bug fixes and improvements.")
#   --upload      Also create/update the GitHub release v<version> and upload the IPAs with gh
#
# Version and build number come from MARKETING_VERSION and CURRENT_PROJECT_VERSION in the project,
# so bump them in Xcode before running. Commit and push repo.json afterwards for it to go live.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/NativeGrind.xcodeproj"
OUT="$ROOT/build/release"
REPO="imaoreo/NativeGrind-Swift"

NOTES="Bug fixes and improvements."
UPLOAD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--notes) NOTES="$2"; shift 2 ;;
        --upload) UPLOAD=true; shift ;;
        -h|--help) sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

# name in repo.json | scheme | configuration | ipa file name
BUILDS=(
    "NativeGrind|NativeGrind|Release|NativeGrind.ipa"
    "NativeGrind (NS)|NativeGrind (NS)|Release (NS)|NativeGrind-NS.ipa"
)

setting() {
    xcodebuild -project "$PROJECT" -scheme NativeGrind -configuration Release -sdk iphoneos -showBuildSettings 2>/dev/null \
        | awk -v key="$1" '$1 == key { print $3; exit }'
}

VERSION="$(setting MARKETING_VERSION)"
BUILD_NUMBER="$(setting CURRENT_PROJECT_VERSION)"
MIN_OS="$(setting IPHONEOS_DEPLOYMENT_TARGET)"
TAG="v$VERSION"

echo "==> NativeGrind $VERSION ($BUILD_NUMBER), iOS $MIN_OS+"

rm -rf "$OUT"
mkdir -p "$OUT"

for entry in "${BUILDS[@]}"; do
    IFS='|' read -r name scheme configuration ipa <<< "$entry"
    archive="$OUT/$scheme.xcarchive"

    echo "==> Archiving $name ($configuration)"
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$scheme" \
        -configuration "$configuration" \
        -destination "generic/platform=iOS" \
        -archivePath "$archive" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        -quiet

    app="$(find "$archive/Products/Applications" -maxdepth 1 -name "*.app" | head -1)"
    if [[ -z "$app" ]]; then
        echo "No .app found in $archive" >&2
        exit 1
    fi

    echo "==> Packaging $ipa"
    payload="$OUT/payload-$ipa"
    mkdir -p "$payload/Payload"
    cp -R "$app" "$payload/Payload/"
    (cd "$payload" && zip -qry "$OUT/$ipa" Payload)
    rm -rf "$payload"
done

echo "==> Updating repo.json"
python3 - "$ROOT/repo.json" "$OUT" "$VERSION" "$BUILD_NUMBER" "$MIN_OS" "$NOTES" "$REPO" "$TAG" "${BUILDS[@]}" <<'EOF'
import json, os, sys
from datetime import date

path, out, version, build, min_os, notes, repo, tag, *builds = sys.argv[1:]
today = date.today().isoformat()

with open(path) as f:
    source = json.load(f)

for entry in builds:
    name, _, _, ipa = entry.split("|")
    app = next((a for a in source["apps"] if a["name"] == name), None)
    if app is None:
        sys.exit(f"No app named {name!r} in repo.json")

    url = f"https://github.com/{repo}/releases/download/{tag}/{ipa}"
    size = os.path.getsize(os.path.join(out, ipa))
    new_version = {
        "version": version,
        "buildVersion": build,
        "date": today,
        "localizedDescription": notes,
        "downloadURL": url,
        "size": size,
        "minOSVersion": min_os,
    }

    # re-running for the same version replaces its entry rather than duplicating it
    app["versions"] = [new_version] + [
        v for v in app.get("versions", [])
        if (v.get("version"), v.get("buildVersion")) != (version, build)
    ]

    # legacy fields for sources that only read the top-level version
    app["version"] = version
    app["versionDate"] = today
    app["versionDescription"] = notes
    app["downloadURL"] = url
    app["size"] = size

    print(f"    {name}: {version} ({build}), {size} bytes")

with open(path, "w") as f:
    json.dump(source, f, indent=2, ensure_ascii=False)
    f.write("\n")
EOF

if $UPLOAD; then
    echo "==> Uploading to GitHub release $TAG"
    ipas=()
    for entry in "${BUILDS[@]}"; do
        IFS='|' read -r _ _ _ ipa <<< "$entry"
        ipas+=("$OUT/$ipa")
    done

    if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
        gh release upload "$TAG" "${ipas[@]}" --repo "$REPO" --clobber
    else
        gh release create "$TAG" "${ipas[@]}" --repo "$REPO" --title "NativeGrind $VERSION" --notes "$NOTES"
    fi
fi

echo "==> Done. IPAs are in $OUT"
$UPLOAD || echo "    Upload them to the $TAG release (or re-run with --upload), then commit and push repo.json."
