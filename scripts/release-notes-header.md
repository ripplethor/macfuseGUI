Unsigned macOS build (NOT code signed / NOT notarized)

macOS may block first launch.

Recommended install path (Terminal installer):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ripplethor/macfuseGUI/main/scripts/install_release.sh)"
```

Homebrew install (tap + cask):
```bash
brew tap ripplethor/macfusegui https://github.com/ripplethor/macfuseGUI
brew install --cask ripplethor/macfusegui/macfusegui
```

DMG fallback:
1) Open the DMG.
2) Open Terminal.
3) Run: /bin/bash "/Volumes/macfuseGui/Install macFUSEGui.command"
4) The installer copies the app to /Applications, clears quarantine, and opens it.

If Finder blocks the app anyway, use the direct command shown in INSTALL_IN_TERMINAL.txt inside the DMG.
