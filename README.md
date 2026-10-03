# Anland Plasma on Ubuntu Resolute in Termux

This installer sets up **KDE Plasma on Ubuntu 26.04 Resolute in PRoot-Distro**, using [Anland: Termux](https://github.com/lfdevs/anland-termux). It follows the [official user guide](https://github.com/lfdevs/anland-termux/blob/main/docs/user-guide.md) and uses the project's prebuilt `resolute-anland-plasma` image.

## What gets installed

- Ubuntu Resolute PRoot-Distro image with KDE Plasma preconfigured
- Anland daemon in Termux, plus Ubuntu-specific Anland XWayland and KWin packages
- Ubuntu Resolute Freedreno/Mesa container driver
- PipeWire audio support and extra apps: VLC, MPV, Xarchiver, File Roller, Fastfetch, and Htop
- Optional LibreOffice
- Optional SteamOS-Ubuntu helper `.deb` packages, with dependencies resolved by Ubuntu `apt`; these are not the Steam client

## Requirements

- ARM64 Android device; Adreno GPU is required for the bundled Freedreno acceleration
- Termux from [GitHub releases](https://github.com/termux/termux-app/releases) or [F-Droid](https://f-droid.org/packages/com.termux/)
- Several GB of free storage for the Ubuntu root filesystem and graphics packages
- Stable internet connection
- Anland Termux display APK matching your Termux source; the installer prints which variant to use

## Install and run

1. Install the matching Anland Termux display APK from the [latest release](https://github.com/lfdevs/anland-termux/releases/latest). For F-Droid/ZeroTermux, use the compatible APK. Long-press its icon to configure it.

2. In Termux, download and run the installer:

   ```bash
   curl -LO https://raw.githubusercontent.com/asveroid/anland-plasma-termux/main/install-anland-plasma.sh
   chmod +x install-anland-plasma.sh
   ./install-anland-plasma.sh
   ```

3. Allow storage access and set battery use for both Termux and Anland Termux to Unrestricted / Don't optimize when prompted.

4. Open the **Anland Termux** app, then run this in Termux:

   ```bash
   ~/startplasma-anland.sh
   ```

5. KDE Plasma will start in the Anland Termux app.

## Notes

- The Ubuntu image already contains Plasma. The installer adds the matching Anland display packages and Mesa driver; do not install Termux-native KWin, Mesa, or LayerShellQt packages into this container.
- The optional SteamOS-Ubuntu packages are helper applications, not a Steam client. PRoot may not provide the hardware access or system services those helpers expect.
- Chromium is not installed because Ubuntu's package uses Snap, which does not run normally in PRoot.
- Package versions are pinned in the script. Check the [Anland releases](https://github.com/lfdevs/anland-termux/releases/latest) and [Mesa container releases](https://github.com/lfdevs/mesa-for-android-container/releases) before updating them.

## Credits

- [lfdevs/anland-termux](https://github.com/lfdevs/anland-termux) — Anland daemon, display packages, and Ubuntu images
- [lfdevs/mesa-for-android-container](https://github.com/lfdevs/mesa-for-android-container) — container Freedreno driver

## License

This installer is provided for personal/community use. Feel free to modify it to fit your device.