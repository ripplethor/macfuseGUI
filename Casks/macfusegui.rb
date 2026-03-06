cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.22"
  sha256 arm: "0b26c653cd4fde2e0f4b67a2b8cf4a7d0974ac361e262235fb36bf5dfb27cf96", intel: "35ce3eedc882d3824db6321cd9c4b68f5e86d7fc4a0b51e6b11888e55da5675b"

  url "https://github.com/ripplethor/macfuseGUI/releases/download/v#{version}/macfuseGui-v#{version}-macos-#{arch}.dmg",
      verified: "github.com/ripplethor/macfuseGUI/"
  name "macfuseGui"
  desc "SSHFS GUI for macOS using macFUSE"
  homepage "https://www.macfusegui.app/"

  depends_on macos: ">= :ventura"

  app "macFUSEGui.app"

  caveats <<~EOS
    This app is unsigned and not notarized.
    If macOS blocks launch, run:
      xattr -dr com.apple.quarantine "/Applications/macFUSEGui.app"
  EOS
end
