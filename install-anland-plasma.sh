#!/data/data/com.termux/files/usr/bin/bash
# Installs Anland KDE Plasma in the Ubuntu 26.04 Resolute PRoot-Distro image.
# Guide: https://github.com/lfdevs/anland-termux/blob/main/docs/user-guide.md

set -euo pipefail

ANLAND_VERSION="5.13.3"
DISTRO_NAME="ubuntu-anland"
UBUNTU_IMAGE="ghcr.io/lfdevs/ubuntu:resolute-anland-plasma"
ANLAND_RELEASE="https://github.com/lfdevs/anland-termux/releases/download/${ANLAND_VERSION}"
MESA_VERSION="26.3.0-devel-20260824"
MESA_RELEASE="https://github.com/lfdevs/mesa-for-android-container/releases/download/mesa-${MESA_VERSION}"
STEAMOS_RELEASE="https://github.com/MaSieS4Fun/SteamOS-Ubuntu/releases/download/v1.0.9"
PLASMA_STARTER_URL="https://github.com/lfdevs/anland-termux/raw/refs/heads/main/scripts/startplasma-anland.sh"

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
TMP_ROOT="${TMPDIR:-$PREFIX/tmp}"
ASSET_DIR="$TMP_ROOT/anland-resolute-assets"
ROOTFS_DIR="$PREFIX/var/lib/proot-distro/installed-rootfs/$DISTRO_NAME"

log() { printf '\n==> %s\n' "$1"; }
die() { printf '[!] %s\n' "$1" >&2; exit 1; }

download() {
    local url="$1"
    local destination="$2"
    [[ -s "$destination" ]] || curl --fail --location --retry 3 "$url" -o "$destination"
}

container() {
    proot-distro login "$DISTRO_NAME" --shared-tmp -- "$@"
}

[[ -n "${TERMUX_VERSION:-}" ]] || die "Run this installer from Termux, not inside a PRoot container."
[[ "$(uname -m)" == "aarch64" ]] || die "Ubuntu Resolute Anland images require an ARM64 device."

mkdir -p "$ASSET_DIR"

log "Step 1: Install Termux host tools"
pkg update -y
pkg upgrade -y
pkg install -y proot-distro curl wget procps unzip tar termux-api pipewire

log "Step 2: Android permissions and Anland display app"
termux-setup-storage
echo "Allow storage access if Android asks."
am start -a android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS >/dev/null 2>&1 || true
echo "Set battery usage for Termux and Anland Termux to Unrestricted / Don't optimize."

case "${TERMUX_APP__APK_RELEASE:-}" in
    F_DROID|ZERO_TERMUX)
        DISPLAY_APK="AnlandTermux-${ANLAND_VERSION}-compatible.apk"
        echo "Install the compatible display APK: $DISPLAY_APK"
        echo "F-Droid/ZeroTermux builds also need the anland-compatible bridge."
        ;;
    *)
        DISPLAY_APK="AnlandTermux-${ANLAND_VERSION}.apk"
        echo "Install the standard display APK: $DISPLAY_APK"
        ;;
esac
echo "Download it from: https://github.com/lfdevs/anland-termux/releases/latest"
echo "After installing, long-press the Anland Termux app icon and review its settings."
read -rp "Press Enter after the display APK is installed and configured... " _

log "Step 3: Install Anland daemon in Termux"
ANLAND_DEB="anland_${ANLAND_VERSION}_aarch64.deb"
download "$ANLAND_RELEASE/$ANLAND_DEB" "$ASSET_DIR/$ANLAND_DEB"
pkg reinstall "$ASSET_DIR/$ANLAND_DEB" -y --allow-downgrades

log "Step 4: Install the Ubuntu 26.04 Resolute Plasma image"
pkg install -y proot-distro
if [[ -d "$ROOTFS_DIR" ]]; then
    echo "Found existing $DISTRO_NAME container; keeping it."
else
    proot-distro install "$UBUNTU_IMAGE" --name "$DISTRO_NAME"
fi

log "Step 5: Download Ubuntu-specific Anland graphics packages"
XWAYLAND_DEB="xwayland_24.1.10-91_arm64.deb"
KWIN_ZIP="kwin_anland-5.13-4_6.6.4-0ubuntu95.zip"
MESA_ARCHIVE="mesa-for-android-container_${MESA_VERSION}_ubuntu_resolute_arm64.tar.gz"
download "$ANLAND_RELEASE/$XWAYLAND_DEB" "$ASSET_DIR/$XWAYLAND_DEB"
download "$ANLAND_RELEASE/$KWIN_ZIP" "$ASSET_DIR/$KWIN_ZIP"
download "$MESA_RELEASE/$MESA_ARCHIVE" "$ASSET_DIR/$MESA_ARCHIVE"
download "$PLASMA_STARTER_URL" "$ASSET_DIR/startplasma-anland.sh"

