#!/usr/bin/env bash
set -euo pipefail
app_path=${1:?usage: build-macos-installer.sh APP_PATH OUTPUT_DIR}
output_dir=${2:?usage: build-macos-installer.sh APP_PATH OUTPUT_DIR}
workspace_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
version=$(node -p "require(process.argv[1]).version" "$workspace_root/app/package.json")
# Installer package versions use the same monotonic three-field mapping as the
# Windows MSI (alpha.84 -> 1.2.84, rc.1 -> 1.2.6001, final -> 1.2.9000).
package_version=$(node --input-type=module -e "import { pathToFileURL } from 'node:url'; const { msiProductVersion } = await import(pathToFileURL(process.argv[1]).href); process.stdout.write(msiProductVersion(process.argv[2]))" "$workspace_root/app/scripts/installer-lifecycle-policy.mjs" "$version")
[[ $(uname -s) == Darwin && $(uname -m) == arm64 ]] || exit 1
[[ -d "$app_path" && ! -L "$app_path" ]] || exit 1
codesign --verify --deep --strict "$app_path"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/app-scripts" "$stage/djlink-scripts" "$stage/core-scripts" "$output_dir"
source_dir="$workspace_root/tools/distribution/macos-installer"
cp "$source_dir/preinstall" "$stage/app-scripts/preinstall"
chmod 755 "$stage/app-scripts/preinstall"
mkdir -p "$stage/app-root"
ditto "$app_path" "$stage/app-root/Syndocal.app"
pkgbuild --analyze --root "$stage/app-root" "$stage/app-components.plist"
# An existing build/DMG copy must not redirect installation away from Applications.
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$stage/app-components.plist"
pkgbuild --root "$stage/app-root" --component-plist "$stage/app-components.plist" --install-location /Applications --scripts "$stage/app-scripts" --identifier jp.seraf.ktn.syndocal.pkg.app --version "$package_version" "$stage/app.pkg"
for feature in djlink core; do
  enabled=0; [[ "$feature" != djlink ]] || enabled=1
  cp "$source_dir/preinstall" "$stage/$feature-scripts/preinstall"
  sed "s/@DJLINK@/$enabled/g" "$source_dir/postinstall" > "$stage/$feature-scripts/postinstall"
  chmod 755 "$stage/$feature-scripts/"*
  pkgbuild --nopayload --scripts "$stage/$feature-scripts" --identifier "jp.seraf.ktn.syndocal.pkg.$feature" --version "$package_version" "$stage/$feature.pkg"
done
sed "s/@VERSION@/$version/g" "$source_dir/Distribution.xml" > "$stage/Distribution.xml"
productbuild --distribution "$stage/Distribution.xml" --package-path "$stage" "$output_dir/Syndocal_${version}_arm64.pkg"
shasum -a 256 "$output_dir/Syndocal_${version}_arm64.pkg" > "$output_dir/Syndocal_${version}_arm64.pkg.sha256"
