#!/usr/bin/env bash
# Fail on errors, unset variables, and failed pipeline commands.
set -euo pipefail

# Print the supported command-line options.
usage() {
  cat <<'EOF'
Usage: scripts/build_deb.sh [--skip-checks] [--skip-build]

Builds dist/lazy-word_<version>_amd64.deb from the Flutter Linux release bundle.

Options:
  --skip-checks  Skip flutter analyze and flutter test.
  --skip-build   Reuse build/linux/x64/release/bundle instead of rebuilding it.
EOF
}

# By default, run checks and rebuild the Flutter Linux bundle.
skip_checks=0
skip_build=0

# Parse optional flags before doing any work.
for arg in "$@"; do
  case "$arg" in
    --skip-checks)
      skip_checks=1
      ;;
    --skip-build)
      skip_build=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# Resolve paths relative to the repository root, not the caller's cwd.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

# Package metadata shared by the Debian control file and desktop entry.
package_name="lazy-word"
app_binary="lazy_word"
application_id="com.example.lazy_word"
icon_name="lazy-word"
maintainer="chzw517 <chzw517@outlook.com>"

# Read the Flutter version and drop the build suffix for Debian.
version_line="$(grep -E '^version:[[:space:]]*[0-9]' pubspec.yaml | head -n 1)"
if [[ -z "$version_line" ]]; then
  echo "Could not find a version line in pubspec.yaml." >&2
  exit 1
fi

app_version="${version_line#version:}"
app_version="${app_version//[[:space:]]/}"
deb_version="${app_version%%+*}"

# Key input and output paths.
bundle_dir="build/linux/x64/release/bundle"
stage_dir="dist/deb/$package_name"
deb_path="dist/${package_name}_${deb_version}_amd64.deb"
icon_path="linux/runner/resources/${icon_name}-256.png"

# The desktop launcher references this icon name.
if [[ ! -f "$icon_path" ]]; then
  echo "Missing package icon: $icon_path" >&2
  exit 1
fi

# Run static analysis and tests unless explicitly skipped.
if [[ "$skip_checks" -eq 0 ]]; then
  flutter analyze --no-pub
  flutter test
fi

# Build the release bundle, or verify an existing bundle can be reused.
if [[ "$skip_build" -eq 0 ]]; then
  flutter build linux --no-pub --release
elif [[ ! -x "$bundle_dir/$app_binary" ]]; then
  echo "Missing release bundle at $bundle_dir. Run without --skip-build first." >&2
  exit 1
fi

# Recreate the Debian staging tree from scratch.
rm -rf "$stage_dir"
mkdir -p \
  "$stage_dir/DEBIAN" \
  "$stage_dir/opt/$package_name" \
  "$stage_dir/usr/bin" \
  "$stage_dir/usr/share/applications" \
  "$stage_dir/usr/share/icons/hicolor/256x256/apps"

# Copy the Flutter release bundle and package icon into their install paths.
cp -a "$bundle_dir/." "$stage_dir/opt/$package_name/"
cp "$icon_path" "$stage_dir/usr/share/icons/hicolor/256x256/apps/$icon_name.png"

# Debian package metadata. ffmpeg provides ffplay for Linux audio.
cat > "$stage_dir/DEBIAN/control" <<EOF
Package: $package_name
Version: $deb_version
Section: education
Priority: optional
Architecture: amd64
Maintainer: $maintainer
Depends: libgtk-3-0, libblkid1, liblzma5, ffmpeg
Description: Local-first Flutter flashcard app for Anki APKG decks
 lazy_word imports downloaded Anki .apkg decks locally, stores cards and
 review progress in SQLite, and supports swipe-based vocabulary review.
EOF

# Command users run after installation.
cat > "$stage_dir/usr/bin/$package_name" <<EOF
#!/bin/sh
exec /opt/$package_name/$app_binary "\$@"
EOF

# Desktop launcher metadata. The filename matches the GTK application ID.
cat > "$stage_dir/usr/share/applications/$application_id.desktop" <<EOF
[Desktop Entry]
Name=lazy_word
Comment=Local flashcard vocabulary app
Exec=$package_name
Icon=$icon_name
Terminal=false
Type=Application
Categories=Education;
StartupWMClass=$application_id
EOF

# Refresh desktop and icon caches when the package is installed or removed.
for hook in postinst postrm; do
  cat > "$stage_dir/DEBIAN/$hook" <<'EOF'
#!/bin/sh
set -e

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi

exit 0
EOF
done

# Normalize permissions so installed files are owned and executable correctly.
find "$stage_dir" -type d -exec chmod 755 {} +
find "$stage_dir" -type f -exec chmod 644 {} +
chmod 755 "$stage_dir/usr/bin/$package_name"
chmod 755 "$stage_dir/DEBIAN/postinst" "$stage_dir/DEBIAN/postrm"
chmod 755 "$stage_dir/opt/$package_name/$app_binary"
find "$stage_dir/opt/$package_name/lib" -maxdepth 1 -name '*.so' -exec chmod 755 {} +

# Build a broadly compatible xz-compressed Debian package.
dpkg-deb --root-owner-group -Zxz --build "$stage_dir" "$deb_path"

# Print the key package fields for a quick sanity check.
dpkg-deb --field "$deb_path" Package Version Architecture Depends
echo "Built $deb_path"