log "Step 6: Install Anland KWin, XWayland, audio, and Freedreno in Ubuntu"
container bash -s <<'UBUNTU_SETUP'
set -euo pipefail
source /etc/os-release
[[ "${VERSION_CODENAME:-}" == "resolute" ]] || {
    echo "Expected Ubuntu Resolute, found ${VERSION_CODENAME:-unknown}." >&2
    exit 1
}

asset_dir=/tmp/anland-resolute-assets
kwin_dir="$asset_dir/kwin-debs"
mkdir -p "$kwin_dir"
apt-get update
apt-get install -y unzip pipewire-audio pipewire-libcamera
install -m 0755 "$asset_dir/startplasma-anland.sh" /usr/local/bin/startplasma-anland
unzip -oq "$asset_dir/kwin_anland-5.13-4_6.6.4-0ubuntu95.zip" -d "$kwin_dir"
shopt -s nullglob
kwin_debs=("$kwin_dir"/*.deb)
((${#kwin_debs[@]} > 0)) || {
    echo "The KWin archive did not contain any .deb packages." >&2
    exit 1
}
apt-get install -y "$asset_dir/xwayland_24.1.10-91_arm64.deb" "${kwin_debs[@]}"

tar -xzf "$asset_dir/mesa-for-android-container_26.3.0-devel-20260824_ubuntu_resolute_arm64.tar.gz" -C /
ldconfig

apt-get install -y vlc mpv xarchiver file-roller fastfetch htop

apt-mark hold xwayland libegl-mesa0 libgbm1 libgl1-mesa-dri libglx-mesa0 \
    mesa-libgallium mesa-vulkan-drivers kwin-common kwin-data kwin-wayland libkwin6
mkdir -p /etc/apt/preferences.d
cat > /etc/apt/preferences.d/hold-anland-package <<'HOLD_EOF'
Package: xwayland libegl-mesa0 libgbm1 libgl1-mesa-dri libglx-mesa0 mesa-libgallium mesa-vulkan-drivers kwin-common kwin-data kwin-wayland libkwin6
Pin: release *
Pin-Priority: -1
HOLD_EOF
UBUNTU_SETUP

read -rp "Install LibreOffice in Ubuntu? It is a large download (y/n) " install_libreoffice
if [[ "$install_libreoffice" == "y" || "$install_libreoffice" == "Y" ]]; then
    container apt-get install -y libreoffice
fi

read -rp "Install optional SteamOS-Ubuntu helper apps in this container? These are not the Steam client (y/n) " install_steam_helpers
if [[ "$install_steam_helpers" == "y" || "$install_steam_helpers" == "Y" ]]; then
    log "Step 7: Download SteamOS-Ubuntu helper packages"
    STEAM_PACKAGES=(
        "easy-ufs-install_1.0.0_arm64.deb"
        "emukitarm_1.0.4_arm64.deb"
        "gyro-desktop_1.0.0_arm64.deb"
        "mesa-easy-manager_1.0.1_arm64.deb"
        "no-steam-games_1.0.1_arm64.deb"
        "proton-arm-easy-manager_1.0.0_arm64.deb"
        "steamos-ubuntu-apps_1.0.3_all.deb"
    )
    mkdir -p "$ASSET_DIR/steam"
    for package in "${STEAM_PACKAGES[@]}"; do
        download "$STEAMOS_RELEASE/$package" "$ASSET_DIR/steam/$package"
    done

    if ! container bash -s <<'STEAM_SETUP'
set -euo pipefail
asset_dir=/tmp/anland-resolute-assets/steam
shopt -s nullglob
packages=("$asset_dir"/*.deb)
((${#packages[@]} > 0))
apt-get update
apt-get install -y "${packages[@]}"
STEAM_SETUP
    then
        echo "SteamOS helper installation failed; check whether all dependencies exist in the Ubuntu repositories."
        echo "The SteamOS helper packages are not the Steam client and may require system services unavailable in PRoot."
    fi
fi

log "Step 8: Create Plasma launcher"
cat > "$HOME/startplasma-anland.sh" <<'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

pkill -x anland 2>/dev/null || true
anland > "$HOME/anland-daemon.log" 2>&1 &

case "${TERMUX_APP__APK_RELEASE:-}" in
    F_DROID|ZERO_TERMUX)
        pkill -TERM -x anland-compatible 2>/dev/null || true
        anland-compatible > "$HOME/anland-compatible.log" 2>&1 &
        ;;
esac

exec proot-distro login ubuntu-anland --shared-tmp -- bash -c 'startplasma-anland'
LAUNCHER
chmod +x "$HOME/startplasma-anland.sh"

echo
echo "Installation complete. To start KDE Plasma:"
echo "1. Open the Anland Termux Android app."
echo "2. Run ~/startplasma-anland.sh in Termux."
echo "3. The optional SteamOS packages are helper apps only, not a Steam client."
echo "Ubuntu Chromium is not installed because its package uses Snap, which does not run normally in PRoot."