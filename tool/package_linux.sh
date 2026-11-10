#!/usr/bin/env bash
# Builds .deb, .rpm and .AppImage from `flutter build linux --release` output.
# Requires: dpkg-deb, rpmbuild, appimagetool (downloaded if missing).
#   tool/package_linux.sh [x64|arm64]
set -euo pipefail
cd "$(dirname "$0")/.."

arch="${1:-x64}"
version="$(grep -m1 '^version:' pubspec.yaml | sed -E 's/version: *([^+]+).*/\1/')"
bundle="build/linux/$arch/release/bundle"
dist="dist"
app="sharrow"
deb_arch=$([ "$arch" = arm64 ] && echo arm64 || echo amd64)
rpm_arch=$([ "$arch" = arm64 ] && echo aarch64 || echo x86_64)
ai_arch=$([ "$arch" = arm64 ] && echo aarch64 || echo x86_64)

[ -x "$bundle/$app" ] || { echo "Run: flutter build linux --release" >&2; exit 1; }
[ -d core ] && { mkdir -p "$bundle/core"; cp core/* "$bundle/core/"; }
mkdir -p "$dist"

desktop() {
  cat <<EOF
[Desktop Entry]
Type=Application
Name=Sharrow
GenericName=VPN client
Comment=Fast and private VPN
Exec=$1 %U
Icon=sharrow
Terminal=false
Categories=Network;
Keywords=vpn;proxy;xray;vless;
StartupWMClass=sharrow
EOF
}

# --- deb -------------------------------------------------------------------
root="$(mktemp -d)"
mkdir -p "$root/opt/sharrow" "$root/usr/bin" "$root/usr/share/applications" "$root/usr/share/icons/hicolor/512x512/apps" "$root/DEBIAN"
cp -r "$bundle"/. "$root/opt/sharrow/"
ln -s /opt/sharrow/sharrow "$root/usr/bin/sharrow"
desktop /opt/sharrow/sharrow > "$root/usr/share/applications/sharrow.desktop"
cp assets/icons/app_icon_512.png "$root/usr/share/icons/hicolor/512x512/apps/sharrow.png"
cat > "$root/DEBIAN/control" <<EOF
Package: sharrow
Version: $version
Architecture: $deb_arch
Maintainer: Sharrow <support@sharrow.app>
Depends: libgtk-3-0, libayatana-appindicator3-1 | libappindicator3-1, libsecret-1-0, libnotify4
Section: net
Priority: optional
Description: Sharrow VPN client
 Cross-platform VPN client powered by Xray-core.
EOF
cat > "$root/DEBIAN/postinst" <<'EOF'
#!/bin/sh
setcap cap_net_admin,cap_net_raw,cap_net_bind_service=+eip /opt/sharrow/core/xray 2>/dev/null || true
command -v update-desktop-database >/dev/null && update-desktop-database -q || true
EOF
chmod 755 "$root/DEBIAN/postinst"
dpkg-deb --build --root-owner-group "$root" "$dist/sharrow_${version}_${deb_arch}.deb"
rm -rf "$root"

# --- rpm -------------------------------------------------------------------
if command -v rpmbuild >/dev/null; then
  top="$(mktemp -d)"
  mkdir -p "$top"/{BUILD,RPMS,SOURCES,SPECS,SRPMS,BUILDROOT}
  cat > "$top/SPECS/sharrow.spec" <<EOF
Name: sharrow
Version: $version
Release: 1
Summary: Sharrow VPN client
License: Proprietary
URL: https://sharrow.app
Requires: gtk3, libayatana-appindicator-gtk3, libsecret, libnotify
AutoReqProv: no
%global debug_package %{nil}
%global __strip /bin/true

%description
Cross-platform VPN client powered by Xray-core.

%install
mkdir -p %{buildroot}/opt/sharrow %{buildroot}/usr/bin %{buildroot}/usr/share/applications %{buildroot}/usr/share/icons/hicolor/512x512/apps
cp -r $PWD/$bundle/. %{buildroot}/opt/sharrow/
ln -s /opt/sharrow/sharrow %{buildroot}/usr/bin/sharrow
cat > %{buildroot}/usr/share/applications/sharrow.desktop <<'DESK'
$(desktop /opt/sharrow/sharrow)
DESK
cp $PWD/assets/icons/app_icon_512.png %{buildroot}/usr/share/icons/hicolor/512x512/apps/sharrow.png

%post
setcap cap_net_admin,cap_net_raw,cap_net_bind_service=+eip /opt/sharrow/core/xray 2>/dev/null || true

%files
/opt/sharrow
/usr/bin/sharrow
/usr/share/applications/sharrow.desktop
/usr/share/icons/hicolor/512x512/apps/sharrow.png
EOF
  rpmbuild --define "_topdir $top" --target "$rpm_arch" -bb "$top/SPECS/sharrow.spec"
  cp "$top"/RPMS/*/*.rpm "$dist/"
  rm -rf "$top"
else
  echo "rpmbuild not found, skipping .rpm" >&2
fi

# --- AppImage --------------------------------------------------------------
tool="$(command -v appimagetool || true)"
if [ -z "$tool" ]; then
  tool="$(mktemp -d)/appimagetool"
  curl -fsSL -o "$tool" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ai_arch.AppImage"
  chmod +x "$tool"
fi
appdir="$(mktemp -d)/Sharrow.AppDir"
mkdir -p "$appdir/usr/bin"
cp -r "$bundle"/. "$appdir/usr/bin/"
desktop sharrow > "$appdir/sharrow.desktop"
cp assets/icons/app_icon_512.png "$appdir/sharrow.png"
cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/sharrow" "$@"
EOF
chmod +x "$appdir/AppRun"
ARCH="$ai_arch" APPIMAGE_EXTRACT_AND_RUN=1 "$tool" "$appdir" "$dist/Sharrow-$version-$ai_arch.AppImage"

ls -lh "$dist"
