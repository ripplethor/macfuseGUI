cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.7"
  sha256 arm: "38fe0fd670dde3673252d3834c270a7c2ac4f26efde73e1e03480b7f9156f56b", intel: "c4399bf1482b32452b7dbbff568c8bb53e8b02cfe3321a3210504bee8bf1b559"

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
