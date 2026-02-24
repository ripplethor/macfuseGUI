cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.11"
  sha256 arm: "f9024af965676de6152bcfe663c30b87341f1862a8139d942e15b9b08cef9f58", intel: "1c9e71c01f63ef24549bd2b332fb4c137dbdb3e782d6ebbc19ac9624d829b9c1"

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
